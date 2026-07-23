# Miro Board — Vikram & Betaal Game Design

**API Endpoint:** `https://api.miro.com/v2/boards/uXjVH4irbHI=/items`
**Board ID:** `uXjVH4irbHI=`
**Auth Token:** `eyJtaXJvLm9yaWdpbiI6ImV1MDEifQ_oLZ1cq4F2YauQZdizIYUtA6YaQg`
> ⚠ Token is for read-only board access. Regenerate if compromised.

**Fetch command (PowerShell):**
```powershell
$token = "eyJtaXJvLm9yaWdpbiI6ImV1MDEifQ_oLZ1cq4F2YauQZdizIYUtA6YaQg"
$headers = @{ Authorization = "Bearer $token" }
$boardId = [System.Uri]::EscapeDataString("uXjVH4irbHI=")
Invoke-RestMethod -Uri "https://api.miro.com/v2/boards/$boardId/items?limit=50" -Headers $headers
```

**Fetched:** 2026-07-23

## Structure

The board is organized into labelled section-shapes with items inside each area.

---

## CENTRAL — Title

| Item | Position |
|------|----------|
| [SHAPE] **VIKRAM BETAAL** | x=-196.3 y=-122.4 |

## ART (x≈-293, y≈223)

| Item | Position | Notes |
|------|----------|-------|
| [SHAPE] art | x=-292.9 y=223.0 | Section header |
| [SHAPE] anim rigs | x=-559.8 y=254.1 | Animation skeleton rigs |
| [SHAPE] vikram rigs | x=-826.8 y=254.1 | Vikram character rigs |
| [SHAPE] betaal idle anims | x=-559.8 y=469.4 | Betaal idle animation |
| [SHAPE] recoil anims (on stop and start) | x=-559.8 y=38.8 | Recoil animations |
| [SHAPE] running | x=-847.4 y=50.8 | Running animation |
| [SHAPE] backdrops | x=-58.0 y=223.0 | Background environments |
| [SHAPE] skybox | x=153.3 y=247.9 | Sky/atmosphere |
| [SHAPE] night sky/variants | x=324.0 y=298.7 | Night sky variants |
| [SHAPE] weather | x=349.4 y=177.8 | Weather effects |
| [SHAPE] props | x=77.5 y=429.1 | General props |
| [SHAPE] forest items/greenery | x=284.3 y=458.6 | Forest vegetation |
| [SHAPE] grass | x=-515.3 y=-893.3 | Grass textures/placement |
| [SHAPE] detritus and other leaf litter | x=110.4 y=635.2 | Ground detail |

---

## SOUND (x≈-711, y≈-393)

| Item | Position | Notes |
|------|----------|-------|
| [SHAPE] sound | x=-710.6 y=-393.2 | Section header |
| [SHAPE] sfx | x=-710.6 y=-589.9 | Sound effects |
| [SHAPE] background music | x=-1062.4 y=-518.5 | BGM tracks |
| [SHAPE] per event music | x=-994.1 y=-303.2 | Event-triggered music |
| [SHAPE] in puzzle music | x=-1277.6 y=-518.5 | Puzzle-state music |
| [SHAPE] running sfx | x=-797.0 y=-754.4 | Footstep/running SFX |
| [SHAPE] betaal sfx | x=-700.0 y=-790.5 | Betaal voice SFX |
| [SHAPE] object sfx | x=-860.4 y=-637.2 | Object interaction SFX |
| [SHAPE] forest ambiance sfx | x=-486.2 y=-670.8 | Ambient forest sounds |
| [SHAPE] title screen idle | x=-1148.0 y=-708.9 | Title screen music |

---

## GAMEPLAY (x≈696, y≈-473)

| Item | Position | Notes |
|------|----------|-------|
| [SHAPE] gameplay | x=695.9 y=-473.4 | Section header |
| [SHAPE] movement? | x=678.5 y=-189.4 | Movement mechanics |
| [SHAPE] perspective? | x=903.3 y=-116.6 | Perspective/camera |
| [SHAPE] platforming | x=1434.8 y=-5.2 | Platforming elements |
| [SHAPE] climb stages | x=1581.9 y=102.7 | Climbing segments |
| [SHAPE] death action | x=776.7 y=-32.9 | Death animation/state |
| [SHAPE] puzzle mechanics | x=1625.5 y=-764.5 | Puzzle interaction design |
| [SHAPE] roguelike features | x=1772.9 y=-624.8 | Roguelike systems |
| [SHAPE] game stages | x=984.5 y=-334.4 | Stage progression |
| [SHAPE] game rewards | x=1273.1 y=-334.4 | Reward system |
| [SHAPE] per puzzle | x=1561.7 y=-334.4 | Per-puzzle configuration |
| [SHAPE] end goal | x=1273.1 y=-94.4 | Win condition |

---

## PUZZLES & RIDDLES (x≈984, y≈-814)

| Item | Position | Notes |
|------|----------|-------|
| [SHAPE] puzzles | x=984.5 y=-574.4 | Section header |
| [SHAPE] quzzzies | x=984.5 y=-814.4 | Quiz/puzzle types |
| [SHAPE] riddles text | x=455.9 y=-844.5 | Riddle content/writing |
| [SHAPE] Story board | x=695.9 y=-844.5 | Story/riddle integration |
| [SHAPE] story board | x=507.1 y=-1010.4 | Storyboard (duplicate?) |

---

## DIALOGUE (x≈467, y≈-214)

| Item | Position | Notes |
|------|----------|-------|
| [SHAPE] dialogue | x=467.3 y=-214.4 | Dialogue system design |

---

## CUTSCENES (x≈-293, y≈822)

| Item | Position | Notes |
|------|----------|-------|
| [SHAPE] cutscenes | x=-292.9 y=822.3 | Section header |
| [SHAPE] starting cutscene | x=-62.1 y=756.1 | Opening cutscene |
| [SHAPE] countdown reset cutscene | x=-383.0 y=1172.0 | Timer-reset cutscene |
| [SHAPE] title screen (maybe not?) | x=-691.1 y=907.3 | Title screen (undecided) |
| [SHAPE] Puzzle open/start | x=-1109.7 y=260.4 | Puzzle intro animation |
| [SHAPE] what the puzzles and interactions actually look like | x=-113.2 y=484.6 | Puzzle interaction mockup |

---

## Instructions Note

> x=55.9 y=-544.4: "circles are questions put your answers in sticky notes (yellow)"
