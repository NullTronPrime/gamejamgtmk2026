# Fore - Jungle Grass Tileset Ruleset

## Source
- File: Fore - Jungle Grass.png (224×128 px)
- Tile size: 32×32 px
- Grid: 7 columns × 4 rows
- Palette: Indexed (P) with transparency

---

## Merged Chunks

### Chunk A — 2×2 Foreground Block
- **Position**: (0,0) to (1,1) — cols 0-1, rows 0-1
- **Size**: 64×64 px
- **Content**: Grass top (row 0) over dirt body (row 1)
- **All internal edges connected**: H(0,0-1), H(1,0-1), V(0-1,0), V(0-1,1)
- **Role**: Core terrain block — grass surface with dirt underneath. Repeat this 2×2 horizontally to form flat ground.

### Chunk B — 3×2 Background Cave
- **Position**: (0,2) to (2,3) — cols 0-2, rows 2-3
- **Size**: 96×64 px
- **Content**: Dark background cave wall
- **All internal edges connected**: H on all rows, V at cols 0-1
- **Role**: Underground/background cave section. Use behind terrain to show depth.

## Tile Legends (32×32 cells)

### Row 0 — Grass Top Edge (Foreground Surface)
| Cell | Type | Role | Standalone? |
|------|------|------|-------------|
| (0,0) | GRASS | Left grass top — part of Chunk A | No (use with 0,1 and body below) |
| (0,1) | GRASS | Right grass top — part of Chunk A | No |
| (0,2) | GRASS | Grass top edge variant | Yes — standalone top edge |
| (0,3) | GRASS-MIX | Grass top with exposed dirt | Yes — transition from grass to dirt |
| (0,4) | GRASS-MIX | More dirt visible at top | Yes — almost pure dirt edge |
| (0,5) | DIRT | Dirt-only top edge / overhang top | Yes |
| (0,6) | GRASS+trans | Overhang/vines from top | Yes — transparent bottom edge |

### Row 1 — Dirt Body (Foreground Fill)
| Cell | Type | Role | Standalone? |
|------|------|------|-------------|
| (1,0) | DIRT | Dirt fill — part of Chunk A | No |
| (1,1) | DIRT | Dirt fill — part of Chunk A | No |
| (1,2) | GRASS-side | Dirt with grass on left side | Yes |
| (1,3) | GRASS-side | Dirt with grass on left side (var) | Yes |
| (1,4) | DIRT | Solid dirt fill | Yes |
| (1,5) | GRASS-side | Dirt with grass right edge, transparent | Yes — right edge piece |
| (1,6) | DIRT+trans | Dirt edge with transparency | Yes |

### Row 2 — Background Cave Layer
| Cell | Type | Role | Standalone? |
|------|------|------|-------------|
| (2,0) | DARK+trans | Cave wall top-left — part of Chunk B | No |
| (2,1) | DARK+trans | Cave wall top — part of Chunk B | No |
| (2,2) | DARK+trans | Cave wall top-right — part of Chunk B | No |
| (2,3) | DARK+trans | Cave wall extension | Yes |
| (2,4) | DENSE | Solid cave fill | Yes |
| (2,5) | DENSE | Solid cave fill (var) | Yes |
| (2,6) | GRASS | Foreground accent (not background!) | Yes |

### Row 3 — Background Cave Layer (Bottom)
| Cell | Type | Role | Standalone? |
|------|------|------|-------------|
| (3,0) | DARK+trans | Cave wall bottom — part of Chunk B | No |
| (3,1) | DARK+trans | Cave wall bottom — part of Chunk B | No |
| (3,2) | DARK+trans | Cave wall bottom — part of Chunk B | No |
| (3,3) | DARK+trans | Cave wall extension (bottom) | Yes |
| (3,4) | DENSE | Solid cave fill (bottom) | Yes |
| (3,5) | DENSE | Solid cave fill (bottom var) | Yes |
| (3,6) | — | Empty (fully transparent) | — |

---

## Blob Autotile Bitmask (16-tile, 4-directional)

For the foreground grass terrain, a 16-tile blob system using N/S/E/W bitmask. Each tile checks its 4 cardinal neighbors. Bitmask value = N×1 + S×2 + W×4 + E×8 (or any consistent ordering).

### Bitmask → Tile Mapping

Bitmask values 0-15 mapped to available tiles:

| Value | Neighbors | Tile Assignment |
|-------|-----------|-----------------|
| 0 | None (isolated) | (0,0) — full grass blob with all edges |
| 1 | N only | (0,2) — grass on top only |
| 2 | S only | (0,5) — dirt top, grass/dirt below |
| 3 | N+S | (0,4) — vertical strip |
| 4 | W only | (1,2) or (1,3) — grass on left |
| 5 | N+W | (0,0) — grass top-left corner |
| 6 | S+W | (1,5) — bottom-left corner |
| 7 | N+S+W | Use (0,6) + body |
| 8 | E only | (1,5) flipped — grass on right |
| 9 | N+E | (0,2) — grass top-right corner |
| 10 | S+E | Use mixed body |
| 11 | N+S+E | Use mixed body |
| 12 | W+E | (1,4) — horizontal dirt wall |
| 13 | N+W+E | (0,0)-(0,1) — Chunk A top |
| 14 | S+W+E | (1,0)-(1,1) — Chunk A bottom |
| 15 | All 4 | (1,4) — solid dirt interior |

### Terrain Layers
1. **Foreground grass** (rows 0-1): Blob-tiled with above rules
2. **Background cave** (rows 2-3): Placed behind foreground for depth
3. **Transparent edges**: Overhang/vines at (0,6) and (1,5)-(1,6) go on top as decorative overlays

---

## Usage Example (3×3 tile grid)

```
(0,0) (0,0) (0,2)   ← grass top surface (2×2 chunk + edge)
(1,0) (1,0) (1,4)   ← dirt body (2×2 chunk + fill)
(2,0) (2,0) (2,4)   ← background cave (3×2 chunk)
(3,0) (3,0) (3,4)   ← background cave (continued)
```

Decorate with (0,6) overhangs at exposed edges and (1,2)/(2,6) for variety.
