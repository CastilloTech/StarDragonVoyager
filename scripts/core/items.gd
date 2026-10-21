extends RefCounted
## Equipment for the captain (7 slots) and for dragons (4 slots, each dragon has its own),
## six grades. Every grade above Common adds one more random bonus (affix) and raises
## all values. Captain bonuses can be stats or +ranks to a skill; dragon bonuses boost
## the dragon, and a few ("bond" stats) also help the captain.

const Skills := preload("res://scripts/core/skills.gd")

const SLOTS := ["weapon", "helm", "armor", "gloves", "boots", "ring", "charm"]
const DRAGON_SLOTS := ["saddle", "talons", "crest", "bond"]
const SLOT_NAMES := {
	"weapon": "Weapon", "helm": "Hat", "armor": "Coat", "gloves": "Gloves", "boots": "Boots",
	"ring": "Ring", "charm": "Charm",
	"saddle": "Saddle", "talons": "Talon Guards", "crest": "Crest", "bond": "Bond Charm",
}
const DRAGON_DROP_CHANCE := 0.3

const GRADES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
const GRADE_COLORS := [
	Color(0.82, 0.82, 0.86), Color(0.45, 0.92, 0.5), Color(0.38, 0.62, 1.0),
	Color(0.78, 0.45, 1.0), Color(1.0, 0.66, 0.22), Color(1.0, 0.32, 0.42),
]
const GRADE_MULT := [1.0, 1.3, 1.7, 2.2, 2.8, 3.5]
const GRADE_WEIGHTS := [52.0, 27.0, 13.0, 6.0, 1.8, 0.2]

const BASES := {
	"weapon": ["Twin Cutlasses", "Corsair Blades", "Starsteel Daggers", "Brass-Hilt Sabers", "Comet Fangs"],
	"helm": ["Bandana", "Tricorn", "Navigator's Hat", "Star-Sail Hood", "Brass Goggles"],
	"armor": ["Corsair Coat", "Brass-Plated Longcoat", "Navigator's Jacket", "Sky-Silk Duster", "Deckhand Leathers"],
	"gloves": ["Grip Gloves", "Duelist Gauntlets", "Rigging Wraps", "Brass Knuckles", "Silk Handguards"],
	"boots": ["Deck Boots", "Sky-Treads", "Corsair Boots", "Comet Striders", "Brass-Toe Boots"],
	"ring": ["Signet Ring", "Starstone Band", "Compass Ring", "Coral Loop", "Admiral's Seal"],
	"charm": ["Star Compass", "Dragon-Scale Charm", "Comet Locket", "Nebula Pearl", "Brass Astrolabe"],
	"saddle": ["Brass Saddle", "Sky-Rider Saddle", "Corsair Harness", "Cloud-Leather Saddle"],
	"talons": ["Talon Guards", "Starsteel Claw Caps", "Comet Spurs", "Brass Talon Rings"],
	"crest": ["Horn Crown", "Crest Plate", "Star Diadem", "Brass Horn Caps"],
	"bond": ["Bond Pendant", "Hatchling Bell", "Twin-Soul Locket", "Egg-Shell Charm"],
}
const PREFIXES := [
	["Worn", "Plain", "Salt-Stained"],
	["Fine", "Polished", "Tempered"],
	["Starsteel", "Moonlit", "Brass-Bound"],
	["Tidecaller's", "Stormforged", "Pirate King's"],
	["Dragonheart", "Admiral-Slayer", "Nebula-Woven"],
	["Starwyrm", "Eclipse", "Worldsplitter"],
]

## Main stat of each slot at Common (scaled by grade).
const MAIN := {
	"weapon": {"attack": 0.06},
	"helm": {"max_hp": 10.0, "max_mana": 6.0},
	"armor": {"max_hp": 15.0, "armor": 0.02},
	"gloves": {"attack_speed": 0.04, "crit_chance": 0.01},
	"boots": {"move_speed_mult": 0.03, "stamina_regen": 4.0},
	"ring": {"crit_damage": 0.08, "spell_power": 0.03},
	"charm": {"spell_power": 0.06, "max_mana": 10.0},
	"saddle": {"dragon_hp": 15.0, "dragon_armor": 0.03},
	"talons": {"dragon_damage": 0.08},
	"crest": {"special_cdr": 0.05, "special_damage": 0.08},
	"bond": {"dragon_xp": 0.1, "spell_power": 0.03},
}

## Random bonus pools: [min, max] at Common (scaled by grade). "skill" = +ranks to a skill.
## Dragon gear: dragon stats, plus "bond" stats that help the captain (spell power etc.).
const DRAGON_AFFIXES := {
	"dragon_hp": [8.0, 15.0],
	"dragon_armor": [0.01, 0.025],
	"dragon_damage": [0.04, 0.08],
	"dragon_attack_speed": [0.04, 0.08],
	"special_cdr": [0.03, 0.05],
	"special_damage": [0.05, 0.1],
	"dragon_xp": [0.05, 0.1],
	"spell_power": [0.02, 0.04],
	"mana_regen": [0.5, 1.0],
	"cdr": [0.015, 0.03],
}
const AFFIXES := {
	"attack": [0.03, 0.06],
	"crit_chance": [0.01, 0.025],
	"crit_damage": [0.06, 0.12],
	"attack_speed": [0.03, 0.06],
	"max_hp": [8.0, 15.0],
	"armor": [0.01, 0.025],
	"move_speed_mult": [0.02, 0.04],
	"max_mana": [6.0, 12.0],
	"mana_regen": [0.6, 1.2],
	"spell_power": [0.03, 0.06],
	"cdr": [0.02, 0.035],
	"stamina_regen": [3.0, 6.0],
	"dragon_damage": [0.05, 0.1],
	"skill": [1.0, 1.0],
}

