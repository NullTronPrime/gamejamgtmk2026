# Fore - Jungle Grass connecting rules

Source art: `assets/dungeon/fore_jungle_grass.png` is a **224×128** sheet of **16×16** logical tiles, arranged as **14 columns × 8 rows**.

## Important implementation rule

The sheet is an autotiling sheet, but not every 16×16 tile is a safe fill tile. Many of the tiles outside the main blocks contain transparent edge/corner/socket shapes. If those connector tiles are used as generic interior fill, the generated level gets square holes and disconnected blobs.

For generated dungeon collision geometry:

1. Render each 64×64 gameplay cell as a 4×4 block of 16×16 atlas samples.
2. Use the coherent foreground block `(0..3, 0..3)` for generated dirt/grass floor.
3. If a 16×16 floor subtile has another floor subtile directly above it, render buried dirt rows from `(0..3, 2..3)` instead of repeating grass.
4. Use dense cave samples for generated walls/platforms; do not use transparent cave connector/socket tiles as fill.
5. Reserve the diagonal/side connector tiles for future hand-authored or true terrain-bitmask placement where empty space around a tile is intentional.

## Coordinate system

Atlas coordinates are `(x, y)` 16 px tile coordinates starting at the top-left tile `(0, 0)`.

## Atlas regions

| Region | Coordinates | Usage |
| --- | --- | --- |
| Foreground generated floor block | `(0..3, 0..3)` | Main 64×64 grass-over-dirt block. Safe for generated solid floor. |
| Buried foreground dirt rows | `(0..3, 2..3)` | Used when another floor subtile exists above, so stacked floor cells do not create repeated grass bands. |
| Foreground connector/socket variants | `(4..11, 0..3)` | Transparent/autotile edge pieces. Do **not** use as generated interior fill. |
| Sloped/large decoration | `(12..13, 0..4)` and `(12..13, 5..7)` | Hand-placed decorative terrain. |
| Low-alpha cave connector area | `(0..7, 4..7)` | Mostly transparent cave edge/socket art. Do **not** use as generated interior fill. |
| Dense cave fill samples | `(8..10, 4..6)` | Safest samples for generated cave walls/platforms. |

## Micro-grid mask

`DungeonLevel` expands each gameplay cell to four 16×16 subtiles in each direction, then computes neighbor information on that micro-grid. The direct north neighbor is currently used to suppress repeated grass in buried floor cells.

| Bit | Neighbor |
| --- | --- |
| `1` | north `(x, y - 1)` |
| `2` | south `(x, y + 1)` |
| `4` | west `(x - 1, y)` |
| `8` | east `(x + 1, y)` |
| `16` | north-west `(x - 1, y - 1)` |
| `32` | north-east `(x + 1, y - 1)` |
| `64` | south-west `(x - 1, y + 1)` |
| `128` | south-east `(x + 1, y + 1)` |

The diagonal bits are still collected for future real edge/socket placement, but the generated room renderer deliberately avoids those transparent socket tiles as fill.
