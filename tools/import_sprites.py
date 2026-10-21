"""Import AI-generated sprite sheets (e.g. from ChatGPT) into the game's sheet layout.

Usage:  python tools/import_sprites.py [character]      (or: sdv import)

Each source in tools/sprite_import.json is one PNG showing one facing, with one
animation per row (top to bottom, frames left to right). For every source this script:
  1. finds each figure, keeping blades / slash arcs / spell effects with the right frame;
  2. strips the soft glow and semi-transparent fringe;
  3. scales it - sheets with an idle row set the base scale (`height` px tall idle),
     other sheets are matched to that idle using their `stand` frame;
  4. reduces everything to one shared palette (crisp pixels) and adds a 1 px outline;
  5. anchors every frame by the feet and hips, so effects don't shift the body;
  6. writes assets/sprites/<character>_sheet.png in the layout the game expects, plus a
     .json sidecar with the frame size and feet position.

Animations that haven't been drawn for a facing are filled with stand-ins built from
that facing's drawn frames (see FALLBACK), so the character always uses the new art.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "tools", "sprite_import.json")

# Must match PIRATE_ANIMS order and frame counts in scripts/render/sprite_factory.gd.
LAYOUTS = {
    "pirate": {
        "anims": [("idle", 4), ("walk", 6), ("run", 6), ("dodge", 4), ("sidestep", 3), ("backdash", 3),
                  ("attack1", 4), ("attack2", 4), ("attack3", 5), ("charge", 2), ("charged", 5),
                  ("cast", 6), ("hit", 5), ("ko", 4)],
        "facings": ["down", "up", "side"],
    },
    # Must match DRAGON_ANIMS in scripts/render/sprite_factory.gd.
    "dragon": {
        "anims": [("hover", 6), ("fly", 6), ("attack", 4), ("special", 5), ("hit", 2), ("ko", 4)],
        "facings": ["down", "up", "side"],
        "fallback": {
            "hover": [("fly", i) for i in range(6)],
            "fly": [("hover", i) for i in range(6)],
            "attack": [("hover", 0)] * 4,
            "special": [("hover", 0)] * 5,
            "hit": [("hover", 0)] * 2,
            "ko": [("side:ko", i) for i in range(4)],
        },
    },
}

# Stand-ins: (animation, frame index). The animation is resolved for the same facing
# (recursively, so it can itself be a stand-in). "side:ko" borrows another facing;
# "lying" is the idle pose rotated flat.
FALLBACK = {
    "idle": [("idle", 0)] * 4,
    "run": [("walk", i) for i in range(6)],
    "walk": [("run", i) for i in range(6)],
    "dodge": [("run", 1), ("run", 2), ("run", 3), ("run", 4)],
    "sidestep": [("dodge", 0), ("dodge", 2), ("dodge", 3)],
    "backdash": [("dodge", 0), ("dodge", 0), ("dodge", 3)],
    "attack1": [("idle", 0)] * 4,
    "attack2": [("attack1", i) for i in range(4)],
    "attack3": [("attack1", 0), ("attack1", 0), ("attack1", 1), ("attack1", 2), ("attack1", 3)],
    "charge": [("attack2", 0), ("attack2", 0)],
    "charged": [("attack2", 0), ("attack2", 0), ("attack2", 1), ("attack2", 2), ("attack2", 3)],
    "cast": [("idle", 0), ("attack1", 2), ("attack1", 2), ("attack1", 3), ("attack1", 3), ("idle", 0)],
    "hit": [("idle", 0), ("idle", 1), ("idle", 0), ("idle", 1), ("idle", 0)],
    "ko": [("side:ko", 0), ("side:ko", 1), ("side:ko", 2), ("side:ko", 3)],
}

ALPHA_CUT = 128
BIG_PIECE = 150   # pixels; loose pieces at least this big are attached to the nearest body first


# ----------------------------------------------------------------------------- extraction

def _bands(mask, wanted):
    """Row bands that contain pixels, merged until there are `wanted` of them."""
    occ = mask.any(axis=1)
    bands, start = [], None
    for y, v in enumerate(occ):
        if v and start is None:
            start = y
        elif not v and start is not None:
            bands.append([start, y])
            start = None
    if start is not None:
        bands.append([start, len(occ)])
    # Ignore specks (stray pixels a few rows tall).
    tallest = max(b[1] - b[0] for b in bands)
    bands = [b for b in bands if b[1] - b[0] >= max(8, tallest * 0.1)]
    # Rows that touch (e.g. a slash arc reaching into the row above) form one tall band:
    # split the tallest band at its thinnest row until there are enough rows.
    counts = mask.sum(axis=1)
    while len(bands) < wanted:
        i = int(np.argmax([b[1] - b[0] for b in bands]))
        b0, b1 = bands[i]
        lo, hi = b0 + int((b1 - b0) * 0.25), b0 + int((b1 - b0) * 0.75)
        cut = lo + int(np.argmin(counts[lo:hi]))
        bands[i:i + 1] = [[b0, cut], [cut, b1]]
    while len(bands) > wanted:
        gaps = [bands[i + 1][0] - bands[i][1] for i in range(len(bands) - 1)]
        i = int(np.argmin(gaps))
        bands[i][1] = bands[i + 1][1]
        del bands[i + 1]
    if len(bands) < wanted:
        raise SystemExit(f"Found {len(bands)} rows of sprites but the config lists {wanted}.")
    return bands


LIGHT_IS_EFFECT = True   # set per character: False for pale/white characters (e.g. an ice dragon)


def _light(rgb):
    """Near-white, unsaturated pixels (blade shine, slash arcs)."""
    if not LIGHT_IS_EFFECT:
        return np.zeros(rgb.shape[:2], dtype=bool)
    mx = rgb.max(axis=-1).astype(int)
    mn = rgb.min(axis=-1).astype(int)
    return (mx > 200) & (mx - mn < 60)


def _peaks(profile, n, min_sep):
    p = profile.astype(float).copy()
    out = []
    for _ in range(n):
        i = int(np.argmax(p))
        out.append(i)
        p[max(0, i - min_sep):i + min_sep] = -1
    return sorted(out)


def remove_solid_background(src, cut=24):
    """For sheets without transparency: key out the dark background.

    Removes near-black pixels connected to the image border, plus enclosed pure-black
    gaps (e.g. between an arm and the body). The character's dark outline may go too;
    a fresh outline is added later anyway.
    """
    rgb = src[..., :3].astype(int)
    if (src[..., 3] < 255).any():
        return src   # already has transparency
    corner = rgb[[0, 0, -1, -1], [0, -1, 0, -1]].max()
    if corner > cut:
        print("    (background isn't black - leaving it as is)")
        return src
    mx = rgb.max(axis=-1)
    lab, _ = ndimage.label(mx <= cut)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    holes = (mx <= 6) & ~bg
    hl, hn = ndimage.label(holes)
    if hn:
        sizes = ndimage.sum(holes, hl, index=np.arange(1, hn + 1))
        bg |= np.isin(hl, np.where(sizes >= 40)[0] + 1)
    out = src.copy()
    out[..., 3] = np.where(bg, 0, 255)
    print("    (removed solid black background)")
    return out


def extract(path, rows):
    """Returns {anim: [frame, ...]}; frame = dict(rgba, feet_y, center_x, height) in source px."""
    src = remove_solid_background(np.array(Image.open(path).convert("RGBA")))
    mask = src[..., 3] >= ALPHA_CUT
    out = {}
    for (y0, y1), row in zip(_bands(mask, len(rows)), rows):
        anim, count = row[0], row[1]
        band = mask[y0:y1]
        rgb = src[y0:y1, :, :3]
        body = band & ~_light(rgb)
        xs = np.where(band.any(axis=0))[0]
        spacing = (xs[-1] - xs[0]) / count
        profile = ndimage.uniform_filter1d(body.sum(axis=0).astype(float), size=max(3, int(spacing / 3)))
        centers = _peaks(profile, count, int(spacing * 0.55))

        labels, n = ndimage.label(band, structure=np.ones((3, 3)))
        sizes = ndimage.sum(band, labels, index=np.arange(1, n + 1))
        owner = np.full(band.shape, -1, dtype=int)
        seed_owner = np.full(band.shape, -1, dtype=int)

        # 1. Main body of each figure = the biggest blob under its column peak.
        seeds = {}
        for f, cx in enumerate(centers):
            col = labels[:, max(0, cx - 3):cx + 4]
            labs, cnt = np.unique(col[col > 0], return_counts=True)
            if len(labs):
                seeds.setdefault(int(labs[np.argmax(cnt)]), []).append(f)
        for lab, fs in seeds.items():
            ys, xs_c = np.where(labels == lab)
            if len(fs) == 1:
                who = np.full(len(xs_c), fs[0])
            else:   # two figures touching: split the shared blob between their columns
                local_cuts = [(centers[fs[i]] + centers[fs[i + 1]]) // 2 for i in range(len(fs) - 1)]
                who = np.array(fs)[np.searchsorted(local_cuts, xs_c)]
            owner[ys, xs_c] = who
            seed_owner[ys, xs_c] = who

        # 2. Loose pieces (blades, arcs, spell effects, sparks): big ones go to the nearest
        #    body, then small fragments go to whatever they sit closest to.
        rest = sorted((lab for lab in range(1, n + 1) if lab not in seeds), key=lambda lab: -sizes[lab - 1])
        dist = [ndimage.distance_transform_edt(seed_owner != f) for f in range(count)]
        for lab in rest:
            if sizes[lab - 1] >= BIG_PIECE:
                m = labels == lab
                owner[m] = int(np.argmin([d[m].min() for d in dist]))
        dist = [ndimage.distance_transform_edt(owner != f) for f in range(count)]
        for lab in rest:
            if sizes[lab - 1] < BIG_PIECE:
                m = labels == lab
                near = [d[m].min() for d in dist]
                # Tiny specks floating far from every figure are leftovers (e.g. the tip
                # of a breath effect drifting toward the next frame): drop them.
                if min(near) > spacing * 0.12:
                    continue
                owner[m] = int(np.argmin(near))

        frames = []
        for f in range(count):
            sel = owner == f
            ys, xs_f = np.where(sel)
            if len(ys) == 0:
                raise SystemExit(f"Couldn't find frame {f + 1} of '{anim}' in {os.path.basename(path)} "
                                 f"(row at y={y0}-{y1}, figure columns found at {centers}).")
            top, bottom = ys.min(), ys.max() + 1
            left, right = xs_f.min(), xs_f.max() + 1
            region = src[y0 + top:y0 + bottom, left:right]
            m = sel[top:bottom, left:right]
            crop = np.zeros((bottom - top, right - left, 4), dtype=np.uint8)
            crop[m] = region[m]
            crop[..., 3] = np.where(m, 255, 0)
            # Anchor on the body only (seed blob), ignoring effects and blade shine.
            solid = (seed_owner[top:bottom, left:right] == f) & ~_light(region[..., :3])
            if solid.sum() < 50:
                solid = m
            rows_with = np.where(solid.sum(axis=1) >= 3)[0]
            feet = int(rows_with.max())
            head = int(rows_with.min())
            h = feet - head
            # Hips/legs give a stable horizontal anchor (arms and effects swing around).
            hips = solid[head + int(h * 0.55):feet + 1]
            hx = np.where(hips)[1]
            center = float(np.median(hx)) if len(hx) else crop.shape[1] / 2
            frames.append({"rgba": crop, "feet_y": feet, "center_x": center, "height": h + 1})
        out[anim] = frames   # in source order; any "map" is applied after scaling
    return out


# ----------------------------------------------------------------------------- processing

def scale_frame(frame, s):
    img = Image.fromarray(frame["rgba"], "RGBA").convert("RGBa")   # premultiplied: no dark fringes
    w = max(1, round(img.width * s))
    h = max(1, round(img.height * s))
    small = np.array(img.resize((w, h), Image.Resampling.LANCZOS).convert("RGBA"))
    small[..., 3] = np.where(small[..., 3] >= 110, 255, 0)
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
    canvas[grow & ~solid] = (*color, 255)


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
    global LIGHT_IS_EFFECT
    LIGHT_IS_EFFECT = cfg.get("light_is_effect", True)
    layout = LAYOUTS[name]
    fallback = layout.get("fallback", FALLBACK)
    base_anim = cfg.get("base_anim", "idle")
    counts = dict(layout["anims"])
    size = tuple(cfg["frame"])
    feet = tuple(cfg["feet"])
    outline = tuple(int(cfg["outline"][i:i + 2], 16) for i in (0, 2, 4))

    # Extract every source (still in source pixels).
    raw = {}       # facing -> anim -> frames
    sources = []
    for src in cfg["sources"]:
        rows = [tuple(r[:2]) + ((r[2],) if len(r) > 2 else ()) for r in src["rows"]]
        got = extract(os.path.join(ROOT, src["file"]), rows)
        sources.append((src, got))
        print(f"  {src['facing']:>4} {os.path.basename(src['file'])}: " + ", ".join(f"{a} x{len(f)}" for a, f in got.items()))

    # Base scale from the down-facing base pose (idle); other sheets are matched to their
    # facing's base pose. "each_facing_own_scale": every sheet with the base pose is
    # normalized to `height` on its own (for facings drawn as separate images).
    base = next(g for s, g in sources if s["facing"] == "down" and base_anim in g)
    s0 = cfg["height"] / base[base_anim][0]["height"]
    own = cfg.get("each_facing_own_scale", False)

    def base_scale(got):
        return cfg["height"] / got[base_anim][0]["height"] if own else s0

    idle_h = {s["facing"]: g[base_anim][0]["height"] * base_scale(g) for s, g in sources if base_anim in g}
    print(f"  base scale: 1/{1 / s0:.2f}")
    scaled = {}
    for src, got in sources:
        facing = src["facing"]
        if base_anim in got:
            s = base_scale(got)
            if own:
                print(f"    {os.path.basename(src['file'])}: scale 1/{1 / s:.2f}")
        else:
            first = next(iter(got.values()))
            stand = first[src.get("stand", 0)]
            s = idle_h[facing] / stand["height"]
            print(f"    {os.path.basename(src['file'])}: scale 1/{1 / s:.2f} (matched to {facing} idle)")
        maps = {r[0]: r[2] for r in src["rows"] if len(r) > 2}
        for anim, frames in got.items():
            frames = [scale_frame(fr, s) for fr in frames]
            if anim in maps:   # repeat / reorder frames to the count the game needs
                frames = [frames[i] for i in maps[anim]]
            scaled.setdefault(facing, {})[anim] = frames

    all_frames = [fr for anims in scaled.values() for frs in anims.values() for fr in frs]
    pal = build_palette(all_frames, cfg["colors"])
    for fr in all_frames:
        apply_palette(fr, pal)

    # Resolve each (facing, animation): drawn art, else stand-ins.
    drawn, stand_ins = {f: [] for f in layout["facings"]}, {f: [] for f in layout["facings"]}

    def resolve(facing, anim, depth=0):
        have = scaled.get(facing, {})
        if anim in have and len(have[anim]) == counts.get(anim, len(have[anim])):
            return have[anim]
        if depth > 6:
            return have[base_anim]
        out = []
        for src_anim, i in fallback[anim][:counts[anim]]:
            if src_anim == "lying":
                out.append(lying(have[base_anim][0]))
                continue
            f2 = facing
            if ":" in src_anim:
                f2, src_anim = src_anim.split(":")
            pool = resolve(f2, src_anim, depth + 1)
            out.append(pool[min(i, len(pool) - 1)])
        return out

    anims = layout["anims"]
    max_frames = max(c for _, c in anims)
    sheet = np.zeros((len(anims) * len(layout["facings"]) * size[1], max_frames * size[0], 4), dtype=np.uint8)
    clipped = []
    row = 0
    for anim, count in anims:
        for facing in layout["facings"]:
            have = scaled.get(facing, {})
            (drawn if anim in have else stand_ins)[facing].append(anim)
            for i, fr in enumerate(resolve(facing, anim)):
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
    meta = {"frame": list(size), "feet": list(feet), "body_height": cfg["height"],
            "drawn": drawn, "stand_ins": stand_ins, "sources": [s["file"] for s in cfg["sources"]]}
    with open(os.path.join(out_dir, f"{name}_sheet.json"), "w") as fh:
        json.dump(meta, fh, indent=2)

    prev_dir = os.path.join(ROOT, "build")
    os.makedirs(prev_dir, exist_ok=True)
    prev = Image.fromarray(sheet, "RGBA")
    bg = Image.new("RGBA", prev.size, (40, 38, 60, 255))
    bg.alpha_composite(prev)
    bg.resize((prev.width * 2, prev.height * 2), Image.Resampling.NEAREST).save(
        os.path.join(prev_dir, f"{name}_sheet_preview.png"))

    print(f"  wrote {os.path.relpath(out_png, ROOT)}  ({sheet.shape[1]}x{sheet.shape[0]}, frames {size[0]}x{size[1]})")
    for facing in layout["facings"]:
        print(f"  {facing:>4}: drawn {', '.join(drawn[facing])}")
        print(f"        stand-ins {', '.join(stand_ins[facing]) or '-'}")
    if clipped:
        print(f"  WARNING: {len(clipped)} frames cut off at the frame edge: {', '.join(clipped[:8])}")


def main():
    with open(CONFIG) as fh:
        config = json.load(fh)
    for name in sys.argv[1:] or list(config):
        print(f"Importing {name}...")
        import_character(name, config[name])


if __name__ == "__main__":
    main()
