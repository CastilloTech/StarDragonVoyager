extends CanvasLayer
## Mobile touch controls: floating joystick on the left half, action buttons on
## the right. Movement feeds Godot's Input actions, so gameplay code is shared
## with keyboard/mouse. Attack: tap = combo, hold = charged attack.

const E := preload("res://scripts/core/elements.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")
const UI := preload("res://scripts/ui/ui_style.gd")

signal pause_pressed

const STICK_RADIUS := 70.0
const HOLD_TO_CHARGE := 0.22

var _pad: Control


func _ready() -> void:
	layer = 11
	_pad = TouchPad.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.owner_layer = self
	add_child(_pad)
	Game.settings_changed.connect(_apply)
	_apply()


func _apply() -> void:
	visible = Game.touch_controls
	_pad.set_process_input(Game.touch_controls)
	if not Game.touch_controls:
		_pad.release_all()


class TouchPad:
	extends Control

	var owner_layer: CanvasLayer
	var buttons := {}          # id -> {pos, r, label}
	var _fingers := {}         # finger index -> "stick" or button id
	var _stick_origin := Vector2.ZERO
	var _stick_pos := Vector2.ZERO
	var _stick_active := false
	var _attack_down_t := -1.0
	var _charging := false

	func _ready() -> void:
		get_viewport().size_changed.connect(_layout)
		_layout()

	func _layout() -> void:
		var s := get_viewport_rect().size
		var m := UI.safe_margins(self)
		var right := s.x - 40.0 - m.z
		var bottom := s.y - 40.0 - m.w
		buttons = {
			"attack": {"pos": Vector2(right - 70, bottom - 70), "r": 70.0, "label": "ATTACK"},
			"dodge": {"pos": Vector2(right - 205, bottom - 32), "r": 46.0, "label": "DASH"},
			"skill": {"pos": Vector2(right - 185, bottom - 165), "r": 48.0, "label": ""},
			"element": {"pos": Vector2(right - 52, bottom - 215), "r": 38.0, "label": ""},
			"dragon": {"pos": Vector2(right - 300, bottom - 120), "r": 36.0, "label": "DRAGON"},
			"pause": {"pos": Vector2(s.x - 44 - m.z, 40 + m.y), "r": 26.0, "label": "II"},
		}
		queue_redraw()

	func release_all() -> void:
		_fingers.clear()
		_stick_active = false
		_set_move(Vector2.ZERO)
		_charging = false
		_attack_down_t = -1.0

	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed:
				_on_press(t.index, t.position)
			else:
				_on_release(t.index)
			queue_redraw()
		elif event is InputEventScreenDrag:
			var d := event as InputEventScreenDrag
			if _fingers.get(d.index, "") == "stick":
				_stick_pos = d.position
				var v := (_stick_pos - _stick_origin) / STICK_RADIUS
				_set_move(v.limit_length(1.0))
				queue_redraw()

	func _on_press(index: int, pos: Vector2) -> void:
		for id in buttons:
			var b: Dictionary = buttons[id]
			if pos.distance_to(b["pos"]) <= b["r"] * 1.15:
				_fingers[index] = id
				_button_down(id)
				return
		if pos.x < get_viewport_rect().size.x * 0.5 and not _stick_active:
			_fingers[index] = "stick"
			_stick_active = true
			_stick_origin = pos
			_stick_pos = pos

	func _on_release(index: int) -> void:
		var what: String = _fingers.get(index, "")
		_fingers.erase(index)
		if what == "stick":
			_stick_active = false
			_set_move(Vector2.ZERO)
		elif what != "":
			_button_up(what)

	func _button_down(id: String) -> void:
		var p := Game.player
		if p == null or not is_instance_valid(p):
			if id == "pause":
				owner_layer.pause_pressed.emit()
			return
		match id:
			"attack":
				_attack_down_t = 0.0
			"dodge":
				p.try_dodge()
			"skill":
				p.abilities.use_slot(1)
			"element":
				p.abilities.cycle_element()
			"dragon":
				Game.float_text(p.global_position + Vector3.UP * 2.0, "Dragon - Phase 4", Color(0.7, 0.7, 0.8), 24, 0.7)
			"pause":
				owner_layer.pause_pressed.emit()

	func _button_up(id: String) -> void:
		var p := Game.player
		if id == "attack" and p and is_instance_valid(p):
			if _charging:
				p.combat.release_charge()
			elif _attack_down_t >= 0.0:
				p.combat.request_attack()
			_charging = false
			_attack_down_t = -1.0

	func _process(delta: float) -> void:
		if _attack_down_t >= 0.0 and not _charging:
			_attack_down_t += delta
			if _attack_down_t >= HOLD_TO_CHARGE and Game.player:
				_charging = true
				Game.player.combat.begin_charge()
		queue_redraw()

	func _set_move(v: Vector2) -> void:
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		if v.x < -0.05:
			Input.action_press("move_left", -v.x)
		elif v.x > 0.05:
			Input.action_press("move_right", v.x)
		if v.y < -0.05:
			Input.action_press("move_up", -v.y)
		elif v.y > 0.05:
			Input.action_press("move_down", v.y)

	func _draw() -> void:
		var font := Game.ui_font()
		if _stick_active:
			draw_circle(_stick_origin, STICK_RADIUS, Color(0.03, 0.03, 0.1, 0.35))
			draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(UI.BRASS, 0.6), 2.0)
			var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
			draw_circle(knob, 30, Color(UI.BRASS, 0.55))
		else:
			var hint := Vector2(150, get_viewport_rect().size.y - 150)
			draw_arc(hint, STICK_RADIUS, 0, TAU, 48, Color(UI.BRASS, 0.18), 2.0)
		var p := Game.player
		var el: int = p.abilities.element if p and is_instance_valid(p) else 0
		for id in buttons:
			var b: Dictionary = buttons[id]
			var pos: Vector2 = b["pos"]
			var r: float = b["r"]
			var held: bool = id in _fingers.values()
			var border := UI.BRASS
			if id == "skill" or id == "element":
				border = E.COLORS[el]
			var fill := Color(0.05, 0.06, 0.16, 0.62 if not held else 0.85)
			if id == "dragon":
				fill.a = 0.3
				border = Color(UI.BRASS_DIM, 0.6)
			draw_circle(pos, r, fill)
			draw_arc(pos, r, 0, TAU, 48, border, 3.0 if held else 2.0)
			if id == "attack" and _charging and p:
				var c: float = p.combat.charge_level()
				draw_arc(pos, r + 6, -PI / 2, -PI / 2 + TAU * c, 48, E.COLORS[el], 5.0)
			if id == "skill" or id == "element":
				var icon_el := el if id == "skill" else (el + 1) % E.COUNT
				var size := r * 1.1
				draw_texture_rect(SpriteFactory.element_icon(icon_el), Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size)), false)
				if id == "skill" and p:
					var cd: float = p.abilities.cooldown_ratio(el)
					if cd > 0.0:
						draw_arc(pos, r - 4, -PI / 2, -PI / 2 + TAU * cd, 48, Color(0, 0, 0, 0.7), 8.0)
			var text: String = b["label"]
			if text != "":
				var fs := 18 if r > 50 else 14
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
				draw_string(font, pos + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT)
