extends RefCounted
## Procedural PLACEHOLDER textures: 32x32 world tiles (32 texels per meter, matching
## the sprites), plus shapes used by effects. Replace with hand-painted PNGs later.

const TILE := 32


## kind: deck, hull, brass, crate, barrel, rope, stone, rock, moss
static func tile_texture(kind: String) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var img := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			img.set_pixel(x, y, _tile_pixel(kind, x, y, rng))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _tile_pixel(kind: String, x: int, y: int, rng: RandomNumberGenerator) -> Color:
	var n := rng.randf()
	match kind:
		"deck":
			# Dark hardwood planks along X, 4 planks per meter, staggered joints, brass nails.
			var plank := int(y / 8.0)
			var joint := (plank * 13 + 5) % TILE
			var has_joint := plank % 2 == 0   # long planks: only every other row has a butt joint
			if y % 8 == 7:
				return Color("1e120d")
			if has_joint and x == joint:
				return Color("24150f")
			if has_joint and (x == (joint + 2) % TILE or x == (joint + TILE - 2) % TILE) and y % 8 == 3:
				return Color("c9a052")
			var grain := 0.5 + 0.5 * sin(x * 0.35 + plank * 1.7 + sin(x * 0.11 + plank) * 2.0)
			var base := Color("4a2f24").lerp(Color("5f3e2c"), grain * 0.7)
			if y % 8 == 0:
				base = base.lightened(0.07)
			return base.darkened(n * 0.08)
		"hull":
			if y % 6 == 5:
				return Color("170d0a")
			if y % 24 == 2 and x % 8 == 4:
				return Color("b88a3e")
			return Color("3a2419").darkened(n * 0.12).lerp(Color("452b1e"), 0.5 + 0.5 * sin(x * 0.2 + y))
		"brass":
			var v := 0.5 + 0.5 * sin(y * 0.45 + x * 0.05)
			var c := Color("a8782a").lerp(Color("e6bb58"), v)
			if n < 0.04:
				c = Color("f8e09a")
			if (x + y) % 16 == 0:
				c = c.darkened(0.22)
			return c.darkened(n * 0.05)
		"crate":
			var edge := x < 3 or y < 3 or x > TILE - 4 or y > TILE - 4
			var corner := (x < 5 or x > TILE - 6) and (y < 5 or y > TILE - 6)
			if corner:
				return Color("d0a048") if (x + y) % 3 != 0 else Color("8a6424")
			if edge:
				return Color("5a3a20").darkened(n * 0.1)
			if x % 7 == 3:
				return Color("4a2e18")
			if absi(x - y) <= 1 or absi(x - (TILE - 1 - y)) <= 1:
				return Color("6e4626")
			return Color("8c5c34").darkened(n * 0.12)
		"barrel":
			if x % 5 == 4:
				return Color("3a2214")
			return Color("7a4a2a").darkened(n * 0.12).lerp(Color("8c5a32"), 0.3 * sin(y * 0.3))
		"rope":
			var stripe := (x + y) % 6 < 3
			return (Color("c4a670") if stripe else Color("8a6e44")).darkened(n * 0.08)
		"stone":
			var row := int(y / 16.0)
			var shift := 8 if row % 2 == 1 else 0
			if y % 16 == 15 or (x + shift) % 16 == 0:
				return Color("262940")
			if (x + shift) % 16 == 8 and y % 16 == 7 and row % 2 == 0:
				return Color("a8b8ff")
			return Color("596080").darkened(n * 0.14)
		"rock":
			var c := Color("4a3e5e").darkened(n * 0.18)
			if rng.randf() < 0.06:
				c = Color("2c2440")
			return c
		"moss":
			var c := Color("3d7d68").darkened(n * 0.16)
			if rng.randf() < 0.08:
				c = Color("63b08a")
			return c
	return Color.MAGENTA


## White circle with alpha. soft = radial falloff (shadows); otherwise a ring.
static func circle_texture(size: int, soft: bool) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			var a := 0.0
			if soft:
				a = 1.0 - smoothstep(0.25, 1.0, d)
			else:
				a = (1.0 - smoothstep(0.9, 1.0, d)) * (0.15 + 0.85 * smoothstep(0.7, 0.93, d))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## Crescent arc pointing toward +U (sword and charged-attack trails).
static func crescent_texture() -> ImageTexture:
	var size := 64
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (x + 0.5) / 32.0 - 1.0
			var v := (y + 0.5) / 32.0 - 1.0
			var r := sqrt(u * u + v * v)
			var ang := absf(atan2(v, u))
			var a := 0.0
			if ang < 1.35 and r > 0.45 and r < 1.0:
				a = clampf((r - 0.45) / 0.45, 0.0, 1.0)
				a *= 1.0 - smoothstep(0.9, 1.0, r)
				a *= 1.0 - pow(ang / 1.35, 3.0)
				a = floorf(a * 4.0) / 4.0   # banded alpha keeps a pixel-art look
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## 4-point impact star with short diagonal rays (hit sparks).
static func spark_texture() -> ImageTexture:
	var size := 25
	var c := 12
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size:
		for x in size:
			var dx := absi(x - c)
			var dy := absi(y - c)
			var on := false
			# Long cross arms that taper to a point.
			if dx <= maxi(0, 2 - int(dy / 4.0)) and dy <= 11:
				on = true
			if dy <= maxi(0, 2 - int(dx / 4.0)) and dx <= 11:
				on = true
			# Short diagonal rays.
			if dx == dy and dx >= 3 and dx <= 6:
				on = true
			if dx * dx + dy * dy <= 6:
				on = true
			if on:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


## Star-chart compass rose (glowing deck inlay and sail sigils).
static func compass_texture(size := 160) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var px := 2.0 / size
	for y in size:
		for x in size:
			var u := (x + 0.5) / (size * 0.5) - 1.0
			var v := (y + 0.5) / (size * 0.5) - 1.0
			var r := sqrt(u * u + v * v)
			var ang := atan2(v, u)
			var a := 0.0
			if absf(r - 0.95) < px * 1.2 or absf(r - 0.86) < px * 0.8 or absf(r - 0.42) < px * 0.8:
				a = 1.0
			if r > 0.86 and r < 0.95:
				var tick := fposmod(ang / TAU * 48.0, 1.0)
				if tick < 0.12:
					a = 0.8
			var star_r := lerpf(0.16, 0.8, pow(absf(cos(ang * 4.0)), 10.0))
			if absf(r - star_r) < px * 1.3 and r < 0.82:
				a = 1.0
			var small_r := lerpf(0.1, 0.52, pow(absf(cos(ang * 4.0 + PI / 4.0)), 10.0))
			if absf(r - small_r) < px and r < 0.55:
				a = 0.7
			if r < px * 2.5:
				a = 1.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
