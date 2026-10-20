extends Node3D
## Celestial Pirate Harbor: the prototype combat arena, a floating dock among
## the stars. Built in code from procedural PLACEHOLDER textures (32 texels per
## meter, matching the sprites).
##
## Mobile notes: the deck is split into chunks so each chunk only receives the
## lanterns near it (the Mobile renderer caps lights per object), only the sun
## casts shadows, and decorative particles scale with the quality setting.

const PixelArt := preload("res://scripts/render/pixel_art.gd")
const HD2D := preload("res://scripts/core/hd2d.gd")

const HALF_W := 8.5   # deck spans x -8.5..8.5
const HALF_D := 6.5   # deck spans z -6.5..6.5
const CHUNK := 4

var player_spawn := Vector3(0, 0, 2.0)
var enemy_spawns: Array = []
var camera_bounds := Rect2(-0.9, -1.2, 1.8, 2.2)

var _body: StaticBody3D
var _mats := {}
var _rng := RandomNumberGenerator.new()
var _lanterns: Array = []   # [{light, base, seed}]
var _t := 0.0


func _ready() -> void:
	_rng.seed = 4242
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_make_materials()
	_build_deck()
	_build_edges()
	_build_props()
	_build_lanterns()
	_build_compass_and_conduits()
	_build_ship()
	_build_islands()
	_build_atmosphere()
	enemy_spawns = [
		Vector3(-6.5, 0, -4.5), Vector3(6.5, 0, -4.5), Vector3(-7.0, 0, 3.5), Vector3(7.0, 0, 3.5),
		Vector3(0.0, 0, -5.2), Vector3(-3.5, 0, -5.0), Vector3(3.5, 0, -5.0), Vector3(0.0, 0, 5.5),
	]


func _process(delta: float) -> void:
	_t += delta
	for l in _lanterns:
		var light: OmniLight3D = l["light"]
		var s: float = l["seed"]
		var base: float = l["base"]
		light.light_energy = base * (0.9 + 0.07 * sin(_t * 6.0 + s) + 0.03 * sin(_t * 15.0 + s * 3.0))


# ---------------------------------------------------------------- materials

