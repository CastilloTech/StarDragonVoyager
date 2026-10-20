extends Node
## ElementalAbilityManager: the selected element, mana costs, per-element
## cooldowns, and the five elemental abilities (ability slot 1).
## Slots 2-4 are reserved for abilities added in later phases.

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")

signal element_changed(element: int)

const VOID_RANGE := 4.5
const GRAVITY_RANGE := 7.0

var player: Node
var element: int = E.SUN
var cooldowns := [0.0, 0.0, 0.0, 0.0, 0.0]
var _release_t := -1.0
var _release_element := 0


func _ready() -> void:
	player = get_parent()


func cooldown_ratio(el: int) -> float:
	return cooldowns[el] / E.COOLDOWNS[el]


func cycle_element() -> void:
	element = (element + 1) % E.COUNT
	element_changed.emit(element)
	var col: Color = E.COLORS[element]
	Game.burst(player.global_position + Vector3.UP * 0.9, col, 10, 2.0, 0.06, 0.35, 0.0)
	Game.float_text(player.global_position + Vector3.UP * 2.1, E.NAMES[element], col, 28, 0.6)


func use_slot(slot: int) -> void:
	if slot != 1:
		Game.float_text(player.global_position + Vector3.UP * 2.0, "Locked", Color(0.7, 0.7, 0.8), 24, 0.5)
		return
	cast_ability()


func cast_ability() -> void:
	if not (player.is_free() or (player.in_action() and player.action_anim() != "charge" and player.action_anim() != "cast" and player.action_time_left() < 0.15)):
		return
	if cooldowns[element] > 0.0:
		return
	var cost: float = E.MANA_COSTS[element]
	if not player.spend_mana(cost):
		Game.float_text(player.global_position + Vector3.UP * 2.0, "No mana", Color(0.5, 0.7, 1.0), 26, 0.6)
		return
	cooldowns[element] = E.COOLDOWNS[element]
	player.combat.cancel()
	player.start_action("cast", SpriteFactory.anim_duration("cast"), 0.3)
	_release_element = element
	_release_t = SpriteFactory.strike_time("cast")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_element"):
		cycle_element()
	for i in 4:
		if event.is_action_pressed("ability_%d" % (i + 1)):
			use_slot(i + 1)


func _physics_process(delta: float) -> void:
	for i in cooldowns.size():
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	if _release_t >= 0.0:
		_release_t -= delta
		if _release_t < 0.0:
			if player.action_anim() == "cast":
				_release(_release_element)


func _release(el: int) -> void:
	var hand: Vector3 = player.hand_position()
	var aim: Vector3 = player.aim_dir
	var col: Color = E.COLORS[el]
	Game.flash_light(hand, col, 3.0, 0.2)
	Game.burst(hand, col, 8, 2.5, 0.06, 0.25, 0.0)
	match el:
		0:  # Sun: Solar Flare - fireball that explodes and burns
			_spawn_projectile({"element": el, "dir": aim, "speed": 15.0, "damage": 12.0, "radius": 0.5,
				"life": 1.1, "explode_radius": 1.8, "explode_damage": 8.0, "knockback": 2.5}, hand)
		1:  # Comet: Comet Shard - fast piercing frost shard that chills, then freezes
			_spawn_projectile({"element": el, "dir": aim, "speed": 24.0, "damage": 10.0, "radius": 0.4,
				"life": 0.75, "pierce": 2, "knockback": 1.0}, hand)
		2:  # Storm: Arc Lightning - instant chain between nearby enemies
			_arc_lightning(hand, aim)
		3:  # Gravity: Gravity Well - orb that becomes a pulling vortex
			var to: Vector3 = player.aim_point - player.global_position
			to.y = 0.0
			var dist := clampf(to.length(), 2.0, GRAVITY_RANGE)
			_spawn_projectile({"element": el, "dir": aim, "speed": 12.0, "damage": 4.0, "radius": 0.45,
				"life": dist / 12.0, "well": true, "knockback": 0.0}, hand)
		4:  # Void: Void Step - blink forward, burst on arrival, hex enemies
			_void_step(aim)


func _spawn_projectile(cfg: Dictionary, pos: Vector3) -> void:
	var p := Projectile.new()
	p.configure(cfg)
	p.position = pos
	Game.world.add_child(p)


func _arc_lightning(from: Vector3, aim: Vector3) -> void:
	var col: Color = E.COLORS[E.STORM]
	var targets := []
	var first: Node3D = _closest_enemy(player.global_position, 9.0, aim, 0.35, targets)
	var points := [from]
	if first == null:
		points.append(from + aim * 6.0)
		Game.lightning_fx(points, col)
		return
	var cur: Node3D = first
	while cur != null and targets.size() < 3:
		targets.append(cur)
		points.append(cur.global_position + Vector3.UP * 0.5)
		cur = _closest_enemy(cur.global_position, 5.0, Vector3.ZERO, -2.0, targets)
	Game.lightning_fx(points, col)
	var dmg := [15.0, 11.0, 8.0]
	for i in targets.size():
		var t: Node3D = targets[i]
		var dir: Vector3 = t.global_position - player.global_position
		dir.y = 0.0
		t.take_damage(Damage.make(dmg[i], E.STORM, dir.normalized(), 1.5, true, 0.08, player))
	Game.hitstop(0.05)
	Game.shake(0.25)


func _closest_enemy(origin: Vector3, max_dist: float, dir: Vector3, min_dot: float, exclude: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e in Game.enemies():
		if e in exclude or not e.can_be_hit():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > max_dist:
			continue
		if dir != Vector3.ZERO and d > 0.5 and dir.dot(to / d) < min_dot:
			continue
		if d < best_d:
			best_d = d
			best = e
	return best


func _void_step(aim: Vector3) -> void:
	var col: Color = E.COLORS[E.VOID]
	var start: Vector3 = player.global_position
	var to: Vector3 = player.aim_point - start
	to.y = 0.0
	var dist := clampf(to.length(), 2.0, VOID_RANGE)
	var target := start + aim * dist
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 0.6, target + Vector3.UP * 0.6, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		target = Vector3(hp.x, 0.0, hp.z) - aim * 0.5
	Game.burst(start + Vector3.UP * 0.6, Color(0.05, 0.0, 0.08), 12, 2.0, 0.12, 0.6, 1.0, false)
	Game.burst(start + Vector3.UP * 0.6, col, 12, 3.0, 0.07, 0.4, 0.5)
	player.teleport_to(target)
	Game.ring_fx(target, col, 1.8, 0.35)
	Game.burst(target + Vector3.UP * 0.6, col, 18, 4.0, 0.08, 0.45, 0.5)
	Game.flash_light(target + Vector3.UP, col, 4.0, 0.3)
	var hits := 0
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var d: Vector3 = e.global_position - target
		d.y = 0.0
		if d.length() < 1.8 + e.radius:
			e.take_damage(Damage.make(14.0, E.VOID, d.normalized() if d.length() > 0.01 else aim, 5.0, true, 0.08, player))
			hits += 1
	if hits > 0:
		Game.hitstop(0.06)
		Game.shake(0.3)
