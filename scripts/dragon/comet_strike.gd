extends Node3D
## One falling frost comet from Nova's Comet Shower. A friendly blue ring marks
## the impact point, the comet falls, then deals Comet damage in a small area.

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")

const FALL_TIME := 0.32
const RADIUS := 1.3
const DAMAGE := 10.0
const START_HEIGHT := 7.0

var _t := 0.0
var _comet: MeshInstance3D
var _trail: CPUParticles3D


func _ready() -> void:
	var col: Color = E.COLORS[E.COMET]
	Game.ring_fx(global_position, col, RADIUS, FALL_TIME, true)
	_comet = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.22, 0.6, 0.22)
	_comet.mesh = b
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.8, 2.2, 2.6)
	m.disable_fog = true
	_comet.material_override = m
	_comet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_comet.position = Vector3(-1.2, START_HEIGHT, -0.6)
	_comet.rotation.z = -0.2
	add_child(_comet)
	_trail = CPUParticles3D.new()
	_trail.mesh = Game.particle_mesh(0.08)
	_trail.amount = maxi(6, int(16 * Game.particle_scale()))
	_trail.lifetime = 0.3
	_trail.local_coords = false
	_trail.spread = 15.0
	_trail.direction = Vector3.UP
	_trail.initial_velocity_min = 0.5
	_trail.initial_velocity_max = 1.5
	_trail.gravity = Vector3.ZERO
	_trail.color_ramp = Game.fade_ramp(col.lerp(Color.WHITE, 0.4))
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_comet.add_child(_trail)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / FALL_TIME, 0.0, 1.0)
	_comet.position = Vector3(-1.2, START_HEIGHT, -0.6).lerp(Vector3(0, 0.2, 0), k * k)
	if _t >= FALL_TIME:
		_impact()


func _impact() -> void:
	set_physics_process(false)
	var col: Color = E.COLORS[E.COMET]
	Game.ring_fx(global_position, col, RADIUS, 0.3)
	Game.burst(global_position + Vector3.UP * 0.3, Color(0.85, 0.97, 1.0), 16, 5.0, 0.08, 0.4, -8.0)
	Game.flash_light(global_position + Vector3.UP * 0.8, col, 3.0, 0.25)
	Game.shake(0.15)
	Audio.play("comet_impact", -2.0)
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		if d.length() < RADIUS + e.radius:
			e.take_damage(Damage.make(DAMAGE, E.COMET, d.normalized() if d.length() > 0.01 else Vector3.RIGHT, 3.0, true, 0.0, Game.dragon))
	_comet.queue_free()
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(queue_free)
