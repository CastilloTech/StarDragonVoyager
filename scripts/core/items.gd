extends RefCounted
## Equipment: three slots, six grades. Every grade above Common adds one more random
## bonus (affix) and raises all values. Bonuses can be stats or +ranks to a skill.

const Skills := preload("res://scripts/core/skills.gd")

const SLOTS := ["weapon", "armor", "charm"]
const SLOT_NAMES := {"weapon": "Weapon", "armor": "Armor", "charm": "Charm"}

const GRADES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
const GRADE_COLORS := [
	Color(0.82, 0.82, 0.86), Color(0.45, 0.92, 0.5), Color(0.38, 0.62, 1.0),
	Color(0.78, 0.45, 1.0), Color(1.0, 0.66, 0.22), Color(1.0, 0.32, 0.42),
]
const GRADE_MULT := [1.0, 1.3, 1.7, 2.2, 2.8, 3.5]
const GRADE_WEIGHTS := [52.0, 27.0, 13.0, 6.0, 1.8, 0.2]

const BASES := {
	"weapon": ["Twin Cutlasses", "Corsair Blades", "Starsteel Daggers", "Brass-Hilt Sabers", "Comet Fangs"],
	"armor": ["Corsair Coat", "Brass-Plated Longcoat", "Navigator's Jacket", "Sky-Silk Duster", "Deckhand Leathers"],
	"charm": ["Star Compass", "Dragon-Scale Charm", "Comet Locket", "Nebula Pearl", "Brass Astrolabe"],
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
	"armor": {"max_hp": 15.0, "armor": 0.02},
	"charm": {"spell_power": 0.06, "max_mana": 10.0},
}

## Random bonus pool: [min, max] at Common (scaled by grade). "skill" = +ranks to a skill.
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
}


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
		slot = SLOTS.pick_random()
	var mult: float = GRADE_MULT[grade]
	var main := {}
	for stat in MAIN[slot]:
		main[stat] = _round_stat(stat, MAIN[slot][stat] * mult)
	var affixes := []
	var pool: Array = AFFIXES.keys()
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
			var r: Array = AFFIXES[stat]
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


static func apply(s: Dictionary, items: Array) -> void:
	for item in items:
		for stat in item["main"]:
			s[stat] += item["main"][stat]
		for a in item["affixes"]:
			if a.has("stat"):
				s[a["stat"]] += a["value"]


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
