extends CharacterBody3D
## PlayerController: 8-direction movement, dodge with i-frames, facing,
## animation state and vitals (health, mana, stamina).
## Attacks live in CombatController and spells in ElementalAbilityManager (children).

const HD2D := preload("res://scripts/core/hd2d.gd")
const E := preload("res://scripts/core/elements.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")
const Health := preload("res://scripts/components/health_component.gd")
const Combat := preload("res://scripts/player/combat_controller.gd")
const Abilities := preload("res://scripts/player/elemental_ability_manager.gd")

signal knocked_out

enum State { FREE, ACTION, DODGE, HIT, KO }

const RUN_SPEED := 6.0
const ACCEL := 40.0          # speeding up
const DECEL := 30.0          # slowing down: a little momentum, ~0.2 s to stop from a run
const TURN_ACCEL := 70.0     # sharp direction changes bite harder so steering stays responsive
const DODGE_SPEED := 14.5
const DODGE_TIME := 0.24
const DODGE_COST := 22.0
const STAMINA_REGEN := 36.0
const STAMINA_DELAY := 0.5
const MANA_REGEN := 6.0
const AUTO_AIM_RANGE := 8.0

var health: Node
var combat: Node
var abilities: Node
var sprite: AnimatedSprite3D
var visual: Node3D
var hand_light: OmniLight3D

var max_mana := 100.0
var mana := 100.0
var max_stamina := 100.0
var stamina := 100.0
var state := State.FREE
var aim_dir := Vector3(0, 0, 1)
var aim_point := Vector3.ZERO
var facing := "down"
var face_left := false
var mouse_aim := false

var _state_t := 0.0
var _action_anim := ""
var _action_move_mult := 0.0
var _dodge_dir := Vector3.ZERO
var _invuln_t := 0.0
var _stamina_delay := 0.0
var _ghost_t := 0.0
var _move_input := Vector3.ZERO
var _knock := Vector3.ZERO
var _last_move_dir := Vector3(0, 0, 1)
var _aim_lock_t := 0.0
var _skid_cd := 0.0
var _last_step_frame := -1
var _reticle: MeshInstance3D
var _reticle_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 1.3
	shape.shape = cyl
	shape.position.y = 0.65
	add_child(shape)
	health = Health.new()
	health.setup(120.0)
	add_child(health)
	visual = Node3D.new()
	add_child(visual)
	sprite = HD2D.make_animated_sprite(SpriteFactory.pirate_frames(), SpriteFactory.PIRATE_FEET_FROM_CENTER)
	visual.add_child(sprite)
	sprite.play("idle_down")
	add_child(Game.make_blob_shadow(0.42))
	hand_light = OmniLight3D.new()
	hand_light.omni_range = 2.6
	hand_light.light_energy = 0.8
	hand_light.position = Vector3(0, 0.9, 0.3)
	add_child(hand_light)
	combat = Combat.new()
	add_child(combat)
	abilities = Abilities.new()
	add_child(abilities)
	aim_point = global_position + aim_dir * 3.0
	_build_reticle()


## Ground marker under the mouse cursor (desktop) showing where attacks go.
func _build_reticle() -> void:
	const PixelArt := preload("res://scripts/render/pixel_art.gd")
	_reticle = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.7, 0.7)
	_reticle.mesh = pm
	_reticle_mat = StandardMaterial3D.new()
	_reticle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reticle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reticle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_reticle_mat.albedo_texture = PixelArt.circle_texture(24, false)
	_reticle_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_reticle_mat.disable_fog = true
	_reticle.material_override = _reticle_mat
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle.top_level = true
	add_child(_reticle)


## Holds the aim direction for a moment (used when a swing snaps onto an enemy).
func lock_aim(dir: Vector3, duration: float) -> void:
	aim_dir = dir
	_aim_lock_t = duration


# ---------------------------------------------------------------- queries

func is_alive() -> bool:
	return state != State.KO


func is_free() -> bool:
	return state == State.FREE


func in_action() -> bool:
	return state == State.ACTION


func action_anim() -> String:
	return _action_anim if state == State.ACTION else ""


func action_time_left() -> float:
	return _state_t if state == State.ACTION else 0.0


func is_invulnerable() -> bool:
	return _invuln_t > 0.0


func hand_position() -> Vector3:
	return global_position + Vector3.UP * 0.85 + aim_dir * 0.45


# ---------------------------------------------------------------- actions

## Locks the player into a timed action (attack, cast, charge) that plays `anim`.
func start_action(anim: String, duration: float, move_mult := 0.0) -> void:
	state = State.ACTION
	_state_t = duration
	_action_anim = anim
	_action_move_mult = move_mult
	_update_facing()
	_play(anim, true)


func end_action() -> void:
	if state == State.ACTION:
		state = State.FREE
		_action_anim = ""


func lunge(speed: float) -> void:
	velocity = aim_dir * speed


