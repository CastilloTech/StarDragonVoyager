extends Node
## ElementalAbilityManager: the captain's spells come from the active dragon.
## The dragon's element picks the spell set (spells.gd); its evolution stage decides
## how many are unlocked (Hatchling 1, Drake 2, Wyrm 3). Q / E / wheel cycle the
## unlocked spells, 1-3 pick one, right click casts it.
##
## Damage scales with spell power, cooldowns with cooldown reduction (Progress.stats()).
## Spellblade skills hook in here: Spell Weave and Dragon's Echo.

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")
const Spells := preload("res://scripts/core/spells.gd")
const Skills := preload("res://scripts/core/skills.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")
const GravityWell := preload("res://scripts/combat/gravity_well.gd")
const StormField := preload("res://scripts/combat/storm_field.gd")
const Strike := preload("res://scripts/dragon/comet_strike.gd")

signal spell_changed(index: int)

var player: Node
var element: int = E.COMET
var spell_index := 0
var cooldowns := [0.0, 0.0, 0.0]
var _release_t := -1.0
var _cast_buffer := 0.0
var _release_spell := {}


func _ready() -> void:
	player = get_parent()
	Progress.changed.connect(_sync_with_dragon)
	_sync_with_dragon()


## Called when the active dragon (or its stage) changes.
func _sync_with_dragon() -> void:
	var el := Progress.active_element()
	if el != element:
		element = el
		cooldowns = [0.0, 0.0, 0.0]
	spell_index = mini(spell_index, unlocked() - 1)


func unlocked() -> int:
	return Progress.spells_unlocked()


func current_spell() -> Dictionary:
	return Spells.spell(element, spell_index)


func cooldown_of(spell: Dictionary) -> float:
	return spell["cd"] * (1.0 - Progress.stats()["cdr"])


func cooldown_ratio(_unused := 0) -> float:
	var cd := cooldown_of(current_spell())
	return cooldowns[spell_index] / cd if cd > 0.0 else 0.0


func cooldown_left() -> float:
	return cooldowns[spell_index]


# ---------------------------------------------------------------- selecting

func cycle_spell(step := 1) -> void:
	var n := unlocked()
	if n <= 1:
		Game.float_text(player.global_position + Vector3.UP * 2.0, "Evolve your dragon to unlock more spells",
			Color(0.75, 0.75, 0.85), 22, 0.9)
		return
	select_spell((spell_index + step + n) % n)


## Old name kept for the touch button.
func cycle_element(step := 1) -> void:
	cycle_spell(step)


func select_spell(i: int) -> void:
	if i >= unlocked():
		var stage_name: String = ["Hatchling", "Drake", "Wyrm"][i]
		Game.float_text(player.global_position + Vector3.UP * 2.0, "Unlocks when your dragon becomes a %s" % stage_name,
			Color(0.75, 0.75, 0.85), 22, 0.9)
		return
	if i == spell_index:
		return
	spell_index = i
	spell_changed.emit(i)
	Audio.play("switch", -2.0, 0.0, "SFX", 0.9 + 0.1 * i)
	var col: Color = E.COLORS[element]
	Game.burst(player.global_position + Vector3.UP * 0.9, col, 10, 2.0, 0.06, 0.35, 0.0)
	Game.float_text(player.global_position + Vector3.UP * 2.1, current_spell()["name"], col, 26, 0.7)


func use_slot(_slot: int) -> void:
	cast_ability()


# ---------------------------------------------------------------- casting

func cast_ability() -> void:
	_cast_buffer = 0.3
	_try_buffered_cast()


func _can_cast_now() -> bool:
	return player.is_free() or (player.in_action() and player.action_anim() != "charge" \
		and player.action_anim() != "cast" and player.action_time_left() < 0.15)


## Cast requests are buffered briefly (like attacks), so right-clicking during a
## swing casts as soon as the swing allows.
func _try_buffered_cast() -> void:
	if _cast_buffer > 0.0 and cooldowns[spell_index] <= 0.0 and _can_cast_now():
		_cast_buffer = 0.0
		_do_cast()


