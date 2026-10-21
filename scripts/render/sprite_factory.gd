extends RefCounted
## SpriteFactory: generates PLACEHOLDER pixel-art sprite sheets at startup.
##
## Characters are drawn by a small pose rig (limbs, ellipses, auto outline and a
## top-left light pass), so every animation has real frames with stable
## proportions and feet that never drift. Swap in hand-drawn sheets later by
## keeping the same layout (export the generated ones with `-- --export-sprites`):
##   Pirate   48x64 frames, feet at (24, 60). Rows: each animation x [down, up, side].
##   Voidling 40x32 frames, feet at (20, 28). Rows: each animation (faces right).

const PIRATE_FRAME := Vector2i(48, 64)
const PIRATE_FEET_FROM_CENTER := 28.0
const VOIDLING_FRAME := Vector2i(40, 32)
const VOIDLING_FEET_FROM_CENTER := 12.0
const FACINGS := ["down", "up", "side"]

## animation: [frame count, fps, loops, strike frame (-1 = none)]
const PIRATE_ANIMS := {
	"idle": [4, 5.0, true, -1],
	"walk": [6, 9.0, true, -1],
	"run": [6, 13.0, true, -1],
	"dodge": [4, 20.0, false, -1],
	"sidestep": [3, 16.0, false, -1],
	"backdash": [3, 15.0, false, -1],
	"attack1": [4, 16.0, false, 1],
	"attack2": [4, 16.0, false, 1],
	"attack3": [5, 14.0, false, 2],
	"charge": [2, 8.0, true, -1],
	"charged": [5, 14.0, false, 2],
	"cast": [6, 20.0, false, 1],
	"hit": [5, 16.0, false, -1],
	"ko": [4, 6.0, false, -1],
}
const VOIDLING_ANIMS := {
	"idle": [4, 6.0, true, -1],
	"move": [4, 12.0, true, -1],
	"windup": [2, 8.0, true, -1],
	"lunge": [2, 10.0, true, -1],
	"hit": [2, 10.0, false, -1],
	"death": [5, 12.0, false, -1],
}

## Enemy humanoids (Admiralty) reuse the pirate rig with other palettes/outfits.
## Frames 48x64, feet at (24, 60), rows: each animation x [down, up, side].
const HUMANOID_ANIMS := {
	"idle": [4, 5.0, true, -1],
	"run": [6, 11.0, true, -1],
	"windup": [2, 8.0, true, -1],
	"slash": [4, 16.0, false, 1],
	"aim": [2, 4.0, true, -1],
	"shoot": [3, 12.0, false, 0],
	"hit": [2, 8.0, false, -1],
	"ko": [3, 6.0, false, -1],
}
## Dragon companion: 48x40 frames, centered on the body, faces right. One row per animation.
const DRAGON_FRAME := Vector2i(48, 40)
const DRAGON_ANIMS := {
	"hover": [6, 10.0, true, -1],
	"fly": [6, 15.0, true, -1],
	"attack": [4, 12.0, false, 2],
	"special": [4, 8.0, false, -1],
	"hit": [2, 8.0, false, -1],
	"ko": [3, 6.0, false, -1],
}
const DEFAULT_OUTFIT :={"hat": "tricorn", "weapon": "cutlass", "plume": true, "ponytail": true, "gauntlet": true, "crossbelt": false}

static var _cache := {}
static var _pal_override := {}
static var _outfit := {}


static func _o(key: String) -> Variant:
	return _outfit.get(key, DEFAULT_OUTFIT[key])


## Notes written by tools/import_sprites.py next to an imported sheet:
## {"frame": [w, h], "feet": [x, y], ...}. Empty when there is no imported sheet.
static func _sheet_meta(sheet_name: String) -> Dictionary:
	var key := "meta_" + sheet_name
	if _cache.has(key):
		return _cache[key]
	var meta := {}
	var path := "res://assets/sprites/%s_sheet.json" % sheet_name
	if FileAccess.file_exists(path) and ResourceLoader.exists("res://assets/sprites/%s_sheet.png" % sheet_name):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			meta = parsed
	_cache[key] = meta
	return meta


static func pirate_frame_size() -> Vector2i:
	var meta := _sheet_meta("pirate")
	if meta.has("frame"):
		return Vector2i(int(meta["frame"][0]), int(meta["frame"][1]))
	return PIRATE_FRAME


## Art pixels from the frame center down to the feet (positions the sprite on the ground).
static func pirate_feet_from_center() -> float:
	var meta := _sheet_meta("pirate")
	if meta.has("feet") and meta.has("frame"):
		return float(meta["feet"][1]) - float(meta["frame"][1]) * 0.5
	return PIRATE_FEET_FROM_CENTER


## Hand-made art wins: res://assets/sprites/<sheet_name>_sheet.png replaces the generated
## sheet if its size matches the layout (see docs/SPRITE_STYLE_PROMPT.md). Imported
## sheets may use a bigger frame, declared in <sheet_name>_sheet.json.
static func _override_sheet(sheet_name: String, anims: Dictionary, frame: Vector2i, rows_per_anim: int) -> Image:
	var path := "res://assets/sprites/%s_sheet.png" % sheet_name
	if not ResourceLoader.exists(path):
		return null
	var meta := _sheet_meta(sheet_name)
	if meta.has("frame"):
		frame = Vector2i(int(meta["frame"][0]), int(meta["frame"][1]))
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var max_frames := 0
	for a in anims:
		max_frames = maxi(max_frames, int(anims[a][0]))
	var expected := Vector2i(max_frames * frame.x, anims.size() * rows_per_anim * frame.y)
	if img.get_size() != expected:
		push_warning("%s is %s but should be %s - using placeholder art instead." % [path, img.get_size(), expected])
		return null
	return img


# ================================================================ public API

static func humanoid_frames(kind: String) -> SpriteFrames:
	var key := "humanoid_" + kind
	if not _cache.has(key):
		_cache[key] = _build_frames(humanoid_sheet_image(kind), HUMANOID_ANIMS, PIRATE_FRAME, FACINGS)
	return _cache[key]


static func dragon_frames() -> SpriteFrames:
	if not _cache.has("dragon"):
		_cache["dragon"] = _build_frames(dragon_sheet_image(), DRAGON_ANIMS, DRAGON_FRAME, [""])
	return _cache["dragon"]


## Head close-up for the HUD portrait.
static func dragon_portrait() -> Texture2D:
	if not _cache.has("dragon_portrait"):
		var at := AtlasTexture.new()
		at.atlas = ImageTexture.create_from_image(dragon_sheet_image())
		at.region = Rect2(24, 1, 20, 20)
		_cache["dragon_portrait"] = at
	return _cache["dragon_portrait"]


static func dragon_strike_time(anim: String) -> float:
	var spec: Array = DRAGON_ANIMS[anim]
	return maxf(0.0, float(spec[3])) / float(spec[1])


static func dragon_duration(anim: String) -> float:
	var spec: Array = DRAGON_ANIMS[anim]
	return float(spec[0]) / float(spec[1])


static func humanoid_strike_time(anim: String) -> float:
	var spec: Array = HUMANOID_ANIMS[anim]
	return maxf(0.0, float(spec[3])) / float(spec[1])


static func humanoid_duration(anim: String) -> float:
	var spec: Array = HUMANOID_ANIMS[anim]
	return float(spec[0]) / float(spec[1])

static func anim_duration(anim: String) -> float:
	var spec: Array = PIRATE_ANIMS[anim]
	return float(spec[0]) / float(spec[1])


## Seconds from animation start until the strike frame (when damage lands).
static func strike_time(anim: String) -> float:
	var spec: Array = PIRATE_ANIMS[anim]
	return maxf(0.0, float(spec[3])) / float(spec[1])


static func pirate_frames() -> SpriteFrames:
	if not _cache.has("pirate"):
		_cache["pirate"] = _build_frames(pirate_sheet_image(), PIRATE_ANIMS, pirate_frame_size(), FACINGS)
	return _cache["pirate"]


