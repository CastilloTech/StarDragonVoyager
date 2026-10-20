extends RefCounted
## Shared look for the celestial-navigation UI: dark navy panels, brass borders.

const NAVY := Color(0.05, 0.06, 0.14, 0.86)
const NAVY_DEEP := Color(0.03, 0.03, 0.08, 0.92)
const BRASS := Color(0.86, 0.67, 0.32)
const BRASS_DIM := Color(0.48, 0.37, 0.18)
const TEXT := Color(0.94, 0.9, 0.82)
const TEXT_DIM := Color(0.7, 0.68, 0.75)


static func panel(bg := NAVY, border := BRASS, width := 2, radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 3
	return s


static func bar(fill: Color, size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.02, 0.06, 0.9)
	bg.border_color = BRASS_DIM
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(2)
	fg.border_color = fill.lightened(0.35)
	fg.border_width_top = 1
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


static func label(text: String, size := 16, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.05, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = Game.ui_font()
	t.default_font_size = 18
	var normal := panel(NAVY_DEEP, BRASS_DIM, 2, 4)
	var hover := panel(Color(0.1, 0.1, 0.22, 0.95), BRASS, 2, 4)
	var pressed := panel(Color(0.16, 0.12, 0.08, 0.95), BRASS, 2, 4)
	for st in ["normal", "focus"]:
		t.set_stylebox(st, "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", BRASS)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	return t


## Distance in base UI pixels to keep away from notches/rounded corners on phones.
static func safe_margins(control: Control) -> Vector4:
	# Only meaningful on phones; on desktop the "safe area" is the whole monitor.
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var scale := control.get_viewport_rect().size.x / float(win.x)
	var limit := control.get_viewport_rect().size * 0.15
	return Vector4(
		clampf(safe.position.x * scale, 0.0, limit.x),
		clampf(safe.position.y * scale, 0.0, limit.y),
		clampf((win.x - safe.end.x) * scale, 0.0, limit.x),
		clampf((win.y - safe.end.y) * scale, 0.0, limit.y))