func _do_cast() -> void:
	var spell := current_spell()
	if not player.spend_mana(spell["cost"]):
		Game.float_text(player.global_position + Vector3.UP * 2.0, "No mana", Color(0.5, 0.7, 1.0), 26, 0.6)
		return
	cooldowns[spell_index] = cooldown_of(spell)
	player.combat.cancel()
	player.start_action("cast", SpriteFactory.anim_duration("cast"), 0.3)
	_release_spell = spell
	_release_t = SpriteFactory.strike_time("cast")


func _input(event: InputEvent) -> void:
	# Mouse clicks are read before the UI so the HUD can never swallow them.
	if event.is_action_pressed("cast_spell") and not Game.touch_controls and not get_tree().paused:
		cast_ability()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("element_next"):
		cycle_spell(1)
	elif event.is_action_pressed("element_prev"):
		cycle_spell(-1)
	else:
		for i in 3:
			if event.is_action_pressed("element_%d" % (i + 1)):
				select_spell(i)
				break


func _physics_process(delta: float) -> void:
	for i in cooldowns.size():
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	_cast_buffer -= delta
	_try_buffered_cast()
	if _release_t >= 0.0:
		_release_t -= delta
		if _release_t < 0.0 and player.action_anim() == "cast":
			_release(_release_spell)
			_after_cast(_release_spell)


## Spellblade hooks after a cast.
func _after_cast(spell: Dictionary) -> void:
	var weave := Progress.skill_rank("spell_weave")
	if weave > 0:
		player.combat.weave_charges = 2
		player.combat.weave_bonus = Skills.value_for(Skills.WEAVE_BONUS, weave)
	if Progress.skill_rank("dragons_echo") > 0:
		if Game.dragon and is_instance_valid(Game.dragon):
			Game.dragon.special_cd = maxf(Game.dragon.special_cd - 1.0, 0.0)
		if randf() < 0.25:
			await get_tree().create_timer(0.25, false).timeout
			if is_inside_tree() and player.is_alive():
				Game.float_text(player.global_position + Vector3.UP * 2.2, "Echo!", E.COLORS[element], 24, 0.6)
				_release(spell)


# ---------------------------------------------------------------- spell effects

func _release(spell: Dictionary) -> void:
	var el := element
	var hand: Vector3 = player.hand_position()
	var aim: Vector3 = player.aim_dir
	var col: Color = E.COLORS[el]
	var sp: float = Progress.stats()["spell_power"]
	var dmg: float = spell["damage"] * sp
	Game.flash_light(hand, col, 3.0, 0.2)
	Game.burst(hand, col, 8, 2.5, 0.06, 0.25, 0.0)
	Audio.play(["cast_sun", "cast_comet", "cast_storm", "cast_gravity", "cast_void"][el])
	match spell["kind"]:
		"projectile":
			var cfg := spell.duplicate()
			cfg["element"] = el
			cfg["dir"] = aim
			cfg["damage"] = dmg
			if cfg.has("explode_damage"):
				cfg["explode_damage"] = spell["explode_damage"] * sp
			_spawn_projectile(cfg, hand)
		"chain":
			_chain_lightning(hand, aim, dmg, spell["jumps"], spell["range"])
		"well":
			var to: Vector3 = player.aim_point - player.global_position
			to.y = 0.0
			var dist := clampf(to.length(), 2.0, spell["range"])
			_spawn_projectile({"element": el, "dir": aim, "speed": 12.0, "damage": 4.0 * sp, "radius": 0.45,
				"life": dist / 12.0, "well": true, "knockback": 0.0,
				"well_cfg": {"pull_radius": spell["radius"], "duration": spell["duration"], "pull_strength": spell["strength"],
					"implode_damage": dmg, "tick_damage": dmg * 0.2}}, hand)
		"teleport":
			_void_step(aim, dmg, spell["range"], spell["radius"])
		"cone":
			_cone(el, aim, dmg, spell["range"], spell["dot"], spell["knockback"])
		"nova":
			_nova(el, dmg, spell["radius"], spell["knockback"])
		"blast":
			_strike_at(el, _aim_point(spell["range"]), dmg, spell["radius"], spell["delay"], false)
		"strike":
			_strike_at(el, _aim_point(spell["range"]), dmg, spell["radius"], 0.22, true)
		"line":
			_spike_line(el, aim, dmg, spell["count"], spell["spacing"], spell["spike_radius"])
		"field":
			var f := StormField.new()
			f.follow = player
			f.radius = spell["radius"]
			f.duration = spell["duration"]
			f.tick = spell["tick"]
			f.damage = dmg
			f.position = Vector3(player.global_position.x, 0.0, player.global_position.z)
			Game.world.add_child(f)
		"homing":
			_homing_bolts(el, hand, aim, dmg, spell["count"])


