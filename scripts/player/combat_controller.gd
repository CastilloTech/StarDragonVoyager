extends Node
## CombatController: 3-hit basic combo (tap Attack) and a charged attack
## (hold Charge / hold the touch Attack button). Damage lands on each
## animation's strike frame so visuals and hits line up.
##
## Responsiveness rules:
##  - Presses are buffered for BUFFER seconds, so a click during another action
##    (swing recovery, spell, hit reaction, dash) still happens as soon as possible.
##  - A swing's recovery can be cancelled into the next swing shortly after it strikes.
##  - Swings "magnetize": if an enemy is near your aim but out of reach, the
##    pirate lunges further to connect.

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")

const COMBO := [
	{"anim": "attack1", "damage": 10.0, "knockback": 3.0, "range": 2.0, "arc": 0.2, "step": 3.0, "shake": 0.12},
	{"anim": "attack2", "damage": 12.0, "knockback": 3.5, "range": 2.0, "arc": 0.2, "step": 3.0, "shake": 0.12},
	{"anim": "attack3", "damage": 20.0, "knockback": 9.0, "range": 2.4, "arc": 0.4, "step": 5.5, "shake": 0.3},
]
const CRIT_CHANCE := 0.12
const CHARGE_TIME := 0.6
const CHARGE_COST := 30.0
const CHARGED_DAMAGE := 34.0
const BUFFER := 0.4
const CANCEL_AFTER_STRIKE := 0.05
const MAGNET_RANGE := 4.0
const MAGNET_DOT := 0.5

var player: Node
var stat_requests := 0   # debug counters used by the click test
var stat_swings := 0

var _combo_idx := 0
var _combo_window := 0.0
var _buffer := 0.0
var _charge_buffer := 0.0
var _pending := {}
var _hit_timer := -1.0
var _since_strike := 0.0
var _attacking := false
var _charging := false
var _charge := 0.0
var _charge_ready_fx := false


func _ready() -> void:
	player = get_parent()


func charge_level() -> float:
	return _charge


func cancel() -> void:
	_hit_timer = -1.0
	_charging = false
	_charge = 0.0
	_attacking = false


func request_attack() -> void:
	_buffer = BUFFER
	stat_requests += 1


func begin_charge() -> void:
	if _can_start():
		_charging = true
		_charge = 0.0
		_charge_ready_fx = false
		_charge_buffer = 0.0
		player.start_action("charge", INF, 0.35)
	else:
		_charge_buffer = BUFFER


func release_charge() -> void:
	_charge_buffer = 0.0
	if not _charging:
		return
	_charging = false
	if _charge < 1.0:
		# Released early: becomes a normal combo swing.
		player.end_action()
		request_attack()
		return
	if not player.spend_stamina(CHARGE_COST):
		Game.float_text(player.global_position + Vector3.UP * 2.0, "No stamina", Color(0.9, 0.85, 0.4), 26, 0.6)
		player.end_action()
		return
	var el: int = player.abilities.element
	player.start_action("charged", SpriteFactory.anim_duration("charged"), 0.0)
	player.lunge(_magnet_step(6.5, 2.7))
	_pending = {"damage": CHARGED_DAMAGE, "knockback": 11.0, "range": 2.7, "arc": 0.1, "shake": 0.5, "element": el, "heavy": true}
	_hit_timer = SpriteFactory.strike_time("charged")
	_attacking = true
	_charge = 0.0
	Audio.play("whoosh_heavy")


## True when a new attack may begin right now.
func _can_start() -> bool:
	if player.is_free():
		return true
	if not player.in_action():
		return false
	var anim: String = player.action_anim()
	if _attacking and _hit_timer < 0.0 and _since_strike >= CANCEL_AFTER_STRIKE:
		return true   # cancel swing recovery
	if anim == "cast" and player.action_time_left() < 0.12:
		return true   # cancel the end of a spell cast
	return false


func _input(event: InputEvent) -> void:
	# Event-driven so no click is ever missed between physics frames.
	if Game.touch_controls or get_tree().paused:
		return
	if event.is_action_pressed("attack"):
		request_attack()
	elif event.is_action_pressed("charged_attack"):
		begin_charge()
	elif event.is_action_released("charged_attack"):
		release_charge()


