extends "res://scripts/enemies/enemy_base.gd"
## Shared base for Admiralty soldiers: humanoid sprites with three facings
## (down / up / side), a warp-in spawn, a ground telegraph helper and knockout death.

const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")
const PixelArt := preload("res://scripts/render/pixel_art.gd")

var kind := "marine"
var look_dir := Vector3(0, 0, 1)
var _anim := "idle"
var _telegraph: MeshInstance3D
var _tele_mat: StandardMaterial3D


func _build_visuals() -> void:
	sprite = HD2D.make_animated_sprite(SpriteFactory.humanoid_frames(kind), SpriteFactory.PIRATE_FEET_FROM_CENTER)
	visual.add_child(sprite)
	play_anim("idle", true)


func play_anim(anim: String, restart := false) -> void:
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


func face_towards(dir: Vector3) -> void:
	if dir.length() > 0.05:
		look_dir = dir.normalized()
		face_dir = signf(dir.x) if absf(dir.x) > 0.05 else face_dir


func _facing() -> String:
	if absf(look_dir.x) > absf(look_dir.z) * 0.85:
		return "side"
	return "down" if look_dir.z > 0.0 else "up"


func _update_visuals(delta: float) -> void:
	super(delta)
	if not dead:
		play_anim(_anim)
	sprite.flip_h = look_dir.x < -0.05


func _play_death() -> void:
	play_anim("ko", true)
	if _telegraph:
		_telegraph.visible = false


func _warp_in() -> void:
	visual.scale = Vector3(0.6, 1.6, 0.6)
	Game.ring_fx(global_position, Color(0.6, 0.85, 1.0), 1.3, 0.45, true)
	Game.burst(global_position + Vector3.UP * 0.8, Color(0.8, 0.92, 1.0), 18, 3.0, 0.07, 0.45, 2.5)
	Game.flash_light(global_position + Vector3.UP, Color(0.6, 0.85, 1.0), 3.0, 0.4)
	Audio.play("spawn", -4.0)


## Flat red warning shape on the ground. `crescent` = sword-arc wedge, else a long strip.
func _make_telegraph(crescent: bool) -> void:
	_telegraph = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	if crescent:
		pm.size = Vector2(4.2, 4.2)
	else:
		pm.size = Vector2(0.5, 1.0)
		pm.center_offset = Vector3(0, 0, -0.5)
	_telegraph.mesh = pm
	_tele_mat = StandardMaterial3D.new()
	_tele_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tele_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tele_mat.albedo_color = Color(1.0, 0.2, 0.3, 0.0)
	_tele_mat.disable_fog = true
	_tele_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if crescent:
		_tele_mat.albedo_texture = PixelArt.crescent_texture()
		_tele_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_telegraph.material_override = _tele_mat
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph.position.y = 0.03
	_telegraph.visible = false
	add_child(_telegraph)


func _show_telegraph(dir: Vector3, k: float, crescent: bool, length := 1.0) -> void:
	_telegraph.visible = true
	if crescent:
		_telegraph.rotation.y = atan2(-dir.z, dir.x)
	else:
		_telegraph.rotation.y = atan2(-dir.x, -dir.z)
		_telegraph.scale = Vector3(1.0, 1.0, length)
	var blink := 0.15 if int(state_time * 16.0) % 2 == 0 else 0.0
	_tele_mat.albedo_color.a = 0.15 + 0.45 * k + blink