func _aim_point(max_range: float) -> Vector3:
	var start: Vector3 = player.global_position
	var to: Vector3 = player.aim_point - start
	to.y = 0.0
	if to.length() < 0.5:
		to = player.aim_dir * 3.0
	return start + to.limit_length(max_range)


func _spawn_projectile(cfg: Dictionary, pos: Vector3) -> void:
	var p := Projectile.new()
	p.configure(cfg)
	p.position = pos
	Game.world.add_child(p)


func _hit(e: Node3D, amount: float, el: int, dir: Vector3, kb: float) -> void:
	e.take_damage(Damage.make(amount, el, dir.normalized() if dir.length() > 0.01 else player.aim_dir, kb, true, 0.08, player))


func _chain_lightning(from: Vector3, aim: Vector3, dmg: float, jumps: int, max_range: float) -> void:
	var col: Color = E.COLORS[E.STORM]
	var targets := []
	var first: Node3D = _closest_enemy(player.global_position, max_range, aim, 0.35, targets)
	var points := [from]
	if first == null:
		points.append(from + aim * 6.0)
		Game.lightning_fx(points, col)
		return
	var cur: Node3D = first
	while cur != null and targets.size() < jumps:
		targets.append(cur)
		points.append(cur.global_position + Vector3.UP * 0.5)
		cur = _closest_enemy(cur.global_position, 5.0, Vector3.ZERO, -2.0, targets)
	Game.lightning_fx(points, col)
	for i in targets.size():
		var t: Node3D = targets[i]
		_hit(t, dmg * pow(0.73, i), E.STORM, t.global_position - player.global_position, 1.5)
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


func _void_step(aim: Vector3, dmg: float, max_range: float, radius: float) -> void:
	var col: Color = E.COLORS[E.VOID]
	var start: Vector3 = player.global_position
	var to: Vector3 = player.aim_point - start
	to.y = 0.0
	var dist := clampf(to.length(), 2.0, max_range)
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
	Game.ring_fx(target, col, radius, 0.35)
	Game.burst(target + Vector3.UP * 0.6, col, 18, 4.0, 0.08, 0.45, 0.5)
	Game.flash_light(target + Vector3.UP, col, 4.0, 0.3)
	var hits := 0
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var d: Vector3 = e.global_position - target
		d.y = 0.0
		if d.length() < radius + e.radius:
			_hit(e, dmg, E.VOID, d, 5.0)
			hits += 1
	if hits > 0:
		Game.hitstop(0.06)
		Game.shake(0.3)


## Flame Wave: everything in a cone in front of you.
func _cone(el: int, aim: Vector3, dmg: float, reach: float, min_dot: float, kb: float) -> void:
	var col: Color = E.COLORS[el]
	var origin: Vector3 = player.global_position
	Game.slash_fx(origin + Vector3.UP * 0.5, aim, col, reach * 2.2, 0.3)
	for k in 5:
		var spread := aim.rotated(Vector3.UP, randf_range(-0.6, 0.6))
		Game.burst(origin + Vector3.UP * 0.5 + spread * (1.0 + k * 0.7), col, 8, 3.0, 0.1, 0.45, 2.0)
	var hits := 0
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d < reach + e.radius and (d < 0.6 or aim.dot(to / d) >= min_dot):
			_hit(e, dmg, el, to, kb)
			hits += 1
	Game.shake(0.25)
	if hits > 0:
		Game.hitstop(0.05)


