#!/usr/bin/env python3
"""Bake the Outskirts ground art.

Outputs (all deterministic, seed fixed):
  art/ground/outskirts_base.png   whole-map ground at half resolution (64 px per 128-px tile)
  art/ground/hazard_{oil,crack,gravel}_{0,1,2}.png   soft-edged overlays drawn at runtime
                                                      on every hazard tile (x, o, :)

Hazard tiles are NOT baked into the base image because outskirts.gd re-rolls them at
runtime; the overlays keep what you see in sync with what slows you down.

Usage:  python3 godot/tools/bake_ground.py   (needs numpy, scipy, pillow)
"""
from pathlib import Path
import re
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "ground"
TILE = 128
PX = 64                      # baked pixels per tile (half resolution)
rng = np.random.default_rng(20261018)


def map_rows():
    src = (ROOT / "scripts" / "outskirts.gd").read_text()
    block = src[src.index("const MAP_ROWS"):]
    block = block[:block.index("]\n")]
    return re.findall(r'"([^"]*)"', block)


def fbm(h, w, scales, weights):
    """Sum of smoothed white noise at several scales, normalised to about -1..1."""
    out = np.zeros((h, w), np.float32)
    for s, wt in zip(scales, weights):
        n = rng.standard_normal((h, w)).astype(np.float32)
        n = ndi.gaussian_filter(n, s, mode="wrap")
        n /= n.std() + 1e-6
        out += n * wt
    return out / sum(weights)


def rgb(c):
    return np.array(c, np.float32)


# ---------------------------------------------------------------- base ground
EXPLICIT = {",": "scrub", "-": "highway", "=": "forecourt", "B": "pad", ".": "asphalt"}


def zone_grid(rows):
    """Explicit zones from the map; hazard/prop/car tiles inherit their neighbours' zone
    so the highway doesn't get asphalt squares where a car or crack tile sits."""
    H, W = len(rows), len(rows[0])
    z = [[EXPLICIT.get(ch) for ch in r] for r in rows]
    for _ in range(8):
        changed = False
        for y in range(H):
            for x in range(W):
                if z[y][x] is None:
                    near = [z[y + dy][x + dx] for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))
                            if 0 <= y + dy < H and 0 <= x + dx < W and z[y + dy][x + dx] not in (None, "pad")]
                    if near:
                        z[y][x] = max(set(near), key=near.count); changed = True
        if not changed:
            break
    return [[c or "asphalt" for c in r] for r in z]


