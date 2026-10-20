extends Node
## Autoload "Game": references to key nodes, player settings, and shared
## combat-feel effects (hit-stop, shake, particles, floating text).

const PixelArt := preload("res://scripts/render/pixel_art.gd")
const HD2D := preload("res://scripts/core/hd2d.gd")
const E := preload("res://scripts/core/elements.gd")

signal settings_changed

enum Quality { LOW, MEDIUM, HIGH }

const SETTINGS_PATH := "user://settings.cfg"
const MAX_FLASH_LIGHTS := 4   # mobile renderer: keep dynamic lights per object low

var world: Node3D
var player: Node3D
var dragon: Node3D
var camera: Camera3D
var hud: CanvasLayer

# Settings (saved to user://settings.cfg)
var quality: int = Quality.HIGH
var shake_enabled := true
var touch_controls := false
var tutorial_done := false

var _particle_meshes := {}
var _slash_tex: Texture2D
var _ring_tex: Texture2D
var _shadow_mat: StandardMaterial3D
var _font: SystemFont
var _hitstop_count := 0
var _slowmo_until := 0
var _spark_tex: Texture2D
var _flash_lights := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mobile := OS.has_feature("mobile")
	touch_controls = mobile
	quality = Quality.MEDIUM if mobile else Quality.HIGH
	_load_settings()
	if "--touch" in OS.get_cmdline_user_args():
		touch_controls = true
		Input.emulate_touch_from_mouse = true   # lets the mouse drive the touch UI on desktop
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Noto Serif", "serif"])
	_font.font_weight = 700


func reset(new_world: Node3D) -> void:
	world = new_world
	player = null
	dragon = null
	camera = null
	hud = null
	_hitstop_count = 0
	_slowmo_until = 0
	_flash_lights = 0
	Engine.time_scale = 1.0
	apply_settings()


# ---------------------------------------------------------------- settings

func apply_settings() -> void:
	var vp := get_tree().root
	# Lower quality renders the 3D world at fewer pixels; the HUD stays native.
	# Desktop (Forward+) can use FSR upscaling; the Mobile renderer only has bilinear.
	var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
	vp.scaling_3d_scale = [0.67, 0.84, 1.0][quality]
	if forward_plus and quality < Quality.HIGH:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	settings_changed.emit()


func set_quality(q: int) -> void:
	quality = clampi(q, 0, 2)
	apply_settings()
	save_settings()


func particle_scale() -> float:
	return [0.45, 0.75, 1.0][quality]


func dynamic_lights_enabled() -> bool:
	return quality >= Quality.MEDIUM


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality)
	cfg.set_value("game", "shake", shake_enabled)
	if not ("--touch" in OS.get_cmdline_user_args()):   # a test flag shouldn't stick
		cfg.set_value("game", "touch", touch_controls)
	cfg.set_value("game", "tutorial_done", tutorial_done)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	quality = cfg.get_value("video", "quality", quality)
	shake_enabled = cfg.get_value("game", "shake", shake_enabled)
	touch_controls = cfg.get_value("game", "touch", touch_controls)
	tutorial_done = cfg.get_value("game", "tutorial_done", tutorial_done)


# ---------------------------------------------------------------- queries

func enemies() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	return out


## The captain and the dragon, when alive (targets for enemy attacks).
func allies() -> Array:
	var out := []
	for a in [player, dragon]:
		if a != null and is_instance_valid(a) and a.is_alive():
			out.append(a)
	return out


## Hits every ally inside a cone (or within `close` distance). Returns how many were hit.
func hit_allies_in_arc(origin: Vector3, dir: Vector3, reach: float, min_dot: float, info_maker: Callable, close := 0.5) -> int:
	var n := 0
	for a in allies():
		var to: Vector3 = a.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > reach:
			continue
		if d > close and dir.dot(to / d) < min_dot:
			continue
		a.take_damage(info_maker.call())
		n += 1
	return n


func ui_font() -> Font:
	return _font


# ---------------------------------------------------------------- combat feel

const SLOWMO_SCALE := 0.3


func is_hitstopped() -> bool:
	return _hitstop_count > 0


func _base_time_scale() -> float:
	return SLOWMO_SCALE if Time.get_ticks_msec() < _slowmo_until else 1.0


## Freezes the game for `duration` real seconds (the "impact frame").
func hitstop(duration: float) -> void:
	_hitstop_count += 1
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstop_count -= 1
	if _hitstop_count <= 0:
		_hitstop_count = 0
		Engine.time_scale = _base_time_scale()


## Slow motion for `duration` real seconds (used on the last kill of a wave).
func slowmo(duration: float) -> void:
	_slowmo_until = Time.get_ticks_msec() + int(duration * 1000.0)
	if _hitstop_count == 0:
		Engine.time_scale = SLOWMO_SCALE
	await get_tree().create_timer(duration, true, false, true).timeout
	if Time.get_ticks_msec() >= _slowmo_until and _hitstop_count == 0:
		Engine.time_scale = 1.0


