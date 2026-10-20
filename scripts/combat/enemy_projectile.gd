extends Node3D
## Admiralty arcane bolt. Slow enough to read; passes harmlessly through a
## dashing (invulnerable) player, rewarding well-timed dodges.

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")

var dir := Vector3.FORWARD
var speed := 10.5
var damage := 12.0
var life := 2.5
var source: Node = null
var _dodged := false


func _ready() -> void:
	var col := Color(0.85, 0.5, 1.0)
	var core := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.16
	s.height = 0.32
	s.radial_segments = 10
	s.rings = 5
	core.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(2.2, 1.4, 2.6)
	m.disable_fog = true
	core.material_override = m
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var trail := CPUParticles3D.new()
	trail.mesh = Game.particle_mesh(0.07)
	trail.amount = maxi(6, int(16 * Game.particle_scale()))
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.direction = -dir
	trail.spread = 20.0
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.8
	trail.gravity = Vector3.ZERO
	trail.color_ramp = Game.fade_ramp(col)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	if Game.dynamic_lights_enabled():
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.2
		l.omni_range = 2.5
		add_child(l)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + dir * speed * delta
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if not hit.is_empty():
		_pop(hit["position"])
		return
	global_position = to
	var p := Game.player
	if p and is_instance_valid(p) and p.is_alive():
		var d := p.global_position - global_position
		d.y = 0.0
		if d.length() < 0.45:
			if p.is_invulnerable():
				if not _dodged:
					_dodged = true
					Game.float_text(p.global_position + Vector3.UP * 2.0, "Dodge!", Color(0.6, 0.9, 1.0), 26, 0.6)
			else:
				p.take_damage(Damage.make(damage, E.PHYSICAL, dir, 6.0, true, 0.0, source))
				_pop(global_position)
				return
	life -= delta
	if life <= 0.0:
		_pop(global_position)


func _pop(pos: Vector3) -> void:
	Game.burst(pos, Color(0.85, 0.5, 1.0), 10, 3.0, 0.06, 0.3, 0.0)
	queue_free()
