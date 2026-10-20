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
const CameraController := preload("res://scripts/render/camera_controller.gd")
const PostFX := preload("res://scripts/render/post_fx.gd")
const HUD := preload("res://scripts/ui/combat_hud.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const SpriteFactory := preload("res://scripts/render/sprite_factory.gd")

const WAVES := [3, 5, 7]

var arena: Node3D
var player: Node3D
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
var _shot_frame := 182
var _frames := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--export-sprites":
			SpriteFactory.export_sheets(ProjectSettings.globalize_path("res://assets/generated"))
			get_tree().quit()
			return
		if arg.begins_with("--screenshot="):
			_shot_path = arg.trim_prefix("--screenshot=")
		if arg == "--demo":
			_demo = true
		if arg.begins_with("--shot-frame="):
			_shot_frame = int(arg.trim_prefix("--shot-frame="))
	Game.reset(self)
	_build_environment()
	arena = Arena.new()
	add_child(arena)
	player = Player.new()
	player.position = arena.player_spawn
	add_child(player)
	Game.player = player
	player.knocked_out.connect(_on_player_ko)
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
	_spawn_queue.clear()
	for i in WAVES[wave - 1]:
		_spawn_queue.append(i)
	_spawn_cd = 0.3
	_wave_active = true


func _spawn(_index: int) -> void:
	var candidates := []
	for s in arena.enemy_spawns:
		if (s as Vector3).distance_to(player.global_position) > 5.0:
			candidates.append(s)
	if candidates.is_empty():
		candidates = arena.enemy_spawns
	var pos: Vector3 = candidates.pick_random()
	pos += Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
	var e := Voidling.new()
	e.position = pos
	add_child(e)


func _on_player_ko() -> void:
	_finished = true
	hud.show_message("Knocked Out", -1.0, "Restart from the pause menu (or R).")


func restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
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


func _screenshot_tick() -> void:
	if _frames == _shot_frame:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		get_tree().quit()
