# Fore - Jungle Grass generated-geometry rules

Source art: `assets/dungeon/fore_jungle_grass.png` is a **224×128** sheet of **16×16** logical tiles, arranged as **14 columns × 8 rows**.

## Correct generated-ground layering

The procedural floor needs two layers:

1. Opaque dirt backing under every 16×16 floor subtile: `(2, 2)`.
2. A single exposed top row using the lush grass texture from the top-left surface block.

The sparse clump tiles in the later megablock are not the floor-top texture; they are body/decorative variants and look wrong when repeated as the top grass.

## Top grass slicing

Use the top row of the lush surface block as a left/middle/right strip:

| Role | Atlas tile |
| --- | --- |
| Left end | `(0, 0)` |
| Repeating middle A | `(1, 0)` |
| Repeating middle B | `(2, 0)` |
| Right end | `(3, 0)` |

Only use the left and right pieces at true platform ends. For connected interior micro-tiles, alternate the two middle tiles so the cap stays continuous without repeating end pieces.

## Continuous generated fill tiles

| Generated use | Atlas tile(s) | Reason |
| --- | --- | --- |
| Exposed lush grass cap overlay | `(0..3, 0)` | Correct top grass texture from the sheet. |
| Opaque dirt backing/interior fill | `(2, 2)` | Fully opaque dirt under floor art so transparent pixels reveal dirt instead of background. |
| Cave wall/platform fill | `(2, 6)` | Continuous cave fill sample; avoids transparent connector holes. |

## Runtime rendering rule

Each 64×64 gameplay cell is drawn as a 4×4 set of 16×16 samples.

- Every floor subtile first draws opaque dirt backing `(2, 2)`.
- If the whole floor cell is exposed on top, only source row `0` overlays the grass cap.
- West/east micro-neighbors choose the surface tile: no west → `(0, 0)`, no east → `(3, 0)`, otherwise alternate `(1, 0)` and `(2, 0)`.
- Source rows `1..3` and all buried cells remain solid dirt `(2, 2)`.
- Walls and platforms use cave fill `(2, 6)` for procedural geometry.

## Room generation rule

The generated bottom ground remains three gameplay cells deep so the surface has enough vertical dirt mass. Gameplay objects spawn one cell above that surface:

- floor cells: `ROOM_H - 1`, `ROOM_H - 2`, and `ROOM_H - 3`
- player/block/pickup placement row: `ROOM_H - 4`
- ladder bottom row: `ROOM_H - 4`
