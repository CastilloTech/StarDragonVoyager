extends "res://scripts/enemies/admiralty_base.gd"
## Admiralty Rifleman: keeps its distance, aims (red sight line that locks on
## shortly before firing), then shoots a slow arcane bolt you can dash through.

const EnemyProjectile := preload("res://scripts/combat/enemy_projectile.gd")

const PREFERRED_RANGE := 6.0
const TOO_CLOSE := 3.8
const AIM_TIME := 0.9
const LOCK_AT := 0.6        # sight line stops tracking at this point of the aim
const SHOT_DAMAGE := 12.0

var _shot_dir := Vector3.FORWARD
var _strafe := 1.0
var _shot_cd := 1.0
var _laser: MeshInstance3D
var _laser_mat: StandardMaterial3D


func _init() -> void:
	kind = "rifleman"
	max_health = 45.0
	move_speed = 2.8
	radius = 0.36
	poise = 0.0
	sprite_height = 1.45


func _build_visuals() -> void:
	super()
	_laser = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.035, 0.035, 1.0)
	_laser.mesh = b
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_laser_mat.albedo_color = Color(1.4, 0.25, 0.45, 0.6)
	_laser_mat.disable_fog = true
	_laser.material_override = _laser_mat
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.top_level = true
	_laser.visible = false
	add_child(_laser)


func _setup_states() -> void:
	add_state("spawn", _st_spawn, _warp_in)
	add_state("reposition", _st_reposition, _en_reposition)
	add_state("aim", _st_aim, _en_aim)
	add_state("shoot", _st_shoot, _en_shoot)
	add_state("stagger", _st_stagger, _en_stagger)
	change_state("spawn")


func _tick(delta: float) -> void:
	_shot_cd -= delta


func _on_stagger() -> void:
	_laser.visible = false
	change_state("stagger")


func _play_death() -> void:
	super()
	_laser.visible = false


func _muzzle() -> Vector3:
	return global_position + Vector3.UP * 0.95 + look_dir * 0.6


func _has_line_of_sight() -> bool:
	if Game.player == null:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_muzzle(), Game.player.global_position + Vector3.UP * 0.8, 1)
	return space.intersect_ray(q).is_empty()


func _st_spawn(_delta: float) -> void:
	if state_time > 0.6:
		change_state("reposition")


func _en_reposition() -> void:
	_strafe = -1.0 if randf() < 0.5 else 1.0
	play_anim("run")


func _st_reposition(_delta: float) -> void:
	var to := player_vector()
	var dist := to.length()
	if dist < 0.01:
		return
	var dir := to / dist
	face_towards(dir)
	var tangent := Vector3(-dir.z, 0, dir.x) * _strafe
	var move := tangent * 0.6
	if dist < TOO_CLOSE:
		move -= dir * 1.2          # back away from the pirate
	elif dist > PREFERRED_RANGE + 1.5:
		move += dir
	desired_velocity = move.normalized() * move_speed if move.length() > 0.01 else Vector3.ZERO
	play_anim("run" if desired_velocity.length() > 0.1 else "idle")
	if is_on_wall():
		_strafe = -_strafe
	if state_time > 0.8 and _shot_cd <= 0.0 and dist < PREFERRED_RANGE + 3.0 and _has_line_of_sight():
		change_state("aim")


func _en_aim() -> void:
	play_anim("aim", true)
	Audio.play("rifle_charge", -4.0)


func _st_aim(_delta: float) -> void:
	var to := player_vector()
	if state_time < AIM_TIME * LOCK_AT and to.length() > 0.1:
		_shot_dir = to.normalized()
	face_towards(_shot_dir)
	var from := _muzzle()
	var length := 9.0
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + _shot_dir * length, 1))
	if not hit.is_empty():
		length = from.distance_to(hit["position"])
	_laser.visible = true
	_laser.scale = Vector3(1.0, 1.0, length)
	_laser.look_at_from_position(from + _shot_dir * length * 0.5, from + _shot_dir * length, Vector3.UP)
	var locked := state_time >= AIM_TIME * LOCK_AT
	_laser_mat.albedo_color.a = (0.9 if int(state_time * 24.0) % 2 == 0 else 0.3) if locked else 0.45
	if state_time >= AIM_TIME:
		change_state("shoot")


func _en_shoot() -> void:
	_laser.visible = false
	play_anim("shoot", true)
	var p := EnemyProjectile.new()
	p.dir = _shot_dir
	p.damage = SHOT_DAMAGE
	p.source = self
	p.position = _muzzle()
	Game.world.add_child(p)
	Game.burst(_muzzle(), Color(0.85, 0.5, 1.0), 10, 3.0, 0.06, 0.25, 0.0)
	Game.flash_light(_muzzle(), Color(0.85, 0.5, 1.0), 3.0, 0.15)
	Audio.play("rifle_shot")
	knockback -= _shot_dir * 3.0   # recoil


func _st_shoot(_delta: float) -> void:
	if state_time >= 0.45:
		_shot_cd = randf_range(1.4, 2.2)
		change_state("reposition")


func _en_stagger() -> void:
	play_anim("hit", true)
	visual.scale = Vector3(1.1, 0.9, 1.1)


func _st_stagger(_delta: float) -> void:
	if state_time >= 0.4:
		_shot_cd = maxf(_shot_cd, 0.6)
		change_state("reposition")
