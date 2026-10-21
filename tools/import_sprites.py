"""Import AI-generated sprite sheets (e.g. from ChatGPT) into the game's sheet layout.

Usage:  python tools/import_sprites.py [character]      (or: sdv import)

For each facing listed in tools/sprite_import.json this script:
  1. finds every figure on the source sheet (rows top to bottom, frames left to right),
     keeping blades/effects attached to the right frame;
  2. strips the soft glow / semi-transparent fringe;
  3. scales everything with one shared factor so the idle pose is `height` px tall;
  4. reduces to a shared palette (crisp pixels, no blur) and adds a 1 px outline;
  5. anchors each frame by its feet so nothing jitters between frames;
  6. writes assets/sprites/<character>_sheet.png in the exact layout the game expects,
     plus a .json sidecar with the frame size and feet position.

Animations that haven't been drawn yet are filled with stand-ins built from the
drawn frames (listed in FALLBACK), so the character always looks like the new art.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "tools", "sprite_import.json")

# Must match PIRATE_ANIMS order in scripts/render/sprite_factory.gd.
LAYOUTS = {
    "pirate": {
        "anims": [("idle", 4), ("walk", 6), ("run", 6), ("dodge", 4), ("sidestep", 3), ("backdash", 3),
                  ("attack1", 4), ("attack2", 4), ("attack3", 5), ("charge", 2), ("charged", 5),
                  ("cast", 4), ("hit", 2), ("ko", 3)],
        "facings": ["down", "up", "side"],
    },
}

# Stand-ins for animations not drawn yet: (drawn animation, frame index); "lying" = idle rotated flat.
FALLBACK = {
    "idle": [("idle", 0)] * 4,
    "walk": [("run", i) for i in range(6)],
    "run": [("idle", i % 4) for i in range(6)],
    "dodge": [("run", 1), ("run", 2), ("run", 3), ("run", 4)],
    "sidestep": [("run", 0), ("run", 2), ("run", 4)],
    "backdash": [("idle", 0), ("run", 3), ("idle", 2)],
    "attack1": [("idle", 0)] * 4,
    "attack2": [("attack1", i) for i in range(4)],
    "attack3": [("attack1", 0), ("attack1", 0), ("attack1", 1), ("attack1", 2), ("attack1", 3)],
    "charge": [("attack1", 0), ("attack1", 0)],
    "charged": [("attack1", 0), ("attack1", 0), ("attack1", 1), ("attack1", 2), ("attack1", 3)],
    "cast": [("idle", 0), ("attack1", 2), ("attack1", 2), ("attack1", 3)],
    "hit": [("idle", 0), ("idle", 1)],
    "ko": [("idle", 0), ("idle", 2), ("lying", 0)],
}

ALPHA_CUT = 128


# ----------------------------------------------------------------------------- extraction

def _bands(mask, wanted):
    """Row bands that contain pixels, merged until there are `wanted` of them."""
    occ = mask.any(axis=1)
    bands = []
    start = None
    for y, v in enumerate(occ):
        if v and start is None:
            start = y
        elif not v and start is not None:
            bands.append([start, y])
            start = None
    if start is not None:
        bands.append([start, len(occ)])
    while len(bands) > wanted:
        gaps = [bands[i + 1][0] - bands[i][1] for i in range(len(bands) - 1)]
        i = int(np.argmin(gaps))
        bands[i][1] = bands[i + 1][1]
        del bands[i + 1]
    if len(bands) < wanted:
        raise SystemExit(f"Found {len(bands)} rows of sprites but the config lists {wanted}.")
    return bands


def _light(rgb):
    """Pixels that are near-white and unsaturated (slash arcs, highlights)."""
    mx = rgb.max(axis=-1).astype(int)
    mn = rgb.min(axis=-1).astype(int)
    return (mx > 200) & (mx - mn < 60)


def _peaks(profile, n, min_sep):
    """n strongest peaks of a 1-D profile, at least min_sep apart, sorted left to right."""
    p = profile.astype(float).copy()
    out = []
    for _ in range(n):
        i = int(np.argmax(p))
        out.append(i)
        p[max(0, i - min_sep):i + min_sep] = -1
    return sorted(out)


def extract(path, rows):
    """Returns {anim: [frame, ...]}; a frame is dict(rgba, feet_y, center_x) in source pixels."""
    src = np.array(Image.open(path).convert("RGBA"))
    alpha = src[..., 3]
    mask = alpha >= ALPHA_CUT
    out = {}
    for (y0, y1), (anim, count) in zip(_bands(mask, len(rows)), rows):
        band = mask[y0:y1]
        rgb = src[y0:y1, :, :3]
        body = band & ~_light(rgb)
        xs = np.where(band.any(axis=0))[0]
        spacing = (xs[-1] - xs[0]) / count
        profile = ndimage.uniform_filter1d(body.sum(axis=0).astype(float), size=max(3, int(spacing / 3)))
        centers = _peaks(profile, count, int(spacing * 0.55))
        cuts = [(centers[i] + centers[i + 1]) // 2 for i in range(count - 1)]
        owner = np.zeros(band.shape, dtype=int) - 1

        labels, n = ndimage.label(band, structure=np.ones((3, 3)))
        sizes = ndimage.sum(band, labels, index=np.arange(1, n + 1))
        # 1. Each figure's main body = the biggest blob under its column peak.
        seeds = {}
        for f, cx in enumerate(centers):
            col = labels[:, max(0, cx - 3):cx + 4]
            labs, cnt = np.unique(col[col > 0], return_counts=True)
            if len(labs):
                seeds.setdefault(int(labs[np.argmax(cnt)]), []).append(f)
        for lab, fs in seeds.items():
            ys, xs_c = np.where(labels == lab)
            if len(fs) == 1:
                owner[ys, xs_c] = fs[0]
            else:
                # Two figures touching: split the shared blob between their columns.
                local_cuts = [(centers[fs[i]] + centers[fs[i + 1]]) // 2 for i in range(len(fs) - 1)]
                owner[ys, xs_c] = np.array(fs)[np.searchsorted(local_cuts, xs_c)]
        # 2. Attach loose pieces (blades, slash arcs, sparkles) to the closest figure:
        #    big pieces first, then small ones (so arc fragments follow their arc).
        rest = [lab for lab in range(1, n + 1) if lab not in seeds]
        rest.sort(key=lambda lab: -sizes[lab - 1])
        # Big pieces (a whole slash arc) go by their center to the nearest figure column;
        # small fragments then go to whichever figure's pixels they touch / sit closest to.
        for lab in rest:
            if sizes[lab - 1] >= 150:
                m = labels == lab
                cx = np.where(m)[1].mean()
                owner[m] = int(np.argmin([abs(cx - c) for c in centers]))
        dist = [ndimage.distance_transform_edt(owner != f) for f in range(count)]
        for lab in rest:
            if sizes[lab - 1] < 150:
                m = labels == lab
                owner[m] = int(np.argmin([d[m].min() for d in dist]))

        frames = []
        for f in range(count):
            sel = owner == f
            ys, xs_f = np.where(sel)
            top, bottom = ys.min(), ys.max() + 1
            left, right = xs_f.min(), xs_f.max() + 1
            crop = np.zeros((bottom - top, right - left, 4), dtype=np.uint8)
            region = src[y0 + top:y0 + bottom, left:right]
            m = sel[top:bottom, left:right]
            crop[m] = region[m]
            crop[..., 3] = np.where(m, 255, 0)
            # Feet: lowest row with a few solid (non-highlight) pixels.
            solid = m & ~_light(region[..., :3])
            row_counts = solid.sum(axis=1)
            feet = int(np.where(row_counts >= 3)[0].max())
            # Body center: mean x of solid pixels in the torso band.
            h = feet
            torso = solid[int(h * 0.3):int(h * 0.85)]
            tx = np.where(torso)[1]
            center = float(tx.mean()) if len(tx) else crop.shape[1] / 2
            frames.append({"rgba": crop, "feet_y": feet, "center_x": center})
        out[anim] = frames
    return out


# ----------------------------------------------------------------------------- processing

def scale_frame(frame, s):
    img = Image.fromarray(frame["rgba"], "RGBA").convert("RGBa")   # premultiplied: no dark fringes
    w = max(1, round(img.width * s))
    h = max(1, round(img.height * s))
    small = np.array(img.resize((w, h), Image.Resampling.LANCZOS).convert("RGBA"))
    a = small[..., 3]
    small[..., 3] = np.where(a >= 110, 255, 0)
    small[small[..., 3] == 0] = 0
    return {"rgba": small, "feet_y": round(frame["feet_y"] * s), "center_x": frame["center_x"] * s}


def build_palette(frames, colors):
    pixels = np.concatenate([f["rgba"][f["rgba"][..., 3] > 0][:, :3] for f in frames])
    strip = Image.fromarray(pixels.reshape(1, -1, 3), "RGB")
    return strip.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def apply_palette(frame, pal):
    rgba = frame["rgba"]
    rgb = Image.fromarray(rgba[..., :3], "RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.array(rgb), rgba[..., 3]])
    out[out[..., 3] == 0] = 0
    frame["rgba"] = out.astype(np.uint8)


def add_outline(canvas, color):
    solid = canvas[..., 3] > 0
    grow = np.zeros_like(solid)
    grow[1:] |= solid[:-1]
    grow[:-1] |= solid[1:]
    grow[:, 1:] |= solid[:, :-1]
    grow[:, :-1] |= solid[:, 1:]
    ring = grow & ~solid
    canvas[ring] = (*color, 255)


def place(frame, size, feet):
    w, h = size
    canvas = np.zeros((h, w, 4), dtype=np.uint8)
    img = frame["rgba"]
    ox = feet[0] - round(frame["center_x"])
    oy = feet[1] - frame["feet_y"]
    x0, y0 = max(0, ox), max(0, oy)
    x1, y1 = min(w, ox + img.shape[1]), min(h, oy + img.shape[0])
    if x1 > x0 and y1 > y0:
        canvas[y0:y1, x0:x1] = img[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    clipped = ox < 0 or oy < 0 or ox + img.shape[1] > w or oy + img.shape[0] > h
    return canvas, clipped


def lying(frame):
    rot = np.rot90(frame["rgba"], 1).copy()
    return {"rgba": rot, "feet_y": rot.shape[0] - 1, "center_x": rot.shape[1] / 2}


# ----------------------------------------------------------------------------- main

def import_character(name, cfg):
    layout = LAYOUTS[name]
    size = tuple(cfg["frame"])
    feet = tuple(cfg["feet"])
    outline = tuple(int(cfg["outline"][i:i + 2], 16) for i in (0, 2, 4))
    rows = [tuple(r) for r in cfg["rows"]]

    raw = {}
    for facing, rel in cfg["facings"].items():
        raw[facing] = extract(os.path.join(ROOT, rel), rows)
        print(f"  {facing}: " + ", ".join(f"{a} x{len(fr)}" for a, fr in raw[facing].items()))

    ref = raw["down"]["idle"][0] if "down" in raw else next(iter(raw.values()))["idle"][0]
    s = cfg["height"] / (ref["feet_y"] + 1)
    print(f"  scale: 1/{1 / s:.2f}  (idle is {ref['feet_y'] + 1}px tall in the source)")

    scaled = {f: {a: [scale_frame(fr, s) for fr in frs] for a, frs in anims.items()} for f, anims in raw.items()}
    pal = build_palette([fr for anims in scaled.values() for frs in anims.values() for fr in frs], cfg["colors"])
    for anims in scaled.values():
        for frs in anims.values():
            for fr in frs:
                apply_palette(fr, pal)

    anims = layout["anims"]
    max_frames = max(c for _, c in anims)
    sheet = np.zeros((len(anims) * len(layout["facings"]) * size[1], max_frames * size[0], 4), dtype=np.uint8)
    drawn, stand_ins, clipped = set(), set(), []
    row = 0
    for anim, count in anims:
        for facing in layout["facings"]:
            have = scaled.get(facing, {})
            if anim in have and len(have[anim]) == count:
                frames = have[anim]
                drawn.add(anim)
            else:
                frames = []
                for src_anim, i in FALLBACK[anim][:count]:
                    if src_anim == "lying":
                        frames.append(lying(have["idle"][0]))
                    else:
                        pool = have.get(src_anim) or have["idle"]
                        frames.append(pool[min(i, len(pool) - 1)])
                stand_ins.add(anim)
            for i, fr in enumerate(frames):
                canvas, was_clipped = place(fr, size, feet)
                add_outline(canvas, outline)
                if was_clipped:
                    clipped.append(f"{anim}_{facing}[{i}]")
                sheet[row * size[1]:(row + 1) * size[1], i * size[0]:(i + 1) * size[0]] = canvas
            row += 1

    out_dir = os.path.join(ROOT, "assets", "sprites")
    os.makedirs(out_dir, exist_ok=True)
    out_png = os.path.join(out_dir, f"{name}_sheet.png")
    Image.fromarray(sheet, "RGBA").save(out_png)
    meta = {"frame": list(size), "feet": list(feet), "drawn": sorted(drawn),
            "stand_ins": sorted(stand_ins - drawn), "source": cfg["facings"]}
    with open(os.path.join(out_dir, f"{name}_sheet.json"), "w") as fh:
        json.dump(meta, fh, indent=2)

    # Big preview with a grid, for checking the result by eye.
    prev_dir = os.path.join(ROOT, "build")
    os.makedirs(prev_dir, exist_ok=True)
    prev = Image.fromarray(sheet, "RGBA")
    bg = Image.new("RGBA", prev.size, (40, 38, 60, 255))
    bg.alpha_composite(prev)
    big = bg.resize((prev.width * 3, prev.height * 3), Image.Resampling.NEAREST)
    px = big.load()
    for x in range(0, big.width, size[0] * 3):
        for y in range(big.height):
            px[x, y] = (90, 90, 120, 255)
    for y in range(0, big.height, size[1] * 3):
        for x in range(big.width):
            px[x, y] = (90, 90, 120, 255)
    big.save(os.path.join(prev_dir, f"{name}_sheet_preview.png"))

    print(f"  wrote {os.path.relpath(out_png, ROOT)}  ({sheet.shape[1]}x{sheet.shape[0]})")
    print(f"  drawn: {', '.join(sorted(drawn))}")
    print(f"  stand-ins (reusing drawn frames until you make them): {', '.join(sorted(stand_ins - drawn))}")
    if clipped:
        print(f"  WARNING: {len(clipped)} frames were cut off at the frame edge, e.g. {clipped[:4]}")


def main():
    with open(CONFIG) as fh:
        config = json.load(fh)
    names = sys.argv[1:] or list(config)
    for name in names:
        print(f"Importing {name}...")
        import_character(name, config[name])


if __name__ == "__main__":
    main()
