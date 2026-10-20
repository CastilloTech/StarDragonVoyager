extends Node
## CombatController: 3-hit basic combo (tap Attack) and a charged attack
## (hold Charge / hold the touch Attack button). Damage lands on each
## animation's strike frame so visuals and hits line up.

const E := preload("res://scripts/core/elements.gd")
const Damage := preload("res://scripts/core/damage.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")

const COMBO := [
	{"anim": "attack1", "damage": 10.0, "knockback": 3.0, "range": 1.9, "arc": 0.3, "step": 3.0, "shake": 0.12},
	{"anim": "attack2", "damage": 12.0, "knockback": 3.5, "range": 1.9, "arc": 0.3, "step": 3.0, "shake": 0.12},
	{"anim": "attack3", "damage": 20.0, "knockback": 9.0, "range": 2.3, "arc": 0.5, "step": 5.5, "shake": 0.3},
]
const CRIT_CHANCE := 0.12
const CHARGE_TIME := 0.6
const CHARGE_COST := 30.0
const CHARGED_DAMAGE := 34.0

var player: Node
var _combo_idx := 0
var _combo_window := 0.0
var _buffer := 0.0
var _pending := {}
var _hit_timer := -1.0
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
	_buffer = 0.25


func begin_charge() -> void:
	if player.is_free() or _can_chain():
		_charging = true
		_charge = 0.0
		_charge_ready_fx = false
		player.start_action("charge", INF, 0.35)


func release_charge() -> void:
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
	player.lunge(6.5)
	_pending = {"damage": CHARGED_DAMAGE, "knockback": 11.0, "range": 2.7, "arc": 0.15, "shake": 0.5, "element": el, "heavy": true}
	_hit_timer = SpriteFactory.strike_time("charged")
	_attacking = true
	_charge = 0.0


func _can_chain() -> bool:
	return player.in_action() and _attacking and _hit_timer < 0.0 and player.action_time_left() < 0.14


func _physics_process(delta: float) -> void:
	_combo_window -= delta
	_buffer -= delta
	if not Game.touch_controls:
		if Input.is_action_just_pressed("attack"):
			request_attack()
		if Input.is_action_just_pressed("charged_attack"):
			begin_charge()
		if _charging and not Input.is_action_pressed("charged_attack"):
			release_charge()

	if _attacking and not player.in_action():
		_attacking = false

	if _hit_timer >= 0.0:
		_hit_timer -= delta
		if _hit_timer < 0.0:
			_strike(_pending)

	if _buffer > 0.0 and not _charging and (player.is_free() or _can_chain()):
		_start_combo_swing()

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


func _start_combo_swing() -> void:
	_buffer = 0.0
	if _combo_window <= 0.0:
		_combo_idx = 0
	var atk: Dictionary = COMBO[_combo_idx].duplicate()
	var anim: String = atk["anim"]
	var dur := SpriteFactory.anim_duration(anim)
	player.start_action(anim, dur, 0.15)
	player.lunge(atk["step"])
	atk["element"] = E.PHYSICAL
	atk["heavy"] = _combo_idx == 2
	_pending = atk
	_hit_timer = SpriteFactory.strike_time(anim)
	_attacking = true
	_combo_window = dur + 0.4
	_combo_idx = (_combo_idx + 1) % COMBO.size()


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
	var hits := 0
	for e in Game.enemies():
		if not e.can_be_hit():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > reach + e.radius:
			continue
		if d > 0.35 and aim.dot(to / d) < atk["arc"]:
			continue
		var dir := to / d if d > 0.01 else aim
		e.take_damage(Damage.make(atk["damage"], el, dir, atk["knockback"], true, CRIT_CHANCE, player))
		hits += 1
	if hits > 0:
		player.gain_mana(4.0 * hits)
		Game.hitstop(0.1 if heavy else 0.045)
		Game.shake(atk["shake"])
