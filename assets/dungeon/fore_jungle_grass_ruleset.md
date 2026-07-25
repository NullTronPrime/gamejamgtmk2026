# Fore - Jungle Grass generated-geometry rules

Source art: `assets/dungeon/fore_jungle_grass.png` is a **224×128** sheet of **16×16** logical tiles, arranged as **14 columns × 8 rows**.

## Correct generated-ground layering

The foreground sheet has a 3×3 dirt/grass megablock. Procedural floors should use that megablock's top row for the visible surface, not the separate 3×1 edge strip.

For generated floors:

1. Draw opaque dirt backing `(2, 2)` under every 16×16 floor subtile.
2. On the top exposed source row only, use the 3×3 megablock top row:
   - left end: `(8, 0)`
   - tileable middle: `(9, 0)`
   - right end: `(10, 0)`
3. Use `(9, 0)` for every connected interior micro-tile. Use `(8, 0)` only when there is no west neighbor and `(10, 0)` only when there is no east neighbor.
4. Do not use the separate grass edge strip as generated top fill, because it keeps edge/underhang artifacts in the middle of long platforms.
5. Keep rows below the top as opaque dirt backing so the ground body stays continuous.

## Continuous generated fill tiles

| Generated use | Atlas tile(s) | Reason |
| --- | --- | --- |
| Exposed surface left end | `(8, 0)` | Left cap from the 3×3 megablock. |
| Exposed surface middle | `(9, 0)` | Center of the 3×3 megablock; this is the repeatable top tile. |
| Exposed surface right end | `(10, 0)` | Right cap from the 3×3 megablock. |
| Opaque dirt backing/interior fill | `(2, 2)` | Fully opaque dirt drawn under floor art so transparent pixels reveal dirt instead of background. |
| Cave wall/platform fill | `(2, 6)` | Continuous cave fill sample; avoids transparent connector holes. |

## Room generation rule

The generated bottom ground remains three gameplay cells deep so the surface has enough vertical dirt mass. Gameplay objects spawn one cell above that surface:

- floor cells: `ROOM_H - 1`, `ROOM_H - 2`, and `ROOM_H - 3`
- player/block/pickup placement row: `ROOM_H - 4`
- ladder bottom row: `ROOM_H - 4`

## Runtime rendering rule

Each 64×64 gameplay cell is drawn as a 4×4 set of 16×16 samples.

- Every floor subtile first draws opaque dirt backing `(2, 2)`.
- If the whole floor cell is exposed on top, source row `0` overlays the 3×3 megablock top row.
- West/east micro-neighbors choose the surface tile: no west → `(8, 0)`, no east → `(10, 0)`, otherwise `(9, 0)`.
- Source rows `1..3` and all buried cells remain solid dirt `(2, 2)`.
- Walls and platforms use cave fill `(2, 6)` for procedural geometry.

## Reserved tiles

The remaining connector/variant areas are useful art, but they are not safe as procedural fill:

- The separate grass edge strip around `(0..3, 0)` should not be used for generated long-platform middles.
- Sparse foreground clumps and edge/socket variants around `(4..11, 0..3)` outside the 3×3 top row choices above.
- Low-alpha cave connector/socket areas around `(0..7, 4..7)` and `(8..11, 4..7)`.
- Sloped/large decorative pieces around `(12..13, 0..7)`.

Use reserved tiles only for hand-authored edge decoration or a future boundary-only autotile implementation that places them only on real exposed boundaries.