def bake_base():
    rows = map_rows()
    H, W = len(rows), len(rows[0])
    h, w = H * PX, W * PX
    zones = ["asphalt", "highway", "forecourt", "scrub", "pad"]
    label = np.zeros((H, W), np.int32)
    zg = zone_grid(rows)
    for y in range(H):
        for x in range(W):
            label[y, x] = zones.index(zg[y][x])
    label_px = np.kron(label, np.ones((PX, PX), np.int32))

    grain = fbm(h, w, [0.7, 2.0], [1.0, 0.6])
    blotch = fbm(h, w, [18, 60], [1.0, 0.8])

    layers = {}
    # Asphalt: cool dark grey, fine grain, large worn blotches, faint tyre wear.
    a = rgb([50, 53, 57]) + grain[..., None] * 5.0 + blotch[..., None] * 6.0
    tyre = fbm(h, w, [1.5], [1.0])
    tyre = ndi.gaussian_filter1d(tyre, 40, axis=0)  # stretched streaks
    a += (tyre[..., None] * 3.0)
    layers["asphalt"] = a

    # Highway: slightly darker, smoother, with worn lane paint added below.
    layers["highway"] = rgb([42, 45, 49]) + grain[..., None] * 4.0 + blotch[..., None] * 4.0

    # Forecourt: concrete slabs with joints and stains.
    c = rgb([74, 73, 70]) + grain[..., None] * 4.0 + blotch[..., None] * 7.0
    yy, xx = np.mgrid[0:h, 0:w]
    joints = ((xx % PX) < 1) | ((yy % PX) < 1)
    c[joints] *= 0.72
    layers["forecourt"] = c

    # Scrub: dark olive dirt with grass clumps.
    s = rgb([56, 54, 40]) + grain[..., None] * 5.0 + blotch[..., None] * 8.0
    tufts = fbm(h, w, [1.2, 3.0], [1.0, 0.7])
    s[tufts > 1.1] = s[tufts > 1.1] * 0.75 + rgb([44, 56, 34]) * 0.25
    layers["scrub"] = s

    # Building pads: darker concrete, mostly hidden under building art.
    layers["pad"] = rgb([36, 37, 40]) + grain[..., None] * 3.0

    # Soft-edged composite: blur each zone mask a little so seams aren't grid-hard.
    img = np.zeros((h, w, 3), np.float32)
    total = np.zeros((h, w), np.float32)
    for i, z in enumerate(zones):
        m = ndi.gaussian_filter((label_px == i).astype(np.float32), 2.5)
        img += layers[z] * m[..., None]
        total += m
    img /= np.maximum(total, 1e-4)[..., None]

    # Highway paint: solid worn edge lines and dashed lane dividers.
    hw_rows = sorted({y for y, r in enumerate(rows) if r.count("-") > W // 3})
    if hw_rows:
        top, bot = hw_rows[0] * PX, (hw_rows[-1] + 1) * PX
        wear = fbm(h, w, [3.0], [1.0]) > -1.1
        def paint(y0, thick, color, dashed):
            band = np.zeros((h, w), bool)
            band[y0:y0 + thick, :] = True
            if dashed:
                band &= ((xx // 24) % 2 == 0)
            band &= wear
            img[band] = img[band] * 0.35 + rgb(color) * 0.65
        paint(top + 4, 3, [178, 170, 150], False)
        paint(bot - 7, 3, [178, 170, 150], False)
        mid = (top + bot) // 2
        paint(mid - 2, 4, [190, 160, 70], False)
        for y0 in range(top + PX, bot, PX):
            if abs(y0 - mid) > 4:
                paint(y0 - 1, 3, [168, 162, 145], True)

    # Ambient occlusion around anything solid: ground darkens where it meets walls.
    solid = np.isin(np.array([[c for c in r] for r in rows]), list("BTJFPb"))
    solid_px = np.kron(solid.astype(np.uint8), np.ones((PX, PX), np.uint8)).astype(bool)
    dist = ndi.distance_transform_edt(~solid_px)
    ao = np.clip(dist / 14.0, 0, 1) ** 0.7
    img *= (0.62 + 0.38 * ao)[..., None]

    # Gentle vignette toward the map border so the edges fade into the dark.
    ey = np.minimum(yy, h - 1 - yy) / (2.5 * PX)
    ex = np.minimum(xx, w - 1 - xx) / (2.5 * PX)
    edge = np.clip(np.minimum(ex, ey), 0, 1)
    img *= (0.7 + 0.3 * edge)[..., None]

    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(OUT / "outskirts_base.png", optimize=True)
    print("base", w, h, "highway rows", hw_rows[:1], hw_rows[-1:] if hw_rows else None)


# ---------------------------------------------------------------- hazard overlays
DEC = 160          # 128 tile + 16 px feather each side, drawn at 1:1 world scale
CORE = 128


def soft_mask(roughness=10.0, power=6):
    yy, xx = np.mgrid[0:DEC, 0:DEC].astype(np.float32)
    c = (DEC - 1) / 2
    # Rounded-square distance (superellipse) plus edge noise.
    d = (np.abs(xx - c) ** power + np.abs(yy - c) ** power) ** (1 / power)
    d += fbm(DEC, DEC, [4.0], [1.0]) * roughness * 0.5
    # Opaque inside the tile, fading out across the 16-px feather.
    return np.clip((c - d) / 14.0 + 0.55, 0, 1)


def save_rgba(name, color, alpha):
    a = np.clip(alpha, 0, 1)
    arr = np.dstack([np.clip(color, 0, 255), a * 255]).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(OUT / name, optimize=True)


def bake_hazards():
    yy, xx = np.mgrid[0:DEC, 0:DEC]
    for v in range(3):
        # OIL (slippery, 0.7x): near-black glossy pool with a faint cool sheen.
        m = soft_mask(22.0, power=2.6)
        g = fbm(DEC, DEC, [3.0, 10.0], [1.0, 1.0])
        col = rgb([16, 18, 24]) + g[..., None] * 4.0
        n = fbm(DEC, DEC, [7.0], [1.0])
        sheen = np.clip(1 - np.abs(n - 0.6) / 0.08, 0, 1) * 0.5   # thin oily contour streaks
        col += sheen[..., None] * rgb([38, 46, 62])
        save_rgba(f"hazard_oil_{v}.png", col, m * 0.86)

        # CRACKED (0.8x): broken asphalt slabs, dark crack network, dirt in the gaps.
        m = soft_mask(10.0, power=4)
        g = fbm(DEC, DEC, [0.8, 3.0], [1.0, 0.8])
        col = rgb([58, 52, 46]) + g[..., None] * 7.0
        cells = rng.integers(0, DEC, (7, 2))
        dist = np.full((DEC, DEC), 1e9); second = np.full((DEC, DEC), 1e9)
        for cy, cx in cells:
            d = np.hypot(yy - cy, xx - cx) + fbm(DEC, DEC, [5.0], [1.0]) * 3
            second = np.where(d < dist, dist, np.minimum(second, d))
            dist = np.minimum(dist, d)
        crack = np.clip(1 - (second - dist) / 3.0, 0, 1)
        col = col * (1 - crack[..., None] * 0.75) + rgb([20, 17, 14]) * crack[..., None] * 0.75
        edge_light = np.clip(1 - np.abs(second - dist - 4) / 1.5, 0, 1) * 0.25
        col += edge_light[..., None] * 40
        save_rgba(f"hazard_crack_{v}.png", col, m * 0.95)

        # GRAVEL (0.9x): lighter tan-grey stones, readable against asphalt.
        m = soft_mask(7.0, power=4)
        g = fbm(DEC, DEC, [0.6, 2.5], [1.0, 0.7])
        col = rgb([96, 90, 78]) + g[..., None] * 12.0
        stones = fbm(DEC, DEC, [1.0], [1.0])
        col[stones > 1.3] *= 0.7
        col[stones < -1.4] = col[stones < -1.4] * 0.6 + 140 * 0.4
        save_rgba(f"hazard_gravel_{v}.png", col, m * 0.93)
    print("hazard overlays", len(list(OUT.glob("hazard_*.png"))))


if __name__ == "__main__":
    bake_base()
    bake_hazards()
