extends RefCounted
## HD-2D rendering constants and helpers. See docs/RENDERING.md.
##
## One rule ties everything together: 32 art pixels = 1 meter, for sprites AND
## world textures. The orthographic camera is sized so one art pixel covers a
## whole number of screen pixels, so sprites stay crisp on every screen.

const PITCH_DEG := 40.0          # camera tilt below the horizon
const PIXELS_PER_METER := 32     # art density
const TARGET_VIEW_HEIGHT := 11.25  # meters of world visible vertically (approx.)
const PIXEL_SIZE := 0.03125      # 1 / PIXELS_PER_METER


## Screen pixels per art pixel for a given render height (always a whole number).
static func pixel_scale_for(screen_height: float) -> int:
	return maxi(1, roundi(screen_height / (TARGET_VIEW_HEIGHT * PIXELS_PER_METER)))


## Orthographic camera size that keeps art pixels square and whole.
static func ortho_size_for(screen_height: float) -> float:
	return screen_height / float(PIXELS_PER_METER * pixel_scale_for(screen_height))


## Sprites stand upright; stretching them by 1/cos(pitch) cancels the camera tilt
## so their pixels appear square on screen.
static func sprite_y_scale() -> float:
	return 1.0 / cos(deg_to_rad(PITCH_DEG))


## Upright pixel sprite whose feet sit at the parent's origin.
## feet_px = distance in art pixels from the frame center down to the feet.
static func make_animated_sprite(frames: SpriteFrames, feet_px: float) -> AnimatedSprite3D:
	var s := AnimatedSprite3D.new()
	s.sprite_frames = frames
	s.pixel_size = PIXEL_SIZE
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var ys := sprite_y_scale()
	s.scale = Vector3(1.0, ys, 1.0)
	s.position.y = feet_px * PIXEL_SIZE * ys
	return s
