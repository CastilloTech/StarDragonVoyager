extends Node3D
## Gravity vortex: pulls nearby enemies to its center, ticks Gravity damage
## (Bound status; combos with Burning), then implodes with an outward blast.
## Configure the public vars before adding it (Gravity Well and Singularity use it).

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")

var duration := 1.6
var pull_radius := 3.6
var pull_strength := 22.0
var tick := 0.4
var tick_damage := 3.0
var implode_damage := 14.0

var _t := 0.0
var _tick_t := 0.0
var _swirl: CPUParticles3D
var _disc: MeshInstance3D


func _ready() -> void:
	var col: Color = E.COLORS[E.GRAVITY]
	var big := pull_radius / 3.6
	_disc = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.35 * big
	s.height = 0.7 * big
	s.radial_segments = 12
	s.rings = 6
	_disc.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.04, 0.02, 0.12)
	_disc.material_override = m
	_disc.position.y = 0.6
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)

	_swirl = CPUParticles3D.new()
	_swirl.mesh = Game.particle_mesh(0.08)
	_swirl.amount = maxi(12, int(40 * big * Game.particle_scale()))
	_swirl.lifetime = 0.8
	_swirl.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_swirl.emission_ring_axis = Vector3.UP
	_swirl.emission_ring_radius = pull_radius * 0.8
	_swirl.emission_ring_inner_radius = pull_radius * 0.6
	_swirl.emission_ring_height = 0.2
	_swirl.radial_accel_min = -9.0 * big
	_swirl.radial_accel_max = -6.0 * big
	_swirl.tangential_accel_min = 6.0
	_swirl.tangential_accel_max = 9.0
	_swirl.gravity = Vector3.ZERO
	_swirl.color_ramp = Game.fade_ramp(Color(col.r * 1.4, col.g * 1.4, col.b * 1.6), true)
	_swirl.position.y = 0.4
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_swirl)
	Game.ring_fx(global_position, col, pull_radius, 0.4, true)
	Game.flash_light(global_position + Vector3.UP, col, 3.0, duration, pull_radius * 1.4)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_t -= delta
	_disc.scale = Vector3.ONE * (1.0 + 0.15 * sin(_t * 20.0))
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var to: Vector3 = global_position - e.global_position
		to.y = 0.0
		var d := to.length()
		if d < pull_radius and d > 0.3:
			e.knockback += to / d * pull_strength * delta
	if _tick_t <= 0.0:
		_tick_t = tick
		_damage_in_radius(tick_damage, 0.0)
	if _t >= duration:
		_implode()


func _damage_in_radius(amount: float, push: float) -> void:
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		if d.length() < pull_radius:
			var dir := d.normalized() if d.length() > 0.01 else Vector3.RIGHT
			e.take_damage(Damage.make(amount, E.GRAVITY, dir, push, push > 0.0, 0.0, Game.player))


func _implode() -> void:
	set_physics_process(false)
	Audio.play("hit_heavy")
	var col: Color = E.COLORS[E.GRAVITY]
	_damage_in_radius(implode_damage, 7.0 + pull_radius)
	Game.ring_fx(global_position, col, pull_radius * 0.9, 0.3)
	Game.burst(global_position + Vector3.UP * 0.5, col, 24, 6.0, 0.08, 0.4, 0.0)
	Game.shake(0.3 * pull_radius / 3.6)
	_swirl.emitting = false
	var tw := create_tween()
	tw.tween_property(_disc, "scale", Vector3.ZERO, 0.15)
	tw.tween_interval(0.5)
	tw.tween_callback(queue_free)
