extends RefCounted
## The five elemental energies: ids, colors, costs and cooldowns.
##
## Combos (resolved in components/status_effect_manager.gd):
##   Comet on Chilled      -> FROZEN (can't act)
##   Sun on Frozen         -> MELT (2.5x damage)
##   Storm on Frozen       -> SHATTER (3x damage)
##   Sun on Shocked        -> OVERLOAD (explosion hits nearby enemies)
##   Gravity on Burning    -> SOLAR VORTEX (2x damage, burn spreads)
##   Void                  -> HEXED (takes +30% damage from everything)

enum { SUN, COMET, STORM, GRAVITY, VOID }

const PHYSICAL := -1
const COUNT := 5
const NAMES := ["Sun", "Comet", "Storm", "Gravity", "Void"]
const ABILITY_NAMES := ["Solar Flare", "Comet Shard", "Arc Lightning", "Gravity Well", "Void Step"]
const COLORS := [
	Color(1.0, 0.62, 0.2),
	Color(0.55, 0.88, 1.0),
	Color(0.74, 0.48, 1.0),
	Color(0.45, 0.42, 1.0),
	Color(0.92, 0.28, 0.85),
]
const MANA_COSTS := [14.0, 10.0, 18.0, 22.0, 16.0]
const COOLDOWNS := [0.35, 0.25, 0.7, 3.0, 1.6]
