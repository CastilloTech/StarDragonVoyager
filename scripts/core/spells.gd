extends RefCounted
## The three spells of each element, unlocked by the active dragon's evolution stage.
## "kind" selects the effect in elemental_ability_manager.gd; the rest are its numbers.
## Damage is multiplied by the captain's spell power; cooldowns by cooldown reduction.

const E := preload("res://scripts/core/elements.gd")

const SPELLS := {
	E.SUN: [
		{"name": "Solar Flare", "kind": "projectile", "cost": 14.0, "cd": 0.35,
			"desc": "A fireball that explodes and burns.",
			"speed": 15.0, "damage": 12.0, "radius": 0.5, "life": 1.1, "explode_radius": 1.8, "explode_damage": 8.0, "knockback": 2.5},
		{"name": "Flame Wave", "kind": "cone", "cost": 20.0, "cd": 3.0,
			"desc": "A wave of fire scorches everything in front of you.",
			"damage": 18.0, "range": 4.2, "dot": 0.4, "knockback": 6.0},
		{"name": "Supernova", "kind": "blast", "cost": 40.0, "cd": 12.0,
			"desc": "A sun-burst gathers at your aim, then detonates.",
			"damage": 48.0, "radius": 3.4, "delay": 0.8, "range": 8.0},
	],
	E.COMET: [
		{"name": "Comet Shard", "kind": "projectile", "cost": 10.0, "cd": 0.25,
			"desc": "A fast piercing shard that chills; a second chill freezes.",
			"speed": 24.0, "damage": 10.0, "radius": 0.4, "life": 0.75, "pierce": 2, "knockback": 1.0},
		{"name": "Frost Nova", "kind": "nova", "cost": 22.0, "cd": 5.0,
			"desc": "Ice bursts out around you, chilling enemies (freezing chilled ones).",
			"damage": 12.0, "radius": 3.2, "knockback": 4.0},
		{"name": "Glacial Spikes", "kind": "line", "cost": 34.0, "cd": 9.0,
			"desc": "A line of ice spikes erupts toward your aim.",
			"damage": 20.0, "count": 7, "spacing": 0.95, "spike_radius": 1.0},
	],
	E.STORM: [
		{"name": "Arc Lightning", "kind": "chain", "cost": 18.0, "cd": 0.7,
			"desc": "Lightning chains between nearby enemies and shocks them.",
			"damage": 15.0, "jumps": 3, "range": 9.0},
		{"name": "Thunder Strike", "kind": "strike", "cost": 22.0, "cd": 4.0,
			"desc": "A bolt from the sky hits your aim.",
			"damage": 26.0, "radius": 1.8, "range": 8.0},
		{"name": "Storm Field", "kind": "field", "cost": 40.0, "cd": 14.0,
			"desc": "A storm crackles around you, zapping nearby enemies.",
			"damage": 10.0, "radius": 4.2, "duration": 3.5, "tick": 0.35},
	],
	E.GRAVITY: [
		{"name": "Gravity Well", "kind": "well", "cost": 22.0, "cd": 3.0,
			"desc": "An orb becomes a vortex that pulls enemies in, then implodes.",
			"damage": 14.0, "radius": 3.6, "duration": 1.6, "strength": 22.0, "range": 7.0},
		{"name": "Repulse", "kind": "nova", "cost": 18.0, "cd": 5.0,
			"desc": "A gravity pulse hurls enemies away from you.",
			"damage": 10.0, "radius": 3.6, "knockback": 15.0},
		{"name": "Singularity", "kind": "well", "cost": 45.0, "cd": 15.0,
			"desc": "A massive vortex drags in everything nearby before collapsing.",
			"damage": 40.0, "radius": 5.2, "duration": 2.6, "strength": 34.0, "range": 7.0},
	],
	E.VOID: [
		{"name": "Void Step", "kind": "teleport", "cost": 16.0, "cd": 1.6,
			"desc": "Blink forward; void bursts out where you land and hexes enemies.",
			"damage": 14.0, "range": 4.5, "radius": 1.8},
		{"name": "Void Orb", "kind": "projectile", "cost": 20.0, "cd": 3.0,
			"desc": "A slow orb that passes through everything in its path.",
			"speed": 7.0, "damage": 16.0, "radius": 0.75, "life": 1.6, "pierce": 99, "knockback": 2.0},
		{"name": "Rift Barrage", "kind": "homing", "cost": 38.0, "cd": 10.0,
			"desc": "Six void bolts seek out nearby enemies.",
			"damage": 12.0, "count": 6},
	],
}


static func spell(element: int, tier: int) -> Dictionary:
	return SPELLS[element][clampi(tier, 0, 2)]
