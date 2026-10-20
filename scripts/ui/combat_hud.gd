extends CanvasLayer
## CombatHUD: vitals and element (upper-left), ability bar (lower-center, desktop),
## encounter info (top-center), center messages. On touch devices the ability
## buttons live in touch_controls.gd instead of the ability bar.

const E := preload("res://scripts/core/elements.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")
const UI := preload("res://scripts/ui/ui_style.gd")

var _root: Control
var _vitals: PanelContainer
var _hp: ProgressBar
var _mp: ProgressBar
var _st: ProgressBar
var _hp_text: Label
var _element_label: Label
var _element_icons: Array = []
var _ability_bar: HBoxContainer
var _slot1_icon: TextureRect
var _slot1_cd: ColorRect
var _slot1_cd_text: Label
var _slot1_panel: PanelContainer
var _encounter: Label
var _center: Label
var _sub: Label
var _help: Label
var _center_tween: Tween
var _shown_element := -1


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.theme()
	add_child(_root)
	_build_vitals()
	_build_ability_bar()
	_build_top()
	_build_center()
	_build_help()
	Game.settings_changed.connect(_apply_mode)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_mode()
	_apply_safe_area()


func _apply_mode() -> void:
	_ability_bar.visible = not Game.touch_controls
	_help.visible = not Game.touch_controls


func _apply_safe_area() -> void:
	var m := UI.safe_margins(_root)
	_vitals.position = Vector2(16 + m.x, 14 + m.y)
	_help.position = Vector2(16 + m.x, _root.get_viewport_rect().size.y - 34 - m.w)


# ---------------------------------------------------------------- build

func _build_vitals() -> void:
	_vitals = PanelContainer.new()
	_vitals.add_theme_stylebox_override("panel", UI.panel())
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vitals)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_vitals.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	head.add_child(UI.label("✦ CAPTAIN", 15, UI.BRASS))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_hp_text = UI.label("120 / 120", 14, UI.TEXT_DIM)
	head.add_child(_hp_text)
	_hp = UI.bar(Color(0.88, 0.3, 0.36), Vector2(250, 14))
	box.add_child(_hp)
	_mp = UI.bar(Color(0.3, 0.55, 1.0), Vector2(250, 9))
	box.add_child(_mp)
	_st = UI.bar(Color(0.86, 0.76, 0.3), Vector2(250, 7))
	box.add_child(_st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)
	for i in E.COUNT:
		var tr := TextureRect.new()
		tr.texture = SpriteFactory.element_icon(i)
		tr.custom_minimum_size = Vector2(24, 24)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
		_element_icons.append(tr)
	_element_label = UI.label("Sun", 16, E.COLORS[0])
	row.add_child(_element_label)


func _build_ability_bar() -> void:
	_ability_bar = HBoxContainer.new()
	_ability_bar.add_theme_constant_override("separation", 8)
	_ability_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ability_bar.offset_left = -170
	_ability_bar.offset_right = 170
	_ability_bar.offset_top = -82
	_ability_bar.offset_bottom = -18
	_ability_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ability_bar)
	for slot in range(1, 5):
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(62, 62)
		p.add_theme_stylebox_override("panel", UI.panel(UI.NAVY_DEEP, UI.BRASS_DIM, 2, 4))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ability_bar.add_child(p)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(holder)
		if slot == 1:
			_slot1_panel = p
			_slot1_icon = TextureRect.new()
			_slot1_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			_slot1_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_slot1_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_slot1_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			holder.add_child(_slot1_icon)
			_slot1_cd = ColorRect.new()
			_slot1_cd.color = Color(0, 0, 0, 0.6)
			_slot1_cd.anchor_right = 1.0
			_slot1_cd.anchor_bottom = 1.0
			_slot1_cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(_slot1_cd)
			_slot1_cd_text = UI.label("", 15)
			_slot1_cd_text.set_anchors_preset(Control.PRESET_CENTER)
			holder.add_child(_slot1_cd_text)
		else:
			p.modulate = Color(1, 1, 1, 0.45)
			var lock := UI.label("—", 20, UI.TEXT_DIM)
			lock.set_anchors_preset(Control.PRESET_CENTER)
			holder.add_child(lock)
		var key := UI.label(str(slot), 12, UI.BRASS)
		key.position = Vector2(-4, -6)
		holder.add_child(key)


