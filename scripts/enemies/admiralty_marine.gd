extends "res://scripts/enemies/admiralty_base.gd"
## Admiralty Marine: melee soldier with an electrified saber.
## Closes in, raises the saber (red arc telegraph), then slashes.
## Has poise: the first light hits of a combo don't stagger it, finishers do.

const CHASE_RANGE := 1.8
const WINDUP_TIME := 0.6
const RECOVER_TIME := 0.7
const SLASH_RANGE := 2.1
const SLASH_DOT := 0.2

var _attack_dir := Vector3.FORWARD
var _attack_cd := 0.6
var _struck := false


func _init() -> void:
	kind = "marine"
	max_health = 75.0
	move_speed = 3.3
	radius = 0.38
	poise = 14.0
	contact_damage = 15.0
	sprite_height = 1.45
	xp_reward = 22
	loot_chance = 0.25
	set_chance = 0.04


func _build_visuals() -> void:
	super()
	_make_telegraph(true)


func _setup_states() -> void:
	add_state("spawn", _st_spawn, _warp_in)
	add_state("chase", _st_chase, func() -> void: play_anim("run"))
	add_state("windup", _st_windup, _en_windup)
	add_state("slash", _st_slash, _en_slash)
	add_state("recover", _st_recover, func() -> void: play_anim("idle"))
	add_state("stagger", _st_stagger, _en_stagger)
	change_state("spawn")


func _tick(delta: float) -> void:
	_attack_cd -= delta


func _on_stagger() -> void:
	_telegraph.visible = false
	change_state("stagger")


func _st_spawn(_delta: float) -> void:
	if state_time > 0.6:
		change_state("chase")


func _st_chase(_delta: float) -> void:
	var to := player_vector()
	var dist := to.length()
	if dist < 0.01:
		play_anim("idle")
		return
	var dir := to / dist
	face_towards(dir)
	if dist <= CHASE_RANGE:
		play_anim("idle")
		if _attack_cd <= 0.0:
			change_state("windup")
		return
	play_anim("run")
	desired_velocity = dir * move_speed


func _en_windup() -> void:
	play_anim("windup", true)
	var to := player_vector()
	_attack_dir = to.normalized() if to.length() > 0.01 else look_dir
	Audio.play("saber_crackle", -2.0)


func _st_windup(delta: float) -> void:
	var to := player_vector()
	if state_time < WINDUP_TIME * 0.55 and to.length() > 0.1:
		_attack_dir = _attack_dir.lerp(to.normalized(), 6.0 * delta).normalized()
	face_towards(_attack_dir)
	_show_telegraph(_attack_dir, clampf(state_time / WINDUP_TIME, 0.0, 1.0), true)
	if int(state_time * 20.0) % 3 == 0:
		Game.burst(global_position + Vector3.UP * 1.6 + _attack_dir * 0.2, Color(0.6, 0.95, 1.0), 2, 2.0, 0.05, 0.15, 0.0)
	if state_time >= WINDUP_TIME:
		change_state("slash")


func _en_slash() -> void:
	play_anim("slash", true)
	_telegraph.visible = false
	_struck = false
	knockback += _attack_dir * 5.0   # short step into the swing


func _st_slash(_delta: float) -> void:
	if not _struck and state_time >= SpriteFactory.humanoid_strike_time("slash"):
		_struck = true
		Game.slash_fx(global_position + Vector3.UP * 0.7, _attack_dir, Color(0.55, 0.9, 1.0), SLASH_RANGE * 2.0, 0.2)
		Audio.play("whoosh_heavy")
		var hits := Game.hit_allies_in_arc(global_position, _attack_dir, SLASH_RANGE + 0.3, SLASH_DOT,
			func() -> Dictionary: return Damage.make(contact_damage, E.PHYSICAL, _attack_dir, 8.0, true, 0.0, self))
		if hits > 0:
			Game.burst(global_position + Vector3.UP * 0.8 + _attack_dir * 1.2, Color(0.6, 0.95, 1.0), 10, 5.0, 0.05, 0.2, 0.0)
	if state_time >= SpriteFactory.humanoid_duration("slash"):
		change_state("recover")


func _st_recover(_delta: float) -> void:
	if state_time >= RECOVER_TIME:
		_attack_cd = randf_range(0.6, 1.3)
		change_state("chase")


func _en_stagger() -> void:
	play_anim("hit", true)
	visual.scale = Vector3(1.1, 0.9, 1.1)


func _st_stagger(_delta: float) -> void:
	if state_time >= 0.45:
		_attack_cd = maxf(_attack_cd, 0.4)
		change_state("chase")
