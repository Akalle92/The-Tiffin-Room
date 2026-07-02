"""Strip the baked checkerboard background from bust portraits.

Flood fill seeded ONLY from the top edge and the upper part of the side
edges (the bottom of a bust portrait is figure, not background). Pixels
join the region only if they match one of the two checker tones learned
from the top corners. A tiny neighbour-step tolerance rides anti-aliased
checker seams but cannot cross the figure's dark outline.

Safety: if a result clears more than MAX_CLEAR of the image, the file is
left untouched and reported, so a bad mask can never ship silently.
"""
import os
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NPC_DIR = os.path.join(ROOT, "assets", "sprites", "npcs")

PALETTE_TOL = 22
STEP_TOL = 12
SIDE_SEED_FRAC = 0.55   # seed only the top 55% of left/right edges
MAX_CLEAR = 0.88        # reject masks that clear more than this
ISLAND_MAX = 2200       # px² — leftover checker islands smaller than this get removed


def close(a, b, tol):
    return abs(a[0] - b[0]) <= tol and abs(a[1] - b[1]) <= tol and abs(a[2] - b[2]) <= tol


def learn_palette(px, w, h):
    """Sample the top edge band and upper side bands — guaranteed background."""
    seen = []
    pts = []
    for x in range(0, w, 8):
        for y in range(0, 48, 8):
            pts.append((x, y))
    for y in range(0, int(h * SIDE_SEED_FRAC), 8):
        for x in range(0, 48, 8):
            pts.append((x, y))
            pts.append((w - 1 - x, y))
    for x, y in pts:
        c = px[min(x, w - 1), min(y, h - 1)][:3]
        if not any(close(c, s, 16) for s in seen):
            seen.append(c)
    return seen


def is_checker_tone(c):
    """Bright and desaturated — the transparency-checker look."""
    mx, mn = max(c), min(c)
    return mx - mn <= 26 and mx >= 150


def flood(px, w, h, bg, palette, seeds):
    q = deque(seeds)
    while q:
        x, y = q.popleft()
        cur = px[x, y][:3]
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny * w + nx]:
                c = px[nx, ny][:3]
                if any(close(c, p, PALETTE_TOL) for p in palette) or close(c, cur, STEP_TOL):
                    bg[ny * w + nx] = 1
                    q.append((nx, ny))


def build_mask(px, w, h, palette):
    bg = bytearray(w * h)
    seeds = []

    def try_seed(x, y):
        if not bg[y * w + x] and any(close(px[x, y][:3], p, PALETTE_TOL) for p in palette):
            bg[y * w + x] = 1
            seeds.append((x, y))

    for x in range(w):
        try_seed(x, 0)
    for y in range(int(h * SIDE_SEED_FRAC)):
        try_seed(0, y)
        try_seed(w - 1, y)
    flood(px, w, h, bg, palette, seeds)

    # Iteratively absorb leftover checker: any bright desaturated tone still
    # touching the cleared region must be background (outline is dark).
    for _round in range(4):
        new_tones = []
        seeds = []
        for y in range(h):
            row = y * w
            for x in range(w):
                if bg[row + x]:
                    continue
                touching = ((x > 0 and bg[row + x - 1]) or (x < w - 1 and bg[row + x + 1]) or
                            (y > 0 and bg[row - w + x]) or (y < h - 1 and bg[row + w + x]))
                if not touching:
                    continue
                c = px[x, y][:3]
                if is_checker_tone(c):
                    seeds.append((x, y))
                    bg[row + x] = 1
                    if not any(close(c, t, 16) for t in new_tones + palette):
                        new_tones.append(c)
        if not seeds:
            break
        palette = palette + new_tones
        flood(px, w, h, bg, palette, seeds)
    return bg


def cleanup_islands(px, w, h, bg, palette):
    """Remove small leftover opaque components that are mostly checker-coloured."""
    seen = bytearray(w * h)
    for y0 in range(h):
        for x0 in range(w):
            i0 = y0 * w + x0
            if bg[i0] or seen[i0]:
                continue
            # flood this opaque component
            comp = [(x0, y0)]
            seen[i0] = 1
            qi = 0
            checker_hits = 0
            while qi < len(comp):
                x, y = comp[qi]
                qi += 1
                if any(close(px[x, y][:3], p, PALETTE_TOL + 8) for p in palette):
                    checker_hits += 1
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        ni = ny * w + nx
                        if not bg[ni] and not seen[ni]:
                            seen[ni] = 1
                            comp.append((nx, ny))
            if len(comp) <= ISLAND_MAX and checker_hits >= len(comp) * 0.5:
                for x, y in comp:
                    bg[y * w + x] = 1


def process(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    palette = learn_palette(px, w, h)
    bg = build_mask(px, w, h, palette)

    frac = sum(bg) / (w * h)
    if frac > MAX_CLEAR or frac < 0.05:
        return None, frac

    cleanup_islands(px, w, h, bg, palette)

    # 1px feather to kill the anti-alias halo
    extra = []
    for y in range(h):
        row = y * w
        for x in range(w):
            if bg[row + x]:
                continue
            if ((x > 0 and bg[row + x - 1]) or (x < w - 1 and bg[row + x + 1]) or
                    (y > 0 and bg[row - w + x]) or (y < h - 1 and bg[row + w + x])):
                extra.append(row + x)
    for i in extra:
        bg[i] = 1

    for y in range(h):
        for x in range(w):
            if bg[y * w + x]:
                r, g, b, _a = px[x, y]
                px[x, y] = (r, g, b, 0)

    im.save(path)
    return im, frac


def main():
    files = sorted(f for f in os.listdir(NPC_DIR)
                   if f.endswith("_portrait.png") or f.endswith("_spirit_portrait.png"))
    thumbs = []
    for f in files:
        p = os.path.join(NPC_DIR, f)
        im, frac = process(p)
        if im is None:
            print(f"{f:36s} REJECTED (mask would clear {frac * 100:.1f}%) — left untouched")
            im = Image.open(p).convert("RGBA")
        else:
            print(f"{f:36s} cleared {frac * 100:5.1f}%")
        thumbs.append((f, im.resize((256, 256), Image.LANCZOS)))

    cols = 4
    rows = (len(thumbs) + cols - 1) // cols
    grid = Image.new("RGBA", (cols * 256, rows * 256), (255, 0, 255, 255))
    for i, (_f, t) in enumerate(thumbs):
        grid.paste(t, ((i % cols) * 256, (i // cols) * 256), t)
    out = os.path.join(ROOT, "tools", "portrait_check.png")
    grid.convert("RGB").save(out)
    print("review grid:", out)


if __name__ == "__main__":
    main()
