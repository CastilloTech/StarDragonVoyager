extends RefCounted
## Captain gear sets: one per skill tree, each made in five versions (tiers) that
## require levels 10 / 20 / 30 / 40 / 50. Wearing pieces of the same set unlocks
## bonuses. When versions are mixed, the set works at the lowest version worn.
##
## Bonus effects:
##   2 pieces: stats (apply_stats)
##   3 pieces: +ranks to every skill in the set's branch (Progress.skill_rank)
##   5 pieces: a signature mechanic, checked in gameplay code with
##             Progress.set_bonus(id, 5) / Progress.set_power(id)

const SET_GRADE := 6   # index in Items.GRADES ("Set")
const PIECES := ["weapon", "helm", "armor", "gloves", "boots"]
const TIER_LEVELS := [10, 20, 30, 40, 50]
## Bonus strength per tier (1..5).
const TIER_POWER := [1.0, 1.4, 1.8, 2.3, 2.8]
## Piece stat strength per tier (comparable to Rare .. beyond Mythic).
const TIER_ITEM_MULT := [1.7, 2.3, 2.9, 3.6, 4.4]
const ROMAN := ["I", "II", "III", "IV", "V"]

const SETS := {
	"galeblade": {
		"name": "Galeblade", "branch": "duelist", "color": Color(0.45, 0.95, 0.9),
		"piece_names": {"weapon": "Cutlasses", "helm": "Bandana", "armor": "Duster", "gloves": "Grips", "boots": "Treads"},
		"affixes": {"attack_speed": 0.035, "crit_chance": 0.02},
		"bonus2": {"attack_speed": 0.05, "crit_chance": 0.03},
		"bonus5_name": "Gale Step",
		"bonus5_desc": "After a dash, your next strike within 2 s is a guaranteed critical hit and deals %d%% more damage.",
	},
	"ironwake": {
		"name": "Ironwake", "branch": "vanguard", "color": Color(0.45, 0.95, 0.9),
		"piece_names": {"weapon": "Cleavers", "helm": "Helm", "armor": "Plated Coat", "gloves": "Gauntlets", "boots": "Sabatons"},
		"affixes": {"max_hp": 15.0, "armor": 0.025},
		"bonus2": {"max_hp": 20.0, "armor": 0.03},
		"bonus5_name": "Bulwark Surge",
		"bonus5_desc": "Charged attacks heal you for %d%% of your max health and halve damage you take for 2.5 s.",
	},
	"astral": {
		"name": "Astral Weaver", "branch": "spellblade", "color": Color(0.45, 0.95, 0.9),
		"piece_names": {"weapon": "Spellblades", "helm": "Circlet", "armor": "Robe-Coat", "gloves": "Runed Gloves", "boots": "Starstep Boots"},
		"affixes": {"spell_power": 0.05, "max_mana": 10.0},
		"bonus2": {"spell_power": 0.08, "max_mana": 10.0},
		"bonus5_name": "Starfall Echo",
		"bonus5_desc": "Every 3rd spell costs no mana and deals %d%% more damage.",
	},
}


static func tier_of_level(level: int) -> int:
	var t := 0
	for i in TIER_LEVELS.size():
		if level >= TIER_LEVELS[i]:
			t = i + 1
	return t   # 0 = no set tier available yet


static func skill_ranks_for_tier(tier: int) -> int:
	return 2 if tier >= 4 else 1


## Percent shown in the 5-piece description at a tier.
static func bonus5_value(set_id: String, tier: int) -> int:
	var k: float = TIER_POWER[tier - 1]
	match set_id:
		"galeblade":
			return roundi(25.0 * k)
		"ironwake":
			return roundi(5.0 * k)
		_:
			return roundi(30.0 * k)


static func make_piece(id: int, set_id: String, tier: int, slot: String) -> Dictionary:
	const Items := preload("res://scripts/core/items.gd")
	var s: Dictionary = SETS[set_id]
	var mult: float = TIER_ITEM_MULT[tier - 1]
	var main := {}
	for stat in Items.MAIN[slot]:
		main[stat] = Items._round_stat(stat, Items.MAIN[slot][stat] * mult)
	var affixes := []
	for stat in s["affixes"]:
		var v: float = s["affixes"][stat] * mult
		if main.has(stat):   # same stat as the slot's main stat: fold it in (one line, not two)
			main[stat] = Items._round_stat(stat, main[stat] + v)
		else:
			affixes.append({"stat": stat, "value": Items._round_stat(stat, v)})
	return {
		"id": id, "slot": slot, "grade": SET_GRADE, "set": set_id, "set_tier": tier,
		"req": TIER_LEVELS[tier - 1], "theme": "set", "main": main, "affixes": affixes,
		"base": s["piece_names"][slot],
		"name": "%s %s %s" % [s["name"], s["piece_names"][slot], ROMAN[tier - 1]],
	}


## Lines describing a set's bonuses at a tier, marking which are active.
static func describe(set_id: String, tier: int, pieces_worn: int) -> Array:
	const Skills := preload("res://scripts/core/skills.gd")
	var s: Dictionary = SETS[set_id]
	var k: float = TIER_POWER[tier - 1]
	var branch_name := ""
	for b in Skills.BRANCHES:
		if b["id"] == s["branch"]:
			branch_name = b["name"]
	var b2 := []
	for stat in s["bonus2"]:
		b2.append(_stat_short(stat, s["bonus2"][stat] * k))
	return [
		[pieces_worn >= 2, "(2) %s" % ", ".join(b2)],
		[pieces_worn >= 3, "(3) +%d to all %s skills" % [skill_ranks_for_tier(tier), branch_name]],
		[pieces_worn >= 5, "(5) %s: %s" % [s["bonus5_name"], s["bonus5_desc"] % bonus5_value(set_id, tier)]],
	]


static func _stat_short(stat: String, v: float) -> String:
	const Items := preload("res://scripts/core/items.gd")
	return Items.stat_text(stat, v)


## 2-piece stat bonuses for the sets worn. sets = {set_id: {count, tier}}.
static func apply_stats(s: Dictionary, sets: Dictionary) -> void:
	for set_id in sets:
		var info: Dictionary = sets[set_id]
		if info["count"] >= 2:
			var k: float = TIER_POWER[info["tier"] - 1]
			var b2: Dictionary = SETS[set_id]["bonus2"]
			for stat in b2:
				s[stat] += b2[stat] * k
