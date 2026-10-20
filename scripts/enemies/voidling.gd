extends "res://scripts/enemies/enemy_base.gd"
## Voidling: a fast creature that circles the player, then telegraphs and lunges.
## Counterplay: dodge through the lunge, then punish during its recovery.

const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")

const ATTACK_RANGE := 3.4
const WINDUP_TIME := 0.5
const LUNGE_TIME := 0.26
const LUNGE_SPEED := 14.0
const RECOVER_TIME := 0.6

var _lunge_dir := Vector3.FORWARD
var _lunge_hit := false
var _circle_sign := 1.0
var _attack_cd := 0.8
var _telegraph: MeshInstance3D
var _tele_mat: StandardMaterial3D


func _init() -> void:
	max_health = 40.0
	move_speed = 5.0
	radius = 0.42
	contact_damage = 10.0
	sprite_height = 0.8


func _build_visuals() -> void:
	sprite = HD2D.make_animated_sprite(SpriteFactory.voidling_frames(), SpriteFactory.VOIDLING_FEET_FROM_CENTER)
	visual.add_child(sprite)
	sprite.play("idle")
	_telegraph = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.9, 1.0)
	pm.center_offset = Vector3(0, 0, -0.5)
	_telegraph.mesh = pm
	_tele_mat = StandardMaterial3D.new()
	_tele_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tele_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tele_mat.albedo_color = Color(1.0, 0.2, 0.35, 0.0)
	_tele_mat.disable_fog = true
	_telegraph.material_override = _tele_mat
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph.position.y = 0.025
	_telegraph.visible = false
	add_child(_telegraph)


func _setup_states() -> void:
	add_state("spawn", _st_spawn, _en_spawn)
	add_state("chase", _st_chase, func() -> void: sprite.play("move"))
	add_state("circle", _st_circle, _en_circle)
	add_state("windup", _st_windup, _en_windup)
	add_state("lunge", _st_lunge, _en_lunge)
	add_state("recover", _st_recover, func() -> void: sprite.play("idle"))
	add_state("stagger", _st_stagger, _en_stagger)
	change_state("spawn")


func _tick(delta: float) -> void:
	_attack_cd -= delta


func _on_stagger() -> void:
	_telegraph.visible = false
	change_state("stagger")


# ---------------------------------------------------------------- states

func _en_spawn() -> void:
	visual.scale = Vector3(0.1, 0.1, 0.1)
	Audio.play("spawn", -6.0)
	Game.ring_fx(global_position, Color(0.85, 0.3, 0.9), 1.2, 0.5, true)
	Game.burst(global_position + Vector3.UP * 0.3, Color(0.85, 0.3, 0.9), 16, 3.0, 0.07, 0.5, 2.0)


func _st_spawn(_delta: float) -> void:
	if state_time > 0.55:
		change_state("chase")


func _st_chase(_delta: float) -> void:
	var to := player_vector()
	var dist := to.length()
	if dist < 0.01:
		return
	var dir := to / dist
	face_towards(dir)
	if dist < ATTACK_RANGE and _attack_cd <= 0.0:
		change_state("windup")
	elif dist < ATTACK_RANGE - 0.4:
		change_state("circle")
	else:
		desired_velocity = dir * move_speed


func _en_circle() -> void:
	_circle_sign = -1.0 if randf() < 0.5 else 1.0
	sprite.play("move")


func _st_circle(_delta: float) -> void:
	var to := player_vector()
	var dist := to.length()
	if dist < 0.01:
		return
	var dir := to / dist
	face_towards(dir)
	var tangent := Vector3(-dir.z, 0, dir.x) * _circle_sign
	var radial := dir * (dist - 2.8) * 1.5
	desired_velocity = (tangent * move_speed * 0.7 + radial).limit_length(move_speed)
	if _attack_cd <= 0.0 or state_time > 1.4:
		change_state("chase")


func _en_windup() -> void:
	sprite.play("windup")
	Audio.play("enemy_windup", -3.0)
	var to := player_vector()
	_lunge_dir = to.normalized() if to.length() > 0.01 else Vector3(face_dir, 0, 0)
	_telegraph.visible = true
	visual.scale = Vector3(1.15, 0.8, 1.15)


func _st_windup(delta: float) -> void:
	var to := player_vector()
	if state_time < WINDUP_TIME * 0.5 and to.length() > 0.1:
		_lunge_dir = _lunge_dir.lerp(to.normalized(), 6.0 * delta).normalized()
	face_towards(_lunge_dir)
	var k := clampf(state_time / WINDUP_TIME, 0.0, 1.0)
	_telegraph.rotation.y = atan2(-_lunge_dir.x, -_lunge_dir.z)
	_telegraph.scale = Vector3(1.0, 1.0, LUNGE_SPEED * LUNGE_TIME * (0.4 + 0.6 * k))
	_tele_mat.albedo_color.a = 0.15 + 0.4 * k + (0.15 if int(state_time * 16.0) % 2 == 0 else 0.0)
	if state_time >= WINDUP_TIME:
		change_state("lunge")


func _en_lunge() -> void:
	sprite.play("lunge")
	_telegraph.visible = false
	_lunge_hit = false
	visual.scale = Vector3(0.85, 1.15, 0.85)
	Game.burst(global_position + Vector3.UP * 0.2, Color(0.7, 0.3, 0.9), 6, 2.0, 0.07, 0.3, 0.0)


func _st_lunge(_delta: float) -> void:
	desired_velocity = _lunge_dir * LUNGE_SPEED
	if not _lunge_hit:
		var n := Game.hit_allies_in_arc(global_position, _lunge_dir, radius + 0.6, -1.0,
			func() -> Dictionary: return Damage.make(contact_damage, E.PHYSICAL, _lunge_dir, 7.0, true, 0.0, self))
		_lunge_hit = n > 0
	if state_time >= LUNGE_TIME:
		change_state("recover")


func _st_recover(_delta: float) -> void:
	if state_time >= RECOVER_TIME:
		_attack_cd = randf_range(1.0, 1.8)
		change_state("chase")


func _en_stagger() -> void:
	sprite.play("hit")
	visual.scale = Vector3(1.2, 0.8, 1.2)


func _st_stagger(_delta: float) -> void:
	if state_time >= 0.32:
		_attack_cd = maxf(_attack_cd, 0.5)
		change_state("chase")
