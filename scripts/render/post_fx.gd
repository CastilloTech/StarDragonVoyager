extends CanvasLayer
## Screen post-processing: tilt-shift blur at the top/bottom of the screen
## (the HD-2D "diorama" look), vignette and a gentle indigo color grade.
## Disabled on Low quality to save fill-rate on phones.

var _rect: ColorRect


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	_rect.material = m
	add_child(_rect)
	Game.settings_changed.connect(_apply_quality)
	_apply_quality()


func _apply_quality() -> void:
	visible = Game.quality != Game.Quality.LOW


const SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float focus_center = 0.5;
uniform float focus_half_width = 0.22;
uniform float max_lod = 2.4;
uniform float vignette = 0.42;

void fragment() {
	float d = abs(SCREEN_UV.y - focus_center);
	float blur = smoothstep(focus_half_width, focus_half_width + 0.32, d);
	vec3 col = textureLod(screen_tex, SCREEN_UV, blur * max_lod).rgb;
	vec2 v = SCREEN_UV - 0.5;
	float vig = smoothstep(0.38, 0.85, length(v * vec2(1.0, 0.85)));
	col *= 1.0 - vig * vignette;
	col = mix(col, col * vec3(0.92, 0.9, 1.08), 0.5 * vig);
	COLOR = vec4(col, 1.0);
}
"""
