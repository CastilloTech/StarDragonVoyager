extends CanvasLayer
## Captain's Log (Tab): Skills, Equipment and Dragons tabs. Pauses the game while open.

const E := preload("res://scripts/core/elements.gd")
const Skills := preload("res://scripts/core/skills.gd")
const Items := preload("res://scripts/core/items.gd")
const GearSets := preload("res://scripts/core/gear_sets.gd")
const Dragons := preload("res://scripts/core/dragons.gd")
const Spells := preload("res://scripts/core/spells.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")
const UI := preload("res://scripts/ui/ui_style.gd")

var _tab := "skills"
var _tab_buttons := {}
var _content: Control
var _selected_item := -1     # bag item id being inspected
var _selected_slot := ""     # or a worn slot being inspected
var _bag_filter := "all"     # all / captain / dragon


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	var style := UI.panel(UI.NAVY, UI.BRASS, 3, 6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(1060, 610)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	header.add_child(UI.label("✦  Captain's Log", 26, UI.BRASS))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	for t in [["skills", "Skills"], ["equipment", "Equipment"], ["dragons", "Dragons"]]:
		var b := _button(t[1], func() -> void: _show_tab(t[0]))
		b.custom_minimum_size = Vector2(130, 40)
		header.add_child(b)
		_tab_buttons[t[0]] = b
	var close := _button("Close  (Tab)", toggle)
	close.custom_minimum_size = Vector2(130, 40)
	header.add_child(close)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_content)
	Progress.changed.connect(_refresh)
	Progress.item_added.connect(func(_i: Dictionary) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_menu") or (visible and event.is_action_pressed("pause")):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	Engine.time_scale = 1.0
	if visible:
		_refresh()
	Audio.play("ui", -4.0, 0.0, "UI")


func open_tab(tab: String) -> void:
	_tab = tab
	if not visible:
		toggle()
	else:
		_refresh()


func _show_tab(tab: String) -> void:
	_tab = tab
	_refresh()
	Audio.play("ui", -6.0, 0.0, "UI")


func _refresh() -> void:
	if not visible:
		return
	for t in _tab_buttons:
		(_tab_buttons[t] as Button).modulate = Color(1, 1, 1) if t == _tab else Color(0.65, 0.65, 0.7)
	for c in _content.get_children():
		c.queue_free()
	match _tab:
		"skills":
			_build_skills()
		"equipment":
			_build_equipment()
		"dragons":
			_build_dragons()


# ================================================================ helpers

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _wrap_label(text: String, size: int, color: Color, width: float) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _card(border: Color, bg := UI.NAVY_DEEP) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UI.panel(bg, border, 2, 5)
	s.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", s)
	return p


# ================================================================ skills

func _build_skills() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_content.add_child(top)
	var free := Progress.skill_points_free()
	top.add_child(UI.label("Skill points:  %d free  (1 per level, level %d)" % [free, Progress.level], 18,
		Color(1.0, 0.85, 0.4) if free > 0 else UI.TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_button("Reset skills (free)", func() -> void: Progress.respec()))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(cols)
	for branch in Skills.BRANCHES:
		cols.add_child(_branch_column(branch))


func _branch_column(branch: Dictionary) -> Control:
	var col_color: Color = branch["color"]
	var card := _card(col_color)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(UI.label(branch["name"].to_upper(), 20, col_color))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.label("%d pts" % Progress.skill_points_spent(branch["id"]), 15, UI.TEXT_DIM))
	box.add_child(UI.label(branch["tagline"], 13, UI.TEXT_DIM))
	for id in Skills.branch_skills(branch["id"]):
		box.add_child(_skill_row(id, col_color))
	return card


func _skill_row(id: String, col_color: Color) -> Control:
	var s: Dictionary = Skills.SKILLS[id]
	var unlocked := Progress.skill_row_unlocked(id)
	var invested := Progress.invested_rank(id)
	var bonus := Progress.skill_rank(id) - invested
	var row := _card(col_color.darkened(0.45) if unlocked else Color(0.25, 0.25, 0.3), Color(0.04, 0.04, 0.1, 0.9))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	var title := "%s%s" % ["★ " if s.get("capstone", false) else "", s["name"]]
	var name_row := HBoxContainer.new()
	text.add_child(name_row)
	name_row.add_child(UI.label(title, 16, col_color if unlocked else UI.TEXT_DIM))
	var rank_text := "  %d/%d" % [invested, s["max"]]
	if bonus > 0:
		rank_text += "  (+%d gear)" % bonus
	name_row.add_child(UI.label(rank_text, 14, UI.TEXT if invested > 0 or bonus > 0 else UI.TEXT_DIM))
	text.add_child(_wrap_label(s["desc"], 12, UI.TEXT_DIM if unlocked else Color(0.5, 0.5, 0.55), 230))
	if not unlocked:
		var need: int = Skills.TIER_POINTS[s["tier"]]
		text.add_child(UI.label("Needs %d points in this branch" % need, 11, Color(0.85, 0.55, 0.5)))
	var plus := _button("+", func() -> void:
		if Progress.rank_up(id):
			Audio.play("charge_ready", -6.0, 0.0, "UI"))
	plus.custom_minimum_size = Vector2(38, 38)
	plus.disabled = not Progress.can_rank_up(id)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(plus)
	return row


# ================================================================ equipment

func _build_equipment() -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(cols)

	# Worn gear: captain (7 slots) and the active dragon (4 slots).
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.custom_minimum_size = Vector2(320, 0)
	cols.add_child(left)
	left.add_child(UI.label("CAPTAIN", 15, UI.BRASS))
	for slot in Items.SLOTS:
		left.add_child(_slot_row(slot, Progress.equipped[slot]))
	var dragon: Dictionary = Progress.active()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	left.add_child(spacer)
	left.add_child(UI.label("DRAGON  ·  %s" % str(dragon["name"]).to_upper(), 15, E.COLORS[dragon["element"]]))
	for slot in Items.DRAGON_SLOTS:
		left.add_child(_slot_row(slot, dragon["gear"][slot]))

	# Bag with filters.
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 5)
	mid.custom_minimum_size = Vector2(320, 0)
	cols.add_child(mid)
	var bag_head := HBoxContainer.new()
	bag_head.add_theme_constant_override("separation", 4)
	mid.add_child(bag_head)
	bag_head.add_child(UI.label("BAG %d/%d" % [Progress.inventory.size(), Progress.INVENTORY_SIZE], 15, UI.BRASS))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_head.add_child(sp2)
	for f in [["all", "All"], ["captain", "Captain"], ["dragon", "Dragon"]]:
		var fb := _button(f[1], func() -> void:
			_bag_filter = f[0]
			_refresh())
		fb.add_theme_font_size_override("font_size", 13)
		fb.custom_minimum_size = Vector2(0, 30)
		fb.modulate = Color(1, 1, 1) if _bag_filter == f[0] else Color(0.6, 0.6, 0.65)
		bag_head.add_child(fb)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var bag := []
	for item in Progress.inventory:
		var is_dragon := Items.is_dragon_slot(item["slot"])
		if _bag_filter == "all" or (_bag_filter == "dragon") == is_dragon:
			bag.append(item)
	bag.sort_custom(func(a, b): return a["grade"] > b["grade"] or (a["grade"] == b["grade"] and a["id"] > b["id"]))
	if bag.is_empty():
		list.add_child(_wrap_label("Defeated enemies sometimes drop gear, and clearing a wave always drops something. Better grades shine taller. About a third of drops are dragon gear.", 13, UI.TEXT_DIM, 290))
	for item in bag:
		var req_text := "" if Progress.can_equip(item) else "   (Lv %d)" % Items.required_level(item)
		var b := _button("%s   [%s]%s" % [item["name"], Items.SLOT_NAMES[item["slot"]], req_text], func() -> void:
			_selected_item = item["id"]
			_selected_slot = ""
			_refresh())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_color_override("font_color", Items.GRADE_COLORS[item["grade"]])
		b.add_theme_color_override("font_hover_color", Items.GRADE_COLORS[item["grade"]].lightened(0.3))
		b.add_theme_font_size_override("font_size", 13)
		if req_text != "":
			b.modulate = Color(1, 1, 1, 0.55)   # level too low to equip
		if item["id"] == _selected_item:
			b.add_theme_stylebox_override("normal", UI.panel(Color(0.12, 0.12, 0.26), Items.GRADE_COLORS[item["grade"]], 2, 4))
		list.add_child(b)

	# Details + stats.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(_details_card())
	right.add_child(_stats_card())


