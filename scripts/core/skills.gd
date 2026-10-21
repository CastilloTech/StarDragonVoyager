extends RefCounted
## Swordsman skill tree: three branches (playstyles), five skills each.
##
## Row unlocks: a skill's row needs that many points already spent in its branch
## (TIER_POINTS). Each branch costs 17 points to max; a level-30 captain has 29, so
## players specialize or hybridize - they can't take everything.
##
## Effects are applied in two places:
##   - apply(): plain stat changes (attack speed, armor, spell power...)
##   - gameplay code reads Progress.skill_rank("<id>") for mechanics
##     (Riposte, Flurry, Imbue, Earthsplitter, Spell Weave, Dragon's Echo, Unshakable).

const TIER_POINTS := [0, 1, 3, 5, 8]

const BRANCHES := [
	{"id": "duelist", "name": "Duelist", "color": Color(0.45, 0.85, 1.0), "tagline": "Speed, critical hits and dodge counters"},
	{"id": "vanguard", "name": "Vanguard", "color": Color(1.0, 0.62, 0.3), "tagline": "Heavy blows, armor and unstoppable charges"},
	{"id": "spellblade", "name": "Spellblade", "color": Color(0.8, 0.5, 1.0), "tagline": "Sword and dragon magic feeding each other"},
]

const SKILLS := {
	# ---------------------------------------------------------------- Duelist
	"swift_blades": {"branch": "duelist", "tier": 0, "max": 5, "name": "Swift Blades",
		"desc": "+6% attack speed per rank."},
	"keen_edge": {"branch": "duelist", "tier": 1, "max": 5, "name": "Keen Edge",
		"desc": "+3% critical chance and +8% critical damage per rank."},
	"riposte": {"branch": "duelist", "tier": 2, "max": 3, "name": "Riposte",
		"desc": "Dash through an attack at the last moment to counter-slash for 150% / 200% / 250% damage."},
	"fleetfoot": {"branch": "duelist", "tier": 3, "max": 3, "name": "Fleetfoot",
		"desc": "Dashes cost 15% less stamina and you move 5% faster, per rank."},
	"flurry": {"branch": "duelist", "tier": 4, "max": 1, "name": "Flurry", "capstone": true,
		"desc": "Your combo gains a 4th strike: a lightning-fast double slash."},
	# ---------------------------------------------------------------- Vanguard
	"heavy_hand": {"branch": "vanguard", "tier": 0, "max": 5, "name": "Heavy Hand",
		"desc": "+12% charged attack damage and +6% combo finisher damage per rank."},
	"iron_hide": {"branch": "vanguard", "tier": 1, "max": 5, "name": "Iron Hide",
		"desc": "+12 max health and +3% armor per rank."},
	"unshakable": {"branch": "vanguard", "tier": 2, "max": 3, "name": "Unshakable",
		"desc": "While attacking or charging you never flinch and take 10% / 20% / 30% less damage."},
	"quick_charge": {"branch": "vanguard", "tier": 3, "max": 3, "name": "Quick Charge",
		"desc": "Charged attacks build up 15% faster per rank."},
	"earthsplitter": {"branch": "vanguard", "tier": 4, "max": 1, "name": "Earthsplitter", "capstone": true,
		"desc": "Charged attacks release a shockwave that hits everything around you."},
	# ---------------------------------------------------------------- Spellblade
	"mana_siphon": {"branch": "spellblade", "tier": 0, "max": 5, "name": "Mana Siphon",
		"desc": "Sword hits restore 2 more mana per rank."},
	"arcane_focus": {"branch": "spellblade", "tier": 1, "max": 5, "name": "Arcane Focus",
		"desc": "+8% spell power and 4% faster spell cooldowns per rank."},
	"imbue": {"branch": "spellblade", "tier": 2, "max": 3, "name": "Imbue",
		"desc": "Your combo finisher carries your dragon's element and deals 20% / 35% / 50% more damage."},
	"spell_weave": {"branch": "spellblade", "tier": 3, "max": 3, "name": "Spell Weave",
		"desc": "Casting a spell empowers your next 2 sword strikes: +20% / 35% / 50% damage."},
	"dragons_echo": {"branch": "spellblade", "tier": 4, "max": 1, "name": "Dragon's Echo", "capstone": true,
		"desc": "Spells have a 25% chance to cast twice, and every spell cuts your dragon's special cooldown by 1 s."},
}

## Per-rank values for mechanic skills (index = rank - 1).
const RIPOSTE_MULT := [1.5, 2.0, 2.5]
const UNSHAKABLE_REDUCTION := [0.1, 0.2, 0.3]
const IMBUE_BONUS := [0.2, 0.35, 0.5]
const WEAVE_BONUS := [0.2, 0.35, 0.5]


static func branch_skills(branch_id: String) -> Array:
	var out := []
	for id in SKILLS:
		if SKILLS[id]["branch"] == branch_id:
			out.append(id)
	out.sort_custom(func(a, b): return SKILLS[a]["tier"] < SKILLS[b]["tier"])
	return out


static func value_for(table: Array, rank: int) -> float:
	return table[clampi(rank, 1, table.size()) - 1] if rank > 0 else 0.0


## Adds skill stat bonuses to `s` (see Progress.base_stats()). rank(id) -> effective rank.
static func apply(s: Dictionary, rank: Callable) -> void:
	s["attack_speed"] += 0.06 * rank.call("swift_blades")
	s["crit_chance"] += 0.03 * rank.call("keen_edge")
	s["crit_damage"] += 0.08 * rank.call("keen_edge")
	s["dash_cost"] *= 1.0 - 0.15 * mini(rank.call("fleetfoot"), 5)
	s["move_speed_mult"] += 0.05 * rank.call("fleetfoot")
	s["charged_damage"] += 0.12 * rank.call("heavy_hand")
	s["finisher_damage"] += 0.06 * rank.call("heavy_hand")
	s["max_hp"] += 12.0 * rank.call("iron_hide")
	s["armor"] += 0.03 * rank.call("iron_hide")
	s["charge_time"] *= 1.0 - 0.15 * mini(rank.call("quick_charge"), 5)
	s["mana_on_hit"] += 2.0 * rank.call("mana_siphon")
	s["spell_power"] += 0.08 * rank.call("arcane_focus")
	s["cdr"] += 0.04 * rank.call("arcane_focus")
