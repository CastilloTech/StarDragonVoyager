extends Node
## Autoload "Progress": everything that persists between sessions - captain level and
## XP, skill ranks, inventory and equipped gear, the dragon roster and active dragon.
## Also computes the captain's final stats (base + skills + equipment).
## Saved to user://progress.json after every change.

const Skills := preload("res://scripts/core/skills.gd")
const Items := preload("res://scripts/core/items.gd")
const Dragons := preload("res://scripts/core/dragons.gd")
const Spells := preload("res://scripts/core/spells.gd")
const GearSets := preload("res://scripts/core/gear_sets.gd")

signal changed                       # stats / skills / gear / active dragon changed
signal leveled_up(level: int)
signal dragon_evolved(index: int, stage: int)
signal item_added(item: Dictionary)

const SAVE_PATH := "user://progress.json"
const MAX_LEVEL := 50
const INVENTORY_SIZE := 40

var level := 1
var xp := 0
var skill_ranks := {}
var inventory: Array = []
var equipped := _empty_slots(Items.SLOTS)
var dragons: Array = []
var active_dragon := 0
var _next_item_id := 1
var _stats_cache := {}
var _dragon_cache := {}
var _saving_enabled := true


static func _empty_slots(slots: Array) -> Dictionary:
	var d := {}
	for s in slots:
		d[s] = {}
	return d


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Automated tests run on a throwaway profile so they never touch your real save.
	var args := OS.get_cmdline_user_args()
	for arg in args:
		for test_flag in ["--demo", "--clicktest", "--meleetest", "--dashtest", "--spelltest", "--screenshot"]:
			if arg.begins_with(test_flag):
				_saving_enabled = false
	if _saving_enabled:
		load_game()
	if dragons.is_empty():
		dragons = Dragons.starting_roster()
	for d in dragons:
		if not d.has("gear"):
			d["gear"] = _empty_slots(Items.DRAGON_SLOTS)


# ================================================================ levels & XP

func xp_to_next() -> int:
	return 40 + 25 * (level - 1)


func grant_xp(amount: int) -> void:
	if level < MAX_LEVEL:
		xp += amount
		while level < MAX_LEVEL and xp >= xp_to_next():
			xp -= xp_to_next()
			level += 1
			leveled_up.emit(level)
	# The active dragon learns alongside the captain.
	var d: Dictionary = dragons[active_dragon]
	if d["level"] < Dragons.MAX_LEVEL:
		var stage_before := Dragons.stage_of(d["level"])
		d["xp"] += roundi(amount * dragon_stats()["dragon_xp"])
		while d["level"] < Dragons.MAX_LEVEL and d["xp"] >= Dragons.xp_to_next(d["level"]):
			d["xp"] -= Dragons.xp_to_next(d["level"])
			d["level"] += 1
		var stage_after := Dragons.stage_of(d["level"])
		if stage_after != stage_before:
			dragon_evolved.emit(active_dragon, stage_after)
			_changed()
	save_game()


# ================================================================ skills

func skill_points_total() -> int:
	return mini(level - 1, 29) + maxi(0, int((level - 30) / 2))


func skill_points_spent(branch := "") -> int:
	var n := 0
	for id in skill_ranks:
		if branch == "" or Skills.SKILLS[id]["branch"] == branch:
			n += int(skill_ranks[id])
	return n


func skill_points_free() -> int:
	return skill_points_total() - skill_points_spent()


## Points you invested (no equipment bonus).
func invested_rank(id: String) -> int:
	return int(skill_ranks.get(id, 0))


## Rank used by gameplay: invested + equipment bonuses (can exceed the max by up to 2).
func skill_rank(id: String) -> int:
	var max_rank: int = Skills.SKILLS[id]["max"]
	var bonus := Items.skill_bonus(equipped_items(), id) + _set_skill_bonus(Skills.SKILLS[id]["branch"])
	return mini(invested_rank(id) + bonus, max_rank + 3)


func skill_row_unlocked(id: String) -> bool:
	var s: Dictionary = Skills.SKILLS[id]
	return skill_points_spent(s["branch"]) >= Skills.TIER_POINTS[s["tier"]]


func can_rank_up(id: String) -> bool:
	return skill_points_free() > 0 and invested_rank(id) < Skills.SKILLS[id]["max"] and skill_row_unlocked(id)


func rank_up(id: String) -> bool:
	if not can_rank_up(id):
		return false
	skill_ranks[id] = invested_rank(id) + 1
	_changed()
	return true


func respec() -> void:
	skill_ranks.clear()
	_changed()


# ================================================================ items

func equipped_items() -> Array:
	var out := []
	for slot in equipped:
		if not equipped[slot].is_empty():
			out.append(equipped[slot])
	return out


## Level check for equipping (captain level for all gear).
func can_equip(item: Dictionary) -> bool:
	return level >= Items.required_level(item)


