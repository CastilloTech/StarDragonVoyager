extends CanvasLayer
## Pause menu with the minimal settings for the prototype:
## graphics quality, screen shake, touch controls, fullscreen (desktop).

const UI := preload("res://scripts/ui/ui_style.gd")

signal restart_requested
signal open_character_menu

var _reset_button: Button
var _reset_armed := false
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
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)
	var title := UI.label("✦  Paused  ✦", 30, UI.BRASS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	outer.add_child(cols)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(320, 0)
	cols.add_child(box)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	right.add_child(_controls_card())
	right.add_child(_test_tools())
	box.add_child(_button("Resume", toggle))
	box.add_child(_button("Captain's Log  (Tab)", func() -> void: open_character_menu.emit()))
	box.add_child(_button("Restart Encounter", func() -> void: restart_requested.emit()))
	_reset_button = _button("Reset all progress", _on_reset_pressed)
	box.add_child(_reset_button)

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


## Asks for a second click before wiping the save.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Click again to erase everything"
		return
	_reset_armed = false
	_reset_button.text = "Reset all progress"
	Progress.reset_all()
	restart_requested.emit()


## Quick ways to try the progression systems without grinding.
func _test_tools() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel(UI.NAVY_DEEP, UI.BRASS_DIM, 1, 4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(UI.label("TEST TOOLS", 13, UI.TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	row.add_child(_small_button("+1 Level", func() -> void: Progress.grant_xp(Progress.xp_to_next() - Progress.xp)))
	row.add_child(_small_button("Evolve dragon", func() -> void:
		const Dragons := preload("res://scripts/core/dragons.gd")
		var d: Dictionary = Progress.active()
		var stage := Dragons.stage_of(d["level"])
		if stage < 2:
			d["xp"] = 0
			d["level"] = Dragons.STAGE_LEVELS[stage + 1] - 1
			Progress.grant_xp(Dragons.xp_to_next(d["level"]))))
	row.add_child(_small_button("Random gear", func() -> void: Progress.add_random_item(3)))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	v.add_child(row2)
	row2.add_child(_small_button("+10 Levels", func() -> void:
		for _i in 10:
			Progress.grant_xp(Progress.xp_to_next() - Progress.xp)))
	row2.add_child(_small_button("Set piece", func() -> void:
		Progress.add_set_item(Progress.GearSets.SETS.keys().pick_random(), maxi(1, Progress.GearSets.tier_of_level(Progress.level)))))
	return panel


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	return b


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
		["Right click", "Cast your dragon's spell"], ["Q / E, wheel, 1–3", "Switch spell"],
		["Space / Shift", "Dash (no direction = hop back)"], ["F", "Dragon special"],
		["Tab / C", "Captain's Log: skills, gear, dragons"], ["Esc", "Pause"],
	]
	if Game.touch_controls:
		rows = [
			["Left thumb", "Move (auto-aim)"], ["ATTACK tap", "Combo"], ["ATTACK hold", "Charge, release"],
			["Spell button", "Cast spell"], ["Small button", "Switch spell"],
			["DASH", "Dodge"], ["Dragon button", "Dragon special"], ["LOG", "Skills, gear, dragons"],
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
	_reset_armed = false
	_reset_button.text = "Reset all progress"
	Engine.time_scale = 1.0
	if visible:
		_quality.select(Game.quality)
		_shake.set_pressed_no_signal(Game.shake_enabled)
		_touch.set_pressed_no_signal(Game.touch_controls)