func _physics_process(delta: float) -> void:
	_combo_window -= delta
	_buffer -= delta
	_charge_buffer -= delta
	_since_strike += delta

	if _attacking and not player.in_action():
		_attacking = false

	if _hit_timer >= 0.0:
		_hit_timer -= delta
		if _hit_timer < 0.0:
			_since_strike = 0.0
			_strike(_pending)

	if _buffer > 0.0 and not _charging and _can_start():
		_start_combo_swing()

	# A charge pressed while busy starts once free, if the button is still held.
	if _charge_buffer > 0.0 and not _charging and _can_start() and Input.is_action_pressed("charged_attack"):
		begin_charge()

	if _charging:
		if player.action_anim() != "charge":
			_charging = false
			_charge = 0.0
		else:
			_charge = minf(_charge + delta / CHARGE_TIME, 1.0)
			if _charge >= 1.0 and not _charge_ready_fx:
				_charge_ready_fx = true
				var col: Color = E.COLORS[player.abilities.element]
				Game.burst(player.hand_position(), col, 14, 3.0, 0.07, 0.35, 0.0)
				Game.ring_fx(player.global_position, col, 1.0, 0.25)
				Audio.play("charge_ready")


func _start_combo_swing() -> void:
	_buffer = 0.0
	stat_swings += 1
	if _combo_window <= 0.0:
		_combo_idx = 0
	var atk: Dictionary = COMBO[_combo_idx].duplicate()
	var anim: String = atk["anim"]
	var dur := SpriteFactory.anim_duration(anim)
	player.start_action(anim, dur, 0.15)
	player.lunge(_magnet_step(atk["step"], atk["range"]))
	atk["element"] = E.PHYSICAL
	atk["heavy"] = _combo_idx == 2
	_pending = atk
	_hit_timer = SpriteFactory.strike_time(anim)
	_attacking = true
	_combo_window = dur + 0.45
	_combo_idx = (_combo_idx + 1) % COMBO.size()


## Lunge speed for a swing. If an enemy is near the aim but out of reach, turn to
## face it and lunge far enough to connect.
func _magnet_step(base_step: float, reach: float) -> float:
	var origin: Vector3 = player.global_position
	var aim: Vector3 = player.aim_dir
	var best: Node3D = null
	var best_d := INF
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d > MAGNET_RANGE:
			continue
		if aim.dot(to / d) < MAGNET_DOT:
			continue
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return base_step
	var dir: Vector3 = best.global_position - origin
	dir.y = 0.0
	player.lock_aim(dir.normalized(), 0.2)
	var gap: float = best_d - (reach * 0.6 + best.radius)
	if gap <= 0.0:
		return base_step * 0.6   # already in reach: small step only
	# Lunge velocity decays over ~0.15 s, so distance ~= speed * 0.09.
	return clampf(gap / 0.09, base_step, 16.0)


func _strike(atk: Dictionary) -> void:
	var aim: Vector3 = player.aim_dir
	var origin: Vector3 = player.global_position
	var el: int = atk["element"]
	var heavy: bool = atk["heavy"]
	var reach: float = atk["range"]
	var col := Color(1.0, 0.95, 0.85) if el < 0 else (E.COLORS[el] as Color)
	Game.slash_fx(origin + Vector3.UP * 0.7, aim, col, reach * 2.1, 0.22 if heavy else 0.16)
	if el >= 0:
		Game.burst(origin + Vector3.UP * 0.6 + aim * 1.2, col, 16, 4.0, 0.08, 0.4, 0.0)
	if not heavy:
		Audio.play("whoosh")
	elif el < 0:
		Audio.play("whoosh_heavy")
	var hits := 0
	var crit := false
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > reach + e.radius:
			continue
		if d > 0.5 and aim.dot(to / d) < atk["arc"]:
			continue
		var dir := to / d if d > 0.01 else aim
		var info := Damage.make(atk["damage"], el, dir, atk["knockback"], true, CRIT_CHANCE, player)
		crit = crit or info["crit"]
		e.take_damage(info)
		hits += 1
	if hits > 0:
		player.gain_mana(4.0 * hits)
		Game.hitstop(0.1 if heavy else 0.045)
		Game.shake(atk["shake"])
		Audio.play("hit_heavy" if heavy else ("crit" if crit else "hit"))
