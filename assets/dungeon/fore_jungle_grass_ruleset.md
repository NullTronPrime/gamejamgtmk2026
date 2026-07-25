# Fore - Jungle Grass generated-geometry rules

Source art: `assets/dungeon/fore_jungle_grass.png` is a **224×128** sheet of **16×16** logical tiles, arranged as **14 columns × 8 rows**.

## What went wrong

The atlas is a connecting/autotile sheet, but most cells are **not continuous fill**. Many tiles are rounded edges, corners, holes, diagonal sockets, or decorative variants with transparent margins. Repeating those tiles in procedural geometry creates visible seams, square holes, and disconnected blobs.

Generated dungeon terrain must therefore use only atlas cells that can repeat continuously.

## Continuous generated fill tiles

| Generated use | Atlas tile | Reason |
| --- | --- | --- |
| Exposed floor grass cap | `(2, 0)` | Repeats horizontally without left/right rounded margins. |
| Dirt directly below exposed grass | `(2, 1)` | Continues the top surface without side gaps. |
| Buried dirt/interior fill | `(2, 2)` | Full opaque dirt fill for stacked cells and lower floor rows. |
| Cave wall/platform fill | `(2, 6)` | Full opaque cave fill sample; avoids transparent connector holes. |

## Runtime rule

Each 64×64 gameplay cell is still drawn as a 4×4 set of 16×16 samples. For every 16×16 sample, `DungeonLevel` checks the micro-grid north neighbor:

- If a floor subtile has no floor directly above it, row `0` uses `(2, 0)`, row `1` uses `(2, 1)`, and rows `2..3` use `(2, 2)`.
- If a floor subtile has floor directly above it, all rows use buried dirt `(2, 2)` so stacked cells remain continuous.
- Walls and platforms always use cave fill `(2, 6)` for procedural geometry.

## Tiles reserved for manual placement

The remaining connector/variant areas are useful art, but they are not safe as procedural fill:

- Foreground edge/socket variants around `(4..11, 0..3)`.
- Low-alpha cave connector/socket areas around `(0..7, 4..7)` and `(8..11, 4..7)`.
- Sloped/large decorative pieces around `(12..13, 0..7)`.

Use those only for hand-authored edge decoration or a future dedicated autotile implementation that places them only on real exposed boundaries.
