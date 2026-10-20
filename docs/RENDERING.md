# HD-2D Rendering Pipeline

One rule ties everything together: **32 art pixels = 1 meter**, for character
sprites *and* world textures (`scripts/core/hd2d.gd`).

## Camera
- Orthographic, pitched 40° down, yaw fixed at 0 (`render/camera_controller.gd`).
- The ortho size is chosen per screen so one art pixel covers a **whole number** of
  screen pixels: `scale = round(screen_height / 360)` and `size = screen_height / (32 * scale)`.
  So 720p gives 2x, 1080p gives 3x, and 1440p gives 4x. Odd heights (an iPhone at 1170) show a little more of the world rather than scaling unevenly.
- The camera position is snapped to the screen-pixel grid so textures don't shimmer while it scrolls.
- Smoothing, aim look-ahead, arena bounds, and shake driven by "trauma" (shake strength that builds with each hit and fades over time).

## Sprites
- `AnimatedSprite3D`, nearest filtering, alpha scissor (crisp edges, cast real shadows).
- They stand upright (no billboarding). Since the camera yaw is fixed, they always
  face it. Their Y scale is `1 / cos(40°)` so the camera tilt doesn't squash them,
  which keeps pixels square on screen.
- Characters get a soft blob shadow plus a real sun shadow.
- Sheets: pirate 48×64 frames (feet at 24,60), Voidling 40×32 (feet at 20,28).
  Layout and timing live in `render/sprite_factory.gd` (`PIRATE_ANIMS`). Each attack's
  *strike frame* sets when damage lands.

## World
- Blocks use 32×32 textures with world-space triplanar mapping, nearest filtering and mipmaps.
- The deck is split into 4×4 m MultiMesh chunks: few draw calls, and each chunk gets only nearby lights.
- Lighting: one directional "star" light casts shadows. Lanterns and spells use unshadowed omni lights.
- Selective bloom: only emissive materials above 1.0 brightness glow (glow threshold 1.0).
- Depth: height fog swallows anything below the dock. The sky is a pixel-quantized
  nebula shader on a quad attached to the camera.

## Post-processing (`render/post_fx.gd`)
Tilt-shift blur toward the top and bottom of the screen, a vignette and an indigo
grade, all in one full-screen pass. It's turned off on the Low quality setting.

## Mobile renderer constraints
- The project uses the **Mobile** renderer (Vulkan, or Metal on iOS), with an OpenGL fallback.
- No SSAO/SSR/SDFGI/volumetric fog, and no FSR. 3D scaling is bilinear.
- Light limit per object: keep ≤ 8 omni lights touching any one mesh.
  `Game.flash_light` caps spell flashes at 4 at a time.
- Quality presets (`Game.set_quality`):
  - **Low:** 67% 3D resolution, no post-processing, no dynamic spell lights, 45% particles.
  - **Medium:** 84% 3D resolution, 75% particles. This is the phone default.
  - **High:** 100% 3D resolution, all effects. This is the PC default.

## Replacing placeholder art
Keep the frame sizes, feet positions and animation rows. Load a PNG sheet into
`SpriteFactory._build_frames()` instead of the generated image.
