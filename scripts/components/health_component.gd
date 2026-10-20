extends Node
## HealthComponent: hit points with invulnerability. Owners react to its signals.

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

@export var max_health := 100.0
var current := 100.0
var invulnerable := false


func setup(maximum: float) -> void:
	max_health = maximum
	current = maximum


func is_dead() -> bool:
	return current <= 0.0


func ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0


## Returns the damage actually dealt (0 when blocked).
func apply_damage(amount: float) -> float:
	if invulnerable or is_dead() or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, current)
	current -= dealt
	damaged.emit(dealt)
	changed.emit(current, max_health)
	if current <= 0.0:
		died.emit()
	return dealt


func heal(amount: float) -> void:
	if is_dead():
		return
	current = minf(max_health, current + amount)
	changed.emit(current, max_health)