const STAT_LABELS := {
	"attack": ["Sword damage", true], "crit_chance": ["Critical chance", true],
	"crit_damage": ["Critical damage", true], "attack_speed": ["Attack speed", true],
	"max_hp": ["Max health", false], "armor": ["Armor", true], "move_speed_mult": ["Move speed", true],
	"max_mana": ["Max mana", false], "mana_regen": ["Mana regen /s", false], "spell_power": ["Spell power", true],
	"cdr": ["Spell cooldowns", true], "stamina_regen": ["Stamina regen /s", false],
	"dragon_damage": ["Dragon damage", true],
	"dragon_hp": ["Dragon health", false], "dragon_armor": ["Dragon armor", true],
	"dragon_attack_speed": ["Dragon breath speed", true], "special_cdr": ["Dragon special cooldown", true],
	"special_damage": ["Dragon special damage", true], "dragon_xp": ["Dragon XP gain", true],
}


static func is_dragon_slot(slot: String) -> bool:
	return slot in DRAGON_SLOTS


static func random_slot() -> String:
	return DRAGON_SLOTS.pick_random() if randf() < DRAGON_DROP_CHANCE else SLOTS.pick_random()


static func roll_grade(luck := 0) -> int:
	var total := 0.0
	for w in GRADE_WEIGHTS:
		total += w
	var r := randf() * total
	var grade := 0
	for i in GRADE_WEIGHTS.size():
		r -= GRADE_WEIGHTS[i]
		if r <= 0.0:
			grade = i
			break
	for _i in luck:
		if randf() < 0.35:
			grade = mini(grade + 1, GRADES.size() - 1)
	return grade


static func generate(id: int, grade := -1, slot := "") -> Dictionary:
	if grade < 0:
		grade = roll_grade()
	if slot == "":
		slot = random_slot()
	var mult: float = GRADE_MULT[grade]
	var main := {}
	for stat in MAIN[slot]:
		main[stat] = _round_stat(stat, MAIN[slot][stat] * mult)
	var affixes := []
	var table: Dictionary = DRAGON_AFFIXES if is_dragon_slot(slot) else AFFIXES
	var pool: Array = table.keys()
	pool.shuffle()
	var used_skills := []
	for stat in pool:
		if affixes.size() >= grade:
			break
		if stat == "skill":
			var options := []
			for sid in Skills.SKILLS:
				var capstone: bool = Skills.SKILLS[sid].get("capstone", false)
				if sid not in used_skills and (not capstone or grade >= 4):
					options.append(sid)
			var sid: String = options.pick_random()
			used_skills.append(sid)
			var ranks := 1 if grade < 4 else (randi_range(1, 2) if grade == 4 else 2)
			affixes.append({"skill": sid, "value": ranks})
		else:
			var r: Array = table[stat]
			affixes.append({"stat": stat, "value": _round_stat(stat, randf_range(r[0], r[1]) * mult)})
	var item_name: String = "%s %s" % [PREFIXES[grade].pick_random(), BASES[slot].pick_random()]
	return {"id": id, "slot": slot, "grade": grade, "name": item_name, "main": main, "affixes": affixes}


static func _round_stat(stat: String, v: float) -> float:
	if STAT_LABELS.has(stat) and STAT_LABELS[stat][1]:
		return snappedf(v, 0.001)
	return snappedf(v, 0.1)


static func stat_text(stat: String, value: float) -> String:
	var label: Array = STAT_LABELS.get(stat, [stat, false])
	if stat == "cdr":
		return "%d%% faster spell cooldowns" % roundi(value * 100.0)
	if stat == "special_cdr":
		return "%d%% faster dragon special" % roundi(value * 100.0)
	if label[1]:
		return "+%s%% %s" % [_fmt(value * 100.0), label[0]]
	return "+%s %s" % [_fmt(value), label[0]]


static func _fmt(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 0.05 else "%.1f" % v


## Readable lines for tooltips / the item panel.
static func describe(item: Dictionary) -> Array:
	var lines := []
	for stat in item["main"]:
		lines.append(stat_text(stat, item["main"][stat]))
	for a in item["affixes"]:
		if a.has("skill"):
			lines.append("+%d to %s" % [int(a["value"]), Skills.SKILLS[a["skill"]]["name"]])
		else:
			lines.append(stat_text(a["stat"], a["value"]))
	return lines


## Adds item stats to `s`. Only stats `s` already has are applied, so the same items
## can feed both the captain's stats and the dragon's stats.
## `only` limits which stats are applied (used for dragon gear "bond" stats on the captain).
static func apply(s: Dictionary, items: Array, only: Array = []) -> void:
	for item in items:
		for stat in item["main"]:
			if s.has(stat) and (only.is_empty() or stat in only):
				s[stat] += item["main"][stat]
		for a in item["affixes"]:
			if a.has("stat") and s.has(a["stat"]) and (only.is_empty() or a["stat"] in only):
				s[a["stat"]] += a["value"]


## Dragon-gear stats that also benefit the captain.
const BOND_STATS := ["spell_power", "mana_regen", "cdr"]


static func skill_bonus(items: Array, skill_id: String) -> int:
	var n := 0
	for item in items:
		for a in item["affixes"]:
			if a.get("skill", "") == skill_id:
				n += int(a["value"])
	return n


## Rough power score, used to compare items ("better than equipped?").
static func score(item: Dictionary) -> float:
	return float(item["grade"]) * 10.0 + item["affixes"].size()
