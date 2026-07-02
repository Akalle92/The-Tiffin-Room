"""Author a seamless top-down terracotta barrel-tile roof texture (64x64),
plus downscale the wall/ground tiles to 64px so tiling density matches the
~40px characters."""
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(ROOT, "assets", "tiles")

random.seed(11)

W = H = 64
ROW_H = 8      # each course of barrel tiles
TILE_W = 8     # each barrel tile across

BASE = (154, 74, 46)
LIGHT = (194, 107, 69)
DARK = (110, 51, 32)
GAP = (74, 34, 22)

img = Image.new("RGB", (W, H))
px = img.load()

for row in range(H // ROW_H):
    y0 = row * ROW_H
    offset = (TILE_W // 2) if row % 2 else 0
    for col in range(-1, W // TILE_W + 1):
        x0 = col * TILE_W + offset
        jitter = random.randint(-10, 10)

        def j(c):
            return tuple(max(0, min(255, v + jitter)) for v in c)

        for dx in range(TILE_W):
            x = (x0 + dx) % W
            for dy in range(ROW_H):
                y = y0 + dy
                if dy == ROW_H - 1:
                    c = GAP                      # gap between courses
                elif dx == 0 or dx == TILE_W - 1:
                    c = j(DARK)                  # barrel edge
                elif dx in (3, 4):
                    c = j(LIGHT)                 # sunlit crown
                else:
                    c = j(BASE)
                # bottom of each course slightly shadowed
                if dy == ROW_H - 2 and c != GAP:
                    c = tuple(max(0, v - 18) for v in c)
                px[x, y] = c

# a few cracked/darker tiles for wear
for _ in range(6):
    row = random.randrange(H // ROW_H)
    col = random.randrange(W // TILE_W)
    offset = (TILE_W // 2) if row % 2 else 0
    for dx in range(1, TILE_W - 1):
        x = (col * TILE_W + offset + dx) % W
        for dy in range(0, ROW_H - 1):
            r, g, b = px[x, row * ROW_H + dy]
            px[x, row * ROW_H + dy] = (int(r * 0.82), int(g * 0.82), int(b * 0.82))

img.save(os.path.join(TILES, "roof_terracotta.png"))
print("roof_terracotta.png written (64x64)")

# ---- downscale existing 128px tiles to 64px for correct density ----
for name in ("tenement_facade", "bazaar_shopfront", "temple_wall",
              "tenement_night", "cobblestone_day", "cobblestone_night"):
    p = os.path.join(TILES, name + ".png")
    im = Image.open(p)
    if im.size != (64, 64):
        im.resize((64, 64), Image.LANCZOS).save(p)
        print(f"{name}.png -> 64x64")
    else:
        print(f"{name}.png already 64")

# tiling preview
prev = Image.new("RGB", (256, 256))
small = Image.open(os.path.join(TILES, "roof_terracotta.png"))
for dx in range(0, 256, 64):
    for dy in range(0, 256, 64):
        prev.paste(small, (dx, dy))
prev.save(os.path.join(ROOT, "tools", "roof_preview.png"))
print("preview written")
