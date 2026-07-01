# TileMap Setup Guide

The environment tile sheets live in `assets/tiles/`. This guide walks through
importing them into Godot's TileMap system to replace the ColorRect placeholders
in `city_day.tscn` and `city_night.tscn`.

---

## Step 1 — Import tile textures

1. Run `python download_portraits.py` to download all assets if you haven't already.
2. In Godot's **FileSystem** panel, navigate to `assets/tiles/`.
3. Select all `.png` files → right-click → **Reimport**.
4. In the Import dock set:
   - **Filter**: Nearest (no interpolation)
   - **Mipmaps**: Off
   - Click **Reimport**.

---

## Step 2 — Create a TileSet resource

1. In the FileSystem panel, right-click `assets/tiles/` → **New Resource…** →
   choose **TileSet** → save as `assets/tiles/city_tileset.tres`.
2. Open the **TileSet** editor (bottom dock).
3. For each tile sheet drag it from the FileSystem into the TileSet editor's
   **Texture** region. Assign tile size **64 × 64**.

### Tile sheets and their regions

| File | Tile size | Usage |
|------|-----------|-------|
| `cobblestone_day.png` | 64×64 | Street ground (day) |
| `cobblestone_night.png` | 64×64 | Street ground (night) |
| `tenement_facade.png` | 64×64 | Building walls |
| `temple_stone.png` | 64×64 | Temple area walls/steps |
| `interior_floor.png` | 64×64 | Apartment kitchen floor |

---

## Step 3 — Replace ColorRect floors in city_day.tscn

1. Open `scenes/world/city_day.tscn`.
2. Delete the `FloorRect` ColorRect node.
3. Add a **TileMapLayer** node as child of the scene root.
4. In the Inspector set **TileSet** → `assets/tiles/city_tileset.tres`.
5. Paint tiles using the TileMap editor dock.

Repeat for `city_night.tscn` using the `cobblestone_night` tiles.

---

## Step 4 — Add prop sprites

The prop sprite sheets are in `assets/sprites/props/`. Each file contains
multiple props on a single image. Add them as **Sprite2D** nodes:

1. Add a Sprite2D child node at the desired world position.
2. Set **Texture** to the prop sheet (e.g. `chai_stall.png`).
3. Set **Region Enabled = true** and drag the region rect to isolate the
   specific prop you want.
4. Add a **StaticBody2D** + **CollisionShape2D** sibling for solid props.

### Prop sprite positions (from current ColorRect placeholders)

| Prop | Scene position | Sheet |
|------|---------------|-------|
| Chai stall (Champa) | `(60, 180)` | `chai_stall.png` |
| Municipal office (Desai) | `(380, 80)` | `municipal_office.png` |
| Temple steps (Raju) | `(240, 50)` | `temple_stone.png` (use as backdrop) |
| Street lamps | crossroads | `street_props.png` |
| Vegetable cart | market area | `market_props.png` |

---

## Step 5 — Night scene

`city_night.tscn` uses the same layout. Swap:
- Floor tiles → `cobblestone_night.png`
- Remove building colour accents (they're baked into night tile sheets)
- PointLight2D lanterns remain unchanged

---

## Godot TileSet quick-reference

```
TileMapLayer node
  ├── TileSet resource (.tres)
  │     ├── TileSetSource (AtlasTilesource)
  │     │     └── Texture = cobblestone_day.png
  │     │         Tile size = 64 × 64
  │     └── (one source per texture file)
  └── painted tile data (embedded in scene)
```

See also: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html
