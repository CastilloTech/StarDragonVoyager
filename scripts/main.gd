extends Node3D
## Encounter director for the combat test scene: builds the world, runs the
## Voidling waves, and handles victory, knockout and restart.
##
## Command-line options (after `--`):
##   --touch               force touch controls on desktop
##   --screenshot=PATH     save a screenshot after a few seconds and quit (with --demo to auto-fight)
##   --export-sprites      write the generated sprite sheets to assets/generated/ and quit

const Arena := preload("res://scripts/world/harbor_arena.gd")
const Player := preload("res://scripts/player/player_controller.gd")
const Voidling := preload("res://scripts/enemies/voidling.gd")
const Marine := preload("res://scripts/enemies/admiralty_marine.gd")
const Rifleman := preload("res://scripts/enemies/admiralty_rifleman.gd")
const Dragon := preload("res://scripts/dragon/dragon_companion.gd")
const CameraController := preload("res://scripts/render/camera_controller.gd")
const PostFX := preload("res://scripts/render/post_fx.gd")
const HUD := preload("res://scripts/ui/combat_hud.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")

## Each wave lists enemy types, spawned in this order.
const WAVES := [
	["voidling", "voidling", "voidling"],
	["marine", "voidling", "marine", "voidling"],
	["rifleman", "marine", "rifleman", "voidling", "voidling"],
	["marine", "marine", "rifleman", "rifleman", "voidling", "voidling"],
]

var arena: Node3D
var player: Node3D
var dragon: Node3D
var camera: Camera3D
var hud: CanvasLayer
var pause_menu: CanvasLayer

var wave := 0
var _spawn_queue: Array = []
var _spawn_cd := 0.0
var _next_wave_t := 1.5
var _wave_active := false
var _finished := false

var _shot_path := ""
var _demo := false
var _clicktest := false
var _meleetest := false
var _dummy: Node3D
var _clicks_sent := 0
var _shot_frame := 182
var _frames := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--export-sprites":
			SpriteFactory.export_sheets(ProjectSettings.globalize_path("res://assets/generated"))
			set_process(false)
			get_tree().quit()
			return
		if arg.begins_with("--screenshot="):
			_shot_path = arg.trim_prefix("--screenshot=")
		if arg == "--demo":
			_demo = true
		if arg == "--clicktest":
			_clicktest = true
		if arg == "--meleetest":
			_meleetest = true
		if arg.begins_with("--wave="):
			wave = clampi(int(arg.trim_prefix("--wave=")) - 1, 0, WAVES.size() - 1)
		if arg.begins_with("--shot-frame="):
			_shot_frame = int(arg.trim_prefix("--shot-frame="))
	Game.reset(self)
	Audio.start_ambience()
	_build_environment()
	arena = Arena.new()
	add_child(arena)
	player = Player.new()
	player.position = arena.player_spawn
	add_child(player)
	Game.player = player
	player.knocked_out.connect(_on_player_ko)
	dragon = Dragon.new()
	dragon.position = arena.player_spawn + Vector3(-1.4, 0, 0.6)
	add_child(dragon)
	Game.dragon = dragon
	camera = CameraController.new()
	add_child(camera)
	camera.target = player
	camera.bounds = arena.camera_bounds
	camera.snap_to_target()
	Game.camera = camera
	add_child(PostFX.new())
	hud = HUD.new()
	add_child(hud)
	Game.hud = hud
	var touch := TouchControls.new()
	add_child(touch)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.restart_requested.connect(restart)
	touch.pause_pressed.connect(pause_menu.toggle)
	var testing := _shot_path != "" or _demo or _clicktest or _meleetest or "--dashtest" in OS.get_cmdline_user_args()
	if not Game.tutorial_done and not testing:
		_run_tutorial()