## Frost Nova / Repulse: a burst around the captain.
func _nova(el: int, dmg: float, radius: float, kb: float) -> void:
	var col: Color = E.COLORS[el]
	var origin: Vector3 = player.global_position
	Game.ring_fx(origin, col, radius, 0.35)
	Game.burst(origin + Vector3.UP * 0.4, col.lerp(Color.WHITE, 0.3), 26, 6.0, 0.09, 0.45, -2.0)
	Game.flash_light(origin + Vector3.UP, col, 4.0, 0.3, radius * 2.0)
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		if to.length() < radius + e.radius:
			_hit(e, dmg, el, to, kb)
	Game.shake(0.3)


## Supernova / Thunder Strike: a strike landing at a point after a short warning.
func _strike_at(el: int, pos: Vector3, dmg: float, radius: float, delay: float, bolt: bool) -> void:
	var s := Strike.new()
	s.element = el
	s.damage = dmg
	s.radius = radius
	s.fall_time = delay
	s.bolt = bolt
	s.source = player
	s.position = Vector3(pos.x, 0.0, pos.z)
	Game.world.add_child(s)


## Glacial Spikes: spikes erupt one after another along the aim.
func _spike_line(el: int, aim: Vector3, dmg: float, count: int, spacing: float, spike_radius: float) -> void:
	var col: Color = E.COLORS[el]
	var start: Vector3 = player.global_position
	var already := []
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for i in count:
		await get_tree().create_timer(0.06, false).timeout
		if not is_inside_tree():
			return
		var p := start + aim * spacing * (i + 1)
		var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(start + Vector3.UP * 0.5, p + Vector3.UP * 0.5, 1))
		if not blocked.is_empty():
			break
		_spike_visual(p, col)
		for e in Game.enemies():
			if e in already or not e.can_be_hit():
				continue
			var d: Vector3 = e.global_position - p
			d.y = 0.0
			if d.length() < spike_radius + e.radius:
				already.append(e)
				_hit(e, dmg, el, aim, 3.0)
	Game.shake(0.2)


func _spike_visual(p: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.45, 1.2, 0.45)
	mi.mesh = prism
	var m := StandardMaterial3D.new()
	m.albedo_color = col.lerp(Color.WHITE, 0.4)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	Game.world.add_child(mi)
	mi.global_position = p + Vector3(randf_range(-0.15, 0.15), -0.6, randf_range(-0.15, 0.15))
	mi.rotation.y = randf() * TAU
	Game.burst(p + Vector3.UP * 0.3, col.lerp(Color.WHITE, 0.5), 8, 3.0, 0.07, 0.35, -6.0)
	Audio.play("freeze", -8.0, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position:y", 0.55, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mi.queue_free)


## Rift Barrage: bolts that seek out different nearby enemies.
func _homing_bolts(el: int, hand: Vector3, aim: Vector3, dmg: float, count: int) -> void:
	var targets := []
	for e in Game.enemies():
		if e.can_be_hit() and e.global_position.distance_to(player.global_position) < 11.0:
			targets.append(e)
	targets.sort_custom(func(a, b): return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	for i in count:
		var spread := aim.rotated(Vector3.UP, lerpf(-1.1, 1.1, float(i) / maxf(count - 1, 1)))
		var tgt: Node3D = targets[i % targets.size()] if not targets.is_empty() else null
		_spawn_projectile({"element": el, "dir": spread, "speed": 10.0, "damage": dmg, "radius": 0.4,
			"life": 1.6, "knockback": 1.5, "homing": tgt}, hand)
