extends RefCounted
## DamageComponent helper: builds the damage packet every take_damage() receives.
## Keys: amount, element, dir, knockback, stagger, crit, source, combo

const CRIT_MULT := 1.75


static func make(amount: float, element: int, dir: Vector3, knockback := 0.0, stagger := true,
		crit_chance := 0.0, source: Node = null, crit_mult := CRIT_MULT) -> Dictionary:
	var crit := randf() < crit_chance
	return {
		"amount": amount * (crit_mult if crit else 1.0),
		"element": element,
		"dir": dir,
		"knockback": knockback,
		"stagger": stagger,
		"crit": crit,
		"source": source,
		"combo": "",
	}