## One compact row for a worn slot; click to inspect it.
func _slot_row(slot: String, item: Dictionary) -> Control:
	var empty := item.is_empty()
	var text := "%s:  %s" % [Items.SLOT_NAMES[slot], "—" if empty else item["name"]]
	var b := _button(text, func() -> void:
		_selected_slot = slot
		_selected_item = -1
		_refresh())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 13)
	var col: Color = UI.TEXT_DIM if empty else Items.GRADE_COLORS[item["grade"]]
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	if slot == _selected_slot:
		b.add_theme_stylebox_override("normal", UI.panel(Color(0.12, 0.12, 0.26), col, 2, 4))
	return b


func _details_card() -> Control:
	var sel := {}
	var from_bag := false
	if _selected_item >= 0:
		for it in Progress.inventory:
			if it["id"] == _selected_item:
				sel = it
				from_bag = true
	elif _selected_slot != "":
		var slots: Dictionary = Progress.active()["gear"] if Items.is_dragon_slot(_selected_slot) else Progress.equipped
		sel = slots[_selected_slot]
	if sel.is_empty():
		var hint := "Select a bag item or a worn slot." if _selected_slot == "" else "Nothing equipped in this slot."
		return UI.label(hint, 14, UI.TEXT_DIM)
	var card := _card(Items.GRADE_COLORS[sel["grade"]])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	v.add_child(_item_title(sel, 16))
	var owner_text := "Dragon gear" if Items.is_dragon_slot(sel["slot"]) else "Captain gear"
	v.add_child(UI.label("%s  ·  %s  ·  %s" % [Items.GRADES[sel["grade"]], Items.SLOT_NAMES[sel["slot"]], owner_text], 12, Items.GRADE_COLORS[sel["grade"]]))
	v.add_child(UI.label("Specialty: %s" % Items.theme_name(sel), 12, UI.BRASS))
	var req := Items.required_level(sel)
	if req > 1:
		var ok := Progress.can_equip(sel)
		v.add_child(UI.label("Requires level %d" % req, 12, UI.TEXT_DIM if ok else Color(1.0, 0.4, 0.4)))
	for line in Items.describe(sel):
		v.add_child(UI.label(line, 13, UI.TEXT))
	if sel.has("set"):
		_set_lines(v, sel)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)
	if from_bag:
		var slots: Dictionary = Progress.active()["gear"] if Items.is_dragon_slot(sel["slot"]) else Progress.equipped
		var cur: Dictionary = slots[sel["slot"]]
		if Items.is_dragon_slot(sel["slot"]):
			v.add_child(UI.label("Equips on %s (your active dragon)" % Progress.active()["name"], 11, UI.TEXT_DIM))
		if not cur.is_empty():
			v.add_child(UI.label("Replaces: %s (%s)" % [cur["name"], Items.GRADES[cur["grade"]]], 11, UI.TEXT_DIM))
		var id: int = sel["id"]
		var equip_btn := _button("Equip", func() -> void:
			Progress.equip(id)
			_selected_item = -1
			Audio.play("ui", 0.0, 0.0, "UI", 1.3))
		equip_btn.disabled = not Progress.can_equip(sel)
		buttons.add_child(equip_btn)
		buttons.add_child(_button("Discard", func() -> void:
			Progress.discard(id)
			_selected_item = -1
			_refresh()))
	else:
		var slot: String = sel["slot"]
		buttons.add_child(_button("Unequip", func() -> void:
			Progress.unequip(slot)
			_selected_slot = ""))
	return card


