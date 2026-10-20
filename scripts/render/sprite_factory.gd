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
	"dodge": [4, 16.0, false, -1],
	"attack1": [4, 16.0, false, 1],
	"attack2": [4, 16.0, false, 1],
	"attack3": [5, 14.0, false, 2],
	"charge": [2, 8.0, true, -1],
	"charged": [5, 14.0, false, 2],
	"cast": [4, 14.0, false, 1],
	"hit": [2, 8.0, false, -1],
	"ko": [3, 6.0, false, -1],
}
const VOIDLING_ANIMS := {
	"idle": [4, 6.0, true, -1],
	"move": [4, 12.0, true, -1],
	"windup": [2, 8.0, true, -1],
	"lunge": [2, 10.0, true, -1],
	"hit": [2, 10.0, false, -1],
	"death": [5, 12.0, false, -1],
}

static var _cache := {}


# ================================================================ public API

static func anim_duration(anim: String) -> float:
	var spec: Array = PIRATE_ANIMS[anim]
	return float(spec[0]) / float(spec[1])


## Seconds from animation start until the strike frame (when damage lands).
static func strike_time(anim: String) -> float:
	var spec: Array = PIRATE_ANIMS[anim]
	return maxf(0.0, float(spec[3])) / float(spec[1])


static func pirate_frames() -> SpriteFrames:
	if not _cache.has("pirate"):
		_cache["pirate"] = _build_frames(pirate_sheet_image(), PIRATE_ANIMS, PIRATE_FRAME, FACINGS)
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


static func voidling_sheet_image() -> Image:
	if _cache.has("voidling_img"):
		return _cache["voidling_img"]
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
			p["arm_b"] = [40.0, 90.0, 92.0, 60.0][i]
			p["elbow_b"] = [70.0, 0.0, 0.0, 20.0][i]
			p["arm_f"] = -15.0
			p["lean"] = [0.0, 2.0, 1.0, 0.0][i]
			p["lf"] = 2.0
			p["lb"] = -2.0
			p["glow"] = [0.5, 1.0, 0.6, 0.2][i]
			p["coat"] = [0.0, 2.0, 1.0, 0.0][i]
		"hit":
			p["lean"] = [-3.0, -2.0][i]
			p["crouch"] = [1.0, 0.0][i]
			p["arm_f"] = -30.0
			p["arm_b"] = -35.0
			p["bob"] = [1.0, 0.0][i]
			p["coat"] = -1.0
		"ko":
			p["crouch"] = [5.0, 9.0, 0.0][i]
			p["lean"] = [2.0, 4.0, 0.0][i]
			p["arm_f"] = [0.0, -10.0, 0.0][i]
			p["arm_b"] = [0.0, 10.0, 0.0][i]
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
		cv.rect(floori(hand.x) - 1, floori(hand.y) - 1, 3, 3, C["brass"])
		cv.pxv(hand, C["crystal"].lerp(Color.WHITE, glow * 0.6))
	else:
		var d := _limb_dir(sword_angle, side)
		var perp := Vector2(-d.y, d.x)
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

	_draw_head_side(cv, Vector2(cx + 1 + lean, 23.0 + b))
	# Front arm carries the cutlass.
	_draw_arm(cv, shoulder + Vector2(1, 1), p["arm_f"], p["elbow_f"], 0, C["coat_lt"], false, 0.0, p["sword"])


static func _draw_head_side(cv: Canvas, c: Vector2) -> void:
	var C := _pal()
	var x := roundi(c.x)
	var y := roundi(c.y)
	cv.rect(x - 6, y - 3, 4, 8, C["hair"])
	cv.line(Vector2(x - 6, y + 2), Vector2(x - 8, y + 7), 2.0, C["hair"])
	cv.px(x - 7, y + 3, C["sash"])
	cv.rect(x - 3, y - 4, 8, 9, C["skin"])
	cv.rect(x - 3, y + 3, 3, 2, C["skin_dk"])
	cv.px(x + 5, y, C["skin"])
	cv.px(x + 3, y - 1, C["eye"])
	cv.px(x + 3, y - 2, C["hair"])
	cv.px(x + 3, y + 3, C["skin_dk"])
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
	cv.ellipse(x + 0.5, y - 4.5, 9.5, 2.2, C["hat"])
	cv.rect(x - 4, y - 11, 9, 7, C["hat"])
	if not back:
		cv.poly(PackedVector2Array([Vector2(x - 2, y - 4), Vector2(x + 3, y - 4), Vector2(x + 0.5, y - 1.5)]), C["hat"])
	cv.line(Vector2(x - 4, y - 6), Vector2(x + 4, y - 6), 1.0, C["brass"])
	cv.px(x, y - 9, C["crystal"])
	cv.px(x - 1, y - 9, C["brass"])
	cv.px(x + 1, y - 9, C["brass"])
	cv.px(x, y - 10, C["brass"])
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