func shake(amount: float) -> void:
	if shake_enabled and camera and is_instance_valid(camera):
		camera.add_trauma(amount)


## The "weight" of a hit in one call. strength 0..1 (light jab .. charged finisher):
## scales hit-stop, screen shake, a camera jolt toward the hit, and for big hits
## a zoom punch plus a dust ring on the deck.
func impact(pos: Vector3, dir: Vector3, strength: float) -> void:
	strength = clampf(strength, 0.0, 1.0)
	hitstop(lerpf(0.04, 0.13, strength))
	shake(lerpf(0.08, 0.5, strength))
	if shake_enabled and camera and is_instance_valid(camera):
		camera.kick(dir, lerpf(0.05, 0.22, strength))
		if strength >= 0.7:
			camera.punch(lerpf(0.02, 0.05, strength))
	if strength >= 0.7:
		var ground := Vector3(pos.x, 0.0, pos.z)
		ring_fx(ground, Color(1.0, 0.95, 0.85), 1.0 + strength, 0.25)
		burst(ground + Vector3.UP * 0.1, Color(0.72, 0.64, 0.56), 12, 3.5, 0.09, 0.45, -4.0, false)


## Pixel star burst where a hit lands.
func spark(pos: Vector3, size := 1.0, color := Color(1.0, 0.97, 0.85)) -> void:
	if world == null:
		return
	if _spark_tex == null:
		_spark_tex = PixelArt.spark_texture()
	var s := Sprite3D.new()
	s.texture = _spark_tex
	s.pixel_size = HD2D.PIXEL_SIZE
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 5
	s.modulate = Color(color.r * 1.8, color.g * 1.8, color.b * 1.8, 1.0)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.flip_h = randf() < 0.5
	world.add_child(s)
	s.global_position = pos
	s.scale = Vector3.ONE * size * 0.5
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * size * 1.2, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.09)
	tw.tween_callback(s.queue_free)


## Red flash at the screen edges when the captain is hurt.
func hurt_flash(strength := 1.0) -> void:
	if hud and is_instance_valid(hud) and hud.has_method("flash_damage"):
		hud.flash_damage(strength)


# ---------------------------------------------------------------- particles

func particle_mesh(size: float, additive := true) -> QuadMesh:
	var key := "%0.3f_%s" % [size, additive]
	if _particle_meshes.has(key):
		return _particle_meshes[key]
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.disable_fog = true
	q.material = m
	_particle_meshes[key] = q
	return q


func fade_ramp(c: Color, fade_in := false) -> Gradient:
	var g := Gradient.new()
	if fade_in:
		g.set_color(0, Color(c.r, c.g, c.b, 0.0))
		g.set_color(1, Color(c.r, c.g, c.b, 0.0))
		g.add_point(0.25, c)
	else:
		g.set_color(0, c)
		g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return g


## One-shot burst of square pixel particles.
func burst(pos: Vector3, color: Color, amount := 14, speed := 4.0, size := 0.08,
		life := 0.45, gravity := -4.0, additive := true) -> void:
	if world == null:
		return
	var count := maxi(2, int(amount * particle_scale()))
	var p := CPUParticles3D.new()
	p.mesh = particle_mesh(size, additive)
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 2.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = fade_ramp(color)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)


## Element-specific impact particles.
func hit_fx(pos: Vector3, element: int) -> void:
	match element:
		E.SUN:
			burst(pos, Color(1.0, 0.7, 0.25), 14, 4.5, 0.09, 0.45, 2.0)
		E.COMET:
			burst(pos, Color(0.8, 0.95, 1.0), 12, 5.0, 0.07, 0.4, -9.0)
		E.STORM:
			burst(pos, Color(0.85, 0.65, 1.0), 12, 7.0, 0.06, 0.22, 0.0)
		E.GRAVITY:
			burst(pos, Color(0.5, 0.45, 1.0), 12, 2.5, 0.09, 0.5, 0.0)
		E.VOID:
			burst(pos, Color(0.08, 0.0, 0.1), 8, 2.0, 0.12, 0.6, 1.5, false)
			burst(pos, Color(0.95, 0.3, 0.9), 8, 3.0, 0.06, 0.45, 1.0)
		_:
			burst(pos, Color(1.0, 0.95, 0.85), 8, 5.0, 0.06, 0.25, -6.0)


# ---------------------------------------------------------------- lights & shapes

func flash_light(pos: Vector3, color: Color, energy: float, duration: float, light_range := 5.0) -> void:
	if world == null or not dynamic_lights_enabled() or _flash_lights >= MAX_FLASH_LIGHTS:
		return
	_flash_lights += 1
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(func() -> void:
		_flash_lights -= 1
		l.queue_free())


func make_blob_shadow(radius: float) -> MeshInstance3D:
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.albedo_texture = PixelArt.circle_texture(32, true)
		_shadow_mat.albedo_color = Color(0.02, 0.0, 0.06, 0.55)
		_shadow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 1.5)
	mi.mesh = pm
	mi.material_override = _shadow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.015
	return mi


