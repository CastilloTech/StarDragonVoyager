extends Camera3D
## CameraController: orthographic three-quarter camera with smoothing, aim
## look-ahead, arena clamping, trauma-based shake and pixel snapping.
## Also owns the cosmic sky backdrop, which is parented to the camera.

const HD2D := preload("res://scripts/core/hd2d.gd")

const DISTANCE := 30.0
const LOOK_AHEAD := 1.2
const SMOOTHING := 7.0

var target: Node3D
var bounds := Rect2(-1.5, -1.0, 3.0, 2.0)   # allowed focus area on the XZ plane
var trauma := 0.0

var _focus := Vector3.ZERO
var _t := 0.0
var _backdrop_mat: ShaderMaterial
var _pixel_world := 0.03   # world size of one screen pixel


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	near = 0.5
	far = 320.0
	rotation = Vector3(-deg_to_rad(HD2D.PITCH_DEG), 0.0, 0.0)
	current = true
	_build_backdrop()
	get_viewport().size_changed.connect(_update_size)
	_update_size()


func _update_size() -> void:
	var h := float(get_window().size.y)
	if h <= 0.0:
		return
	size = HD2D.ortho_size_for(h)
	_pixel_world = size / h


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func snap_to_target() -> void:
	if target:
		_focus = _desired_focus()
		_apply(Vector2.ZERO)


func _desired_focus() -> Vector3:
	var p := target.global_position
	var aim: Vector3 = target.get("aim_dir") if target.get("aim_dir") != null else Vector3.ZERO
	var f := p + aim * LOOK_AHEAD
	f.x = clampf(f.x, bounds.position.x, bounds.end.x)
	f.z = clampf(f.z, bounds.position.y, bounds.end.y)
	f.y = 0.0
	return f


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_focus = _focus.lerp(_desired_focus(), 1.0 - exp(-SMOOTHING * delta))
	trauma = maxf(trauma - 1.8 * delta, 0.0)
	var shake := Vector2.ZERO
	if trauma > 0.0:
		_t += delta * 45.0
		var s := trauma * trauma * 0.3
		shake = Vector2(sin(_t * 1.13), sin(_t * 1.71 + 1.7)) * s
	_apply(shake)
	if _backdrop_mat:
		_backdrop_mat.set_shader_parameter("pan", Vector2(_focus.x, _focus.z) * 0.004)


func _apply(shake: Vector2) -> void:
	var b := global_transform.basis
	var pos := _focus + b.z * DISTANCE
	# Snap the camera to the screen-pixel grid so textures don't shimmer while scrolling.
	var r := snappedf(pos.dot(b.x) + shake.x, _pixel_world)
	var u := snappedf(pos.dot(b.y) + shake.y, _pixel_world)
	var d := pos.dot(b.z)
	global_position = b.x * r + b.y * u + b.z * d


func _build_backdrop() -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(44.0, 26.0)
	mi.mesh = q
	var sh := Shader.new()
	sh.code = BACKDROP_SHADER
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = sh
	mi.material_override = _backdrop_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0, -300.0)
	add_child(mi)


const BACKDROP_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled;

uniform vec2 pan = vec2(0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	// Quantize to the art-pixel grid (44 m * 32 px) so the sky matches the pixel density.
	vec2 grid = vec2(1408.0, 832.0);
	vec2 uvq = floor(UV * grid) / grid;
	vec2 uv = uvq * vec2(3.4, 2.0) + pan;
	float t = TIME * 0.008;
	float n1 = fbm(uv * 1.4 + vec2(t, 0.0));
	float n2 = fbm(uv * 2.8 - vec2(0.0, t) + n1);
	vec3 col = vec3(0.025, 0.02, 0.075);
	col = mix(col, vec3(0.26, 0.09, 0.40), smoothstep(0.38, 0.85, n1));
	col = mix(col, vec3(0.05, 0.30, 0.42), smoothstep(0.55, 0.92, n2) * 0.65);
	col += vec3(0.65, 0.14, 0.45) * pow(smoothstep(0.55, 1.0, n1 * n2 * 1.7), 2.0) * 0.55;
	col = floor(col * 24.0) / 24.0;   // banded gradients read as pixel art
	float s = hash(floor(UV * grid + pan * 600.0));
	float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + s * 300.0);
	col += vec3(step(0.9975, s) * twinkle);
	col += vec3(0.7, 0.85, 1.0) * step(0.99975, s) * 1.6;
	ALBEDO = col;
}
"""