## First-time tips, one at a time, during the opening wave.
func _run_tutorial() -> void:
	var tips: Array
	if Game.touch_controls:
		tips = [
			"Left thumb: move   ·   ATTACK: tap to slash, hold to charge",
			"Big element button: cast   ·   small one: switch element",
			"DASH: dodge through attacks (you can't be hit mid-dash)",
			"Dragon button: Nova's Comet Shower",
		]
	else:
		tips = [
			"Left-click to attack   ·   hold it to charge a heavy blow",
			"Right-click casts your element's spell   ·   Q / E or 1–5 switch elements",
			"Space: dash where you're moving  ·  no direction = hop back  ·  invulnerable mid-dash",
			"F: Nova rains a Comet Shower where you aim",
		]
	await get_tree().create_timer(0.6).timeout
	for tip in tips:
		if not is_inside_tree():
			return
		hud.show_hint(tip, 3.6)
		await get_tree().create_timer(4.4).timeout
	Game.tutorial_done = true
	Game.save_settings()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.34, 0.62)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.11, 0.34)
	env.fog_density = 0.003
	env.fog_height = -1.5
	env.fog_height_density = 0.22
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 0.6
	add_child(sun)


func _process(delta: float) -> void:
	_frames += 1
	if _demo:
		_demo_tick()
	if _clicktest:
		_clicktest_tick()
	if _meleetest:
		_meleetest_tick()
		return
	if "--dashtest" in OS.get_cmdline_user_args():
		_dashtest_tick()
		return
	if _shot_path != "":
		_screenshot_tick()
	if _finished:
		return
	if _next_wave_t > 0.0:
		_next_wave_t -= delta
		if _next_wave_t <= 0.0:
			_start_wave()
	if not _spawn_queue.is_empty():
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_cd = 0.35
			_spawn(_spawn_queue.pop_back())
	elif _wave_active and Game.enemies().is_empty():
		_wave_active = false
		# Last kill of the wave: a small zoom punch.
		if camera:
			camera.punch(0.05)
		if wave >= WAVES.size():
			_finished = true
			hud.show_message("Harbor Secured", -1.0, "The Admiralty Commander arrives in a later phase.  Restart from the pause menu (or R).")
		else:
			hud.show_message("Wave Cleared", 1.2)
			_next_wave_t = 2.4
	hud.set_encounter(wave, WAVES.size(), Game.enemies().size() + _spawn_queue.size())


func _start_wave() -> void:
	wave += 1
	hud.show_message("Wave %d" % wave, 1.2)
	Audio.play("wave", -4.0, 0.0, "UI")
	_spawn_queue.clear()
	var list: Array = WAVES[wave - 1].duplicate()
	list.reverse()   # pop_back() spawns them in listed order
	_spawn_queue.append_array(list)
	_spawn_cd = 0.3
	_wave_active = true


func _spawn(kind: String) -> void:
	var candidates := []
	for s in arena.enemy_spawns:
		if (s as Vector3).distance_to(player.global_position) > 5.0:
			candidates.append(s)
	if candidates.is_empty():
		candidates = arena.enemy_spawns
	var pos: Vector3 = candidates.pick_random()
	pos += Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
	var e: Node3D
	match kind:
		"marine":
			e = Marine.new()
		"rifleman":
			e = Rifleman.new()
		_:
			e = Voidling.new()
	e.position = pos
	add_child(e)
	e.defeated.connect(dragon.on_enemy_defeated)


func _on_player_ko() -> void:
	_finished = true
	hud.show_message("Knocked Out", -1.0, "Restart from the pause menu (or R).")


func restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	# R only restarts from the victory / knockout screen (no accidental restarts mid-fight).
	if event.is_action_pressed("restart") and _finished:
		restart()


func _notification(what: int) -> void:
	# Android back button / app sent to background: pause the game.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if pause_menu and not pause_menu.visible:
			pause_menu.toggle()


# ---------------------------------------------------------------- tooling

