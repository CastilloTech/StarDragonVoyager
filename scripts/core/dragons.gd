extends RefCounted
## Dragon types and evolution. The active dragon's element decides the captain's
## spells: Hatchling = 1 spell, Drake = 2, Wyrm = 3 (see spells.gd).

const E := preload("res://scripts/core/elements.gd")

## Until each dragon has its own art, non-Nova dragons reuse Nova's sprites with a tint.
const TYPES := {
	E.SUN: {"name": "Ember", "tint": Color(1.35, 0.72, 0.42), "special": "Meteor Shower"},
	E.COMET: {"name": "Nova", "tint": Color(1, 1, 1), "special": "Comet Shower"},
	E.STORM: {"name": "Volt", "tint": Color(1.05, 0.82, 1.45), "special": "Thunderstorm"},
	E.GRAVITY: {"name": "Orbit", "tint": Color(0.75, 0.48, 1.25), "special": "Starfall"},
	E.VOID: {"name": "Nyx", "tint": Color(1.15, 0.55, 1.1), "special": "Rift Rain"},
}

const STAGE_NAMES := ["Hatchling", "Drake", "Wyrm"]
const STAGE_LEVELS := [1, 5, 10]       # dragon level needed for each stage
const STAGE_SCALE := [0.85, 1.0, 1.22]  # sprite size per stage
const STAGE_POWER := [1.0, 1.45, 2.0]   # breath / special damage multiplier
const STAGE_HEALTH := [60.0, 90.0, 130.0]
const MAX_LEVEL := 20


static func starting_roster() -> Array:
	var out := []
	for el in [E.COMET, E.SUN, E.STORM, E.GRAVITY, E.VOID]:
		out.append({"element": el, "name": TYPES[el]["name"], "level": 1, "xp": 0})
	return out


static func xp_to_next(level: int) -> int:
	return 45 + 30 * (level - 1)


static func stage_of(level: int) -> int:
	var stage := 0
	for i in STAGE_LEVELS.size():
		if level >= STAGE_LEVELS[i]:
			stage = i
	return stage


static func spells_unlocked(level: int) -> int:
	return stage_of(level) + 1