## Sets worn by the captain: {set_id: {"count": pieces, "tier": lowest version worn}}.
func sets_worn() -> Dictionary:
	var out := {}
	for item in equipped_items():
		if item.has("set"):
			var sid: String = item["set"]
			if not out.has(sid):
				out[sid] = {"count": 0, "tier": 99}
			out[sid]["count"] += 1
			out[sid]["tier"] = mini(out[sid]["tier"], int(item["set_tier"]))
	return out


## True when `pieces` or more of a set are worn.
func set_bonus(set_id: String, pieces: int) -> bool:
	var info: Dictionary = sets_worn().get(set_id, {})
	return not info.is_empty() and info["count"] >= pieces


## Bonus strength of a worn set (by its lowest version worn).
func set_power(set_id: String) -> float:
	var info: Dictionary = sets_worn().get(set_id, {})
	return GearSets.TIER_POWER[info["tier"] - 1] if not info.is_empty() else 0.0


func _set_skill_bonus(branch: String) -> int:
	var n := 0
	var worn := sets_worn()
	for sid in worn:
		if GearSets.SETS[sid]["branch"] == branch and worn[sid]["count"] >= 3:
			n += GearSets.skill_ranks_for_tier(worn[sid]["tier"])
	return n


## A set piece for the captain's level band (or a given tier), added like any drop.
func add_set_item(set_id := "", tier := 0, slot := "") -> Dictionary:
	if set_id == "":
		set_id = GearSets.SETS.keys().pick_random()
	if tier <= 0:
		tier = maxi(1, GearSets.tier_of_level(level))
	if slot == "":
		slot = GearSets.PIECES.pick_random()
	var item := GearSets.make_piece(_next_item_id, set_id, tier, slot)
	_next_item_id += 1
	add_item(item)
	return item


## Gear worn by a dragon (default: the active one).
func dragon_items(index := -1) -> Array:
	var d: Dictionary = dragons[active_dragon if index < 0 else index]
	var out := []
	for slot in d["gear"]:
		if not d["gear"][slot].is_empty():
			out.append(d["gear"][slot])
	return out


## The slot dictionary an item of `slot` goes into: the captain's, or the active dragon's.
func _slots_for(slot: String) -> Dictionary:
	return active()["gear"] if Items.is_dragon_slot(slot) else equipped


## Creates a random item and adds it to the bag (auto-equips into an empty slot).
func add_random_item(luck := 0, grade := -1, slot := "") -> Dictionary:
	var g := grade if grade >= 0 else Items.roll_grade(luck)
	var item := Items.generate(_next_item_id, g, slot)
	_next_item_id += 1
	add_item(item)
	return item


func add_item(item: Dictionary) -> void:
	var slots := _slots_for(item["slot"])
	if slots[item["slot"]].is_empty() and can_equip(item):
		slots[item["slot"]] = item
		_changed()
	else:
		inventory.append(item)
		while inventory.size() > INVENTORY_SIZE:
			inventory.pop_front()   # bag full: the oldest item is discarded
		save_game()
	item_added.emit(item)


func equip(item_id: int) -> void:
	for i in inventory.size():
		if inventory[i]["id"] == item_id:
			var item: Dictionary = inventory[i]
			if not can_equip(item):
				return
			inventory.remove_at(i)
			var slots := _slots_for(item["slot"])
			var old: Dictionary = slots[item["slot"]]
			if not old.is_empty():
				inventory.append(old)
			slots[item["slot"]] = item
			_changed()
			return


func unequip(slot: String) -> void:
	var slots := _slots_for(slot)
	if slots[slot].is_empty() or inventory.size() >= INVENTORY_SIZE:
		return
	inventory.append(slots[slot])
	slots[slot] = {}
	_changed()


func discard(item_id: int) -> void:
	for i in inventory.size():
		if inventory[i]["id"] == item_id:
			inventory.remove_at(i)
			save_game()
			return


# ================================================================ dragons

func active() -> Dictionary:
	return dragons[active_dragon]


func set_active_dragon(index: int) -> void:
	if index >= 0 and index < dragons.size() and index != active_dragon:
		active_dragon = index
		_changed()   # stats change too: dragon gear "bond" bonuses follow the active dragon


func active_element() -> int:
	return int(active()["element"])


func active_stage() -> int:
	return Dragons.stage_of(active()["level"])


func spells_unlocked() -> int:
	return Dragons.spells_unlocked(active()["level"])


# ================================================================ stats

func base_stats() -> Dictionary:
	return {
		"max_hp": 120.0, "armor": 0.0, "attack": 1.0, "attack_speed": 1.0,
		"crit_chance": 0.12, "crit_damage": 1.75, "charged_damage": 1.0, "finisher_damage": 1.0,
		"max_mana": 100.0, "mana_regen": 6.0, "mana_on_hit": 4.0, "spell_power": 1.0, "cdr": 0.0,
		"max_stamina": 100.0, "stamina_regen": 36.0, "dash_cost": 1.0,
		"move_speed": 6.0, "move_speed_mult": 1.0, "charge_time": 0.6, "dragon_damage": 1.0,
	}


