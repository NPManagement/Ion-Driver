# Ion Driver Tester - Godot 4.x Racing Game

**WipEout-style anti-gravity hovercraft racer. Arcade handling, high speed, single player time trial. Built in Godot 4.x GDScript.**

## CLAUDE - OPTIMIZED SEARCH GUIDE

This file tells Claude exactly where to find code in this project. **Read this before touching any file.**

### ONLY 14 SOURCE FILES EXIST (all in scripts/)

Search these directories ONLY:
```
scripts/vehicle/    → 2 files
scripts/race/       → 3 files
scripts/track/      → 1 file
scripts/ui/         → 3 files
scripts/autoloads/  → 3 files
```

**TOTAL: 14 GDScript files** - everything else is binary/assets.

---

## CURRENT WORK IN PROGRESS

*(Replace this line with whatever you're asking Claude to do right now — one sentence is enough)*

---

## KNOWN GOTCHAS

- **Boost AND camera are both inside `ion_vehicle.gd`** — do NOT look in `camera_settings.gd` for camera code that runs during gameplay; that file only holds tuning constants.
- **AI difficulty lives in `ai_controller.gd`** via the `difficulty` export (0=Novice, 1=Pro, 2=Elite, 3=Master) — changing `SPEED_FACTORS`/`STEER_FACTORS` arrays changes all difficulties at once.
- **No AI opponents by default** — `AI_COUNT = 0` in `race_manager.gd` (solo time trial mode). Change this to add AI racers.
- **Steer sensitivity is NOT an export** — it's `steer_sensitivity: int` set at runtime via the HUD, using `STEER_MULTIPLIERS = [0.25, 0.5, 0.75, 1.0, 1.5]`.
- **`drag_coefficient` is disabled** (set to 0.0) — the project uses a custom drag curve instead. Don't re-enable it expecting default Godot drag behaviour.

---

## QUICK LOOKUP TABLE

| What you want | Exact file to open |
|---------------|-------------------|
| **Vehicle physics** | `scripts/vehicle/ion_vehicle.gd` |
| **Hover mechanics** | `scripts/vehicle/ion_vehicle.gd` (grep: "hover") |
| **Steering** | `scripts/vehicle/ion_vehicle.gd` (grep: "steer") |
| **Boost system** | `scripts/vehicle/ion_vehicle.gd` (grep: "boost") |
| **Vehicle audio** | `scripts/vehicle/ion_vehicle.gd` (grep: "audio" or "sound") |
| **Vehicle camera** | `scripts/vehicle/ion_vehicle.gd` (grep: "camera") |
| **AI behavior** | `scripts/vehicle/ai_controller.gd` |
| **AI waypoints** | `scripts/vehicle/ai_controller.gd` (grep: "waypoint") |
| **Race manager** | `scripts/race/race_manager.gd` |
| **Laps/checkpoints** | `scripts/race/checkpoint.gd` |
| **Track generation** | `scripts/track/track_generator.gd` |
| **HUD (speed/boost)** | `scripts/ui/hud.gd` |
| **Menu UI** | `scripts/ui/main_menu.gd` |
| **Game settings** | `scripts/autoloads/game_manager.gd` |
| **Audio settings** | `scripts/autoloads/audio_manager.gd` |
| **Camera settings** | `scripts/autoloads/camera_settings.gd` |

---

## NEVER SEARCH THESE (skip in glob/grep)

- `scenes/` - Godot scene files (not code)
- `shaders/` - Shader files (rarely modify)  
- `Assets/` - Textures/images
- `audio/` - Sound/music files
- `.godot/` - Editor cache
- `resources/` - Godot resources

---

## FILE SIZES (for context)

| File | Lines | Notes |
|------|-------|-------|
| `ion_vehicle.gd` | ~2000 | Largest - contains ALL vehicle logic |
| `hud.gd` | 1169 | All HUD UI |
| `track_generator.gd` | 1159 | Track + city generation |
| `main_menu.gd` | 712 | Menu + options |
| `menu_background.gd` | 501 | 3D showcase scene |
| `race_manager.gd` | 325 | Race orchestration |
| `ai_controller.gd` | 198 | AI driver |
| `checkpoint.gd` | 109 | Lap gates |
| `audio_manager.gd` | 159 | Music/SFX |
| `camera_settings.gd` | 114 | Camera tuning |
| `waypoint_system.gd` | 67 | Path utilities |
| `game_manager.gd` | 98 | Game state |

---

## KEY VARIABLES — GREP TARGETS

### Vehicle Physics (`ion_vehicle.gd`)
| What | Variable | Default |
|------|----------|---------|
| Top speed (normal) | `max_speed` | `145.0` |
| Top speed (boosted) | `max_speed_boosted` | `230.0` |
| Acceleration | `thrust_force` | `40000.0` |
| Braking | `brake_force` | `65000.0` |
| Hover height | `hover_height` | `2.0` |
| Hover spring | `hover_force` | `7000.0` |
| Boost thrust | `boost_force` | `70000.0` |
| Boost energy pool | `max_energy` | `100.0` |
| Boost drain rate | `energy_drain` | `20.0` |
| Boost regen rate | `energy_regen` | `18.0` |
| Steering speed | `steer_speed` | `7500.0` |
| Banking into corners | `steer_tilt_factor` | `0.85` |
| Air brake | `air_brake_force` | `20000.0` |
| Lateral grip | `lateral_drag` | `24.0` |

### AI (`ai_controller.gd`)
| What | Variable |
|------|----------|
| Difficulty level | `@export var difficulty: int` (0–3) |
| Speed per difficulty | `SPEED_FACTORS := [0.74, 0.86, 0.96, 1.04]` |
| Steering per difficulty | `STEER_FACTORS := [0.72, 0.85, 0.94, 1.00]` |
| Boost aggression | `BOOST_THRESHOLDS := [0.88, 0.76, 0.60, 0.45]` |
| AI personality | `_personality` (0=Balanced, 1=Aggressive, 2=Consistent, 3=Drafter) |

### Race (`race_manager.gd`)
| What | Variable |
|------|----------|
| Number of AI | `AI_COUNT` (currently `0`) |
| Total laps | `TOTAL_LAPS_DEFAULT` (currently `3`) |
| Countdown | `COUNTDOWN_SECONDS` (currently `3`) |

---

## COMMON TASKS - WHERE TO START

**Tweak vehicle handling:**
→ `scripts/vehicle/ion_vehicle.gd` - search for "accel", "max_speed", "turn"

**Add HUD element:**
→ `scripts/ui/hud.gd` - search for "speed" or "boost" to find similar patterns

**Change track layout:**
→ `scripts/track/track_generator.gd` - search for "waypoints" or "generate"

**Add menu option:**
→ `scripts/ui/main_menu.gd` - search for "options" or "button"

**Change AI difficulty:**
→ `scripts/vehicle/ai_controller.gd` - search for "speed" or "personality"

**Camera feels wrong:**
→ `scripts/autoloads/camera_settings.gd` - all camera values in one file