# Session Summary — 2026-07-23

## Changes Made

### 1. Chessboard snap-to-grid fix (`puzzle_encounter.gd`)
- `_update_layout()` was missing in the wrong-move path, causing visual drift
- Corrected: every square placement now recalculates positions from board offset

### 2. Platformer as separate scene + fade transitions
- Platformer now a separate packed scene with `Transition.cover`/`reveal` for enter/exit
- Added to root instead of as child of forest_level
- Uses visibility toggling instead of `remove_child` for clean state management

### 3. Grid-based platformer generation (`platformer_level.gd`)
- `_build_level` rewritten: all tiles/spikes/flags snapped to 48px grid
- Random walks, gaps, and bridges generated grid-aligned
- Three difficulty variants (easy/normal/hard) with configurable gap sizes

### 4. Crossroad walls removed
- Cross road generation no longer places walls, fixing progression blocking

### 5. Trigger band extended
- Puzzle trigger area height increased from 80px to 600px (covers entire road)

### 6. Platformer feel features
- Coyote time, jump buffering, variable jump height
- Separate gravity for platformer vs isometric
- Smooth acceleration (lerp-based) only in platformer scene

### 7. Humanoid rig + walk-cycle animation (`humanoid_rig.gd`, `player.gd`, `betaal.gd`)
- New `scripts/shared/humanoid_rig.gd` — `HumanoidRig` class with static `build()` creating jointed stick figure (torso, head, 2-bone arms/legs)
- `player.gd` replaced: Vikram uses rig with neutral gray/tan colors, walk cycle (legs swing opposite, knees bend, arms contralateral, speed scales with sprint, idle bob, airborne tuck)
- `betaal.gd` replaced: Betaal is blue stick figure (scale 0.78) posed piggyback via `_pose_piggyback()`, all existing tween/speech/fly-away logic preserved

### 8. Crossroad config (`config/crossroads.json`)
- New `config/crossroads.json` — each crossroad has `"enabled": true/false`
- `_load_crossroad_config()` reads JSON, `_is_crossroad_enabled()` helper
- Disabled crossroads: invisible, no trigger, auto-skipped in progression
- HUD minimap greys out disabled crossroad markers

### 9. Text replaced with "sample text"
- Title screen cutscene and intro scene texts → `"sample text"`
- All 8 text-based riddle questions, answers, and consequences → `"sample text"`
- Chessboard riddles (3) kept unchanged (not text-based)

### 10. Miro board riddles added (6 new)
Added after the 8 placeholders, with real riddle text from the Miro board:
1. Suryamal's head vs body (theme: upside down)
2. King Rupsen vs Virvar sacrifice (theme: duality)
3. Thief cries and laughs (theme: inequality)
4. What must the king legislate (theme: legality)
5. Will Nageshwari kill Prince Shaktinath (theme: snakes)
6. Gloom forest level (placeholder — theme label only)

### 11. Chessboard widget fixes (`chessboard_widget.gd`)
- Valid-move highlight: when piece on `correct_from` is picked up, `correct_to` square lights up green
- Snap-to-center: dropped piece snaps to target square center position
- Cleaned up layout math, extracted `_square_pos()`/`_square_center()` helpers

### 12. CanvasLayer skybox with 60s day/night cycle (`shaders/sky.gdshader`, `forest_level.gd`)
- Sky moved to `CanvasLayer` (layer -10) so it always renders behind the world
- New `shaders/sky.gdshader` — gradient sky (dark zenith → horizon), colors driven by `night_factor`/`sunset_glow` uniforms
- StarField: 180 stars with per-star twinkle, screen-space coordinates on skybox layer
- **Sun**: `SunCircle` class with warm glow/halo, arcs from left→center→right during day and sets at sunset
- **Moon**: 3-layer circle (glow/halo/disc), arcs opposite the sun during night
- Cycle: 60s total → 25s day → 10s sunset → 20s night → 5s dawn
- Lights rotate and change color: warm at sunset, cool blue at night
- Ambient energy dims during night, rises during day

## Data Sources Fetched
- Miro board (`design/board.md`) — full board structure, 6 new riddles, art/sound/gameplay sections
- Discord code-stuff channel — riddle type discussions (barber paradox, coin trick, observation Qs, chessboard)
