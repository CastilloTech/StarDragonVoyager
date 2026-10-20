extends CanvasLayer
## Pause menu with the minimal settings for the prototype:
## graphics quality, screen shake, touch controls, fullscreen (desktop).

const UI := preload("res://scripts/ui/ui_style.gd")

signal restart_requested

var _quality: OptionButton
var _shake: CheckBox
var _touch: CheckBox


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.04, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	var style := UI.panel(UI.NAVY, UI.BRASS, 3, 6)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(320, 0)
	panel.add_child(box)
	var title := UI.label("✦  Paused  ✦", 30, UI.BRASS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_button("Resume", toggle))
	box.add_child(_button("Restart Encounter", func() -> void: restart_requested.emit()))
	box.add_child(_controls_card())

	var qrow := HBoxContainer.new()
	qrow.add_child(UI.label("Graphics", 18))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(spacer)
	_quality = OptionButton.new()
	for q in ["Low", "Medium", "High"]:
		_quality.add_item(q)
	_quality.custom_minimum_size = Vector2(130, 44)
	_quality.item_selected.connect(func(i: int) -> void: Game.set_quality(i))
	qrow.add_child(_quality)
	box.add_child(qrow)

	_shake = CheckBox.new()
	_shake.text = "Screen shake"
	_shake.toggled.connect(func(on: bool) -> void:
		Game.shake_enabled = on
		Game.save_settings())
	box.add_child(_shake)
	_touch = CheckBox.new()
	_touch.text = "Touch controls"
	_touch.toggled.connect(func(on: bool) -> void:
		Game.touch_controls = on
		Game.save_settings()
		Game.settings_changed.emit())
	box.add_child(_touch)
	if not OS.has_feature("mobile"):
		var full := CheckBox.new()
		full.text = "Fullscreen"
		full.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		full.toggled.connect(func(on: bool) -> void:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
		box.add_child(full)
		box.add_child(_button("Quit", func() -> void: get_tree().quit()))


## Two-column list of controls (keyboard + mouse, or touch).
func _controls_card() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel(UI.NAVY_DEEP, UI.BRASS_DIM, 1, 4))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	panel.add_child(grid)
	var rows := [
		["WASD", "Move"], ["Mouse", "Aim"],
		["Left click", "Attack (3-hit combo)"], ["Hold left click", "Charge, release to unleash"],
		["Right click", "Cast element spell"], ["Q / E, wheel, 1–5", "Switch element"],
		["Space / Shift", "Dash (no direction = hop back)"], ["F", "Nova: Comet Shower"],
		["Esc", "Pause"],
	]
	if Game.touch_controls:
		rows = [
			["Left thumb", "Move (auto-aim)"], ["ATTACK tap", "Combo"], ["ATTACK hold", "Charge, release"],
			["Element button", "Cast spell"], ["Small button", "Switch element"],
			["DASH", "Dodge"], ["Dragon button", "Comet Shower"],
		]
	for r in rows:
		grid.add_child(UI.label(r[0], 14, UI.BRASS))
		grid.add_child(UI.label(r[1], 14, UI.TEXT))
	return panel


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	Engine.time_scale = 1.0
	if visible:
		_quality.select(Game.quality)
		_shake.set_pressed_no_signal(Game.shake_enabled)
		_touch.set_pressed_no_signal(Game.touch_controls)
