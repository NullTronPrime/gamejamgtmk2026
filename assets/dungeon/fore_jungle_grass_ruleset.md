# Fore - Jungle Grass connecting rules

Source art: `assets/dungeon/fore_jungle_grass.png` is a **224×128** sheet of **16×16** logical tiles, arranged as **14 columns × 8 rows**. The previous room renderer treated it as 32×32 tiles; that splits many intended 16×16 edge and diagonal pieces in half, which is why the environment showed incorrect joins.

## Coordinate system

Atlas coordinates in this document are `(x, y)` 16 px tile coordinates, starting at the top-left tile `(0, 0)`.

## High-level layout

| Region | Coordinates | Purpose |
| --- | --- | --- |
| Foreground base chunk | `(0..3, 0..3)` | Canonical 64×64 grass-over-dirt terrain block. Use as the default for solid ground. |
| Foreground connection variants | `(4..11, 0..3)` | Side caps, exposed undersides, and diagonal corner/socket joins for foreground dirt. |
| Sloped/large decoration | `(12..13, 0..4)` plus `(12..13, 5..7)` | Hand-placed triangular/diamond decoration, not general autotile fill. |
| Background/cave base chunk | `(0..3, 4..7)` and `(4..7, 4..7)` | Dark cave/back-wall terrain blocks. |
| Background/cave connection variants | `(8..11, 4..7)` | Cave diagonal corner/socket joins. |
| Foreground accent | `(12..13, 5..7)` | Small grass-topped accent mound; place deliberately rather than via the main autotiler. |

## Neighbor mask

Each generated 64×64 collision cell renders as a 4×4 set of 16×16 atlas tiles. Choose tiles from the eight neighboring cells:

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

Diagonal neighbors are conditional: a diagonal only counts as connected when both supporting cardinal neighbors exist. For example, north-west only connects if north, west, and north-west are all filled. This prevents diagonal-only cells from visually bridging across an empty corner.

## Foreground rules

1. If there is no north neighbor, draw the top two 16 px rows from the base grass cap `(0..3, 0..1)`.
2. If west or east is missing, use the outer side-cap columns from the connection block so the dirt edge remains rounded instead of hard-cut.
3. If north+west exist but north-west is absent, use the upper-left diagonal socket tiles from `(4..5, 0..1)`.
4. If north+east exist but north-east is absent, use the upper-right diagonal socket tiles from `(6..7, 0..1)`.
5. If south+west exist but south-west is absent, use the lower-left diagonal socket tiles from `(4..5, 2..3)`.
6. If south+east exist but south-east is absent, use the lower-right diagonal socket tiles from `(6..7, 2..3)`.
7. Fully surrounded interior dirt uses the dense fill variants `(8..11, 2..3)` to avoid accidental grass in buried cells.

## Background/cave rules

The cave/background layer follows the same eight-neighbor logic as foreground dirt but uses the lower half of the atlas:

- Base cave fill: `(4..7, 4..7)`.
- Upper-left diagonal socket: `(8..9, 4..5)`.
- Upper-right diagonal socket: `(10..11, 4..5)`.
- Lower-left diagonal socket: `(8..9, 6..7)`.
- Lower-right diagonal socket: `(10..11, 6..7)`.

## Implementation note

`DungeonLevel` applies these rules in code using `_neighbor_mask()`, `_floor_subtile()`, and `_cave_subtile()`. Keep the atlas at 16 px granularity; do not reintroduce 32 px sampling for this sheet.
