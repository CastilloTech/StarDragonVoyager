extends Node
## StatusEffectManager: elemental status effects on an enemy and combo resolution.
## Effects: burning, chilled, frozen, shocked, bound, hexed (seconds remaining).

const E := preload("res://scripts/core/elements.gd")

signal effect_added(effect: String)
signal effect_removed(effect: String)

const BURN_TICK := 0.5
const BURN_DAMAGE := 3.0

var effects := {}
var resist_freeze := false
var body: Node   # must implement take_status_damage(amount, color)
var _burn_tick := BURN_TICK


func has(effect: String) -> bool:
	return effects.get(effect, 0.0) > 0.0


func add(effect: String, duration: float) -> void:
	var was := has(effect)
	effects[effect] = maxf(effects.get(effect, 0.0), duration)
	if not was:
		effect_added.emit(effect)


func remove(effect: String) -> void:
	if effects.has(effect):
		effects.erase(effect)
		effect_removed.emit(effect)


func clear() -> void:
	for k in effects.keys():
		remove(k)


func can_act() -> bool:
	return not has("frozen")


func speed_multiplier() -> float:
	if has("frozen"):
		return 0.0
	var m := 1.0
	if has("chilled"):
		m *= 0.55
	if has("bound"):
		m *= 0.5
	return m


func damage_taken_multiplier() -> float:
	return 1.3 if has("hexed") else 1.0


## Applies an incoming hit's element, resolving combos. Mutates and returns info.
func resolve_hit(info: Dictionary) -> Dictionary:
	var el: int = info["element"]
	if el == E.SUN:
		if has("frozen"):
			_combo(info, "MELT", 2.5)
			remove("frozen")
		elif has("shocked"):
			_combo(info, "OVERLOAD", 1.5)
			remove("shocked")
			info["explode"] = true
		else:
			add("burning", 3.0)
	elif el == E.COMET:
		if has("frozen"):
			add("frozen", effects["frozen"] + 0.2)
		elif has("chilled"):
			remove("chilled")
			add("frozen", 1.2 if resist_freeze else 2.2)
			info["froze"] = true
		else:
			add("chilled", 3.5)
	elif el == E.STORM:
		if has("frozen"):
			_combo(info, "SHATTER", 3.0)
			remove("frozen")
		else:
			add("shocked", 1.5)
	elif el == E.GRAVITY:
		if has("burning"):
			_combo(info, "SOLAR VORTEX", 2.0)
			info["spread_burn"] = true
		add("bound", 1.0)
	elif el == E.VOID:
		add("hexed", 4.0)
	info["amount"] = info["amount"] * damage_taken_multiplier()
	return info


func _combo(info: Dictionary, combo_name: String, mult: float) -> void:
	info["combo"] = combo_name
	info["amount"] = info["amount"] * mult
	info["stagger"] = true


func _physics_process(delta: float) -> void:
	for k in effects.keys():
		effects[k] -= delta
		if effects[k] <= 0.0:
			remove(k)
	if has("burning"):
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = BURN_TICK
			if body:
				body.take_status_damage(BURN_DAMAGE, E.COLORS[E.SUN])
