extends Node3D
## A dropped item: a spinning gem in its grade's color with a light beam (rarer =
## taller, brighter). Walk near it to pick it up; it drifts toward you when close.

const Items := preload("res://scripts/core/items.gd")

var luck := 0
var grade := -1
var _picked := false
var _t := 0.0
var _gem: MeshInstance3D
var _col := Color.WHITE


func _ready() -> void:
	if grade < 0:
		grade = Items.roll_grade(luck)
	_col = Items.GRADE_COLORS[grade]
	_gem = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.28, 0.28, 0.28)
	_gem.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = _col
	m.emission_enabled = true
	m.emission = _col
	m.emission_energy_multiplier = 1.5 + grade * 0.6
	_gem.material_override = m
	_gem.rotation = Vector3(PI / 4, 0, PI / 4)
	_gem.position.y = 0.45
	add_child(_gem)
	# Light beam: taller for better grades.
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var h := 1.2 + grade * 0.7
	bm.size = Vector3(0.12, h, 0.12)
	beam.mesh = bm
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(_col.r, _col.g, _col.b, 0.35 + grade * 0.08)
	beam_mat.disable_fog = true
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = h * 0.5
	add_child(beam)
	add_child(Game.make_blob_shadow(0.25))
	Game.burst(global_position + Vector3.UP * 0.4, _col, 10 + grade * 4, 3.0, 0.07, 0.5, -3.0)
	if grade >= 3:
		Game.float_text(global_position + Vector3.UP * 1.6, Items.GRADES[grade] + "!", _col, 28, 1.0)
		Audio.play("charge_ready", -2.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_gem.rotation.y += delta * 2.5
	_gem.position.y = 0.45 + sin(_t * 3.0) * 0.08
	var p := Game.player
	if _picked or p == null or not is_instance_valid(p) or not p.is_alive() or _t < 0.4:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d < 2.2:
		global_position += to.normalized() * minf(d, 6.0 * delta)   # drift toward the captain
	if d < 0.7:
		_pick_up()


func _pick_up() -> void:
	_picked = true
	var item: Dictionary = Progress.add_random_item(0, grade)
	var slot_text: String = Items.SLOT_NAMES[item["slot"]]
	Game.float_text(global_position + Vector3.UP * 1.4, "%s (%s)" % [item["name"], slot_text], _col, 24, 1.2)
	Game.burst(global_position + Vector3.UP * 0.5, _col, 14, 3.0, 0.07, 0.4, 0.0)
	Audio.play("ui", 0.0, 0.0, "UI", 1.0 + grade * 0.15)
	queue_free()