func _tri(kind: String, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = PixelArt.tile_texture(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.roughness = roughness
	m.metallic = metallic
	m.vertex_color_use_as_albedo = true
	return m


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _make_materials() -> void:
	_mats["deck"] = _tri("deck", 0.8)
	_mats["hull"] = _tri("hull", 0.9)
	_mats["brass"] = _tri("brass", 0.38, 0.4)
	_mats["crate"] = _tri("crate")
	_mats["barrel"] = _tri("barrel")
	_mats["rope"] = _tri("rope", 0.95)
	_mats["stone"] = _tri("stone")
	_mats["rock"] = _tri("rock", 0.95)
	_mats["moss"] = _tri("moss", 0.95)
	var groove := StandardMaterial3D.new()
	groove.albedo_color = Color("140c10")
	_mats["groove"] = groove


# ---------------------------------------------------------------- helpers

func _mesh(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, shadows := true) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, pos, mat, rot, shadows)


func _cyl(radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, sides := 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return _mesh(c, pos, mat, rot)


func _collider_box(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = pos
	_body.add_child(cs)


func _collider_cyl(radius: float, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = 2.0
	cs.shape = s
	cs.position = pos + Vector3.UP
	_body.add_child(cs)


func _multimesh(mesh: Mesh, xforms: Array, variation: float) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		var v := 1.0 - _rng.randf() * variation
		mm.set_instance_color(i, Color(v, v * 0.98, v * 0.97))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _omni(pos: Vector3, color: Color, energy: float, light_range: float, flicker := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.position = pos
	add_child(l)
	if flicker:
		_lanterns.append({"light": l, "base": energy, "seed": _rng.randf() * 100.0})
	return l


## Places something so it appears at screen-height `up` (meters above screen center at focus 0).
func _z_for_screen_up(y: float, up: float) -> float:
	var p := deg_to_rad(HD2D.PITCH_DEG)
	return (y * cos(p) - up) / sin(p)


# ---------------------------------------------------------------- deck

func _build_deck() -> void:
	var tile := BoxMesh.new()
	tile.size = Vector3(1.0, 0.2, 1.0)
	tile.material = _mats["deck"]
	# One MultiMesh per 4x4 m chunk keeps per-object light counts low on mobile.
	for cx in range(-int(HALF_W) - 1, int(HALF_W) + 1, CHUNK):
		for cz in range(-int(HALF_D) - 1, int(HALF_D) + 1, CHUNK):
			var xforms := []
			for x in range(cx, cx + CHUNK):
				for z in range(cz, cz + CHUNK):
					var px := x + 0.5
					var pz := z + 0.5
					if absf(px) < HALF_W and absf(pz) < HALF_D:
						xforms.append(Transform3D(Basis(), Vector3(px, -0.1, pz)))
			_multimesh(tile, xforms, 0.14)
	# Platform body below the deck, stepping inward like a ship's hull.
	_box(Vector3(HALF_W * 2 + 0.6, 1.6, HALF_D * 2 + 0.6), Vector3(0, -1.0, 0), _mats["hull"])
	_box(Vector3(HALF_W * 2 + 0.8, 0.14, HALF_D * 2 + 0.8), Vector3(0, -0.28, 0), _mats["brass"])
	_box(Vector3(HALF_W * 2 - 3.0, 1.4, HALF_D * 2 - 3.0), Vector3(0, -2.4, 0), _mats["hull"])
	_box(Vector3(HALF_W * 2 - 7.0, 1.2, HALF_D * 2 - 6.0), Vector3(0, -3.6, 0), _mats["hull"])
	# Levitation crystal under the dock.
	var crystal := _box(Vector3(1.4, 2.6, 1.4), Vector3(0, -5.2, 0), _emissive(Color(0.45, 0.8, 1.0), 3.0), Vector3(0, PI / 4, 0), false)
	crystal.scale = Vector3(1, 1, 1)
	_omni(Vector3(0, -4.0, 2.0), Color(0.45, 0.8, 1.0), 2.0, 9.0, false)


func _build_edges() -> void:
	var brass: Material = _mats["brass"]
	_box(Vector3(HALF_W * 2 + 0.4, 0.12, 0.2), Vector3(0, 0.06, -HALF_D - 0.1), brass)
	_box(Vector3(HALF_W * 2 + 0.4, 0.12, 0.2), Vector3(0, 0.06, HALF_D + 0.1), brass)
	_box(Vector3(0.2, 0.12, HALF_D * 2 + 0.4), Vector3(-HALF_W - 0.1, 0.06, 0), brass)
	_box(Vector3(0.2, 0.12, HALF_D * 2 + 0.4), Vector3(HALF_W + 0.1, 0.06, 0), brass)
	# Railings on three sides; the camera side stays open (low bollards only).
	_railing(Vector3(-HALF_W, 0, -HALF_D - 0.1), Vector3(-1.4, 0, -HALF_D - 0.1))
	_railing(Vector3(1.4, 0, -HALF_D - 0.1), Vector3(HALF_W, 0, -HALF_D - 0.1))
	_railing(Vector3(-HALF_W - 0.1, 0, -HALF_D), Vector3(-HALF_W - 0.1, 0, HALF_D))
	_railing(Vector3(HALF_W + 0.1, 0, -HALF_D), Vector3(HALF_W + 0.1, 0, HALF_D))
	for x in [-6.5, -2.5, 2.5, 6.5]:
		_cyl(0.13, 0.45, Vector3(x, 0.22, HALF_D - 0.05), brass)
		_cyl(0.17, 0.08, Vector3(x, 0.47, HALF_D - 0.05), brass)
	# Invisible boundary.
	_collider_box(Vector3(HALF_W * 2 + 2, 2, 1), Vector3(0, 1, -HALF_D - 0.6))
	_collider_box(Vector3(HALF_W * 2 + 2, 2, 1), Vector3(0, 1, HALF_D + 0.3))
	_collider_box(Vector3(1, 2, HALF_D * 2 + 2), Vector3(-HALF_W - 0.6, 1, 0))
	_collider_box(Vector3(1, 2, HALF_D * 2 + 2), Vector3(HALF_W + 0.6, 1, 0))


func _railing(a: Vector3, b: Vector3) -> void:
	var brass: Material = _mats["brass"]
	var length := a.distance_to(b)
	var n := maxi(1, int(ceil(length / 1.6)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_cyl(0.06, 1.0, p + Vector3(0, 0.5, 0), brass, Vector3.ZERO, 8)
		var finial := SphereMesh.new()
		finial.radius = 0.09
		finial.height = 0.18
		finial.radial_segments = 8
		finial.rings = 4
		_mesh(finial, p + Vector3(0, 1.04, 0), brass)
	var mid := (a + b) * 0.5
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var rail_size := Vector3(length, 0.1, 0.12) if along_x else Vector3(0.12, 0.1, length)
	_box(rail_size, mid + Vector3(0, 0.95, 0), _mats["hull"])
	var low_size := Vector3(length, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, length)
	_box(low_size, mid + Vector3(0, 0.5, 0), brass)


# ---------------------------------------------------------------- props

func _crate(pos: Vector3, rot := 0.0, size := 0.9) -> void:
	_box(Vector3(size, size, size), pos + Vector3(0, size * 0.5, 0), _mats["crate"], Vector3(0, rot, 0))
	if pos.y < 0.1:
		_collider_box(Vector3(size, 2, size), pos + Vector3(0, 1, 0))


func _barrel(pos: Vector3) -> void:
	_cyl(0.36, 0.9, pos + Vector3(0, 0.45, 0), _mats["barrel"])
	for y in [0.18, 0.72]:
		_cyl(0.375, 0.06, pos + Vector3(0, y, 0), _mats["brass"])
	_collider_cyl(0.38, pos)


func _rope_coil(pos: Vector3) -> void:
	for k in 3:
		var t := TorusMesh.new()
		t.inner_radius = 0.16 - k * 0.03
		t.outer_radius = 0.42 - k * 0.04
		t.rings = 12
		t.ring_segments = 6
		_mesh(t, pos + Vector3(0, 0.07 + k * 0.1, 0), _mats["rope"])


func _build_props() -> void:
	_crate(Vector3(-7.2, 0, -5.2), 0.1)
	_crate(Vector3(-6.2, 0, -5.4), -0.15)
	_crate(Vector3(-7.1, 0.9, -5.25), 0.35, 0.8)
	_crate(Vector3(7.0, 0, 4.6), 0.2)
	_crate(Vector3(6.4, 0, 5.5), -0.1, 0.75)
	_barrel(Vector3(-5.1, 0, -5.7))
	_barrel(Vector3(7.4, 0, -5.4))
	_barrel(Vector3(7.7, 0, -4.5))
	_barrel(Vector3(-7.6, 0, 4.4))
	_rope_coil(Vector3(-3.0, 0, 5.6))
	_rope_coil(Vector3(5.2, 0, -5.8))
	_rope_coil(Vector3(-7.6, 0, 1.6))
	_build_armillary(Vector3(5.6, 0, 1.2))
	_build_cannon(Vector3(-2.8, 0, -5.9))


func _build_armillary(pos: Vector3) -> void:
	var brass: Material = _mats["brass"]
	_cyl(0.35, 0.3, pos + Vector3(0, 0.15, 0), _mats["stone"])
	_cyl(0.06, 0.9, pos + Vector3(0, 0.75, 0), brass, Vector3.ZERO, 8)
	var center := pos + Vector3(0, 1.45, 0)
	var core := SphereMesh.new()
	core.radius = 0.12
	core.height = 0.24
	_mesh(core, center, _emissive(Color(1.0, 0.75, 0.35), 4.0), Vector3.ZERO, false)
	for k in 3:
		var t := TorusMesh.new()
		t.inner_radius = 0.48 - k * 0.1
		t.outer_radius = 0.52 - k * 0.1
		t.rings = 24
		t.ring_segments = 4
		var ring := _mesh(t, center, brass, Vector3(PI * 0.5 * k * 0.6, k * 0.8, 0.3 * k))
		var tw := ring.create_tween().set_loops()
		tw.tween_property(ring, "rotation:y", ring.rotation.y + TAU * (1 if k % 2 == 0 else -1), 9.0 + k * 3.0).from(ring.rotation.y)
	_collider_cyl(0.45, pos)


func _build_cannon(pos: Vector3) -> void:
	_box(Vector3(0.7, 0.35, 0.9), pos + Vector3(0, 0.2, 0), _mats["hull"])
	_cyl(0.16, 1.3, pos + Vector3(0, 0.5, -0.3), _mats["brass"], Vector3(deg_to_rad(80), 0, 0))
	_collider_box(Vector3(0.8, 2, 1.0), pos + Vector3(0, 1, 0))


func _build_lanterns() -> void:
	var gold := Color(1.0, 0.72, 0.38)
	var cyan := Color(0.45, 0.85, 1.0)
	var violet := Color(0.78, 0.5, 1.0)
	_lantern(Vector3(-4.6, 0, -6.2), gold)
	_lantern(Vector3(4.6, 0, -6.2), gold)
	_lantern(Vector3(-8.0, 0, 6.0), cyan)
	_lantern(Vector3(8.0, 0, 6.0), cyan)
	_lantern(Vector3(-8.0, 0, -1.2), violet)
	_lantern(Vector3(8.0, 0, -1.6), gold)


func _lantern(pos: Vector3, color: Color) -> void:
	var brass: Material = _mats["brass"]
	_box(Vector3(0.3, 0.1, 0.3), pos + Vector3(0, 0.05, 0), brass)
	_cyl(0.05, 1.7, pos + Vector3(0, 0.85, 0), brass, Vector3.ZERO, 8)
	_box(Vector3(0.28, 0.04, 0.28), pos + Vector3(0, 1.72, 0), brass)
	_box(Vector3(0.24, 0.04, 0.24), pos + Vector3(0, 1.32, 0), brass)
	var core_pos := pos + Vector3(0, 1.52, 0)
	_box(Vector3(0.13, 0.26, 0.13), core_pos, _emissive(color, 5.0), Vector3(0, PI / 4, 0), false)
	_omni(core_pos, color, 1.8, 6.0)
	_collider_cyl(0.2, pos)
	var p := CPUParticles3D.new()
	p.mesh = Game.particle_mesh(0.035)
	p.amount = maxi(2, int(6 * Game.particle_scale()))
	p.lifetime = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, 0.05, 0)
	p.color_ramp = Game.fade_ramp(Color(color.r * 1.4, color.g * 1.4, color.b * 1.4), true)
	p.position = core_pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


# ---------------------------------------------------------------- magic

func _build_compass_and_conduits() -> void:
	var sh := Shader.new()
	sh.code = COMPASS_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", PixelArt.compass_texture())
	m.set_shader_parameter("color", Color(0.45, 0.85, 1.0))
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.0, 5.0)
	var compass := _mesh(pm, Vector3(0, 0.012, 0), m, Vector3.ZERO, false)
	var tw := compass.create_tween().set_loops()
	tw.tween_property(compass, "rotation:y", TAU, 90.0).from(0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 2.5
	ring.outer_radius = 2.62
	ring.rings = 48
	ring.ring_segments = 4
	var r := _mesh(ring, Vector3(0, 0.0, 0), _mats["brass"])
	r.scale = Vector3(1, 0.4, 1)

	var csh := Shader.new()
	csh.code = CONDUIT_SHADER
	var cm := ShaderMaterial.new()
	cm.shader = csh
	cm.set_shader_parameter("color", Color(0.45, 0.85, 1.0))
	var targets := [Vector3(-8.0, 0, 6.0), Vector3(8.0, 0, 6.0), Vector3(-4.6, 0, -6.2), Vector3(4.6, 0, -6.2), Vector3(-8.0, 0, -1.2), Vector3(8.0, 0, -1.6)]
	for t in targets:
		var dir: Vector3 = (t as Vector3).normalized()
		var a: Vector3 = dir * 2.65
		var b: Vector3 = t - dir * 0.3
		var length := a.distance_to(b)
		var mid := (a + b) * 0.5
		var yaw := atan2(dir.x, dir.z)
		_box(Vector3(0.24, 0.02, length), mid + Vector3(0, 0.005, 0), _mats["groove"], Vector3(0, yaw, 0), false)
		_box(Vector3(0.1, 0.02, length), mid + Vector3(0, 0.012, 0), cm, Vector3(0, yaw, 0), false)


# ---------------------------------------------------------------- background

func _build_ship() -> void:
	var z := -10.3
	var dy := -0.6
	var hull: Material = _mats["hull"]
	var brass: Material = _mats["brass"]
	_box(Vector3(16.0, 2.4, 4.0), Vector3(0, dy - 1.2, z), hull)
	_box(Vector3(13.0, 1.6, 2.8), Vector3(0, dy - 3.0, z), hull)
	_box(Vector3(16.2, 0.16, 4.2), Vector3(0, dy - 0.05, z), brass)
	_box(Vector3(15.8, 0.1, 3.8), Vector3(0, dy + 0.02, z), _mats["deck"])
	_box(Vector3(3.0, 2.4, 3.0), Vector3(8.2, dy - 1.2, z), hull, Vector3(0, PI / 4, 0))
	_cyl(0.09, 5.0, Vector3(10.6, dy + 0.8, z), hull, Vector3(0, 0, deg_to_rad(-68)), 6)
	_box(Vector3(3.4, 1.8, 4.0), Vector3(-6.4, dy + 0.9, z), hull)
	_box(Vector3(3.6, 0.12, 4.2), Vector3(-6.4, dy + 1.82, z), brass)
	for wx in [-7.4, -6.4, -5.4]:
		_box(Vector3(0.4, 0.4, 0.05), Vector3(wx, dy + 1.0, z + 2.02), _emissive(Color(1.0, 0.75, 0.4), 3.0), Vector3.ZERO, false)
	var sail_sh := Shader.new()
	sail_sh.code = SAIL_SHADER
	var sail := ShaderMaterial.new()
	sail.shader = sail_sh
	sail.set_shader_parameter("sigil", PixelArt.compass_texture(96))
	sail.set_shader_parameter("glow", Color(0.45, 0.85, 1.0))
	for mx in [-1.5, 3.8]:
		_cyl(0.16, 12.0, Vector3(mx, dy + 6.0, z), hull, Vector3.ZERO, 8)
		for k in 2:
			var h := dy + 3.4 + k * 3.6
			_box(Vector3(5.0, 0.12, 0.12), Vector3(mx, h + 1.4, z + 0.2), hull)
			var q := QuadMesh.new()
			q.size = Vector2(4.6 - k * 0.8, 2.8)
			q.subdivide_width = 6
			q.subdivide_depth = 4
			_mesh(q, Vector3(mx, h, z + 0.3), sail, Vector3.ZERO, false)
	# Gangplank from the dock to the ship.
	_box(Vector3(1.1, 0.08, 3.4), Vector3(0, -0.28, -HALF_D - 1.7), _mats["deck"], Vector3(deg_to_rad(-5), 0, 0))
	_omni(Vector3(-6.4, dy + 2.4, z + 2.4), Color(1.0, 0.72, 0.4), 1.5, 5.0)


func _build_islands() -> void:
	# [x, y, screen-up, radius]
	# Orthographic cameras don't shrink distant objects, so far islands are built
	# smaller and sit deeper in the height fog to read as distant.
	var specs := [
		[-11.2, -3.0, 2.6, 1.3], [-12.6, -9.0, -3.0, 1.6], [-10.6, -14.0, 5.6, 1.4],
		[11.2, -4.0, -1.6, 1.4], [12.4, -11.0, 4.2, 1.8], [10.6, -16.0, -4.4, 2.0],
		[-4.5, -12.0, 7.4, 1.5], [6.5, -8.0, 7.8, 1.1], [1.0, -22.0, 6.6, 2.6], [-10.4, -6.0, -5.8, 1.0],
	]
	var crystal_colors := [Color(0.45, 0.85, 1.0), Color(0.78, 0.5, 1.0), Color(1.0, 0.65, 0.3)]
	for s in specs:
		var x: float = s[0]
		var y: float = s[1]
		var r: float = s[3]
		var z := _z_for_screen_up(y, s[2])
		var island := Node3D.new()
		island.position = Vector3(x, y, z)
		add_child(island)
		var rock := CylinderMesh.new()
		rock.top_radius = r
		rock.bottom_radius = r * 0.12
		rock.height = r * 1.7
		rock.radial_segments = 7
		rock.rings = 2
		var rmi := MeshInstance3D.new()
		rmi.mesh = rock
		rmi.material_override = _mats["rock"]
		rmi.position.y = -r * 0.85
		rmi.rotation.y = _rng.randf() * TAU
		island.add_child(rmi)
		var top := CylinderMesh.new()
		top.top_radius = r * 1.02
		top.bottom_radius = r * 0.98
		top.height = 0.35
		top.radial_segments = 7
		top.rings = 1
		var tmi := MeshInstance3D.new()
		tmi.mesh = top
		tmi.material_override = _mats["moss"]
		tmi.rotation.y = rmi.rotation.y
		island.add_child(tmi)
		var cc: Color = crystal_colors[_rng.randi() % crystal_colors.size()]
		for k in 2:
			var cb := BoxMesh.new()
			cb.size = Vector3(0.3, 0.9 + k * 0.4, 0.3)
			var cmi := MeshInstance3D.new()
			cmi.mesh = cb
			cmi.material_override = _emissive(cc, 3.0)
			cmi.position = Vector3(_rng.randf_range(-r, r) * 0.5, 0.5, _rng.randf_range(-r, r) * 0.5)
			cmi.rotation = Vector3(0.2 * k, PI / 4, -0.15)
			cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			island.add_child(cmi)
		var tw := island.create_tween().set_loops()
		var dur := _rng.randf_range(3.5, 6.0)
		tw.tween_property(island, "position:y", y + 0.35, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(island, "position:y", y - 0.35, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_atmosphere() -> void:
	# Drifting stardust over the deck.
	var dust := CPUParticles3D.new()
	dust.mesh = Game.particle_mesh(0.04)
	dust.amount = maxi(10, int(70 * Game.particle_scale()))
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(HALF_W + 2.0, 1.5, HALF_D + 1.0)
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.2
	dust.gravity = Vector3(0, 0.04, 0)
	dust.color_ramp = Game.fade_ramp(Color(1.2, 1.1, 0.85), true)
	dust.position = Vector3(0, 1.6, 0)
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	# Motes rising from the compass inlay.
	var motes := CPUParticles3D.new()
	motes.mesh = Game.particle_mesh(0.05)
	motes.amount = maxi(6, int(24 * Game.particle_scale()))
	motes.lifetime = 3.0
	motes.preprocess = 3.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_radius = 2.4
	motes.emission_ring_inner_radius = 2.2
	motes.emission_ring_height = 0.0
	motes.direction = Vector3.UP
	motes.spread = 10.0
	motes.initial_velocity_min = 0.3
	motes.initial_velocity_max = 0.6
	motes.gravity = Vector3.ZERO
	motes.color_ramp = Game.fade_ramp(Color(0.6, 1.1, 1.4), true)
	motes.position = Vector3(0, 0.05, 0)
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)


# ---------------------------------------------------------------- shaders

const COMPASS_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 color : source_color;
void fragment() {
	vec4 t = texture(tex, UV);
	float d = length(UV - 0.5);
	float pulse = 0.7 + 0.3 * sin(TIME * 2.0 - floor(d * 40.0) / 40.0 * 14.0);
	ALBEDO = color.rgb * 2.2 * pulse;
	ALPHA = t.a * 0.9;
}
"""

const CONDUIT_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec4 color : source_color;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float d = floor(length(wp.xz) * 32.0) / 32.0;
	float flow = fract(d * 0.45 - TIME * 0.5);
	float pulse = smoothstep(0.0, 0.08, flow) * smoothstep(0.35, 0.08, flow);
	ALBEDO = color.rgb * (0.55 + 2.6 * pulse);
}
"""

const SAIL_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D sigil : source_color, filter_nearest;
uniform vec4 glow : source_color;
void vertex() {
	VERTEX.z += sin(TIME * 1.3 + VERTEX.x * 0.9) * 0.12 * (0.5 - UV.y + 0.5);
}
void fragment() {
	vec4 s = texture(sigil, UV);
	ALBEDO = vec3(0.82, 0.84, 0.92);
	EMISSION = glow.rgb * s.a * (1.6 + 0.5 * sin(TIME * 2.0));
	ROUGHNESS = 0.9;
}
"""
