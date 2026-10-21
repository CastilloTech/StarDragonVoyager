extends Node3D
## DragonCompanionController: Nova, a Comet-element star dragon.
##  - Follows the captain, hovering behind and to one side.
##  - Engages enemies near the captain with frost breath (chills; 2 chills = freeze).
##  - Special (F / DRAGON button): Comet Shower - flies over the target area and
##    rains frost comets.
##  - Can be hit; knocked out at 0 HP and recovers after REVIVE_TIME.
##  - Personality: chirps, idle loops and glances, a happy spin when enemies fall.
## The node sits on the ground (for distance checks and the shadow); the sprite
## flies above it inside `visual`.

const E := preload("res://scripts/core/elements.gd")
const HD2D := preload("res://scripts/core/hd2d.gd")
const Damage := preload("res://scripts/core/damage.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")
const Health := preload("res://scripts/components/health_component.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")
const CometStrike := preload("res://scripts/dragon/comet_strike.gd")

signal knocked_out
signal revived

const DRAGON_NAME := "Nova"
const ELEMENT := E.COMET
const HOVER_HEIGHT := 1.35
const MAX_SPEED := 8.5
const ACCEL := 20.0
const ENGAGE_RADIUS := 7.5     # enemies this close to the captain get attacked
const LEASH := 8.0             # never strays further than this from the captain
const BREATH_RANGE := 4.0
const ATTACK_CD := 1.6
const SPECIAL_CD := 14.0
const SPECIAL_RADIUS := 2.8
const SPECIAL_COMETS := 7
const REVIVE_TIME := 10.0
const RADIUS := 0.4

var health: Node
var sprite: AnimatedSprite3D
var visual: Node3D
var state := "follow"
var state_time := 0.0
var velocity := Vector3.ZERO
var target: Node3D = null
var face := 1.0
var attack_cd := 1.0
var special_cd := 0.0
var revive_t := 0.0
var radius := RADIUS

var _side := 1.0
var _look_dir := Vector3(1, 0, 0)
var _anim := "hover"
var _idle_t := 3.0
var _flash := 0.0
var _invuln := 0.0
var _bob_t := 0.0
var _height := HOVER_HEIGHT
var _wing_sfx := 0.0
var _breathed := false
var _special_center := Vector3.ZERO
var _comets_left := 0
var _comet_t := 0.0
var _spin := 0.0


func _ready() -> void:
	add_to_group("allies")
	health = Health.new()
	health.setup(60.0)
	add_child(health)
	visual = Node3D.new()
	visual.position.y = HOVER_HEIGHT
	add_child(visual)
	sprite = HD2D.make_animated_sprite(SpriteFactory.dragon_frames(), SpriteFactory.dragon_center_offset())
	visual.add_child(sprite)
	_play("hover", true)
	add_child(Game.make_blob_shadow(0.4))


# ---------------------------------------------------------------- queries

func is_alive() -> bool:
	return state != "ko"


func is_invulnerable() -> bool:
	return _invuln > 0.0 or state == "ko"


func special_ratio() -> float:
	return special_cd / SPECIAL_CD


func mouth_position() -> Vector3:
	return visual.global_position + Vector3(_look_dir.x * 0.55, 0.15, _look_dir.z * 0.4)