static func voidling_frames() -> SpriteFrames:
	if not _cache.has("voidling"):
		_cache["voidling"] = _build_frames(voidling_sheet_image(), VOIDLING_ANIMS, VOIDLING_FRAME, [""])
	return _cache["voidling"]


static func element_icon(element: int) -> ImageTexture:
	var key := "icon_%d" % element
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_draw_element_icon(element))
	return _cache[key]


static func export_sheets(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	pirate_sheet_image().save_png(dir.path_join("pirate_sheet.png"))
	voidling_sheet_image().save_png(dir.path_join("voidling_sheet.png"))
	for kind in ["marine", "rifleman"]:
		humanoid_sheet_image(kind).save_png(dir.path_join("%s_sheet.png" % kind))
	dragon_sheet_image().save_png(dir.path_join("dragon_sheet.png"))
	for i in 5:
		_draw_element_icon(i).save_png(dir.path_join("icon_element_%d.png" % i))


# ================================================================ sheet assembly

static func _build_frames(sheet_img: Image, anims: Dictionary, frame: Vector2i, facings: Array) -> SpriteFrames:
	var sheet := ImageTexture.create_from_image(sheet_img)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var row := 0
	for anim in anims:
		var spec: Array = anims[anim]
		for facing in facings:
			var anim_name: String = anim if facing == "" else "%s_%s" % [anim, facing]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, spec[1])
			frames.set_animation_loop(anim_name, spec[2])
			for i in int(spec[0]):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(i * frame.x, row * frame.y, frame.x, frame.y)
				frames.add_frame(anim_name, at)
			row += 1
	return frames


static func pirate_sheet_image() -> Image:
	if _cache.has("pirate_img"):
		return _cache["pirate_img"]
	var custom := _override_sheet("pirate", PIRATE_ANIMS, PIRATE_FRAME, FACINGS.size())
	if custom:
		_cache["pirate_img"] = custom
		return custom
	var max_frames := 0
	for a in PIRATE_ANIMS:
		max_frames = maxi(max_frames, int(PIRATE_ANIMS[a][0]))
	var rows := PIRATE_ANIMS.size() * FACINGS.size()
	var sheet := Image.create_empty(max_frames * PIRATE_FRAME.x, rows * PIRATE_FRAME.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var row := 0
	for anim in PIRATE_ANIMS:
		var n := int(PIRATE_ANIMS[anim][0])
		for facing in FACINGS:
			for i in n:
				var img := _draw_pirate_frame(anim, i, n, facing)
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, PIRATE_FRAME), Vector2i(i * PIRATE_FRAME.x, row * PIRATE_FRAME.y))
			row += 1
	_cache["pirate_img"] = sheet
	return sheet


static func humanoid_sheet_image(kind: String) -> Image:
	var key := "humanoid_img_" + kind
	if _cache.has(key):
		return _cache[key]
	var custom := _override_sheet(kind, HUMANOID_ANIMS, PIRATE_FRAME, FACINGS.size())
	if custom:
		_cache[key] = custom
		return custom
	_pal_override = _humanoid_palette(kind)
	_outfit = _humanoid_outfit(kind)
	var max_frames := 0
	for a in HUMANOID_ANIMS:
		max_frames = maxi(max_frames, int(HUMANOID_ANIMS[a][0]))
	var rows := HUMANOID_ANIMS.size() * FACINGS.size()
	var sheet := Image.create_empty(max_frames * PIRATE_FRAME.x, rows * PIRATE_FRAME.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var row := 0
	for anim in HUMANOID_ANIMS:
		var n := int(HUMANOID_ANIMS[anim][0])
		for facing in FACINGS:
			for i in n:
				var pose := _humanoid_pose(anim, i, n)
				var cv := Canvas.new(PIRATE_FRAME.x, PIRATE_FRAME.y)
				if anim == "ko" and i == n - 1:
					_draw_ko_lying(cv, pose)
				elif facing == "side":
					_draw_pirate_side(cv, pose)
				else:
					_draw_pirate_front(cv, pose, facing == "up")
				cv.shade_and_outline(_pal()["outline"])
				sheet.blit_rect(cv.img, Rect2i(Vector2i.ZERO, PIRATE_FRAME), Vector2i(i * PIRATE_FRAME.x, row * PIRATE_FRAME.y))
			row += 1
	_pal_override = {}
	_outfit = {}
	_cache[key] = sheet
	return sheet


static func _humanoid_palette(kind: String) -> Dictionary:
	var p := {
		"outline": Color("101420"),
		"brass": Color("d8b050"), "brass_dk": Color("8e6c26"),
		"skin": Color("e8b896"), "skin_dk": Color("b88066"),
		"hair": Color("2a2420"), "eye": Color("101018"), "hat": Color("1d2546"),
		"plume": Color("ffffff"), "boots": Color("1a1a24"), "boots_lt": Color("2c2c3a"),
		"crystal": Color("ff5a5a"),
	}
	if kind == "rifleman":
		p.merge({
			"coat": Color("2c3d6e"), "coat_dk": Color("1e2a4e"), "coat_lt": Color("3e5390"),
			"shirt": Color("d8dce6"), "sash": Color("d8dce6"),
			"pants": Color("c8ccd8"), "pants_dk": Color("9ea4b4"),
			"steel": Color("b0b8c8"), "steel_dk": Color("6a4a34"), "muzzle": Color("d080ff"),
		})
	else:
		p.merge({
			"coat": Color("d8dce6"), "coat_dk": Color("9ea6b8"), "coat_lt": Color("eef1f7"),
			"shirt": Color("2a3560"), "sash": Color("b8303e"),
			"pants": Color("2a3560"), "pants_dk": Color("1c2444"),
			"steel": Color("b4f6ff"), "steel_dk": Color("3cb4ff"), "muzzle": Color("ffffff"),
		})
	return p


static func _humanoid_outfit(kind: String) -> Dictionary:
	return {
		"hat": "shako", "plume": false, "ponytail": false, "gauntlet": false,
		"weapon": "rifle" if kind == "rifleman" else "saber",
		"crossbelt": kind == "rifleman",
	}


static func _humanoid_pose(anim: String, i: int, n: int) -> Dictionary:
	match anim:
		"idle", "hit", "ko":
			return _pirate_pose(anim, i, n)
		"run":
			var p := _pirate_pose("run", i, n)
			p["lean"] = 1.0
			p["coat"] = 1.0
			return p
		"slash":
			return _pirate_pose("attack1", i, n)
	var p := _pirate_pose("idle", 0, 4)
	match anim:
		"windup":
			p["arm_f"] = [150.0, 162.0][i]
			p["elbow_f"] = 20.0
			p["sword"] = p["arm_f"] + 20.0
			p["crouch"] = [1.0, 2.0][i]
			p["lean"] = -1.0
			p["lf"] = 2.0
			p["lb"] = -2.0
			p["coat"] = 1.0
		"aim":
			p["arm_f"] = 88.0
			p["elbow_f"] = 0.0
			p["sword"] = 90.0
			p["arm_b"] = 75.0
			p["elbow_b"] = 15.0
			p["lean"] = -1.0
			p["bob"] = [0.0, 1.0][i]
			p["lf"] = 2.0
			p["lb"] = -2.0
		"shoot":
			p["arm_f"] = [100.0, 92.0, 88.0][i]
			p["elbow_f"] = 0.0
			p["sword"] = p["arm_f"]
			p["arm_b"] = [82.0, 78.0, 75.0][i]
			p["elbow_b"] = 15.0
			p["lean"] = [-3.0, -2.0, -1.0][i]
			p["lf"] = 2.0
			p["lb"] = -2.0
	return p


static func voidling_sheet_image() -> Image:
	if _cache.has("voidling_img"):
		return _cache["voidling_img"]
	var custom := _override_sheet("voidling", VOIDLING_ANIMS, VOIDLING_FRAME, 1)
	if custom:
		_cache["voidling_img"] = custom
		return custom
	var max_frames := 0
	for a in VOIDLING_ANIMS:
		max_frames = maxi(max_frames, int(VOIDLING_ANIMS[a][0]))
	var sheet := Image.create_empty(max_frames * VOIDLING_FRAME.x, VOIDLING_ANIMS.size() * VOIDLING_FRAME.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var row := 0
	for anim in VOIDLING_ANIMS:
		var n := int(VOIDLING_ANIMS[anim][0])
		for i in n:
			var img := _draw_voidling_frame(anim, i, n)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, VOIDLING_FRAME), Vector2i(i * VOIDLING_FRAME.x, row * VOIDLING_FRAME.y))
		row += 1
	_cache["voidling_img"] = sheet
	return sheet