## Set bonus list for a set piece; active bonuses are lit, the rest dimmed.
func _set_lines(v: VBoxContainer, item: Dictionary) -> void:
	var sid: String = item["set"]
	var info: Dictionary = Progress.sets_worn().get(sid, {"count": 0, "tier": int(item["set_tier"])})
	var tier: int = info["tier"] if info["count"] > 0 else int(item["set_tier"])
	v.add_child(UI.label("%s set  ·  %d/%d worn" % [GearSets.SETS[sid]["name"], info["count"], GearSets.PIECES.size()], 12, Items.GRADE_COLORS[GearSets.SET_GRADE]))
	for line in GearSets.describe(sid, tier, info["count"]):
		v.add_child(_wrap_label(line[1], 12, Items.GRADE_COLORS[GearSets.SET_GRADE] if line[0] else UI.TEXT_DIM, 330.0))


func _item_title(item: Dictionary, size: int) -> Label:
	return UI.label(item["name"], size, Items.GRADE_COLORS[item["grade"]])


func _stats_card() -> Control:
	var st: Dictionary = Progress.stats()
	var ds: Dictionary = Progress.dragon_stats()
	var card := _card(UI.BRASS_DIM)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var pct := func(x: float) -> String: return "%d%%" % roundi(x * 100.0)
	v.add_child(UI.label("CAPTAIN", 12, UI.BRASS))
	v.add_child(_stat_grid([
		["Health", "%d" % roundi(st["max_hp"])], ["Armor", pct.call(st["armor"])],
		["Sword dmg", pct.call(st["attack"])], ["Atk speed", pct.call(st["attack_speed"])],
		["Crit chance", pct.call(st["crit_chance"])], ["Crit dmg", pct.call(st["crit_damage"])],
		["Spell power", pct.call(st["spell_power"])], ["Cooldowns", "-" + pct.call(st["cdr"])],
		["Mana", "%d" % roundi(st["max_mana"])], ["Move", "%.1f" % st["move_speed"]],
	]))
	v.add_child(UI.label("DRAGON  ·  %s" % str(Progress.active()["name"]).to_upper(), 12, E.COLORS[Progress.active_element()]))
	v.add_child(_stat_grid([
		["Health", "%d" % roundi(ds["dragon_hp"])], ["Armor", pct.call(ds["dragon_armor"])],
		["Damage", pct.call(ds["dragon_damage"])], ["Breath speed", pct.call(ds["dragon_attack_speed"])],
		["Special", pct.call(ds["special_damage"])], ["Special cd", "-" + pct.call(ds["special_cdr"])],
		["XP gain", pct.call(ds["dragon_xp"])],
	]))
	var worn := Progress.sets_worn()
	for sid in worn:
		if worn[sid]["count"] >= 2:
			v.add_child(UI.label("SET  ·  %s %s (%d/5)" % [str(GearSets.SETS[sid]["name"]).to_upper(), GearSets.ROMAN[worn[sid]["tier"] - 1], worn[sid]["count"]], 12, Items.GRADE_COLORS[GearSets.SET_GRADE]))
	return card


