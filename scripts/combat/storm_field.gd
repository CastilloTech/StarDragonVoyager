extends Node3D
## Storm Field: follows its owner and zaps a random nearby enemy every tick.

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")

var follow: Node3D
var radius := 4.2
var duration := 3.5
var tick := 0.35
var damage := 10.0

var _t := 0.0
var _tick_t := 0.0
var _ring: CPUParticles3D


func _ready() -> void:
	var col: Color = E.COLORS[E.STORM]
	_ring = CPUParticles3D.new()
	_ring.mesh = Game.particle_mesh(0.06)
	_ring.amount = maxi(12, int(36 * Game.particle_scale()))
	_ring.lifetime = 0.5
	_ring.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_ring.emission_ring_axis = Vector3.UP
	_ring.emission_ring_radius = radius
	_ring.emission_ring_inner_radius = radius * 0.9
	_ring.emission_ring_height = 0.1
	_ring.tangential_accel_min = 4.0
	_ring.tangential_accel_max = 6.0
	_ring.gravity = Vector3(0, 1.0, 0)
	_ring.color_ramp = Game.fade_ramp(Color(col.r * 1.5, col.g * 1.5, col.b * 1.5))
	_ring.position.y = 0.2
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	Game.ring_fx(global_position, col, radius, 0.35)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_t -= delta
	if follow and is_instance_valid(follow):
		global_position = Vector3(follow.global_position.x, 0.0, follow.global_position.z)
	if _tick_t <= 0.0:
		_tick_t = tick
		var near := []
		for e in Game.enemies():
			if e.can_be_hit() and (e.global_position - global_position).length() < radius + e.radius:
				near.append(e)
		if not near.is_empty():
			var target: Node3D = near.pick_random()
			var col: Color = E.COLORS[E.STORM]
			Game.lightning_fx([target.global_position + Vector3(randf_range(-0.6, 0.6), 4.5, -0.3), target.global_position + Vector3.UP * 0.5], col)
			var dir: Vector3 = target.global_position - global_position
			dir.y = 0.0
			target.take_damage(Damage.make(damage, E.STORM, dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT, 1.0, true, 0.0, Game.player))
			Audio.play("cast_storm", -8.0, 0.2)
	if _t >= duration:
		_ring.emitting = false
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(queue_free)
