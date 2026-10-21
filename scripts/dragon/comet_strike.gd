extends Node3D
## One falling strike (a comet by default; any element). A ring marks the impact
## point, the strike falls, then deals elemental damage in a small area.
## Used by the dragons' special and by spells like Supernova / Thunder Strike.

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")

var element: int = E.COMET
var damage := 10.0
var radius := 1.3
var fall_time := 0.32
var start_height := 7.0
var bolt := false          # true = instant lightning bolt instead of a falling body
var source: Node = null

var _t := 0.0
var _comet: MeshInstance3D


func _ready() -> void:
	var col: Color = E.COLORS[element]
	Game.ring_fx(global_position, col, radius, fall_time, true)
	if bolt:
		return
	_comet = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.22, 0.6, 0.22) * clampf(radius / 1.3, 1.0, 2.5)
	_comet.mesh = b
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r * 2.0 + 0.4, col.g * 2.0 + 0.4, col.b * 2.0 + 0.4)
	m.disable_fog = true
	_comet.material_override = m
	_comet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_comet.position = Vector3(-1.2, start_height, -0.6)
	_comet.rotation.z = -0.2
	add_child(_comet)
	var trail := CPUParticles3D.new()
	trail.mesh = Game.particle_mesh(0.08)
	trail.amount = maxi(6, int(16 * Game.particle_scale()))
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.spread = 15.0
	trail.direction = Vector3.UP
	trail.initial_velocity_min = 0.5
	trail.initial_velocity_max = 1.5
	trail.gravity = Vector3.ZERO
	trail.color_ramp = Game.fade_ramp(col.lerp(Color.WHITE, 0.4))
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_comet.add_child(trail)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / fall_time, 0.0, 1.0)
	if _comet:
		_comet.position = Vector3(-1.2, start_height, -0.6).lerp(Vector3(0, 0.2, 0), k * k)
	if _t >= fall_time:
		_impact()


func _impact() -> void:
	set_physics_process(false)
	var col: Color = E.COLORS[element]
	if bolt:
		Game.lightning_fx([global_position + Vector3(0.3, 9.0, -0.4), global_position + Vector3.UP * 0.3], col)
	Game.ring_fx(global_position, col, radius, 0.3)
	Game.burst(global_position + Vector3.UP * 0.3, col.lerp(Color.WHITE, 0.4), 16, 5.0, 0.08, 0.4, -6.0)
	Game.flash_light(global_position + Vector3.UP * 0.8, col, 3.0, 0.25, radius * 2.5)
	Game.shake(clampf(0.12 * radius, 0.12, 0.5))
	Audio.play("comet_impact" if element == E.COMET else ("explode" if radius > 2.0 else "hit_heavy"), -2.0)
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		if d.length() < radius + e.radius:
			e.take_damage(Damage.make(damage, element, d.normalized() if d.length() > 0.01 else Vector3.RIGHT,
				3.0 + radius, true, 0.0, source))
	if _comet:
		_comet.queue_free()
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(queue_free)
