extends Node3D
## Elemental projectile. Configure with a dictionary before adding to the tree:
##   element, dir, speed, damage, radius, life, knockback,
##   pierce (extra enemies it passes through), explode_radius/explode_damage, well (bool)

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")
const GravityWell := preload("res://scripts/combat/gravity_well.gd")

var element := 0
var dir := Vector3.FORWARD
var speed := 15.0
var damage := 10.0
var radius := 0.5
var life := 1.0
var knockback := 2.0
var pierce := 0
var explode_radius := 0.0
var explode_damage := 0.0
var well := false
var well_cfg := {}          # Gravity Well settings (radius, duration, strength, damage)
var homing: Node3D = null   # steer toward this target (Rift Barrage)
var turn_rate := 7.0

var _hit := []
var _trail: CPUParticles3D
var _done := false


func configure(cfg: Dictionary) -> void:
	element = cfg.get("element", element)
	dir = cfg.get("dir", dir)
	speed = cfg.get("speed", speed)
	damage = cfg.get("damage", damage)
	radius = cfg.get("radius", radius)
	life = cfg.get("life", life)
	knockback = cfg.get("knockback", knockback)
	pierce = cfg.get("pierce", pierce)
	explode_radius = cfg.get("explode_radius", explode_radius)
	explode_damage = cfg.get("explode_damage", explode_damage)
	well = cfg.get("well", well)
	well_cfg = cfg.get("well_cfg", well_cfg)
	homing = cfg.get("homing", homing)


func _ready() -> void:
	var col: Color = E.COLORS[element]
	var core := MeshInstance3D.new()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	if element == E.COMET:
		var b := BoxMesh.new()
		b.size = Vector3(0.1, 0.1, 0.55)
		core.mesh = b
		m.albedo_color = Color(1.6, 2.0, 2.4)
	elif element == E.GRAVITY:
		var s := SphereMesh.new()
		s.radius = 0.2
		s.height = 0.4
		s.radial_segments = 10
		s.rings = 5
		core.mesh = s
		m.albedo_color = Color(0.06, 0.03, 0.18)
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.24
		t.outer_radius = 0.3
		t.rings = 16
		t.ring_segments = 4
		ring.mesh = t
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(col.r * 2.0, col.g * 2.0, col.b * 2.0)
		ring.material_override = rm
		ring.rotation.x = PI * 0.5
		add_child(ring)
	else:
		var s := SphereMesh.new()
		s.radius = 0.17
		s.height = 0.34
		s.radial_segments = 10
		s.rings = 5
		core.mesh = s
		m.albedo_color = Color(col.r * 2.2, col.g * 2.0, col.b * 1.6)
	core.material_override = m
	add_child(core)
	if element == E.COMET:
		core.look_at(global_position + dir, Vector3.UP)

	if Game.dynamic_lights_enabled() and Game.quality == Game.Quality.HIGH:
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.6
		l.omni_range = 3.5
		add_child(l)

	_trail = CPUParticles3D.new()
	_trail.mesh = Game.particle_mesh(0.07)
	_trail.amount = maxi(6, int(20 * Game.particle_scale()))
	_trail.lifetime = 0.3
	_trail.local_coords = false
	_trail.direction = -dir
	_trail.spread = 25.0
	_trail.initial_velocity_min = 0.3
	_trail.initial_velocity_max = 1.2
	_trail.gravity = Vector3(0, 1.5 if element == E.SUN else 0.0, 0)
	_trail.scale_amount_min = 0.6
	_trail.scale_amount_max = 1.2
	_trail.color_ramp = Game.fade_ramp(col.lerp(Color.WHITE, 0.2))
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if homing and is_instance_valid(homing) and homing.can_be_hit():
		var want: Vector3 = homing.global_position + Vector3.UP * 0.6 - global_position
		want.y = 0.0
		if want.length() > 0.05:
			dir = dir.slerp(want.normalized(), clampf(turn_rate * delta, 0.0, 1.0)).normalized()
	var from := global_position
	var to := from + dir * speed * delta
	var space := get_world_3d().direct_space_state
	var res := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if not res.is_empty():
		_finish(res["position"])
		return
	global_position = to
	for e in Game.enemies():
		if e in _hit or not e.can_be_hit():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		if d.length() < radius + e.radius:
			_hit.append(e)
			e.take_damage(Damage.make(damage, element, dir, knockback, true, 0.08, Game.player))
			if pierce <= 0:
				_finish(global_position, e)
				return
			pierce -= 1
	life -= delta
	if life <= 0.0:
		_finish(global_position)


func _finish(pos: Vector3, direct_hit: Node = null) -> void:
	_done = true
	var col: Color = E.COLORS[element]
	if explode_radius > 0.0:
		Game.explosion(pos, explode_radius, explode_damage, element, direct_hit, col)
	elif well:
		var w := GravityWell.new()
		w.position = Vector3(pos.x, 0.0, pos.z)
		for key in well_cfg:
			w.set(key, well_cfg[key])
		Game.world.add_child(w)
	else:
		Game.burst(pos, col, 10, 3.0, 0.07, 0.3, -2.0)
	# Let the trail fade instead of vanishing.
	_trail.emitting = false
	var trail := _trail
	remove_child(trail)
	Game.world.add_child(trail)
	trail.global_position = pos
	get_tree().create_timer(0.4, false).timeout.connect(trail.queue_free)
	queue_free()