## Turn to face a direction on the ground plane (picks the front / back / side sprites).
func _look(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	_look_dir = dir.normalized()
	if absf(_look_dir.x) > 0.15:
		face = signf(_look_dir.x)


func _facing() -> String:
	if absf(_look_dir.x) > absf(_look_dir.z) * 0.85:
		return "side"
	return "down" if _look_dir.z > 0.0 else "up"


## Plays an animation for the current facing; keeps its timing when only the facing changes.
func _play(anim: String, restart := false) -> void:
	_anim = anim
	var full := "%s_%s" % [anim, _facing()]
	if restart:
		sprite.play(full)
		sprite.set_frame_and_progress(0, 0.0)
	elif sprite.animation != full:
		var f := sprite.frame
		var p := sprite.frame_progress
		var same := sprite.animation.begins_with(anim + "_")
		sprite.play(full)
		if same:
			sprite.set_frame_and_progress(f, p)


# ---------------------------------------------------------------- commands

func request_special() -> void:
	if state == "ko":
		Game.float_text(global_position + Vector3.UP * 2.0, "%s is down" % DRAGON_NAME, Color(0.7, 0.8, 1.0), 24, 0.6)
		return
	if special_cd > 0.0 or state.begins_with("special"):
		return
	special_cd = SPECIAL_CD
	_special_center = _pick_special_center()
	_change("special_rise")


func take_damage(info: Dictionary) -> void:
	if is_invulnerable():
		return
	var amount: float = info["amount"]
	health.apply_damage(amount)
	Game.damage_number(global_position + Vector3.UP * 0.4, amount, Color(1.0, 0.5, 0.6))
	_flash = 0.12
	_invuln = 0.5
	var dir: Vector3 = info["dir"]
	velocity += dir * 4.0
	Audio.play("chirp_hurt")
	if health.is_dead():
		_change("ko")
	elif not state.begins_with("special"):
		_change("hit")


func on_enemy_defeated(_enemy: Node) -> void:
	if state == "follow" or state == "engage":
		_spin = 1.0
		Audio.play("chirp_happy", -3.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dragon_special"):
		request_special()


# ---------------------------------------------------------------- loop

func _change(new_state: String) -> void:
	state = new_state
	state_time = 0.0
	match new_state:
		"attack":
			_play("attack", true)
			_breathed = false
		"special_rise":
			_play("special", true)
			Audio.play("roar")
			Game.float_text(global_position + Vector3.UP * 2.6, "Comet Shower!", E.COLORS[ELEMENT], 34, 0.9)
		"special_rain":
			_comets_left = SPECIAL_COMETS
			_comet_t = 0.0
		"hit":
			_play("hit", true)
		"ko":
			_play("ko", true)
			revive_t = REVIVE_TIME
			knocked_out.emit()
			Game.float_text(global_position + Vector3.UP * 1.6, "%s is down!" % DRAGON_NAME, Color(0.7, 0.8, 1.0), 30, 1.0)


func _physics_process(delta: float) -> void:
	state_time += delta
	attack_cd -= delta
	special_cd = maxf(special_cd - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	var player := Game.player
	if player == null or not is_instance_valid(player):
		return
	var desired_height := HOVER_HEIGHT
	match state:
		"follow":
			_st_follow(delta, player)
		"engage":
			_st_engage(delta, player)
		"attack":
			_st_attack(delta)
		"special_rise":
			desired_height = HOVER_HEIGHT + 1.4
			_steer_to(_special_center + Vector3(-face * 0.5, 0, 0.6), delta, MAX_SPEED * 1.4)
			if state_time >= 0.6:
				_change("special_rain")
		"special_rain":
			desired_height = HOVER_HEIGHT + 1.4
			_steer_to(_special_center + Vector3(-face * 0.5, 0, 0.6), delta, MAX_SPEED)
			_st_special_rain(delta)
		"hit":
			velocity = velocity.move_toward(Vector3.ZERO, ACCEL * delta)
			if state_time >= SpriteFactory.dragon_duration("hit"):
				_change("follow")
		"ko":
			desired_height = 0.15
			velocity = velocity.move_toward(Vector3.ZERO, ACCEL * delta)
			revive_t -= delta
			if revive_t <= 0.0:
				_revive()
	global_position += velocity * delta
	global_position.y = 0.0
	_height = lerpf(_height, desired_height, 1.0 - exp(-6.0 * delta))
	_update_visuals(delta)


func _steer_to(point: Vector3, delta: float, max_speed := MAX_SPEED) -> float:
	var to := point - global_position
	to.y = 0.0
	var dist := to.length()
	var want := Vector3.ZERO
	if dist > 0.05:
		want = to / dist * minf(max_speed, dist * 3.5)
	velocity = velocity.move_toward(want, ACCEL * delta)
	return dist


func _st_follow(delta: float, player: Node3D) -> void:
	_play("fly" if velocity.length() > 2.5 else "hover")
	var aim: Vector3 = player.aim_dir
	var perp := Vector3(-aim.z, 0, aim.x)
	var spot: Vector3 = player.global_position - aim * 1.0 + perp * _side * 1.3
	var dist := _steer_to(spot, delta)
	if dist < 0.6:
		_look(aim)
		_idle_t -= delta
		if _idle_t <= 0.0:
			_idle_t = randf_range(4.0, 8.0)
			_idle_flourish()
	elif velocity.length() > 0.6:
		_look(velocity)
	var t := _pick_target(player)
	if t and attack_cd <= 0.5:
		target = t
		_change("engage")


func _st_engage(delta: float, player: Node3D) -> void:
	_play("fly" if velocity.length() > 2.5 else "hover")
	if target == null or not is_instance_valid(target) or not target.can_be_hit() \
			or global_position.distance_to(player.global_position) > LEASH:
		target = _pick_target(player)
		if target == null:
			_change("follow")   # back to the captain once the fight is over
			return
	var tpos: Vector3 = target.global_position
	var away := global_position - tpos
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(-face, 0, 0)
	var spot := tpos + away.normalized() * (BREATH_RANGE * 0.7)
	# Stay on the leash.
	var from_player := spot - player.global_position
	if from_player.length() > LEASH * 0.8:
		spot = player.global_position + from_player.normalized() * LEASH * 0.8
	var dist := _steer_to(spot, delta, MAX_SPEED * 1.1)
	var to_t := tpos - global_position
	_look(to_t if dist < 1.5 or velocity.length() < 1.0 else velocity)
	if attack_cd <= 0.0 and dist < 1.2 and to_t.length() < BREATH_RANGE + 1.0:
		_change("attack")


func _st_attack(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, ACCEL * delta)
	if target and is_instance_valid(target) and not _breathed:
		_look(target.global_position - global_position)
	if not _breathed and state_time >= SpriteFactory.dragon_strike_time("attack"):
		_breathed = true
		_breathe()
	if state_time >= SpriteFactory.dragon_duration("attack"):
		attack_cd = ATTACK_CD
		_change("engage")


func _breathe() -> void:
	var from := mouth_position()
	var dir := _look_dir
	if target and is_instance_valid(target):
		dir = target.global_position + Vector3.UP * 0.5 - from
		dir.y = 0.0
		dir = dir.normalized()
	var p := Projectile.new()
	p.configure({"element": ELEMENT, "dir": dir, "speed": 16.0, "damage": 7.0, "radius": 0.45,
		"life": 0.55, "knockback": 1.0})
	p.position = Vector3(from.x, 0.75, from.z)
	Game.world.add_child(p)
	Game.burst(from, E.COLORS[ELEMENT], 8, 2.5, 0.06, 0.25, 0.0)
	Audio.play("breath", -3.0)


func _st_special_rain(delta: float) -> void:
	_comet_t -= delta
	if _comets_left > 0 and _comet_t <= 0.0:
		_comet_t = 0.17
		_comets_left -= 1
		var spot := _special_center + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * SPECIAL_RADIUS
		# Aim the first comets straight at enemies inside the area.
		var inside := []
		for e in Game.enemies():
			if e.can_be_hit() and e.global_position.distance_to(_special_center) < SPECIAL_RADIUS + 0.5:
				inside.append(e)
		if not inside.is_empty() and _comets_left % 2 == 0:
			spot = (inside.pick_random() as Node3D).global_position
		var c := CometStrike.new()
		c.position = Vector3(spot.x, 0.0, spot.z)
		Game.world.add_child(c)
	if _comets_left <= 0 and _comet_t <= -0.3:
		attack_cd = 0.6
		_change("follow")


func _pick_target(player: Node3D) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var dp: float = e.global_position.distance_to(player.global_position)
		if dp > ENGAGE_RADIUS:
			continue
		var score: float = e.global_position.distance_to(global_position) + dp * 0.5
		if score < best_score:
			best_score = score
			best = e
	return best


func _pick_special_center() -> Vector3:
	var player := Game.player
	if player.mouse_aim and not Game.touch_controls:
		var ap: Vector3 = player.aim_point
		var off: Vector3 = ap - player.global_position
		var center: Vector3 = player.global_position + off.limit_length(8.0)
		# Snap onto the enemies near the cursor so a slightly-off aim isn't wasted.
		var sum := Vector3.ZERO
		var count := 0
		for e in Game.enemies():
			if e.global_position.distance_to(center) < 3.0:
				sum += e.global_position
				count += 1
		return sum / count if count > 0 else center
	# Touch / keyboard: the enemy with the most neighbours near the captain.
	var best: Vector3 = player.global_position + player.aim_dir * 3.0
	var best_n := -1
	for e in Game.enemies():
		if e.global_position.distance_to(player.global_position) > 9.0:
			continue
		var n := 0
		for o in Game.enemies():
			if o.global_position.distance_to(e.global_position) < SPECIAL_RADIUS:
				n += 1
		if n > best_n:
			best_n = n
			best = e.global_position
	return best


func _idle_flourish() -> void:
	match randi() % 3:
		0:
			_spin = 1.0   # little loop
			Audio.play("chirp", -6.0)
		1:
			_look(Vector3(-_look_dir.x if absf(_look_dir.x) > 0.2 else -face, 0, 0))  # glance around
		2:
			_side = -_side   # switch shoulders
			Audio.play("chirp", -8.0)


func _revive() -> void:
	health.heal(health.max_health * 0.5)
	_invuln = 1.5
	_change("follow")
	_play("hover", true)
	revived.emit()
	Game.burst(global_position + Vector3.UP * 0.6, E.COLORS[ELEMENT], 18, 3.0, 0.07, 0.6, 1.5)
	Game.float_text(global_position + Vector3.UP * 2.0, "%s is back!" % DRAGON_NAME, E.COLORS[ELEMENT], 28, 0.9)
	Audio.play("chirp_happy")


func _update_visuals(delta: float) -> void:
	_bob_t += delta
	var bob := sin(_bob_t * 3.2) * 0.1 if state != "ko" else 0.0
	visual.position.y = _height + bob
	_play(_anim)   # refresh the facing (front / back / side)
	sprite.flip_h = face < 0.0 and _facing() == "side"
	# Bank into turns and play the loop/spin flourish by rolling the sprite.
	var bank := clampf(-velocity.x * 0.035, -0.3, 0.3) if state != "ko" else 0.0
	if _spin > 0.0:
		_spin = maxf(_spin - delta * 2.2, 0.0)
		bank += (1.0 - _spin) * TAU * (-face)
		if _spin == 0.0:
			bank = 0.0
	visual.rotation.z = lerp_angle(visual.rotation.z, bank, 1.0 - exp(-14.0 * delta)) if _spin == 0.0 else bank
	sprite.speed_scale = 1.0 + clampf(velocity.length() / MAX_SPEED, 0.0, 1.0) * 0.6 if state == "follow" or state == "engage" else 1.0
	if _flash > 0.0:
		sprite.modulate = Color(3, 3, 3)
	elif _invuln > 0.0 and state != "ko":
		sprite.modulate = Color(1, 1, 1, 1) if int(_invuln * 16.0) % 2 == 0 else Color(1.4, 1.6, 2.0)
	else:
		sprite.modulate = Color(1, 1, 1)
	# Wingbeats when moving fast.
	_wing_sfx -= delta
	if velocity.length() > 4.0 and _wing_sfx <= 0.0 and state != "ko":
		_wing_sfx = 0.32
		Audio.play("wingbeat", -14.0, 0.15)
