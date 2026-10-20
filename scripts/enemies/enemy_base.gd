extends CharacterBody3D
## EnemyAIController base: components, a reusable finite-state machine, damage
## handling, knockback/stagger and status visuals. Subclasses override
## _build_visuals() and _setup_states(), and register states with add_state().

const E := preload("res://scripts/core/elements.gd")
const HD2D := preload("res://scripts/core/hd2d.gd")
const Damage := preload("res://scripts/core/damage.gd")
const Health := preload("res://scripts/components/health_component.gd")
const Status := preload("res://scripts/components/status_effect_manager.gd")

signal defeated(enemy: Node)

var max_health := 40.0
var move_speed := 4.0
var radius := 0.4
var poise := 0.0           # 0 = staggers on every hit; higher resists light hits
var contact_damage := 10.0
var sprite_height := 1.0   # meters, for the health bar

var health: Node
var status: Node
var sprite: AnimatedSprite3D
var visual: Node3D         # pivot for squash/stretch
var dead := false
var state := ""
var state_time := 0.0
var knockback := Vector3.ZERO
var desired_velocity := Vector3.ZERO
var face_dir := 1.0

var _states := {}
var _flash_t := 0.0
var _hp_root: Node3D
var _hp_fill: MeshInstance3D
var _hp_show_t := 0.0
var _ice: MeshInstance3D
var _fx_t := 0.0


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1 | 4
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 1.2
	shape.shape = cyl
	shape.position.y = 0.6
	add_child(shape)
	health = Health.new()
	health.setup(max_health)
	add_child(health)
	health.died.connect(_on_died)
	status = Status.new()
	status.body = self
	add_child(status)
	visual = Node3D.new()
	add_child(visual)
	add_child(Game.make_blob_shadow(radius * 1.3))
	_build_visuals()
	_build_hp_bar()
	_build_ice()
	_setup_states()


# ---------------------------------------------------------------- overridables

func _build_visuals() -> void:
	pass


func _setup_states() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_stagger() -> void:
	if _states.has("stagger"):
		change_state("stagger")


func _play_death() -> void:
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")


# ---------------------------------------------------------------- FSM

func add_state(state_name: String, update: Callable, enter := Callable()) -> void:
	_states[state_name] = {"update": update, "enter": enter}


func change_state(state_name: String) -> void:
	state = state_name
	state_time = 0.0
	var enter: Callable = _states[state_name]["enter"]
	if enter.is_valid():
		enter.call()


# ---------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	if dead:
		return
	state_time += delta
	_flash_t = maxf(_flash_t - delta, 0.0)
	_hp_show_t = maxf(_hp_show_t - delta, 0.0)
	desired_velocity = Vector3.ZERO
	_tick(delta)
	if status.can_act() or state == "spawn":
		var update: Callable = _states[state]["update"]
		update.call(delta)
	velocity = desired_velocity * status.speed_multiplier() + knockback
	knockback = knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()
	global_position.y = 0.0
	_update_visuals(delta)


func player_vector() -> Vector3:
	var p := Game.player
	if p == null or not is_instance_valid(p) or not p.is_alive():
		return Vector3.ZERO
	var to := p.global_position - global_position
	to.y = 0.0
	return to


func face_towards(dir: Vector3) -> void:
	if absf(dir.x) > 0.1:
		face_dir = signf(dir.x)


# ---------------------------------------------------------------- damage

func can_be_hit() -> bool:
	return not dead and state != "spawn"


func take_damage(info: Dictionary) -> void:
	if not can_be_hit():
		return
	info = status.resolve_hit(info)
	var amount: float = info["amount"]
	var el: int = info["element"]
	var color: Color = Color(1, 1, 1) if el < 0 else E.COLORS[el]
	var combo: String = info["combo"]
	health.apply_damage(amount)
	Game.damage_number(global_position, amount, color, info["crit"])
	Game.hit_fx(global_position + Vector3.UP * 0.5, el)
	if combo != "":
		Game.float_text(global_position + Vector3.UP * 2.0, combo + "!", color.lerp(Color.WHITE, 0.3), 54, 1.1)
		Game.hitstop(0.09)
		Game.shake(0.45)
		Audio.play("shatter" if combo == "SHATTER" else "combo")
	if info.get("froze", false):
		Game.float_text(global_position + Vector3.UP * 1.9, "FROZEN", E.COLORS[E.COMET], 34)
		Audio.play("freeze")
	if info.get("explode", false):
		Game.explosion(global_position, 3.0, 16.0, E.PHYSICAL, self, E.COLORS[E.SUN])
	if info.get("spread_burn", false):
		for e in Game.enemies():
			if e != self and e.global_position.distance_to(global_position) < 3.5:
				e.status.add("burning", 3.0)
	_flash_t = 0.1
	_hp_show_t = 3.0
	var kb: float = info["knockback"]
	if status.has("frozen"):
		kb *= 0.2
	var dir: Vector3 = info["dir"]
	knockback += dir * kb / (1.0 + poise * 0.05)
	var stagger: bool = info["stagger"]
	if not dead and stagger and (poise <= 0.0 or combo != "" or amount >= poise):
		_on_stagger()