func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true


func gain_mana(amount: float) -> void:
	mana = minf(max_mana, mana + amount)


func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	_stamina_delay = STAMINA_DELAY
	return true


func try_dodge() -> void:
	if state != State.FREE and state != State.ACTION:
		return
	if not spend_stamina(DODGE_COST):
		Game.float_text(global_position + Vector3.UP * 2.0, "No stamina", Color(0.9, 0.85, 0.4), 26, 0.6)
		return
	combat.cancel()
	_dodge_dir = _move_input.normalized() if _move_input.length() > 0.2 else _last_move_dir
	state = State.DODGE
	_state_t = DODGE_TIME
	_invuln_t = DODGE_TIME + 0.06
	_ghost_t = 0.0
	_play("dodge", true)
	Audio.play("dash")
	Game.burst(global_position + Vector3.UP * 0.1, Color(0.75, 0.68, 0.6), 8, 2.0, 0.07, 0.35, -2.0, false)


func teleport_to(pos: Vector3) -> void:
	var from := global_position
	global_position = Vector3(pos.x, 0.0, pos.z)
	_invuln_t = maxf(_invuln_t, 0.25)
	for k in 4:
		var g := from.lerp(global_position, k / 4.0)
		Game.burst(g + Vector3.UP * 0.6, E.COLORS[E.VOID], 4, 1.0, 0.06, 0.4, 0.5)


func take_damage(info: Dictionary) -> void:
	if state == State.KO or _invuln_t > 0.0:
		return
	var amount: float = info["amount"]
	health.apply_damage(amount)
	Game.damage_number(global_position, amount, Color(1.0, 0.35, 0.4), false)
	Game.hit_fx(global_position + Vector3.UP * 0.7, E.PHYSICAL)
	var hit_dir: Vector3 = info["dir"]
	Game.impact(global_position + Vector3.UP * 0.8, hit_dir, clampf(amount / 25.0, 0.3, 0.8))
	Game.spark(global_position + Vector3.UP * 0.8, 1.0, Color(1.0, 0.5, 0.5))
	Game.hurt_flash(clampf(amount / 20.0, 0.4, 1.0))
	combat.cancel()
	var dir: Vector3 = info["dir"]
	var kb: float = info["knockback"]
	_knock = dir * kb
	Audio.play("hurt")
	if health.is_dead():
		state = State.KO
		_play("ko", true)
		knocked_out.emit()
		return
	state = State.HIT
	_state_t = 0.28
	_invuln_t = 0.8
	_play("hit", true)


# ---------------------------------------------------------------- loop

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_aim = true


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_move_input = Vector3(input.x, 0.0, input.y)
	if _move_input.length() > 0.2:
		_last_move_dir = _move_input.normalized()
	_update_aim()
	_tick_vitals(delta)
	_invuln_t = maxf(_invuln_t - delta, 0.0)
	_aim_lock_t -= delta
	_skid_cd -= delta
	_state_t -= delta

	if Input.is_action_just_pressed("dodge"):
		try_dodge()

	var target_vel := Vector3.ZERO
	match state:
		State.FREE:
			target_vel = _move_input * RUN_SPEED
		State.ACTION:
			target_vel = _move_input * RUN_SPEED * _action_move_mult
			if _state_t <= 0.0:
				end_action()
		State.DODGE:
			_ghost_t -= delta
			if _ghost_t <= 0.0:
				_ghost_t = 0.04
				Game.ghost(sprite, Color(0.55, 0.85, 1.0))
			if _state_t <= 0.0:
				state = State.FREE
		State.HIT:
			if _state_t <= 0.0:
				state = State.FREE
	if state == State.DODGE:
		velocity = _dodge_dir * DODGE_SPEED
	else:
		var speed_before := Vector2(velocity.x, velocity.z).length()
		var rate := ACCEL
		if target_vel.length() < 0.1:
			rate = DECEL
		elif velocity.length() > 0.5 and velocity.normalized().dot(target_vel.normalized()) < 0.0:
			rate = TURN_ACCEL
			_skid(speed_before)
		velocity = velocity.move_toward(target_vel, rate * delta)
		if state == State.FREE and target_vel.length() < 0.1 and speed_before > 4.5:
			_skid(speed_before)
	var base_velocity := velocity
	velocity += _knock
	move_and_slide()
	velocity = base_velocity
	_knock = _knock.move_toward(Vector3.ZERO, 35.0 * delta)
	global_position.y = 0.0
	_update_facing()
	_update_animation()
	_update_hand_light(delta)


## Dust and a scuff sound when stopping or turning hard at speed.
func _skid(speed: float) -> void:
	if _skid_cd > 0.0 or speed < 3.5:
		return
	_skid_cd = 0.35
	Game.burst(global_position + Vector3.UP * 0.05, Color(0.72, 0.64, 0.56), 7, 2.0, 0.08, 0.4, -3.0, false)
	Audio.play("skid", -6.0)