# ================================================================ canvas

class Canvas:
	var img: Image
	var w: int
	var h: int

	func _init(width: int, height: int) -> void:
		w = width
		h = height
		img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

	func px(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			img.set_pixel(x, y, c)

	func pxv(p: Vector2, c: Color) -> void:
		px(floori(p.x), floori(p.y), c)

	func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
		for j in rh:
			for i in rw:
				px(x + i, y + j, c)

	func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
		if rx <= 0.0 or ry <= 0.0:
			return
		for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 1):
			for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 1):
				var dx := (x + 0.5 - cx) / rx
				var dy := (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0:
					px(x, y, c)

	func line(a: Vector2, b: Vector2, width: float, c: Color) -> void:
		var steps := int(ceil(a.distance_to(b) * 2.0)) + 1
		var r := width * 0.5
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			for y in range(floori(p.y - r), ceili(p.y + r) + 1):
				for x in range(floori(p.x - r), ceili(p.x + r) + 1):
					if Vector2(x + 0.5, y + 0.5).distance_to(p) <= r + 0.2:
						px(x, y, c)

	func poly(points: PackedVector2Array, c: Color) -> void:
		var r := Rect2(points[0], Vector2.ZERO)
		for p in points:
			r = r.expand(p)
		for y in range(floori(r.position.y), ceili(r.end.y) + 1):
			for x in range(floori(r.position.x), ceili(r.end.x) + 1):
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
					px(x, y, c)

	## Light from the top-left on silhouette edges, then a 1px dark outline.
	func shade_and_outline(outline: Color) -> void:
		var src: Image = img.duplicate()
		for y in h:
			for x in w:
				var c := src.get_pixel(x, y)
				if c.a > 0.5:
					if not _solid(src, x, y - 1) or not _solid(src, x - 1, y):
						img.set_pixel(x, y, c.lightened(0.16))
					elif not _solid(src, x, y + 1) or not _solid(src, x + 1, y):
						img.set_pixel(x, y, c.darkened(0.14))
				elif _solid(src, x - 1, y) or _solid(src, x + 1, y) or _solid(src, x, y - 1) or _solid(src, x, y + 1):
					img.set_pixel(x, y, outline)

	func _solid(src: Image, x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return false
		return src.get_pixel(x, y).a > 0.5


# ================================================================ pirate

static func _pal() -> Dictionary:
	if not _pal_override.is_empty():
		return _pal_override
	if not _cache.has("pal"):
		_cache["pal"] = {
			"outline": Color("160e1e"),
			"coat": Color("8a2639"), "coat_dk": Color("5c172a"), "coat_lt": Color("a83448"),
			"brass": Color("e2aa42"), "brass_dk": Color("9c6c22"),
			"shirt": Color("ece2cc"), "sash": Color("2f7a96"),
			"skin": Color("f1c29b"), "skin_dk": Color("c98d6c"),
			"hair": Color("3a2030"), "eye": Color("120c18"),
			"hat": Color("272040"), "plume": Color("e8f4ff"),
			"boots": Color("3e2a22"), "boots_lt": Color("5e4232"),
			"pants": Color("2a2e4c"), "pants_dk": Color("1c1f36"),
			"steel": Color("d4dcec"), "steel_dk": Color("8792a8"),
			"crystal": Color("6ff0ff"),
		}
	return _cache["pal"]


static func _pirate_pose(anim: String, i: int, n: int) -> Dictionary:
	var p := {
		"bob": 0.0, "crouch": 0.0, "lean": 0.0, "lf": 0.0, "lb": 0.0, "lift_f": 0.0, "lift_b": 0.0,
		"arm_f": 10.0, "elbow_f": 15.0, "arm_b": -10.0, "elbow_b": 15.0, "sword": NAN, "coat": 0.0, "glow": 0.0,
	}
	var t := TAU * i / n
	match anim:
		"idle":
			p["bob"] = [0.0, 0.0, 1.0, 1.0][i]
			p["arm_f"] = 10.0 + [0.0, 1.0, 3.0, 1.0][i]
			p["coat"] = [0.0, 0.5, 1.0, 0.5][i]
		"walk":
			p["lf"] = 3.5 * sin(t)
			p["lb"] = -3.5 * sin(t)
			p["lift_f"] = maxf(0.0, 2.0 * cos(t))
			p["lift_b"] = maxf(0.0, -2.0 * cos(t))
			p["bob"] = 1.0 if absf(sin(t)) > 0.7 else 0.0
			p["arm_f"] = 10.0 - 16.0 * sin(t)
			p["arm_b"] = -10.0 + 16.0 * sin(t)
			p["coat"] = 1.0
		"run":
			p["lf"] = 6.5 * sin(t)
			p["lb"] = -6.5 * sin(t)
			p["lift_f"] = maxf(0.0, 4.0 * cos(t))
			p["lift_b"] = maxf(0.0, -4.0 * cos(t))
			p["bob"] = 1.0 if absf(sin(t)) > 0.7 else 0.0
			p["lean"] = 2.0
			p["arm_f"] = 15.0 - 40.0 * sin(t)
			p["elbow_f"] = 45.0
			p["arm_b"] = -15.0 + 40.0 * sin(t)
			p["elbow_b"] = 45.0
			p["coat"] = 3.0 + float(i % 2)
		"dodge":
			p["lean"] = [2.0, 5.0, 5.0, 2.0][i]
			p["crouch"] = [2.0, 4.0, 4.0, 1.0][i]
			p["lf"] = [3.0, 7.0, 6.0, 2.0][i]
			p["lb"] = [-3.0, -7.0, -7.0, -2.0][i]
			p["lift_b"] = [0.0, 3.0, 2.0, 0.0][i]
			p["arm_f"] = -50.0
			p["arm_b"] = -70.0
			p["coat"] = [3.0, 7.0, 7.0, 3.0][i]
		"sidestep":
			# Quick lateral hop: wide stance, both feet off the deck mid-step, arms out for balance.
			p["crouch"] = [1.0, 2.0, 1.0][i]
			p["bob"] = [0.0, -2.0, 0.0][i]
			p["lf"] = [3.0, 4.0, 1.5][i]
			p["lb"] = [-3.0, -4.0, -1.5][i]
			p["lift_f"] = [0.0, 2.0, 0.0][i]
			p["lift_b"] = [0.0, 2.0, 0.0][i]
			p["arm_f"] = [35.0, 50.0, 25.0][i]
			p["arm_b"] = [-35.0, -50.0, -25.0][i]
			p["coat"] = [1.0, 2.0, 1.0][i]
		"backdash":
			# Hop backward while still facing forward: lean back, feet kick forward.
			p["crouch"] = [2.0, 0.0, 2.0][i]
			p["bob"] = [0.0, -3.0, 0.0][i]
			p["lean"] = [-3.0, -4.0, -2.0][i]
			p["lf"] = [4.0, 5.0, 3.0][i]
			p["lb"] = [-2.0, 0.0, -3.0][i]
			p["lift_f"] = [0.0, 3.0, 0.0][i]
			p["lift_b"] = [0.0, 3.0, 0.0][i]
			p["arm_f"] = [30.0, 45.0, 20.0][i]
			p["arm_b"] = [-20.0, -40.0, -15.0][i]
			p["coat"] = [-1.0, 1.0, 0.0][i]
		"attack1":
			p["arm_f"] = [160.0, 95.0, 45.0, 25.0][i]
			p["elbow_f"] = [30.0, 0.0, 0.0, 10.0][i]
			p["sword"] = p["arm_f"] + [20.0, 10.0, 0.0, 10.0][i]
			p["lean"] = [-1.0, 2.0, 3.0, 1.0][i]
			p["lf"] = [0.0, 3.0, 4.0, 2.0][i]
			p["lb"] = -2.0
			p["coat"] = [0.0, 2.0, 3.0, 1.0][i]
		"attack2":
			p["arm_f"] = [-20.0, 60.0, 120.0, 100.0][i]
			p["elbow_f"] = [40.0, 0.0, 0.0, 20.0][i]
			p["sword"] = p["arm_f"] + [-30.0, 0.0, 10.0, 20.0][i]
			p["lean"] = [0.0, 2.0, 2.0, 1.0][i]
			p["lf"] = [1.0, 3.0, 4.0, 2.0][i]
			p["lb"] = -2.0
			p["coat"] = [1.0, 2.0, 3.0, 1.0][i]
		"attack3":
			p["arm_f"] = [30.0, 40.0, 90.0, 90.0, 40.0][i]
			p["elbow_f"] = [100.0, 110.0, 0.0, 0.0, 30.0][i]
			p["sword"] = [80.0, 90.0, 90.0, 90.0, 70.0][i]
			p["lean"] = [-2.0, -2.0, 5.0, 4.0, 1.0][i]
			p["crouch"] = [1.0, 2.0, 2.0, 1.0, 0.0][i]
			p["lf"] = [0.0, 0.0, 7.0, 7.0, 3.0][i]
			p["lb"] = [-1.0, -2.0, -5.0, -5.0, -2.0][i]
			p["coat"] = [0.0, 0.0, 5.0, 4.0, 1.0][i]
		"charge":
			p["crouch"] = 2.0 + float(i)
			p["lean"] = -1.0
			p["arm_f"] = -60.0
			p["elbow_f"] = 20.0
			p["sword"] = -110.0
			p["arm_b"] = 70.0
			p["elbow_b"] = 10.0
			p["glow"] = 1.0
			p["lf"] = 3.0
			p["lb"] = -3.0
			p["coat"] = 1.0 + float(i)
		"charged":
			p["arm_f"] = [175.0, 150.0, 70.0, 30.0, 20.0][i]
			p["elbow_f"] = [20.0, 10.0, 0.0, 0.0, 10.0][i]
			p["sword"] = p["arm_f"] + [10.0, 0.0, 0.0, 10.0, 15.0][i]
			p["lean"] = [-2.0, 0.0, 5.0, 4.0, 1.0][i]
			p["crouch"] = [1.0, 0.0, 3.0, 2.0, 0.0][i]
			p["lf"] = [0.0, 2.0, 7.0, 7.0, 3.0][i]
			p["lb"] = [-1.0, -2.0, -5.0, -5.0, -2.0][i]
			p["coat"] = [1.0, 2.0, 6.0, 5.0, 1.0][i]
			p["glow"] = [1.0, 1.0, 1.0, 0.5, 0.0][i]
		"cast":
			var ci := mini(int(float(i) / n * 4.0), 3)   # 4 key poses spread over n frames
			p["arm_b"] = [40.0, 90.0, 92.0, 60.0][ci]
			p["elbow_b"] = [70.0, 0.0, 0.0, 20.0][ci]
			p["arm_f"] = -15.0
			p["lean"] = [0.0, 2.0, 1.0, 0.0][ci]
			p["lf"] = 2.0
			p["lb"] = -2.0
			p["glow"] = [0.5, 1.0, 0.6, 0.2][ci]
			p["coat"] = [0.0, 2.0, 1.0, 0.0][ci]
		"hit":
			var hi := mini(int(float(i) / n * 3.0), 2)   # 3 key poses spread over n frames
			p["lean"] = [-3.0, -4.0, -1.0][hi]
			p["crouch"] = [1.0, 2.0, 0.0][hi]
			p["arm_f"] = [-30.0, -45.0, -10.0][hi]
			p["arm_b"] = [-35.0, -50.0, -15.0][hi]
			p["bob"] = [1.0, 1.0, 0.0][hi]
			p["coat"] = -1.0
		"ko":
			var ki := mini(i, 3)
			p["crouch"] = [3.0, 6.0, 9.0, 0.0][ki]
			p["lean"] = [1.0, 2.0, 4.0, 0.0][ki]
			p["arm_f"] = [5.0, 0.0, -10.0, 0.0][ki]
			p["arm_b"] = [-5.0, 0.0, 10.0, 0.0][ki]
	if is_nan(p["sword"]):
		p["sword"] = p["arm_f"] + p["elbow_f"] + 15.0
	return p


static func _draw_pirate_frame(anim: String, i: int, n: int, facing: String) -> Image:
	var pose := _pirate_pose(anim, i, n)
	var cv := Canvas.new(PIRATE_FRAME.x, PIRATE_FRAME.y)
	if anim == "ko" and i == n - 1:
		_draw_ko_lying(cv, pose)
	elif facing == "side":
		_draw_pirate_side(cv, pose)
	else:
		_draw_pirate_front(cv, pose, facing == "up")
	cv.shade_and_outline(_pal()["outline"])
	return cv.img


## 0 deg = straight down, 90 = forward (+x), 180 = straight up.
static func _dir(deg: float) -> Vector2:
	var r := deg_to_rad(deg)
	return Vector2(sin(r), cos(r))


## Limb direction. side = 0 for the side view; -1/+1 = which side of the body in front/back views.
static func _limb_dir(deg: float, side: int) -> Vector2:
	if side == 0:
		return _dir(deg)
	var r := deg_to_rad(deg)
	return Vector2(side * (0.25 + 0.5 * absf(sin(r))), cos(r)).normalized()


static func _draw_arm(cv: Canvas, shoulder: Vector2, angle: float, bend: float, side: int,
		sleeve: Color, gauntlet: bool, glow: float, sword_angle: float) -> void:
	var C := _pal()
	var elbow := shoulder + _limb_dir(angle, side) * 6.0
	var fore := _limb_dir(angle + bend, side)
	var hand := elbow + fore * 5.5
	cv.line(shoulder, elbow, 3.4, sleeve)
	cv.line(elbow, hand, 3.0, sleeve)
	cv.line(hand - fore * 1.6, hand - fore * 0.6, 3.2, C["brass"])
	if gauntlet:
		if _o("gauntlet"):
			cv.rect(floori(hand.x) - 1, floori(hand.y) - 1, 3, 3, C["brass"])
			cv.pxv(hand, C["crystal"].lerp(Color.WHITE, glow * 0.6))
		else:
			cv.rect(floori(hand.x) - 1, floori(hand.y) - 1, 2, 2, C["skin"])
		return
	var d := _limb_dir(sword_angle, side)
	var perp := Vector2(-d.y, d.x)
	match _o("weapon"):
		"rifle":
			cv.line(hand - d * 5.0, hand + d * 2.0, 2.6, C["steel_dk"])        # wooden stock
			cv.line(hand + d * 1.0, hand + d * 16.0, 1.6, C["steel"])         # barrel
			cv.line(hand + d * 4.0 + perp, hand + d * 9.0 + perp, 1.0, C["brass"])
			cv.pxv(hand + d * 16.5, C["muzzle"])                              # arcane muzzle crystal
		"saber":
			cv.line(hand, hand + d * 15.0, 2.0, C["steel"])
			cv.line(hand + d * 3.0 + perp * 0.6, hand + d * 14.0 + perp * 0.6, 1.0, C["steel_dk"])
			cv.pxv(hand + d * 7.0 + perp * 1.8, C["steel"])                   # crackling sparks
			cv.pxv(hand + d * 12.0 - perp * 1.8, C["steel"])
			cv.line(hand + d * 1.5 - perp * 2.2, hand + d * 1.5 + perp * 2.2, 1.0, C["brass"])
		_:
			cv.line(hand, hand + d * 15.0, 2.0, C["steel"])
			cv.line(hand + d * 3.0 + perp * 0.6, hand + d * 14.0 + perp * 0.6, 1.0, C["steel_dk"])
			cv.line(hand + d * 1.5 - perp * 2.2, hand + d * 1.5 + perp * 2.2, 1.0, C["brass"])
	cv.rect(floori(hand.x) - 1, floori(hand.y) - 1, 2, 2, C["skin"])


static func _draw_leg_side(cv: Canvas, hip: Vector2, foot: Vector2, pants: Color, boot: Color) -> void:
	var dist := hip.distance_to(foot)
	var bend := sqrt(maxf(56.25 - dist * dist * 0.25, 0.0))   # knee bends forward (leg length 15)
	var knee := (hip + foot) * 0.5 + Vector2(bend + 0.5, 0.0)
	var ankle := foot + Vector2(0, -3)
	cv.line(hip, knee, 4.0, pants)
	cv.line(knee, ankle, 3.6, pants)
	cv.line(knee.lerp(ankle, 0.45), ankle, 3.8, boot)
	cv.rect(floori(foot.x) - 2, floori(foot.y) - 3, 5, 3, boot)
	cv.px(floori(foot.x) + 3, floori(foot.y) - 1, boot)


static func _draw_pirate_side(cv: Canvas, p: Dictionary) -> void:
	var C := _pal()
	var cx := 24.0
	var b: float = p["bob"] + p["crouch"]
	var lean: float = p["lean"]
	var hip_y := 44.0 + b
	var waist_y := 38.0 + b
	var shoulder := Vector2(cx + lean * 0.8, 31.0 + b)

	# Back arm carries the elemental gauntlet.
	_draw_arm(cv, shoulder + Vector2(-1, 0), p["arm_b"], p["elbow_b"], 0, C["coat_dk"], true, p["glow"], 0.0)
	_draw_leg_side(cv, Vector2(cx - 1 + lean * 0.4, hip_y), Vector2(cx - 1 + p["lb"], 59.0 - p["lift_b"]), C["pants_dk"], C["boots"])
	_draw_leg_side(cv, Vector2(cx + 1 + lean * 0.4, hip_y), Vector2(cx + 1 + p["lf"], 59.0 - p["lift_f"]), C["pants"], C["boots_lt"])

	# Long coat skirt, flaring back when moving.
	var hem := 53.0 + b * 0.6
	var coat: float = p["coat"]
	var back_hem := Vector2(cx - 6 - coat + lean * 0.2, hem + 1 - coat * 0.3)
	var front_hem := Vector2(cx + 4 + lean * 0.4, hem)
	cv.poly(PackedVector2Array([Vector2(cx - 5 + lean, waist_y), Vector2(cx + 5 + lean, waist_y), front_hem, back_hem]), C["coat"])
	cv.line(back_hem, front_hem, 1.0, C["brass_dk"])

	# Torso.
	var tx := roundi(cx - 5 + lean)
	var ty := roundi(29.0 + b)
	cv.rect(tx, ty, 10, roundi(waist_y) - ty + 2, C["coat"])
	cv.rect(tx + 7, ty + 1, 2, 7, C["shirt"])
	cv.rect(tx, roundi(waist_y), 10, 2, C["sash"])
	cv.px(tx + 7, roundi(waist_y), C["brass"])
	cv.px(tx + 6, ty + 3, C["brass"])
	cv.px(tx + 6, ty + 6, C["brass"])
	cv.rect(tx + 2, ty, 4, 2, C["brass"])
	cv.px(tx + 3, ty + 4, C["crystal"])   # star insignia
	if _o("crossbelt"):
		cv.line(Vector2(tx + 1, ty + 1), Vector2(tx + 8, roundi(waist_y) - 1), 1.0, C["shirt"])

	_draw_head_side(cv, Vector2(cx + 1 + lean, 23.0 + b))
	# Front arm carries the cutlass.
	_draw_arm(cv, shoulder + Vector2(1, 1), p["arm_f"], p["elbow_f"], 0, C["coat_lt"], false, 0.0, p["sword"])


static func _draw_head_side(cv: Canvas, c: Vector2) -> void:
	var C := _pal()
	var x := roundi(c.x)
	var y := roundi(c.y)
	cv.rect(x - 6, y - 3, 4, 8 if _o("ponytail") else 5, C["hair"])
	if _o("ponytail"):
		cv.line(Vector2(x - 6, y + 2), Vector2(x - 8, y + 7), 2.0, C["hair"])
		cv.px(x - 7, y + 3, C["sash"])
	cv.rect(x - 3, y - 4, 8, 9, C["skin"])
	cv.rect(x - 3, y + 3, 3, 2, C["skin_dk"])
	cv.px(x + 5, y, C["skin"])
	cv.px(x + 3, y - 1, C["eye"])
	cv.px(x + 3, y - 2, C["hair"])
	cv.px(x + 3, y + 3, C["skin_dk"])
	if _o("hat") == "shako":
		# Admiralty shako: tall helmet, black visor, brass plate, red cockade.
		cv.rect(x - 4, y - 12, 9, 8, C["hat"])
		cv.line(Vector2(x - 1, y - 4), Vector2(x + 7, y - 4), 1.0, C["outline"])
		cv.rect(x + 2, y - 10, 2, 3, C["brass"])
		cv.px(x + 4, y - 12, C["crystal"])
		cv.line(Vector2(x - 4, y - 5), Vector2(x + 4, y - 5), 1.0, C["brass_dk"])
		return
	# Tricorn hat with brass band, star crystal and plume.
	cv.line(Vector2(x - 8, y - 4), Vector2(x + 7, y - 5), 2.0, C["hat"])
	cv.rect(x - 4, y - 10, 9, 6, C["hat"])
	cv.line(Vector2(x - 8, y - 5), Vector2(x - 7, y - 8), 2.0, C["hat"])
	cv.line(Vector2(x - 6, y - 6), Vector2(x + 5, y - 6), 1.0, C["brass"])
	cv.px(x + 2, y - 8, C["crystal"])
	cv.px(x + 1, y - 8, C["brass"])
	cv.px(x + 3, y - 8, C["brass"])
	cv.px(x + 2, y - 9, C["brass"])
	cv.line(Vector2(x - 3, y - 10), Vector2(x - 8, y - 15), 2.0, C["plume"])


static func _draw_leg_front(cv: Canvas, hip: Vector2, foot: Vector2, side: int, crouch: float) -> void:
	var C := _pal()
	var knee := (hip + foot) * 0.5 + Vector2(side * crouch * 0.35, 0)
	cv.line(hip, knee, 4.0, C["pants"])
	cv.line(knee, foot + Vector2(0, -3), 3.6, C["pants"])
	cv.line(knee.lerp(foot, 0.4), foot + Vector2(0, -2), 4.0, C["boots"])
	cv.rect(floori(foot.x) - 2, floori(foot.y) - 2, 4, 2, C["boots"])


static func _draw_pirate_front(cv: Canvas, p: Dictionary, back: bool) -> void:
	var C := _pal()
	var cx := 24.0
	var b: float = p["bob"] + p["crouch"]
	var crouch: float = p["crouch"]
	var waist_y := 38.0 + b
	var hip_y := 44.0 + b
	var sway: float = p["lean"] * 0.3
	var sword_side := 1 if back else -1

	# Legs: stride reads as alternating foot lift.
	var lfoot := Vector2(cx - 3.5, 59.0 - p["lift_b"] - maxf(p["lb"], 0.0) * 0.25)
	var rfoot := Vector2(cx + 3.5, 59.0 - p["lift_f"] - maxf(p["lf"], 0.0) * 0.25)
	_draw_leg_front(cv, Vector2(cx - 3, hip_y), lfoot, -1, crouch)
	_draw_leg_front(cv, Vector2(cx + 3, hip_y), rfoot, 1, crouch)

	# Coat skirt.
	var hem := 53.0 + b * 0.6
	var flare: float = maxf(p["coat"], 0.0) * 0.5
	if back:
		cv.poly(PackedVector2Array([Vector2(cx - 6, waist_y), Vector2(cx + 6, waist_y),
			Vector2(cx + 7 + flare, hem), Vector2(cx - 7 - flare, hem)]), C["coat"])
		cv.line(Vector2(cx, waist_y + 3), Vector2(cx, hem), 1.0, C["coat_dk"])
	else:
		cv.poly(PackedVector2Array([Vector2(cx - 6, waist_y), Vector2(cx - 1, waist_y),
			Vector2(cx - 2, hem), Vector2(cx - 7 - flare, hem)]), C["coat"])
		cv.poly(PackedVector2Array([Vector2(cx + 1, waist_y), Vector2(cx + 6, waist_y),
			Vector2(cx + 7 + flare, hem), Vector2(cx + 2, hem)]), C["coat"])
	cv.line(Vector2(cx - 7 - flare, hem), Vector2(cx - 2, hem), 1.0, C["brass_dk"])
	cv.line(Vector2(cx + 2, hem), Vector2(cx + 7 + flare, hem), 1.0, C["brass_dk"])

	# Arms behind the torso when they swing back.
	var shoulder_l := Vector2(cx - 6 + sway, 31.0 + b)
	var shoulder_r := Vector2(cx + 6 + sway, 31.0 + b)
	var sword_shoulder := shoulder_l if sword_side < 0 else shoulder_r
	var gaunt_shoulder := shoulder_r if sword_side < 0 else shoulder_l

	# Torso.
	var tx := roundi(cx - 6 + sway)
	var ty := roundi(29.0 + b)
	cv.rect(tx, ty, 12, roundi(waist_y) - ty + 2, C["coat"])
	if back:
		cv.px(tx + 6, ty + 4, C["brass"])
		cv.px(tx + 5, ty + 5, C["brass"])
		cv.px(tx + 7, ty + 5, C["brass"])
		cv.px(tx + 6, ty + 6, C["brass"])
		cv.px(tx + 6, ty + 5, C["crystal"])
	else:
		cv.rect(tx + 5, ty + 1, 2, 8, C["shirt"])
		for yy in [3, 6]:
			cv.px(tx + 3, ty + yy, C["brass"])
			cv.px(tx + 8, ty + yy, C["brass"])
		cv.px(tx + 2, ty + 4, C["crystal"])
	if _o("crossbelt"):
		cv.line(Vector2(tx + 1, ty + 1), Vector2(tx + 10, roundi(waist_y) - 1), 1.0, C["shirt"])
		cv.line(Vector2(tx + 10, ty + 1), Vector2(tx + 1, roundi(waist_y) - 1), 1.0, C["shirt"])
	cv.rect(tx, roundi(waist_y), 12, 2, C["sash"])
	if not back:
		cv.px(tx + 6, roundi(waist_y), C["brass"])
	cv.rect(tx - 1, ty, 3, 2, C["brass"])
	cv.rect(tx + 10, ty, 3, 2, C["brass"])

	_draw_head_front(cv, Vector2(cx + sway, 23.0 + b), back)
	_draw_arm(cv, gaunt_shoulder, p["arm_b"], p["elbow_b"], -sword_side, C["coat_dk"], true, p["glow"], 0.0)
	_draw_arm(cv, sword_shoulder, p["arm_f"], p["elbow_f"], sword_side, C["coat_lt"], false, 0.0, p["sword"])


static func _draw_head_front(cv: Canvas, c: Vector2, back: bool) -> void:
	var C := _pal()
	var x := roundi(c.x)
	var y := roundi(c.y)
	if back:
		cv.rect(x - 4, y - 4, 9, 9, C["hair"])
		if _o("ponytail"):
			cv.line(Vector2(x, y + 3), Vector2(x, y + 8), 2.0, C["hair"])
			cv.px(x, y + 5, C["sash"])
	else:
		cv.rect(x - 4, y - 4, 9, 9, C["skin"])
		cv.rect(x - 5, y - 3, 1, 6, C["hair"])
		cv.rect(x + 5, y - 3, 1, 6, C["hair"])
		cv.rect(x - 4, y - 4, 9, 1, C["hair"])
		cv.px(x - 2, y - 1, C["eye"])
		cv.px(x + 2, y - 1, C["eye"])
		cv.rect(x - 4, y + 4, 9, 1, C["skin_dk"])
		cv.px(x, y + 2, C["skin_dk"])
	if _o("hat") == "shako":
		cv.rect(x - 4, y - 12, 9, 8, C["hat"])
		if not back:
			cv.line(Vector2(x - 4, y - 4), Vector2(x + 4, y - 4), 1.0, C["outline"])
			cv.rect(x - 1, y - 10, 3, 3, C["brass"])
			cv.px(x, y - 12, C["crystal"])
		cv.line(Vector2(x - 4, y - 5), Vector2(x + 4, y - 5), 1.0, C["brass_dk"])
		return
	cv.ellipse(x + 0.5, y - 4.5, 9.5, 2.2, C["hat"])
	cv.rect(x - 4, y - 11, 9, 7, C["hat"])
	if not back:
		cv.poly(PackedVector2Array([Vector2(x - 2, y - 4), Vector2(x + 3, y - 4), Vector2(x + 0.5, y - 1.5)]), C["hat"])
	cv.line(Vector2(x - 4, y - 6), Vector2(x + 4, y - 6), 1.0, C["brass"])
	cv.px(x, y - 9, C["crystal"])
	cv.px(x - 1, y - 9, C["brass"])
	cv.px(x + 1, y - 9, C["brass"])
	cv.px(x, y - 10, C["brass"])
	if _o("plume"):
		cv.line(Vector2(x + 3, y - 11), Vector2(x + 8, y - 15), 2.0, C["plume"])


## Final knockout frame: the side pose drawn, rotated onto the ground.
static func _draw_ko_lying(cv: Canvas, p: Dictionary) -> void:
	var tmp := Canvas.new(64, 64)
	_draw_pirate_side(tmp, p)
	tmp.img.rotate_90(COUNTERCLOCKWISE)
	# After rotation the body lies along row ~40 with the head on the left.
	cv.img.blend_rect(tmp.img, Rect2i(10, 26, 48, 26), Vector2i(0, 36))


# ================================================================ voidling

static func _vpal() -> Dictionary:
	if not _cache.has("vpal"):
		_cache["vpal"] = {
			"outline": Color("0c0614"),
			"body": Color("3e1d5e"), "belly": Color("5c2c82"), "dark": Color("23103a"),
			"spike": Color("7a3aa8"), "rim": Color("d054e0"), "eye": Color("ff7af4"),
			"mouth": Color("0a0410"), "tooth": Color("f4e6ff"),
		}
	return _cache["vpal"]


static func _draw_voidling_frame(anim: String, i: int, n: int) -> Image:
	var p := {"bob": 0.0, "rx": 10.0, "ry": 6.5, "leg": 0.0, "tail": 0.0, "mouth": 0.0, "eye": 1.0, "lean": 0.0, "dissolve": 0.0, "hurt": false}
	var t := TAU * i / n
	match anim:
		"idle":
			p["ry"] = 6.5 + [0.0, 0.5, 1.0, 0.5][i]
			p["rx"] = 10.0 - [0.0, 0.3, 0.6, 0.3][i]
			p["tail"] = sin(t) * 1.5
		"move":
			p["leg"] = float(i)
			p["bob"] = [0.0, 1.0, 0.0, 1.0][i]
			p["tail"] = sin(t) * 3.0
			p["lean"] = 1.0
		"windup":
			p["ry"] = 5.0
			p["rx"] = 11.5
			p["bob"] = 2.0
			p["mouth"] = 1.0
			p["eye"] = 2.0
			p["lean"] = -2.0 + float(i)
			p["tail"] = 3.0
		"lunge":
			p["ry"] = 4.8
			p["rx"] = 13.5
			p["lean"] = 3.0
			p["mouth"] = 1.0
			p["leg"] = 4.0
			p["tail"] = -2.0
		"hit":
			p["ry"] = [8.0, 7.0][i]
			p["rx"] = [9.0, 9.5][i]
			p["hurt"] = true
			p["lean"] = -2.0
		"death":
			p["ry"] = 6.5 - i * 1.0
			p["rx"] = 10.0 + i * 0.8
			p["bob"] = float(i)
			p["hurt"] = true
			p["dissolve"] = 0.1 + 0.2 * i
	var cv := Canvas.new(VOIDLING_FRAME.x, VOIDLING_FRAME.y)
	_draw_voidling(cv, p)
	var C := _vpal()
	cv.shade_and_outline(C["outline"])
	var dissolve: float = p["dissolve"]
	if dissolve > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77 + i
		for y in cv.h:
			for x in cv.w:
				if rng.randf() < dissolve:
					cv.px(x, y, Color(0, 0, 0, 0))
	return cv.img


static func _draw_voidling(cv: Canvas, p: Dictionary) -> void:
	var C := _vpal()
	var rx: float = p["rx"]
	var ry: float = p["ry"]
	var bx: float = 20.0 + p["lean"]
	var by: float = 28.0 - ry - 3.0 + p["bob"]
	var tail: float = p["tail"]
	var leg: float = p["leg"]
	# Tail.
	cv.line(Vector2(bx - rx + 2, by), Vector2(bx - rx - 4, by - 3 + tail), 3.0, C["body"])
	cv.line(Vector2(bx - rx - 4, by - 3 + tail), Vector2(bx - rx - 7, by - 6 + tail * 1.5), 2.0, C["spike"])
	# Far legs.
	for k in 2:
		var hx := bx - 5.0 + k * 8.0
		var off := sin(leg * PI * 0.5 + k * PI) * 2.0
		cv.line(Vector2(hx, by + ry - 2), Vector2(hx - 2.0 + off, 28.0), 2.0, C["dark"])
	# Body.
	cv.ellipse(bx, by, rx, ry, C["body"])
	cv.ellipse(bx + 1.0, by + 2.0, maxf(rx - 3.0, 1.0), maxf(ry - 3.0, 1.0), C["belly"])
	# Spikes along the back.
	for k in 4:
		var sx := bx - 6.0 + k * 4.0
		var top := by - ry + 2.0
		cv.poly(PackedVector2Array([Vector2(sx - 1.5, top), Vector2(sx + 1.5, top), Vector2(sx - 1.0 - p["lean"] * 0.3, top - 3.5 - float(k % 2))]), C["spike"])
	cv.line(Vector2(bx - rx + 3, by - ry + 1.5), Vector2(bx + rx - 4, by - ry + 1.5), 1.0, C["rim"])
	# Near legs.
	for k in 2:
		var hx := bx - 3.0 + k * 8.0
		var off := sin(leg * PI * 0.5 + k * PI + PI * 0.5) * 2.5
		cv.line(Vector2(hx, by + ry - 2), Vector2(hx + 1.0 + off, 28.0), 2.0, C["body"])
	# Face.
	var ex := roundi(bx + rx - 5.0)
	var ey := roundi(by - 2.0)
	if p["hurt"]:
		cv.px(ex, ey, C["eye"])
		cv.px(ex + 1, ey + 1, C["eye"])
		cv.px(ex - 3, ey, C["eye"])
		cv.px(ex - 2, ey + 1, C["eye"])
	else:
		var es: int = int(p["eye"])
		cv.rect(ex, ey, es + 1, es, C["eye"])
		cv.rect(ex - 3, ey, es, es, C["eye"])
	if p["mouth"] > 0.0:
		cv.rect(ex - 4, ey + 3, 6, 2, C["mouth"])
		cv.px(ex - 3, ey + 3, C["tooth"])
		cv.px(ex - 1, ey + 3, C["tooth"])
		cv.px(ex + 1, ey + 3, C["tooth"])
	else:
		cv.rect(ex - 3, ey + 3, 5, 1, C["mouth"])


# ================================================================ dragon

static func dragon_sheet_image() -> Image:
	if _cache.has("dragon_img"):
		return _cache["dragon_img"]
	var custom := _override_sheet("dragon", DRAGON_ANIMS, DRAGON_FRAME, 1)
	if custom:
		_cache["dragon_img"] = custom
		return custom
	var max_frames := 0
	for a in DRAGON_ANIMS:
		max_frames = maxi(max_frames, int(DRAGON_ANIMS[a][0]))
	var sheet := Image.create_empty(max_frames * DRAGON_FRAME.x, DRAGON_ANIMS.size() * DRAGON_FRAME.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var row := 0
	for anim in DRAGON_ANIMS:
		var n := int(DRAGON_ANIMS[anim][0])
		for i in n:
			var cv := Canvas.new(DRAGON_FRAME.x, DRAGON_FRAME.y)
			_draw_dragon(cv, _dragon_pose(anim, i, n))
			cv.shade_and_outline(_dpal()["outline"])
			sheet.blit_rect(cv.img, Rect2i(Vector2i.ZERO, DRAGON_FRAME), Vector2i(i * DRAGON_FRAME.x, row * DRAGON_FRAME.y))
		row += 1
	_cache["dragon_img"] = sheet
	return sheet


static func _dpal() -> Dictionary:
	if not _cache.has("dpal"):
		_cache["dpal"] = {
			"outline": Color("0e1430"),
			"body": Color("4f8fd8"), "body_dk": Color("35609e"), "belly": Color("d4ecff"),
			"wing": Color("9ad6ff"), "wing_dk": Color("6aa2dc"), "bone": Color("2c4c8c"),
			"horn": Color("f2d27a"), "eye": Color("141028"), "white": Color("ffffff"),
			"crystal": Color("c8fbff"), "mouth": Color("1a1030"), "frost": Color("f0ffff"),
		}
	return _cache["dpal"]


static func _dragon_pose(anim: String, i: int, n: int) -> Dictionary:
	var p := {"flap": 0.4, "bob": 0.0, "neck": 0.0, "mouth": false, "tail": 0.0, "tilt": 0.0, "eye": "open", "glow": 0.0, "lying": false}
	var t := TAU * i / n
	match anim:
		"hover":
			p["flap"] = lerpf(-0.55, 1.0, (cos(t) + 1.0) * 0.5)
			p["bob"] = roundf(cos(t))
			p["tail"] = sin(t + 1.0) * 1.5
		"fly":
			p["flap"] = lerpf(-0.55, 1.0, (cos(t) + 1.0) * 0.5)
			p["bob"] = roundf(cos(t) * 0.5)
			p["tilt"] = 1.0
			p["neck"] = -1.0
			p["tail"] = -1.0 + sin(t) * 0.8
		"attack":
			p["neck"] = [3.0, 2.0, -2.0, 0.0][i]
			p["mouth"] = [false, true, true, false][i]
			p["glow"] = [0.0, 0.5, 1.0, 0.0][i]
			p["flap"] = [0.6, 0.8, -0.3, 0.3][i]
			p["tilt"] = [0.0, 0.0, 1.0, 0.0][i]
		"special":
			p["flap"] = [1.0, 1.0, 0.8, 1.0][i]
			p["neck"] = [3.0, 5.0, 5.0, 3.0][i]
			p["mouth"] = i > 0
			p["glow"] = [0.5, 1.0, 1.0, 0.6][i]
			p["tail"] = 2.0
		"hit":
			p["eye"] = "x"
			p["flap"] = [-0.2, 0.2][i]
			p["neck"] = [-2.0, -1.0][i]
			p["bob"] = [1.0, 0.0][i]
		"ko":
			p["eye"] = "closed"
			p["flap"] = [-0.5, -0.6, 0.0][i]
			p["neck"] = [-2.0, -4.0, 0.0][i]
			p["bob"] = [2.0, 4.0, 0.0][i]
			p["lying"] = i == n - 1
	return p


static func _draw_dragon_wing(cv: Canvas, root: Vector2, up: float, far: bool) -> void:
	var C := _dpal()
	var tip := root + Vector2(-5.0, -16.0 * up - 2.0)
	var f1 := root + Vector2(-12.0, -10.0 * up + 1.0)
	var f2 := root + Vector2(-13.0, -4.0 * up + 4.0)
	cv.poly(PackedVector2Array([root + Vector2(4, 0), tip, f1, f2, root + Vector2(-2, 3)]), C["wing_dk"] if far else C["wing"])
	cv.line(root, tip, 1.6, C["bone"])
	cv.line(root, f1, 1.0, C["bone"])
	cv.line(root, f2, 1.0, C["bone"])


static func _draw_dragon(cv: Canvas, p: Dictionary) -> void:
	var C := _dpal()
	if p["lying"]:
		_draw_dragon_lying(cv)
		return
	var cx := 22.0
	var cy: float = 22.0 + p["bob"]
	var flap: float = p["flap"]
	var tilt: float = p["tilt"]
	var tail: float = p["tail"]
	var glow: float = p["glow"]

	_draw_dragon_wing(cv, Vector2(cx + 2, cy - 6), flap, true)

	# Tail ending in a star crystal.
	var pts := [Vector2(cx - 7, cy + 1), Vector2(cx - 12, cy + 1 + tail * 0.5), Vector2(cx - 16, cy - 1 + tail), Vector2(cx - 19, cy - 4 + tail * 1.3)]
	var widths := [4.0, 3.0, 2.0]
	for k in 3:
		cv.line(pts[k], pts[k + 1], widths[k], C["body"])
	var tp: Vector2 = pts[3]
	var tip_col: Color = (C["crystal"] as Color).lerp(Color.WHITE, glow * 0.5)
	cv.poly(PackedVector2Array([tp + Vector2(-2.5, 0), tp + Vector2(0, -2.5), tp + Vector2(2.5, 0), tp + Vector2(0, 2.5)]), tip_col)

	# Body, belly, star markings, legs.
	cv.ellipse(cx, cy, 9.0, 6.0, C["body"])
	cv.ellipse(cx + 1.0, cy + 2.5, 7.0, 3.0, C["belly"])
	cv.px(roundi(cx - 3), roundi(cy - 5), C["crystal"])
	cv.px(roundi(cx + 1), roundi(cy - 6), C["crystal"])
	cv.line(Vector2(cx - 4, cy + 4), Vector2(cx - 5, cy + 8), 2.5, C["body_dk"])
	cv.line(Vector2(cx + 4, cy + 4), Vector2(cx + 5, cy + 8), 2.5, C["body_dk"])
	cv.px(roundi(cx - 4), roundi(cy + 9), C["horn"])
	cv.px(roundi(cx + 6), roundi(cy + 8), C["horn"])

	_draw_dragon_wing(cv, Vector2(cx - 1, cy - 4), flap, false)

	# Neck and head.
	var hx := cx + 11.0 + tilt
	var hy: float = cy - 8.0 - p["neck"] + tilt * 2.0
	cv.line(Vector2(cx + 5, cy - 2), Vector2(hx - 2, hy + 2), 4.5, C["body"])
	cv.line(Vector2(cx + 7, cy), Vector2(hx - 1, hy + 3), 1.5, C["belly"])
	cv.ellipse(hx, hy, 5.0, 4.2, C["body"])
	if p["mouth"]:
		cv.ellipse(hx + 4.5, hy - 0.5, 3.6, 1.8, C["body"])
		cv.ellipse(hx + 3.5, hy + 3.0, 3.0, 1.4, C["body_dk"])
		cv.rect(roundi(hx + 2), roundi(hy + 1), 4, 1, C["mouth"])
		if glow > 0.0:
			cv.px(roundi(hx + 7), roundi(hy + 1), C["frost"])
			cv.px(roundi(hx + 8), roundi(hy + 1), C["crystal"])
	else:
		cv.ellipse(hx + 4.0, hy + 1.0, 3.8, 2.4, C["body"])
		cv.px(roundi(hx + 6), roundi(hy), C["body_dk"])
	cv.line(Vector2(hx - 2, hy - 3), Vector2(hx - 6, hy - 8), 2.0, C["horn"])
	cv.line(Vector2(hx + 0.5, hy - 3.5), Vector2(hx - 1.5, hy - 8.5), 1.5, C["horn"])
	var ex := roundi(hx)
	var ey := roundi(hy)
	match p["eye"]:
		"closed":
			cv.line(Vector2(ex, ey), Vector2(ex + 3, ey), 1.0, C["outline"])
		"x":
			cv.px(ex, ey - 2, C["eye"])
			cv.px(ex + 2, ey - 2, C["eye"])
			cv.px(ex + 1, ey - 1, C["eye"])
			cv.px(ex, ey, C["eye"])
			cv.px(ex + 2, ey, C["eye"])
		_:
			cv.rect(ex, ey - 2, 3, 3, C["white"])
			cv.rect(ex + 1, ey - 1, 2, 2, C["eye"])
			cv.px(ex + 1, ey - 1, C["white"])


static func _draw_dragon_lying(cv: Canvas) -> void:
	var C := _dpal()
	cv.line(Vector2(12, 34), Vector2(4, 32), 3.0, C["body"])
	cv.line(Vector2(4, 32), Vector2(3, 28), 2.0, C["body"])
	cv.poly(PackedVector2Array([Vector2(1, 28), Vector2(3, 25.5), Vector2(5, 28), Vector2(3, 30.5)]), C["crystal"])
	cv.ellipse(20, 33, 10.0, 4.5, C["body"])
	cv.ellipse(21, 35, 8.0, 2.0, C["belly"])
	cv.poly(PackedVector2Array([Vector2(13, 31), Vector2(26, 28), Vector2(24, 32), Vector2(15, 33)]), C["wing"])
	cv.ellipse(32, 34, 5.0, 3.5, C["body"])
	cv.ellipse(36, 35, 3.0, 2.0, C["body"])
	cv.line(Vector2(30, 31), Vector2(26, 28), 1.5, C["horn"])
	cv.line(Vector2(32, 34), Vector2(35, 34), 1.0, C["outline"])


# ================================================================ icons

static func _draw_element_icon(element: int) -> Image:
	const E := preload("res://scripts/core/elements.gd")
	var c: Color = E.COLORS[element]
	var w := c.lerp(Color.WHITE, 0.6)
	var d := c.darkened(0.45)
	var cv := Canvas.new(16, 16)
	match element:
		E.SUN:
			for k in 8:
				var a := k * TAU / 8.0
				var dir := Vector2(cos(a), sin(a))
				cv.line(Vector2(8, 8) + dir * 4.5, Vector2(8, 8) + dir * 6.8, 1.4, c)
			cv.ellipse(8, 8, 4.2, 4.2, c)
			cv.ellipse(7.5, 7.5, 2.2, 2.2, w)
		E.COMET:
			for s in range(8, -1, -1):
				var t := s / 8.0
				var p := Vector2(10.5, 5.5).lerp(Vector2(2.5, 13.5), t)
				cv.ellipse(p.x, p.y, 2.6 * (1.0 - t) + 0.7, 2.6 * (1.0 - t) + 0.7, c.lerp(d, t))
			cv.ellipse(10.5, 5.5, 3.0, 3.0, c)
			cv.ellipse(10.0, 5.0, 1.4, 1.4, w)
		E.STORM:
			cv.poly(PackedVector2Array([Vector2(9, 1), Vector2(4, 9), Vector2(8, 9), Vector2(6, 15), Vector2(12.5, 6), Vector2(8.5, 6), Vector2(11, 1)]), c)
			cv.line(Vector2(9, 2.5), Vector2(6, 8), 1.0, w)
		E.GRAVITY:
			cv.ellipse(8, 8, 6.6, 6.6, d)
			cv.ellipse(8, 8, 5.2, 5.2, Color(0, 0, 0, 0))
			cv.ellipse(8, 8, 3.6, 3.6, c)
			cv.ellipse(8, 8, 1.6, 1.6, w)
			cv.px(2, 4, w)
			cv.px(13, 11, w)
		E.VOID:
			cv.ellipse(8, 8, 7.0, 4.4, c)
			cv.ellipse(8, 8, 5.4, 3.0, Color("1a0820"))
			cv.rect(7, 5, 2, 6, c.lerp(Color.WHITE, 0.3))
			cv.px(6, 6, w)
	cv.shade_and_outline(Color("0d0814"))
	return cv.img
