# Sprite Art Prompts for ChatGPT

How to use ChatGPT's image generator to make sprite animations for Star Dragon
Voyager that drop straight into the game.

> **Be realistic about the result.** ChatGPT can't place pixels on an exact grid.
> Treat what it makes as *concept art and rough frames*. You'll clean them up in a
> pixel editor ([Aseprite](https://www.aseprite.org/), or the free
> [Pixelorama](https://pixelorama.org/) / [LibreSprite](https://libresprite.github.io/))
> before they go in the game. Steps 4–5 below explain how.

---

## 1. Start every chat with the MASTER STYLE PROMPT

Paste this first. It sets the look for everything that follows.

```
You are a professional pixel artist creating game sprites for "Star Dragon Voyager",
an HD-2D action RPG (in the style of Octopath Traveler II): crisp 2D pixel-art
characters standing in a lit 3D world, seen from a three-quarter top-down camera.

WORLD: a magical pirate civilization among the stars. Brass machinery, dark
hardwood ship decks, glowing star crystals, celestial stonework, elemental magic.
Adventurous and colorful, never sterile sci-fi.

STRICT PIXEL-ART RULES
- True pixel art: hard square pixels, NO anti-aliasing, NO blur, NO gradients,
  NO soft brushes, NO painterly texture, NO dithering noise.
- 1-pixel dark outline around the silhouette, colored #160e1e (very dark violet,
  not pure black). Interior lines use darker shades of the local color.
- Light source from the TOP-LEFT on every sprite: top/left edges one shade lighter,
  bottom/right edges one shade darker. Flat cel shading, 2-3 shades per material.
- Limited palette: at most ~20 colors per character (palette given below).
- Chunky readable shapes. Strong, instantly readable silhouette at small size.
  Slightly chibi proportions: head about 1/4 of total height.
- Character scale: a human is about 32 px wide and 48 px tall.
- Background: fully TRANSPARENT (or flat pure magenta #ff00ff if transparency
  is not possible). No shadows on the ground, no scenery, no text, no UI.
- Frames in a sheet are the SAME character at the SAME scale, evenly spaced in a
  grid, with the feet on the same baseline in every frame.
```

---

## 2. Then describe the character (pick one)

### The Captain (player)
```
CHARACTER: the player, a charismatic elemental space-pirate captain (not armored).
- Long crimson pirate coat (#8a2639, shadow #5c172a, light #a83448) with brass
  trim and buttons (#e2aa42, shadow #9c6c22), open front showing a cream shirt (#ece2cc).
- Teal sash belt (#2f7a96) with a brass buckle.
- Dark navy tricorn hat (#272040) with brass band, a small glowing cyan star
  crystal on the front (#6ff0ff) and a white plume (#e8f4ff).
- Dark hair (#3a2030) in a short ponytail tied with a teal ribbon. Skin #f1c29b
  (shadow #c98d6c), eyes #120c18.
- Navy trousers (#2a2e4c), brown boots (#3e2a22 / #5e4232).
- Right hand: a steel cutlass (#d4dcec, edge #8792a8) with a brass guard.
- Left hand: a brass elemental gauntlet with a glowing crystal in the palm.
- Small star-shaped insignia on the coat (cyan crystal pixel).
```

### Nova (dragon companion)
```
CHARACTER: Nova, a small cute Comet-element star dragon companion, about the
size of a large cat, always flying.
- Body sky blue (#4f8fd8, shadow #35609e), pale icy belly (#d4ecff).
- Translucent-looking pale blue wing membranes (#9ad6ff, far wing #6aa2dc) with
  dark blue wing bones (#2c4c8c).
- Short golden horns (#f2d27a). Big expressive eye: white with a dark pupil
  (#141028) and a white highlight. Friendly and curious, not scary.
- A glowing star-shaped crystal (#c8fbff) on the tip of the tail, and two or
  three tiny crystal "star" freckles along the back.
- Faces RIGHT (side view). About 36 px long and 30 px tall.
```

### Voidling (enemy)
```
CHARACTER: Voidling, a fast void creature: a low crawling blob-lizard of dark
purple (#3e1d5e, belly #5c2c82, darkest #23103a) with violet spikes along its
back (#7a3aa8), a thin magenta rim light on its top edge (#d054e0), two
glowing pink eyes (#ff7af4), four thin legs and a whip tail. Menacing but small.
Faces RIGHT (side view). About 30 px long and 20 px tall.
```

### Admiralty Marine (enemy)
```
CHARACTER: Admiralty Marine, a soldier of the oppressive interstellar navy.
- Crisp white uniform coat (#d8dce6, shadow #9ea6b8) with gold trim (#d8b050),
  navy front panel and trousers (#2a3560), red sash (#b8303e), black boots.
- Tall navy shako helmet (#1d2546) with a black visor, brass front plate and a
  small red cockade (#ff5a5a). No plume.
- Electrified saber: pale cyan blade (#b4f6ff) with blue sparks (#3cb4ff).
- Disciplined, stiff, menacing posture. Same body proportions as the Captain.
```

### Admiralty Rifleman (enemy)
```
CHARACTER: Admiralty Rifleman. Same build and shako helmet as the Marine, but a
navy coat (#2c3d6e, shadow #1e2a4e) with white crossbelts forming an X on the
chest, light grey trousers (#c8ccd8), and a long arcane rifle: wooden stock
(#6a4a34), steel barrel (#b0b8c8), brass fittings, and a glowing violet crystal
at the muzzle (#d080ff).
```

---

## 3. Then ask for ONE animation strip at a time

Image models do much better with one row than with a whole sheet. Template:

```
Create a horizontal sprite strip of [CHARACTER NAME] performing the
"[ANIMATION]" animation: [FRAME COUNT] frames, left to right, evenly spaced,
each frame [W]x[H] pixels (draw it larger if needed, but keep it on that exact
grid so it can be scaled down with nearest-neighbor). Facing: [DIRECTION].
Feet on the same baseline in every frame. Motion: [DESCRIPTION OF THE MOTION].
Transparent background.
```

**Tip:** upload the matching placeholder sheet from `assets/generated/` as a
reference image. Run `sdv sprites` to create those sheets. Then say: *"Use this image for
the pose, timing and layout, but redraw it in the style described."* It's the
best way to get the frame count and poses right.

### Animation lists (frame counts must match exactly)

**Captain**: frames 48×64. Draw each animation 3 times, facing **down**
(toward the camera), **up** (away) and **side** (facing right; the game mirrors it for left).

| Animation | Frames | Speed | Motion |
|---|---|---|---|
| idle | 4 | 5 fps | breathing, a slight bob, coat sways |
| walk | 6 | 9 fps | relaxed walk cycle |
| run | 6 | 13 fps | leaning forward, coat flaring back, arms pumping |
| dodge | 4 | 20 fps | low forward dash, coat streaming behind |
| sidestep | 3 | 16 fps | quick sideways hop, wide stance, arms out for balance (still facing forward) |
| backdash | 3 | 15 fps | hop backward while facing forward, leaning back, feet kicking forward |
| attack1 | 4 | 16 fps | high windup, then a **strike on frame 2** (forehand cutlass slash), follow-through, recover |
| attack2 | 4 | 16 fps | backhand slash low to high, **strike on frame 2** |
| attack3 | 5 | 14 fps | pull back, then a lunging thrust, **strike on frame 3**, hold, recover |
| charge | 2 | 8 fps | crouched, sword drawn back, gauntlet glowing (loops) |
| charged | 5 | 14 fps | huge overhead cleave, **strike on frame 3** |
| cast | 6 | 20 fps | thrusts the hand forward, **spell releases on frame 2** |
| hit | 5 | 16 fps | flinch, knocked back, recover |
| ko | 4 | 6 fps | staggers, kneels, collapses, lies on the ground |

**Marine / Rifleman**: frames 48×64, same three facings.

| Animation | Frames | Speed | Motion |
|---|---|---|---|
| idle | 4 | 5 fps | stiff military stance |
| run | 6 | 11 fps | marching run |
| windup | 2 | 8 fps | saber raised high, crackling (Marine) |
| slash | 4 | 16 fps | downward saber slash, **strike on frame 2** |
| aim | 2 | 4 fps | rifle raised to the shoulder, aiming (Rifleman) |
| shoot | 3 | 12 fps | recoil on frame 1, settle back |
| hit | 2 | 8 fps | flinch |
| ko | 3 | 6 fps | collapse |

**Voidling**: frames 40×32, side view only (faces right).
idle 4 (pulsing), move 4 (scuttle), windup 2 (crouched, mouth open, eyes flaring), lunge 2 (stretched, leaping), hit 2, death 5 (dissolving into void particles).

**Nova**: three facings like the Captain (down, up, side facing right), one sheet per facing.
hover 6 (wing-flap loop), fly 6 (faster flaps, body tilted forward), attack 4
(rears back, then breathes frost on **frame 3**), special 5 (wings up, roaring, crystals swirling),
hit 2, ko 4 (falls, ends lying curled on the ground). Imported with `sdv import`
(entry "dragon" in tools/sprite_import.json).

---

## 4. Easiest path: let `sdv import` do the cleanup

If ChatGPT gives you one sheet per facing, laid out with **one animation per row**
(e.g. row 1 idle × 4, row 2 run × 6, row 3 attack1 × 4). The background can be
transparent or solid black; black is removed automatically.

1. Put the PNGs in `assets/source/<character>/`, named `down.png`, `up.png` and `side.png`.
2. List the rows in `tools/sprite_import.json`, top to bottom, with frame counts.
3. Run **`sdv import`**.

The tool finds each figure (blades and effects included) and removes the glow. It shrinks
everything to the game's pixel scale with a shared palette and outline, and lines up the
feet. Then it writes `assets/sprites/<character>_sheet.png`. Any animation you haven't made
yet is filled with stand-ins built from the frames you did make. When you add more rows
later, list them in the JSON and run `sdv import` again.

To check the result by eye, look at the preview in `build/<character>_sheet_preview.png`.

## 4b. Manual path: clean up in a pixel editor

1. **Resize with nearest-neighbor only.** Never use bilinear or bicubic. Shrink to the exact frame size above.
2. **Remove stray colors.** Reduce to the palette ("indexed color" mode helps) and delete semi-transparent edge pixels.
3. **Line up the feet.** Humans stand at **x 24, y 60** in a 48×64 frame. Voidlings stand at **x 20, y 28**. Nova's body is centered.
4. **Play the animation in the editor** and fix any frame where the size or proportions jump.

## 5. Put it in the game

Assemble one PNG per character, with the same layout as the files in `assets/generated/`:
- One row per animation, in the order of the tables above.
- Humans need 3 rows per animation: down, then up, then side.
- Frames go left to right. Leave empty cells transparent.

Save it as:

| Character | File |
|---|---|
| Captain | `assets/sprites/pirate_sheet.png` |
| Marine | `assets/sprites/marine_sheet.png` |
| Rifleman | `assets/sprites/rifleman_sheet.png` |
| Voidling | `assets/sprites/voidling_sheet.png` |
| Nova | `assets/sprites/dragon_sheet.png` |

The game uses your sheet automatically instead of the generated one. If the size
doesn't match the expected layout, it prints a warning and keeps the placeholder.

## Example: a full request

```
[MASTER STYLE PROMPT]
[The Captain CHARACTER block]

Create a horizontal sprite strip of the Captain performing the "run" animation:
6 frames, left to right, evenly spaced, each frame 48x64 pixels. Facing: side
view, facing right. Feet on the same baseline in every frame. Motion: energetic
run cycle, leaning forward, long coat flaring behind, cutlass held low in the
right hand, gauntlet arm pumping. Transparent background.
```
