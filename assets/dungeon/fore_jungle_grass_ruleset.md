# Fore - Jungle Grass generated-geometry rules

Source art: `assets/dungeon/fore_jungle_grass.png` is a **224×128** sheet of **16×16** logical tiles, arranged as **14 columns × 8 rows**.

## Generated ground must use the three-deep dirt megablock

The visible platform floor should not be built by repeating a single grass tile or by repeating rounded edge pieces. The sheet includes a larger dirt megablock that already encodes the intended transition:

- grass cap
- grass-underhang/body transition
- middle dirt
- lower dirt

For generated rooms, use the three-deep megablock at `(8..11, 0..3)` for the exposed surface cell. This removes the black gap under the grass and matches the tileset example that shows three blocks of dirt depth.

## Continuous generated fill tiles

| Generated use | Atlas tile(s) | Reason |
| --- | --- | --- |
| Exposed 3-deep floor surface | `(8..11, 0..3)` | Uses the intended megablock rows instead of a fake repeated grass strip. |
| Buried dirt/interior fill | `(8, 2)` | Continuous dirt for floor cells that have dirt directly above. |
| Cave wall/platform fill | `(2, 6)` | Continuous cave fill sample; avoids transparent connector holes. |

## Room generation rule

The generated bottom ground is three gameplay cells deep so the surface has enough vertical dirt mass to match the atlas example. Gameplay objects spawn one cell above that surface:

- floor cells: `ROOM_H - 1`, `ROOM_H - 2`, and `ROOM_H - 3`
- player/block/pickup placement row: `ROOM_H - 4`
- ladder bottom row: `ROOM_H - 4`

## Runtime rendering rule

Each 64×64 gameplay cell is drawn as a 4×4 set of 16×16 samples.

- If a floor subtile has no floor directly above it, it uses the matching coordinate from `(8..11, 0..3)`.
- If a floor subtile has floor directly above it, it uses buried dirt `(8, 2)` so stacked terrain remains continuous.
- Walls and platforms use cave fill `(2, 6)` for procedural geometry.

## Reserved tiles

The remaining connector/variant areas are useful art, but they are not safe as procedural fill:

- Foreground edge/socket variants around `(0..7, 0..3)` and parts of `(4..11, 0..3)` that are not the generated surface megablock.
- Low-alpha cave connector/socket areas around `(0..7, 4..7)` and `(8..11, 4..7)`.
- Sloped/large decorative pieces around `(12..13, 0..7)`.

Use reserved tiles only for hand-authored edge decoration or a future boundary-only autotile implementation that places them only on real exposed boundaries.
