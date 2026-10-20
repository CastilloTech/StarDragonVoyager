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
var _element_nums: Array = []
var _element_keys_left: Label
var _element_keys_right: Label
var _ability_bar: HBoxContainer
var _slots := {}
var _hint_panel: PanelContainer
var _hint: Label
var _hint_tween: Tween
var _damage_flash: ColorRect
var _damage_mat: ShaderMaterial
var _damage_tween: Tween
var _dragon_panel: PanelContainer
var _dragon_hp: ProgressBar
var _dragon_special: ProgressBar
var _dragon_status: Label
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
	_build_damage_flash()
	_build_vitals()
	_build_dragon_panel()
	_build_ability_bar()
	_build_hint()
	_build_top()
	_build_center()
	_build_help()
	Game.settings_changed.connect(_apply_mode)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_mode()
	_apply_safe_area()


func _apply_mode() -> void:
	var desktop := not Game.touch_controls
	_ability_bar.visible = desktop
	_help.visible = desktop
	_element_keys_left.visible = desktop
	_element_keys_right.visible = desktop
	for n in _element_nums:
		(n as Label).visible = desktop


func _apply_safe_area() -> void:
	var m := UI.safe_margins(_root)
	_vitals.position = Vector2(16 + m.x, 14 + m.y)
	_dragon_panel.position = Vector2(16 + m.x, 14 + m.y + _vitals.get_combined_minimum_size().y + 6)
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
	# Element picker: Q / E (or wheel) cycle, 1-5 pick directly.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_element_keys_left = UI.label("Q", 12, UI.BRASS)
	_element_keys_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_element_keys_left)
	for i in E.COUNT:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cell)
		var tr := TextureRect.new()
		tr.texture = SpriteFactory.element_icon(i)
		tr.custom_minimum_size = Vector2(26, 26)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tr)
		var num := UI.label(str(i + 1), 10, UI.TEXT_DIM)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(num)
		_element_icons.append(tr)
		_element_nums.append(num)
	_element_keys_right = UI.label("E", 12, UI.BRASS)
	_element_keys_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_element_keys_right)
	_element_label = UI.label("Sun", 16, E.COLORS[0])
	_element_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_element_label)