func _tick_vitals(delta: float) -> void:
	if state == State.KO:
		return
	mana = minf(max_mana, mana + MANA_REGEN * delta)
	_stamina_delay -= delta
	if _stamina_delay <= 0.0 and state != State.DODGE:
		stamina = minf(max_stamina, stamina + STAMINA_REGEN * delta)


func _update_aim() -> void:
	var desktop_mouse := mouse_aim and not Game.touch_controls
	_reticle.visible = desktop_mouse and state != State.KO
	if desktop_mouse:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var mp := get_viewport().get_mouse_position()
			var o := cam.project_ray_origin(mp)
			var d := cam.project_ray_normal(mp)
			if absf(d.y) > 0.001:
				var hit := o + d * (-o.y / d.y)   # point on the ground under the cursor
				aim_point = Vector3(hit.x, 0.0, hit.z)
				_reticle.global_position = aim_point + Vector3.UP * 0.02
				_reticle_mat.albedo_color = (E.COLORS[abilities.element] as Color) * 1.3
				var to := aim_point - global_position
				to.y = 0.0
				if to.length() > 0.15 and _aim_lock_t <= 0.0:
					aim_dir = to.normalized()
		return
	if _aim_lock_t > 0.0:
		return
	# Touch / keyboard: auto-aim at the best enemy near the movement direction.
	var best: Node3D = null
	var best_score := INF
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > AUTO_AIM_RANGE:
			continue
		var score := dist - (2.0 * _last_move_dir.dot(to / dist) if dist > 0.01 else 0.0)
		if score < best_score:
			best_score = score
			best = e
	if best:
		var to := best.global_position - global_position
		to.y = 0.0
		aim_dir = to.normalized() if to.length() > 0.05 else aim_dir
		aim_point = best.global_position
	else:
		aim_dir = _last_move_dir
		aim_point = global_position + aim_dir * 4.0


func _update_facing() -> void:
	var dir := aim_dir
	if state == State.FREE and _move_input.length() > 0.2:
		dir = _move_input
	elif state == State.DODGE:
		dir = _dodge_dir
	if absf(dir.x) > absf(dir.z) * 0.85:
		facing = "side"
	elif dir.z > 0.0:
		facing = "down"
	else:
		facing = "up"
	if absf(dir.x) > 0.05:
		face_left = dir.x < 0.0
	sprite.flip_h = face_left


func _update_animation() -> void:
	var anim := "idle"
	match state:
		State.FREE:
			var speed := Vector2(velocity.x, velocity.z).length()
			if speed > 3.2:
				anim = "run"
			elif speed > 0.4:
				anim = "walk"
		State.ACTION:
			anim = _action_anim
		State.DODGE:
			anim = "dodge"
		State.HIT:
			anim = "hit"
		State.KO:
			anim = "ko"
	_play(anim, false)
	# Footsteps: boots hit the deck on frames 0 and 3 of the walk/run cycles.
	if anim == "run" or anim == "walk":
		var f := sprite.frame
		if f != _last_step_frame and (f == 0 or f == 3):
			Audio.play("step", -9.0 if anim == "run" else -14.0, 0.15)
			if anim == "run":
				Game.burst(global_position + Vector3.UP * 0.04, Color(0.7, 0.62, 0.54), 2, 0.7, 0.06, 0.3, -2.0, false)
		_last_step_frame = f
	else:
		_last_step_frame = -1
	# Blink while invulnerable after a hit (not during dodges, which have ghost trails).
	if _invuln_t > 0.0 and state != State.DODGE and state != State.KO:
		sprite.visible = int(_invuln_t * 20.0) % 2 == 0
	else:
		sprite.visible = true


func _play(anim: String, restart: bool) -> void:
	var full := "%s_%s" % [anim, facing]
	if restart:
		sprite.play(full)
		sprite.set_frame_and_progress(0, 0.0)
	elif sprite.animation != full:
		var f := sprite.frame
		var p := sprite.frame_progress
		var same_anim := sprite.animation.begins_with(anim + "_")
		sprite.play(full)
		if same_anim:
			sprite.set_frame_and_progress(f, p)   # facing changed mid-animation: keep timing


func _update_hand_light(delta: float) -> void:
	var col: Color = E.COLORS[abilities.element]
	hand_light.light_color = col
	var target := 0.7
	if state == State.ACTION and _action_anim == "charge":
		target = 0.8 + 2.2 * combat.charge_level()
	elif state == State.ACTION and _action_anim == "cast":
		target = 2.5
	hand_light.light_energy = lerpf(hand_light.light_energy, target, 1.0 - exp(-12.0 * delta))
	hand_light.position = Vector3(aim_dir.x * 0.35, 0.9, aim_dir.z * 0.35 + 0.15)
	hand_light.visible = Game.dynamic_lights_enabled()