## Flat crescent arc on the ground plane (sword trails, wind, cleaves).
func slash_fx(pos: Vector3, dir: Vector3, color: Color, size: float, duration := 0.18) -> void:
	if world == null:
		return
	if _slash_tex == null:
		_slash_tex = PixelArt.crescent_texture()
	var pivot := Node3D.new()
	world.add_child(pivot)
	pivot.global_position = pos
	pivot.rotation.y = atan2(-dir.z, dir.x)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _slash_tex
	m.albedo_color = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.disable_fog = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	pivot.scale = Vector3.ONE * 0.7
	var tw := pivot.create_tween().set_parallel(true)
	tw.tween_property(pivot, "scale", Vector3.ONE * 1.05, duration * 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(pivot.queue_free)


## Expanding ring on the ground (explosions, landings, implosions).
func ring_fx(pos: Vector3, color: Color, radius: float, duration := 0.35, shrink := false) -> void:
	if world == null:
		return
	if _ring_tex == null:
		_ring_tex = PixelArt.circle_texture(64, false)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0, 2.0)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _ring_tex
	m.albedo_color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.disable_fog = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.03
	var from := radius if shrink else radius * 0.2
	var to := radius * 0.1 if shrink else radius
	mi.scale = Vector3(from, 1.0, from)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(to, 1.0, to), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


## Jagged lightning through a list of points.
func lightning_fx(points: Array, color: Color) -> void:
	if world == null or points.size() < 2:
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2)
	m.disable_fog = true
	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.albedo_color = Color(2.5, 2.5, 2.5)
	core.disable_fog = true
	var holder := Node3D.new()
	world.add_child(holder)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var prev := a
		var segs := 6
		for s in range(1, segs + 1):
			var p := a.lerp(b, float(s) / segs)
			if s < segs:
				p += Vector3(randf_range(-0.3, 0.3), randf_range(-0.15, 0.3), randf_range(-0.3, 0.3))
			_bolt_segment(holder, prev, p, m, 0.09)
			_bolt_segment(holder, prev, p, core, 0.035)
			prev = p
		flash_light(b, color, 3.0, 0.2)
		burst(b, color, 8, 5.0, 0.06, 0.2, 0.0)
	var tw := holder.create_tween()
	tw.tween_interval(0.06)
	tw.tween_callback(func() -> void: holder.visible = false)
	tw.tween_interval(0.03)
	tw.tween_callback(func() -> void: holder.visible = true)
	tw.tween_interval(0.07)
	tw.tween_callback(holder.queue_free)


func _bolt_segment(parent: Node3D, a: Vector3, b: Vector3, mat: Material, width: float) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, length)
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	mi.look_at_from_position((a + b) * 0.5, b, up)


## Area damage with visuals. Uses `element` for status effects (PHYSICAL avoids combo loops).
func explosion(pos: Vector3, radius: float, damage: float, element: int, exclude: Node, color: Color) -> void:
	const Damage := preload("res://scripts/core/damage.gd")
	burst(pos + Vector3.UP * 0.5, color, 26, 6.0, 0.1, 0.5, 1.0)
	ring_fx(pos, color, radius, 0.35)
	flash_light(pos + Vector3.UP, color, 6.0, 0.35, radius * 2.5)
	shake(0.35)
	Audio.play("explode")
	for e in enemies():
		if e == exclude:
			continue
		var to: Vector3 = e.global_position - pos
		to.y = 0.0
		if to.length() <= radius + e.radius:
			var dir := to.normalized() if to.length() > 0.01 else Vector3.RIGHT
			e.take_damage(Damage.make(damage, element, dir, 7.0, true))


# ---------------------------------------------------------------- text

func damage_number(pos: Vector3, amount: float, color: Color, crit := false) -> void:
	var text := str(roundi(amount))
	if crit:
		float_text(pos + Vector3(randf_range(-0.3, 0.3), 1.5, 0), text + "!", Color(1.0, 0.86, 0.3), 44, 0.8)
	else:
		float_text(pos + Vector3(randf_range(-0.3, 0.3), 1.4, 0), text, color, 32, 0.65)


func float_text(pos: Vector3, text: String, color: Color, size := 36, duration := 0.9) -> void:
	if world == null:
		return
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0.04, 0.02, 0.08)
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	world.add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.6
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", pos.y + 0.9, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tw.tween_property(l, "outline_modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tw.chain().tween_callback(l.queue_free)


## Fading afterimage of an animated sprite (dodge trail).
func ghost(sprite: AnimatedSprite3D, color: Color) -> void:
	if world == null:
		return
	var g := Sprite3D.new()
	g.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	g.pixel_size = sprite.pixel_size
	g.flip_h = sprite.flip_h
	g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	g.shaded = false
	g.modulate = Color(color.r, color.g, color.b, 0.5)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(g)
	g.global_transform = sprite.global_transform
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)
