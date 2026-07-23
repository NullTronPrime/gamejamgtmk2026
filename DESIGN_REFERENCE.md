# GMTK Game Jam 2026 — Vikram & Betaal

## Core Loop
1. **Isometric path** — player walks forward; trees, bushes, rocks generated via L-system
2. **Puzzle timer triggers** — Betaal asks a riddle (4 options: 1 right, 1 wrong, 2 false)
3. **Riddle outcome determines next step:**
   - **Right** → **easy** 2D platformer (no spikes, wide platforms) + buff (+30% jump or +1 life)
   - **Wrong** → forced into **second riddle** (chessboard: find checkmate in 1)
     - Second correct → **normal** platformer
     - Second wrong → **hard** platformer (red overlay, spikes, gaps)
   - **False/off** → **normal** platformer (skips second riddle)
4. **2D platformer** — reach the flag to complete; jump/sprint mechanics
5. Return to isometric path at next **crossroad** (red distance marker turns green)

## Crossroads
- 6 crossroad markers placed at intervals along the path
- Each starts **red**; turns **green** when the riddle+platformer cycle is done
- Only one crossroad active at a time (sequential progression)

## Timer & Day/Night
- Global 600s (10 min) countdown
- Visualized as 7 day/night cycles (~85.7s per phase)
- Moonlight intensity oscillates; ambient energy follows inversely
- Timer ticks during both isometric and platformer states

## Architecture
| File | Role |
|------|------|
| `scripts/autoload/game_manager.gd` | Game state machine, timer, riddle flow, difficulty/buff tracking |
| `scripts/autoload/riddle_manager.gd` | Riddle pool, 4-option shuffling, second riddle (chessboard) pool |
| `scripts/autoload/audio_manager.gd` | Audio playback (footsteps, ambience) |
| `scripts/autoload/mic_manager.gd` | Microphone capture (for MICROPHONE puzzle type — currently unused) |
| `scripts/game.gd` | Top-level scene orchestration (title → intro → gameplay → ending) |
| `scripts/world/forest_level.gd` | Isometric terrain, tree generation (PlantGenerator/L-system), lighting (Lit plugin), crossroad markers, day/night cycle, platformer level loading |
| `scripts/world/platformer_level.gd` | 2D platformer level builder (3 difficulty variants), spike hazards, flag goal, buff system |
| `scripts/player/player.gd` | Isometric player controller (top-down movement, sprint stamina, pseudo-height jump) |
| `scripts/player/betaal.gd` | Betaal character animation/speech cues |
| `scripts/ui/puzzle_encounter.gd` | Riddle UI (multiple choice, chessboard widget), second-riddle flow |
| `scripts/ui/hud.gd` | Timer bar, puzzle progress, distance, sprint fill, benefits display |
| `scripts/ui/dialogue_box.gd` | Betaal dialogue box with typing animation (currently unused in new flow) |
| `scripts/chessboard/chessboard_widget.gd` | Interactive chessboard (click-to-move, checkmate validation) |

## Game States (GameManager.GameState)
- `TITLE` → `INTRO` → `PLAYING` (isometric walking) → `PUZZLE` (riddle asked) → `SECOND_PUZZLE` (chessboard triggered) → `PLATFORMER` (2D level) → loops back to `PLAYING`
- `RESET` timer expired; `WIN` all 6 crossroads completed

## Riddle Content
- 8 main riddles (paradox/philosophical themes by Betaal)
- 3 chessboard second-riddles (checkmate-in-one positions)
- Riddle history prevents repeats until pool is exhausted

## Notable Dependencies
- **Lit** plugin — 2D lighting (directional light, shadows, bloom, color grading)
- **PlantGenerator** — L-system tree generation (variants 0-4, far/near detail levels)
- **Saltmire Transitions** — scene fade transitions
- Assets: `assets/audio/sfx/footstep/`, `assets/audio/sfx/run/`, `assets/audio/sfx/ambience.wav`
