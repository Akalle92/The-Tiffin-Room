# The Tiffin Route — Art Direction (single source of truth)

This document locks the visual style so every regenerated asset stays coherent.
It doubles as the prompt reference for Higgsfield `generate_image`.

## Core style
- **Perspective:** top-down / three-quarter classic 2D RPG (Stardew Valley / early Zelda),
  matching the orthogonal 480x270 viewport and 4-directional WASD movement.
- **Rendering:** crisp **pixel art**, hard edges, no anti-aliased blur. Imported in Godot with
  **Filter = Nearest, Mipmaps = Off** (`project.godot` already sets `default_texture_filter=0`).
- **Mood:** warm, humane, a little melancholic. A dense Indian city that feels lived-in.

## Palette
- **Day:** warm turmeric / amber sunlight, terracotta, brass, dusty ochre streets, saffron accents.
  Canvas modulate `Color(1.0, 0.92, 0.75)` (see `scripts/world/DayNightController.gd`).
- **Night / spirit:** cool indigo and violet, lantern-gold highlights, soft glow.
  Canvas modulate `Color(0.18, 0.15, 0.32)`; lanterns are warm gold `PointLight2D`s.

## Asset specs
| Asset type | Canvas | Frame grid | Background | Notes |
|-----------|--------|-----------|------------|-------|
| Character sheet | 1024x1024 | 4x4 (dir x frame) OR 4x2 idle | **transparent PNG** | Rows = down/up/left/right, cols = walk frames. Full-body, tiny (feet centered). |
| Portrait (bust) | 1024x1024 | single | transparent or flat | Head-and-shoulders only. NO title bar, NO text box, NO UI frame. |
| Ground tile | 512x512 | single, **seamless** | opaque | Must tile edge-to-edge with no gutters/margins/borders. |
| Building tile | 512x512 | single, seamless | opaque | Facade wall that tiles horizontally. |
| Prop | 1024x1024 | single | **transparent PNG** | Top-down / slight 3-quarter. One object, centered, own shadow only. |
| UI frame | 1024x1024 | single | transparent | 9-slice friendly: solid border, empty flat center. |

## Hard rules for every prompt (avoid the old "concept sheet" mistakes)
Include in the **prompt**: `pixel art, top-down game asset, clean, centered`.
Include as **negative / "do not"** intent:
- NO text, letters, labels, titles, captions, watermarks
- NO panel borders, frames, or grid lines drawn into the image (unless it IS a UI frame)
- NO baked-in ground/floor under characters or props (transparent background instead)
- NO isometric perspective for characters/tiles (keep top-down)
- NO photorealism — stylized pixel art only

## The five NPCs (for portrait + character prompts)
- **Player** — young dabbawala, white kurta, red turban / Gandhi cap, tiffin-tin stack carried on head or in a shoulder sling.
- **Mrs. Mehta** — elderly widow, white sari, silver hair in a bun, gentle grief in the eyes. (Flat 4B)
- **Raju** — ~12-year-old runaway schoolboy, worn uniform shirt, small satchel. (Temple steps)
- **Desai Sahib** — middle-aged municipal clerk, short-sleeve shirt, glasses, tired. (Window 3)
- **Arjun** — estranged adult son, plain shirt, closed-off posture. (Family home)
- **Champa Tai** — warm middle-aged tea-stall owner, apron, headscarf, brass kettle. (Corner stall)

Spirit / night variants: same character, cooler indigo palette, soft translucent glow,
slightly ethereal — same silhouette so they read as the same person.

## Environment set
All world tiles ship at **64x64** so tiling density matches the ~40px characters
(windows/doors must never dwarf a person).
- `cobblestone_day` / `cobblestone_night` — seamless street ground tile.
- `roof_terracotta` — seamless top-down barrel-tile roof (procedural, `tools/make_roof.py`).
- `tenement_facade` — seamless tenement wall (day, NW block).
- `bazaar_shopfront` — seamless shopfront wall with awnings (day, S blocks).
- `temple_wall` — seamless carved temple wall with marigold garlands (day, NE block).
- `tenement_night` — seamless night tenement with warm lit windows (all night blocks).

## Block anatomy (why the city stopped looking like wallpaper)
Every city block is layered top-down: **roof strip → eave shadow line → facade
(street-level face) → drop shadow on the street → walkable ground**. Facades are
only ever the *face* of a building, never a fill texture for a whole region.
NPCs, props, and the player live exclusively on the street cross
(horizontal lane y 105-165, vertical lane x 195-245).
- `temple_stone` — seamless temple stone.
- `interior_floor` — seamless apartment kitchen floor.
- Props: `chai_stall`, `municipal_office`, `market_cart`, `street_lamp`.

## UI skin
- `dialogue_frame` — a stainless tiffin-tin panel border, 9-slice, empty center.
- `journal_cover` — worn cloth-bound delivery ledger texture.
- `title_key_art` — hero shot: dabbawala on a bicycle in a glowing bazaar street at dusk (title screen background, 16:9).
- `ending_key_art` — quiet dawn lane, a lone tiffin on a doorstep, marigold petals (ending screen background, 16:9).