func _build_top() -> void:
	_encounter = UI.label("", 18, UI.TEXT)
	_encounter.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_encounter.offset_left = -200
	_encounter.offset_right = 200
	_encounter.offset_top = 14
	_encounter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_encounter)


func _build_center() -> void:
	_center = UI.label("", 52, UI.BRASS)
	_center.anchor_left = 0.0
	_center.anchor_right = 1.0
	_center.anchor_top = 0.3
	_center.anchor_bottom = 0.3
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.add_theme_constant_override("outline_size", 10)
	_center.modulate.a = 0.0
	_root.add_child(_center)
	_sub = UI.label("", 22, UI.TEXT)
	_sub.anchor_left = 0.0
	_sub.anchor_right = 1.0
	_sub.anchor_top = 0.3
	_sub.anchor_bottom = 0.3
	_sub.offset_top = 70
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.modulate.a = 0.0
	_root.add_child(_sub)


func _build_help() -> void:
	_help = UI.label("WASD move · Mouse aim · LMB attack · hold RMB charged · Space dash · Q element · 1 ability · Esc pause", 13, UI.TEXT_DIM)
	_root.add_child(_help)


# ---------------------------------------------------------------- runtime

func show_message(text: String, duration := 1.6, sub := "") -> void:
	_center.text = text
	_sub.text = sub
	if _center_tween:
		_center_tween.kill()
	_center_tween = create_tween()
	_center.modulate.a = 0.0
	_sub.modulate.a = 0.0
	_center.scale = Vector2.ONE
	_center_tween.set_parallel(true)
	_center_tween.tween_property(_center, "modulate:a", 1.0, 0.25)
	_center_tween.tween_property(_sub, "modulate:a", 1.0, 0.35)
	if duration > 0.0:
		_center_tween.chain().tween_interval(duration)
		_center_tween.chain().tween_property(_center, "modulate:a", 0.0, 0.4)
		_center_tween.parallel().tween_property(_sub, "modulate:a", 0.0, 0.4)


func set_encounter(wave: int, waves: int, remaining: int) -> void:
	if wave <= 0:
		_encounter.text = ""
	else:
		_encounter.text = "Wave %d / %d   ·   Voidlings %d" % [wave, waves, remaining]


func _process(_delta: float) -> void:
	var p := Game.player
	if p == null or not is_instance_valid(p):
		return
	_hp.max_value = p.health.max_health
	_hp.value = p.health.current
	_hp_text.text = "%d / %d" % [ceili(p.health.current), roundi(p.health.max_health)]
	_mp.max_value = p.max_mana
	_mp.value = p.mana
	_st.max_value = p.max_stamina
	_st.value = p.stamina
	var el: int = p.abilities.element
	if el != _shown_element:
		_shown_element = el
		var col: Color = E.COLORS[el]
		for i in _element_icons.size():
			var tr: TextureRect = _element_icons[i]
			tr.modulate = Color(1, 1, 1, 1.0 if i == el else 0.35)
			tr.custom_minimum_size = Vector2(30, 30) if i == el else Vector2(22, 22)
		_element_label.text = E.NAMES[el]
		_element_label.add_theme_color_override("font_color", col)
		_slot1_icon.texture = SpriteFactory.element_icon(el)
		_slot1_panel.add_theme_stylebox_override("panel", UI.panel(UI.NAVY_DEEP, col, 2, 4))
	var r: float = p.abilities.cooldown_ratio(el)
	_slot1_cd.anchor_top = 1.0 - r
	_slot1_cd_text.text = ("%.1f" % p.abilities.cooldowns[el]) if r > 0.0 and p.abilities.cooldowns[el] > 0.3 else ""