func _stat_grid(rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 1)
	for r in rows:
		grid.add_child(UI.label(r[0], 12, UI.TEXT_DIM))
		grid.add_child(UI.label(r[1], 12, UI.TEXT))
	return grid


# ================================================================ dragons

func _build_dragons() -> void:
	_content.add_child(_wrap_label("Your active dragon fights beside you and decides your spells. Dragons learn from every fight you win while active: a Hatchling becomes a Drake at level %d (2nd spell) and a Wyrm at level %d (3rd spell)." % [Dragons.STAGE_LEVELS[1], Dragons.STAGE_LEVELS[2]], 14, UI.TEXT_DIM, 1020))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)
	for i in Progress.dragons.size():
		row.add_child(_dragon_card(i))


func _dragon_card(i: int) -> Control:
	var d: Dictionary = Progress.dragons[i]
	var el: int = d["element"]
	var col: Color = E.COLORS[el]
	var active := i == Progress.active_dragon
	var card := _card(col if active else col.darkened(0.5))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var portrait := TextureRect.new()
	portrait.texture = SpriteFactory.dragon_portrait()
	portrait.custom_minimum_size = Vector2(0, 90)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.modulate = Dragons.TYPES[el]["tint"]
	v.add_child(portrait)
	v.add_child(UI.label(d["name"].to_upper(), 20, col))
	var stage := Dragons.stage_of(d["level"])
	v.add_child(UI.label("%s  ·  %s  ·  Lv %d" % [E.NAMES[el], Dragons.STAGE_NAMES[stage], d["level"]], 13, UI.TEXT))
	var xp_bar := UI.bar(col, Vector2(0, 6))
	xp_bar.max_value = Dragons.xp_to_next(d["level"])
	xp_bar.value = d["xp"]
	v.add_child(xp_bar)
	v.add_child(UI.label("Special: %s" % Dragons.TYPES[el]["special"], 12, UI.TEXT_DIM))
	v.add_child(UI.label("Gear: %d / %d" % [Progress.dragon_items(i).size(), Items.DRAGON_SLOTS.size()], 12, UI.TEXT_DIM))
	for t in 3:
		var sp: Dictionary = Spells.spell(el, t)
		var unlocked := t <= stage
		var line := "%s %s" % ["●" if unlocked else "○", sp["name"]]
		v.add_child(UI.label(line, 13, col if unlocked else Color(0.5, 0.5, 0.55)))
		var sub: String = sp["desc"] if unlocked else "Unlocks as a %s (Lv %d)" % [Dragons.STAGE_NAMES[t], Dragons.STAGE_LEVELS[t]]
		v.add_child(_wrap_label(sub, 11, UI.TEXT_DIM, 170))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	if active:
		v.add_child(UI.label("★ ACTIVE", 15, col))
	else:
		v.add_child(_button("Make active", func() -> void:
			Progress.set_active_dragon(i)
			Audio.play("chirp_happy", -4.0)))
	return card