func stats() -> Dictionary:
	if _stats_cache.is_empty():
		var s := base_stats()
		Skills.apply(s, skill_rank)
		Items.apply(s, equipped_items())
		Items.apply(s, dragon_items(), Items.BOND_STATS)
		GearSets.apply_stats(s, sets_worn())
		s["armor"] = minf(s["armor"], 0.6)
		s["cdr"] = minf(s["cdr"], 0.5)
		s["crit_chance"] = minf(s["crit_chance"], 0.75)
		s["attack_speed"] = minf(s["attack_speed"], 2.25)   # keeps swings readable
		s["move_speed"] *= s["move_speed_mult"]
		_stats_cache = s
	return _stats_cache


## The active dragon's stats: its stage, its own gear and the captain's "dragon damage".
func dragon_stats() -> Dictionary:
	if _dragon_cache.is_empty():
		var stage := Dragons.stage_of(active()["level"])
		var s := {
			"dragon_hp": Dragons.STAGE_HEALTH[stage], "dragon_armor": 0.0,
			"dragon_damage": stats()["dragon_damage"], "dragon_attack_speed": 1.0,
			"special_cdr": 0.0, "special_damage": 1.0, "dragon_xp": 1.0,
		}
		Items.apply(s, dragon_items())
		s["dragon_armor"] = minf(s["dragon_armor"], 0.6)
		s["special_cdr"] = minf(s["special_cdr"], 0.5)
		_dragon_cache = s
	return _dragon_cache


func _changed() -> void:
	_stats_cache = {}
	_dragon_cache = {}
	changed.emit()
	save_game()


# ================================================================ save / load

func save_game() -> void:
	if not _saving_enabled:
		return
	var data := {
		"version": 1, "level": level, "xp": xp, "skills": skill_ranks,
		"inventory": inventory, "equipped": equipped,
		"dragons": dragons, "active_dragon": active_dragon, "next_item_id": _next_item_id,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary):
		return
	level = int(parsed.get("level", 1))
	xp = int(parsed.get("xp", 0))
	skill_ranks = {}
	for id in parsed.get("skills", {}):
		if Skills.SKILLS.has(id):
			skill_ranks[id] = int(parsed["skills"][id])
	inventory = _fix_items(parsed.get("inventory", []))
	var eq: Dictionary = parsed.get("equipped", {})
	equipped = _empty_slots(Items.SLOTS)
	for slot in equipped:
		var it = eq.get(slot, {})
		equipped[slot] = _fix_items([it])[0] if it is Dictionary and not it.is_empty() else {}
	dragons = []
	for d in parsed.get("dragons", []):
		var gear := _empty_slots(Items.DRAGON_SLOTS)
		var saved_gear: Dictionary = d.get("gear", {})
		for slot in gear:
			var it = saved_gear.get(slot, {})
			if it is Dictionary and not it.is_empty():
				gear[slot] = _fix_items([it])[0]
		dragons.append({"element": int(d["element"]), "name": str(d["name"]), "level": int(d["level"]),
			"xp": int(d["xp"]), "gear": gear})
	active_dragon = clampi(int(parsed.get("active_dragon", 0)), 0, maxi(0, dragons.size() - 1))
	# Gear you're not high enough level for (e.g. from before requirements existed) goes to the bag.
	var lists := [equipped]
	for d in dragons:
		lists.append(d["gear"])
	for slots in lists:
		for slot in slots:
			var it: Dictionary = slots[slot]
			if not it.is_empty() and level < Items.required_level(it):
				inventory.append(it)
				slots[slot] = {}
	_next_item_id = int(parsed.get("next_item_id", 1))
	_stats_cache = {}
	_dragon_cache = {}


## JSON turns ints into floats; restore the types items use.
func _fix_items(list: Array) -> Array:
	var out := []
	for it in list:
		if not (it is Dictionary) or it.is_empty():
			continue
		it["id"] = int(it["id"])
		it["grade"] = int(it["grade"])
		if it.has("set_tier"):
			it["set_tier"] = int(it["set_tier"])
			it["req"] = int(it["req"])
		for a in it["affixes"]:
			if a.has("skill"):
				a["value"] = int(a["value"])
		Items.retitle(it)   # older saves: give the item its specialty prefix
		out.append(it)
	return out


## Wipes all progress (pause menu > Reset progress).
func reset_all() -> void:
	level = 1
	xp = 0
	skill_ranks = {}
	inventory = []
	equipped = _empty_slots(Items.SLOTS)
	dragons = Dragons.starting_roster()
	for d in dragons:
		d["gear"] = _empty_slots(Items.DRAGON_SLOTS)
	active_dragon = 0
	_next_item_id = 1
	_changed()