func take_status_damage(amount: float, color: Color) -> void:
	if dead:
		return
	health.apply_damage(amount)
	Game.float_text(global_position + Vector3(randf_range(-0.3, 0.3), 1.3, 0), str(roundi(amount)), color, 24, 0.5)
	_hp_show_t = 3.0


func _on_died() -> void:
	dead = true
	Audio.play("enemy_die")
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	status.clear()
	_ice.visible = false
	_hp_root.visible = false
	sprite.modulate = Color(1, 1, 1)
	sprite.speed_scale = 1.0
	_play_death()
	Game.burst(global_position + Vector3.UP * 0.4, Color(0.9, 0.3, 0.9), 22, 4.0, 0.08, 0.6, 1.0)
	Game.burst(global_position + Vector3.UP * 0.4, Color(0.05, 0.0, 0.08), 12, 2.5, 0.12, 0.7, 1.5, false)
	defeated.emit(self)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.2)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- visuals

func _update_visuals(delta: float) -> void:
	sprite.flip_h = face_dir < 0.0
	var tint := Color(1, 1, 1)
	var flick := int(state_time * 14.0) % 2 == 0
	if status.has("frozen"):
		tint = Color(0.6, 0.85, 1.15)
	elif status.has("chilled"):
		tint = Color(0.75, 0.9, 1.1)
	elif status.has("burning"):
		tint = Color(1.25, 0.75, 0.5) if flick else Color(1.1, 0.85, 0.7)
	elif status.has("shocked"):
		tint = Color(1.0, 0.8, 1.3) if flick else Color(1, 1, 1)
	if status.has("hexed"):
		tint = tint * Color(1.05, 0.75, 1.05)
	if _flash_t > 0.0:
		tint = Color(3.0, 3.0, 3.0)
	sprite.modulate = tint
	sprite.speed_scale = 0.0 if status.has("frozen") else 1.0
	_ice.visible = status.has("frozen")
	visual.scale = visual.scale.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))

	_fx_t -= delta
	if _fx_t <= 0.0:
		_fx_t = 0.15
		var p := global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 0.9), 0)
		if status.has("burning"):
			Game.burst(p, Color(1.0, 0.6, 0.2), 3, 1.0, 0.06, 0.5, 2.0)
		if status.has("shocked"):
			Game.burst(p, Color(0.85, 0.6, 1.0), 3, 3.0, 0.05, 0.15, 0.0)
		if status.has("hexed"):
			Game.burst(p, Color(0.95, 0.3, 0.9), 2, 0.6, 0.06, 0.6, 1.0)
		if status.has("bound"):
			Game.burst(global_position + Vector3.UP * 0.1, Color(0.5, 0.45, 1.0), 2, 0.5, 0.06, 0.4, 0.0)

	var show: bool = _hp_show_t > 0.0 and health.ratio() < 1.0
	_hp_root.visible = show
	if show:
		var r: float = health.ratio()
		_hp_fill.scale.x = maxf(r, 0.001)
		_hp_fill.position.x = -0.4 * (1.0 - r)


func _build_hp_bar() -> void:
	var ys := HD2D.sprite_y_scale()
	_hp_root = Node3D.new()
	_hp_root.position = Vector3(0, sprite_height * ys + 0.15, 0)
	add_child(_hp_root)
	var bg := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(0.86, 0.13)
	bg.mesh = bq
	bg.material_override = _flat_mat(Color(0.05, 0.03, 0.1, 0.9), 0)
	bg.scale.y = ys
	_hp_root.add_child(bg)
	_hp_fill = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.8, 0.07)
	_hp_fill.mesh = fq
	_hp_fill.material_override = _flat_mat(Color(0.92, 0.32, 0.4), 1)
	_hp_fill.scale.y = ys
	_hp_root.add_child(_hp_fill)
	_hp_root.visible = false


func _flat_mat(c: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = priority
	m.disable_fog = true
	return m


func _build_ice() -> void:
	_ice = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(radius * 2.4, sprite_height * 1.05, radius * 2.0)
	_ice.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.9, 1.0, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.4, 0.75, 1.0)
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.1
	_ice.material_override = m
	_ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ice.position.y = sprite_height * 0.5
	_ice.visible = false
	add_child(_ice)
