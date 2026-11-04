# CORPORATE LADDER

Playable mobile proof of concept by **Wrong Button Games** (Godot 4.4.1, GDScript, portrait Android-first).

> Seven years without a raise. The CEO works on the top floor. The elevator is reserved for executives.
> **Climb the corporate ladder. Literally.**

Climb the outside of CORPORATE HQ through 15 floors, 3 per department, while the staff lean out of their windows and throw
things at you: **HR** (paper stacks, warning letters) -> **ACCOUNTING** (calculators, binders) -> **MANAGEMENT** (piles of bull,
PowerPoint slides) -> **IT** (CRT monitors, keyboards that break apart, flying keycaps) -> **MARKETING** (branded mugs, T-shirts,
confetti boxes). Grab a glowing promotion badge to become a MANAGER for 10 seconds (suit, sunglasses, giant gold tie) with an
**intern shield** that takes one hit for you ("GREAT LEARNING OPPORTUNITY!"). Reach the penthouse, demand a raise, get promoted
to SENIOR JUNIOR ASSOCIATE.

## Play it (Windows PC, after `git clone` / checkout)
Builds are made **locally on your PC**, not in the cloud. Both scripts first `git pull --ff-only`, download the pinned
Godot 4.4.1 into `build\godot` on first use (or use `GODOT_EXE`), and re-import all assets before running.

| Script | What it does |
|---|---|
| `run_pc.bat` | Imports assets and starts the game on the PC. |
| `build_android.bat` | Imports assets, exports `build\corporate-ladder-debug.apk` (debug-signed, arm64) and installs + launches it on a phone connected over USB. `build_android.bat --no-push` only builds. Needs the Android SDK (`ANDROID_SDK_ROOT`, default `%LOCALAPPDATA%\Android\Sdk`) and JDK 17+; export templates (~1 GB) and a debug keystore are fetched/created once. |

Linux/macOS: `godot --path . --import` then `godot --path .`.

## Controls
| Input | Action |
|---|---|
| Touch anywhere below the top bar and drag (floating joystick) | Climb up / down, move left / right (hold to keep moving) |
| Arrow keys / WASD | Same on desktop |
| `Esc` / `P`, pause button | Coffee break (pause, restart, quit) |
| `M`, speaker button | Mute |
| Mouse drag | Simulates touch |

## How it plays
* 5 window columns, 4 handhold rows per floor. Boarded-up windows, AC units and office plants block the window rows;
  the ledge rows are always free, so there is always a way around.
* Every throw is announced: the window opens, the manager raises the item over their head with a red **!**, and a dashed
  danger lane (falling things) or a dashed line with an arrow (things flying across a row) appears. Lanes: step sideways.
  Rows: step up or down. The director never threatens your column and both neighbours at once.
* Hazards: bull piles (drop), PowerPoint slides (fly across a row), "the full deck" (three slides down one lane),
  lobbed piles, and twin drops near the top. Difficulty ramps floor by floor (frequency, speed, simultaneous throwers).
* 3 lives, brief invulnerability after a hit, no progress lost. Last life: you fall; **"YOUR POSITION HAS BEEN TERMINATED."** -> **REAPPLY**.
* Score: climbing (+10/row, +100/floor), dodges (+25), promotions (+500), rooftop (+5000), lives left (+1500 each).
  High score + best floor are stored locally (`user://corporate_ladder.json`).

## Build & test
```bash
tools/validation/run_all.sh --playthrough      # import + 200+ headless checks + bot plays street -> CEO
godot --headless --path . --fixed-fps 60 tests/playthrough.tscn -- --runs=5 --skill=0.5   # pacing / difficulty probe
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 --fixed-fps 60 tools/dev/shots.tscn       # gameplay screenshots
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 --fixed-fps 60 tools/dev/shots_flow.tscn  # title/intern/game over/ending
```

## Assets
* **Art**: generated with [Layer](https://layer.ai) (GPT Image 2.5 Flare, ~34 CU), all original. Provenance in
  `assets/source/layer_jobs.json`; raw sheets in `assets/source/sheets/`; `python3 tools/asset_pipeline/build_assets.py` keys
  the magenta backgrounds and cuts the sheets into `assets/sprites/`.
* **Audio**: computed (synthesized with numpy) by `python3 tools/audio/gen_audio.py` -> `assets/audio/*.ogg`.
  No AI-platform audio. The final audio will come from the owner's Suno account: drop files with the same names into `assets/audio/`.
* **Fonts**: Luckiest Guy (Apache 2.0), Inter (OFL) - see `assets/fonts/LICENSES.md`.