## Scripted smoke test: casts every element, combos, charges and dodges.
func _demo_tick() -> void:
	var casts := {150: 0, 210: 1, 240: 1, 290: 2, 340: 3, 420: 4, 470: 0}
	if casts.has(_frames):
		player.abilities.element = casts[_frames]
		player.abilities.cooldowns[casts[_frames]] = 0.0
		player.mana = player.max_mana
		player.abilities.cast_ability()
	if _frames in [175, 190, 205, 380, 395]:
		player.combat.request_attack()
	if _frames == 500:
		player.combat.begin_charge()
	if _frames == 545:
		player.combat.release_charge()
	if _frames == 580:
		player.try_dodge()
	if _frames == 300:
		dragon.request_special()


## Sends real left-clicks through Godot's input pipeline (like a player mashing
## attack) and reports how many became swings.
func _clicktest_tick() -> void:
	if _frames > 120 and _frames < 1320 and _frames % 11 == 0:
		_send_click(true)
		_clicks_sent += 1
	if _frames > 120 and _frames < 1320 and _frames % 11 == 3:
		_send_click(false)
	if _frames == 1400:
		var c = player.combat
		print("CLICKTEST sent=%d requests=%d swings=%d alive=%s hp=%d wave=%d" % [_clicks_sent, c.stat_requests, c.stat_swings, player.is_alive(), player.health.current, wave])
		get_tree().quit()


## Melee reliability test: a dummy stands 1.6 m in front of the captain; the
## test plays 3-hit combos with a pause between them and counts connecting swings.
func _meleetest_tick() -> void:
	if _frames == 30:
		const Dummy := preload("res://scripts/enemies/training_dummy.gd")
		_dummy = Dummy.new()
		_dummy.home = player.global_position + Vector3(1.6, 0, 0)
		_dummy.position = _dummy.home
		add_child(_dummy)
		dragon.process_mode = Node.PROCESS_MODE_DISABLED
	# Optional: point the mouse 35 degrees away from the dummy (sloppy aim).
	if "--aimoff" in OS.get_cmdline_user_args() and _dummy and camera:
		var to: Vector3 = _dummy.global_position - player.global_position
		var off := to.rotated(Vector3.UP, deg_to_rad(35.0))
		var mm := InputEventMouseMotion.new()
		mm.position = camera.unproject_position(player.global_position + off)
		mm.global_position = mm.position
		Input.parse_input_event(mm)
	# Three clicks ~0.18 s apart, then a 0.8 s pause; repeat.
	if _frames > 90 and _frames < 1290:
		var t := (_frames - 90) % 60
		if t == 0 or t == 11 or t == 22:
			_send_click(true)
		if t == 3 or t == 14 or t == 25:
			_send_click(false)
	if _frames == 1350:
		print("MELEETEST swings=%d hits=%d" % [player.combat.stat_swings, _dummy.hits_taken])
		get_tree().quit()


## Measures each dash type: forward (move = aim), side (move across aim), back (no input).
var _dash_start := Vector3.ZERO
func _dashtest_tick() -> void:
	var plan := {60: ["forward", "move_right"], 120: ["side", "move_up"], 180: ["back", ""]}
	for f in plan:
		if _frames == f:
			player.lock_aim(Vector3.RIGHT, 2.0)
			player.global_position = Vector3(0, 0, 1)
			player.velocity = Vector3.ZERO
			player.stamina = player.max_stamina
			_dash_start = player.global_position
			var act: String = plan[f][1]
			if act != "":
				Input.action_press(act)
		if _frames == f + 2:
			player.request_dodge()
		if _frames == f + 4:
			for a in ["move_right", "move_up"]:
				Input.action_release(a)
		if _frames == f + 40:
			var moved: Vector3 = player.global_position - _dash_start
			print("DASHTEST %s kind=%s distance=%.2f" % [plan[f][0], player._dash_kind, moved.length()])
	if _frames == 240:
		get_tree().quit()


func _send_click(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = get_viewport().get_visible_rect().size * 0.5
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _screenshot_tick() -> void:
	if _frames == _shot_frame:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		get_tree().quit()
