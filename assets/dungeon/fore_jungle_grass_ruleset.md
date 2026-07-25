# Fore - Jungle Grass generated-geometry rules

Source art: `assets/dungeon/fore_jungle_grass.png` is a **224×128** sheet of **16×16** logical tiles, arranged as **14 columns × 8 rows**.

## Correct generated-ground layering

The foreground sheet is not a single repeated fill. It has a lush grass cap, dirt fill, and many connector/decorative pieces with transparency. Procedural room geometry must be layered so transparent art pixels reveal dirt, not the sky/background.

For generated floors:

1. Draw opaque dirt backing `(2, 2)` under every 16×16 floor subtile.
2. On the top exposed gameplay cell only, overlay the lush grass cap block `(0..3, 0..1)`.
3. Do not overlay sparse grass-clump/decorative rows through the body of the ground.
4. Keep buried/stacked floor cells as pure opaque dirt backing.

This keeps the floor continuous while using the proper grass art from the tileset instead of the sparse clump row.

## Continuous generated fill tiles

| Generated use | Atlas tile(s) | Reason |
| --- | --- | --- |
| Exposed lush grass cap overlay | `(0..3, 0..1)` | Proper continuous grass surface from the sheet. |
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
- If the whole floor cell is exposed on top, source rows `0..1` overlay the lush grass cap `(0..3, 0..1)`.
- Source rows `2..3` and all buried cells remain solid dirt `(2, 2)`.
- Walls and platforms use cave fill `(2, 6)` for procedural geometry.

## Reserved tiles

The remaining connector/variant areas are useful art, but they are not safe as procedural fill:

- Sparse foreground clumps and edge/socket variants around `(4..11, 0..3)`.
- Low-alpha cave connector/socket areas around `(0..7, 4..7)` and `(8..11, 4..7)`.
- Sloped/large decorative pieces around `(12..13, 0..7)`.

Use reserved tiles only for hand-authored edge decoration or a future boundary-only autotile implementation that places them only on real exposed boundaries.
