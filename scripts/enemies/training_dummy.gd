extends "res://scripts/enemies/voidling.gd"
## Training dummy for automated tests: looks like a Voidling, never attacks,
## and drifts back to its spot after being knocked away (like an enemy closing in).

var home := Vector3.ZERO
var hits_taken := 0


func _setup_states() -> void:
	xp_reward = 0
	loot_chance = 0.0
	max_health = 99999.0
	health.setup(max_health)
	add_state("idle", _st_idle, func() -> void: sprite.play("idle"))
	add_state("stagger", _st_idle)
	change_state("idle")


func take_damage(info: Dictionary) -> void:
	hits_taken += 1
	super(info)


func _st_idle(_delta: float) -> void:
	var to := home - global_position
	to.y = 0.0
	if to.length() > 0.1:
		desired_velocity = to.normalized() * minf(move_speed, to.length() * 3.0)