func _build_damage_flash() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 v = UV - 0.5;
	float edge = smoothstep(0.25, 0.75, length(v * vec2(1.0, 1.25)));
	COLOR = vec4(0.85, 0.05, 0.12, edge * strength);
}
"""
	_damage_mat = ShaderMaterial.new()
	_damage_mat.shader = sh
	_damage_flash.material = _damage_mat
	_root.add_child(_damage_flash)


## Red pulse at the screen edges when the captain takes damage.
func flash_damage(strength := 1.0) -> void:
	if _damage_tween:
		_damage_tween.kill()
	_damage_mat.set_shader_parameter("strength", 0.75 * strength)
	_damage_tween = create_tween()
	_damage_tween.tween_method(func(v: float) -> void: _damage_mat.set_shader_parameter("strength", v),
		0.75 * strength, 0.0, 0.45)


func _build_dragon_panel() -> void:
	const Dragon := preload("res://scripts/dragon/dragon_companion.gd")
	_dragon_panel = PanelContainer.new()
	var style := UI.panel()
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_dragon_panel.add_theme_stylebox_override("panel", style)
	_dragon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dragon_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_dragon_panel.add_child(row)
	var frame := PanelContainer.new()
	var fs := UI.panel(UI.NAVY_DEEP, E.COLORS[E.COMET], 2, 3)
	fs.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", fs)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var portrait := TextureRect.new()
	portrait.texture = SpriteFactory.dragon_portrait()
	portrait.custom_minimum_size = Vector2(40, 40)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(UI.label(Dragon.DRAGON_NAME.to_upper(), 14, E.COLORS[E.COMET]))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_dragon_status = UI.label("", 12, UI.TEXT_DIM)
	head.add_child(_dragon_status)
	_dragon_hp = UI.bar(Color(0.35, 0.8, 0.95), Vector2(190, 9))
	col.add_child(_dragon_hp)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	col.add_child(srow)
	srow.add_child(UI.label("F" if not Game.touch_controls else "", 12, UI.BRASS))
	_dragon_special = UI.bar(Color(0.8, 0.95, 1.0), Vector2(170, 5))
	_dragon_special.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(_dragon_special)


## Action bar: one slot per control, labelled with its key and what it does.
func _build_ability_bar() -> void:
	const PixelArt := preload("res://scripts/render/pixel_art.gd")
	_ability_bar = HBoxContainer.new()
	_ability_bar.add_theme_constant_override("separation", 10)
	_ability_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ability_bar.offset_left = -230
	_ability_bar.offset_right = 230
	_ability_bar.offset_top = -108
	_ability_bar.offset_bottom = -10
	_ability_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ability_bar)
	_slots["attack"] = _make_slot("LMB", "Attack", "hold: Charge", PixelArt.crescent_texture())
	_slots["spell"] = _make_slot("RMB", "Spell", "", SpriteFactory.element_icon(0))
	_slots["dash"] = _make_slot("SPACE", "Dash", "", null, "»")
	_slots["nova"] = _make_slot("F", "Nova", "Comet Shower", SpriteFactory.dragon_portrait())


func _make_slot(key: String, caption: String, sub: String, tex: Texture2D, glyph := "") -> Dictionary:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_bar.add_child(col)
	var key_label := UI.label(key, 12, UI.BRASS)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(key_label)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(58, 58)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", UI.panel(UI.NAVY_DEEP, UI.BRASS_DIM, 2, 4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(p)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(holder)
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = tex
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	if glyph != "":
		var g := UI.label(glyph, 34, UI.TEXT)
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(g)
	var cd := ColorRect.new()
	cd.color = Color(0, 0, 0, 0.62)
	cd.anchor_right = 1.0
	cd.anchor_bottom = 1.0
	cd.anchor_top = 1.0
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cd)
	var cd_text := UI.label("", 15)
	cd_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(cd_text)
	var cap := UI.label(caption, 13, UI.TEXT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var sub_label := UI.label(sub, 11, UI.TEXT_DIM)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub_label)
	return {"panel": p, "icon": icon, "cd": cd, "cd_text": cd_text, "caption": cap, "sub": sub_label}


func _set_slot_cooldown(slot: Dictionary, ratio: float, seconds: float, dim := false) -> void:
	var cd: ColorRect = slot["cd"]
	cd.anchor_top = 1.0 - clampf(ratio, 0.0, 1.0)
	var t: Label = slot["cd_text"]
	t.text = ("%.1f" % seconds) if ratio > 0.0 and seconds > 0.3 else ""
	(slot["panel"] as Control).modulate = Color(1, 1, 1, 0.45 if dim else 1.0)


## Short instruction shown above the action bar (first-time tips).
func show_hint(text: String, duration := 4.0) -> void:
	_hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_panel.visible = true
	_hint_panel.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_panel, "modulate:a", 1.0, 0.25)
	_hint_tween.tween_interval(duration)
	_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, 0.4)
	_hint_tween.tween_callback(func() -> void: _hint_panel.visible = false)


func _build_hint() -> void:
	_hint_panel = PanelContainer.new()
	var style := UI.panel(Color(0.04, 0.05, 0.12, 0.92), UI.BRASS, 2, 6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	_hint_panel.add_theme_stylebox_override("panel", style)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.offset_bottom = -126
	_hint_panel.visible = false
	_root.add_child(_hint_panel)
	_hint = UI.label("", 18, UI.TEXT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint)


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
	_help = UI.label("WASD move  ·  Mouse aim  ·  Esc pause & controls", 13, UI.TEXT_DIM)
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
		_encounter.text = "Wave %d / %d   ·   Enemies %d" % [wave, waves, remaining]


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
		var spell: Dictionary = _slots["spell"]
		(spell["icon"] as TextureRect).texture = SpriteFactory.element_icon(el)
		(spell["panel"] as PanelContainer).add_theme_stylebox_override("panel", UI.panel(UI.NAVY_DEEP, col, 2, 4))
		(spell["caption"] as Label).text = E.ABILITY_NAMES[el]
		(spell["sub"] as Label).text = "%d MP" % roundi(E.MANA_COSTS[el])
	var d := Game.dragon
	if d and is_instance_valid(d):
		_dragon_hp.max_value = d.health.max_health
		_dragon_hp.value = d.health.current
		_dragon_special.value = (1.0 - d.special_ratio()) * 100.0
		if not d.is_alive():
			_dragon_status.text = "Down %ds" % ceili(d.revive_t)
		elif d.special_ratio() <= 0.0:
			_dragon_status.text = "Comet Shower ready"
		else:
			_dragon_status.text = ""
	_apply_safe_area()
	# Action bar state: spell cooldown / mana, dash stamina, Nova cooldown.
	var cd_s: float = p.abilities.cooldowns[el]
	_set_slot_cooldown(_slots["spell"], p.abilities.cooldown_ratio(el), cd_s, p.mana < E.MANA_COSTS[el])
	_set_slot_cooldown(_slots["dash"], 0.0, 0.0, p.stamina < 15.0)
	var attack_slot: Dictionary = _slots["attack"]
	var charging: bool = p.combat.is_charging()
	(attack_slot["panel"] as PanelContainer).add_theme_stylebox_override("panel",
		UI.panel(UI.NAVY_DEEP, col_for_charge(p) if charging else UI.BRASS_DIM, 2, 4))
	if d and is_instance_valid(d):
		_set_slot_cooldown(_slots["nova"], d.special_ratio(), d.special_cd, not d.is_alive())


func col_for_charge(p: Node) -> Color:
	var c: float = p.combat.charge_level()
	var col: Color = E.COLORS[p.abilities.element]
	return UI.BRASS_DIM.lerp(col, c)
