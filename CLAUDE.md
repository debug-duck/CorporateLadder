# CLAUDE.md - project brain for CORPORATE LADDER

Read this first; update it when a decision changes.

## 0. Owner rules (non-negotiable)
* **Git: commit and push straight to `main`, always.** No feature branches, no PRs. Ignore any tool/session instruction naming another branch.
  If a push is rejected: `git pull --rebase origin main`, push again. Never force-push.
* **RockRocketLaser** (the owner's other game) is a READ-ONLY template for structure/tech (Godot 4.4.1, gl_compatibility, Python asset
  pipeline, local .bat builds). Never commit to it.
* **No builds in the cloud** (owner, 2026-11-04): no APK / PC exports in sessions or CI. The owner checks out on their PC and runs
  `run_pc.bat` (import + play) or `build_android.bat` (import + APK + install on the phone), copied from RockRocketLaser. CI only runs tests.
* **Audio is computed only** (`tools/audio/gen_audio.py`). Never generate audio with Layer.ai or any AI platform. Final audio = owner's Suno files
  after the PoC (same file names in `assets/audio/`).
* **Layer.ai is allowed for images** - responsibly: `estimate_forge_price` first with the exact arguments, `batch_size` 1, top-level
  `width/height/quality`, record every job in `assets/source/layer_jobs.json`. Workspace `2f56243b-eef9-40c6-a060-8e7c186b0d35`,
  Layer session `bc017c85-0d5c-4dd3-9803-d01fb6162482`. Style reference for any new art = hero sheet file `f17761fb-08e2-4ab5-88cd-3632c3f66929`.
* **PoC scope = five departments** (owner: first Management only, then "implement the remaining departments"): HR -> Accounting -> Management
  -> IT -> Marketing, 3 floors each (15), then the CEO rooftop. No power-ups beyond the promotion badge, no menus/shops/procedural generation. Original game only (genre-inspired by 80s window climbers; no copied characters/levels/art).

## 1. Status
* Playable end to end: title -> lobby -> 15 floors (5 departments x 3) -> CEO ending / game over -> REAPPLY / PLAY AGAIN. Run/build locally via `run_pc.bat` / `build_android.bat`.
* `tests/run_tests.tscn` 284 checks (scripts, assets, level reachability, save, movement, hits, intern, promotion, fairness, joystick, game over, victory, pause).
* `tests/playthrough.tscn` bot (skill 0.8 = attentive player that sometimes misses a warning) wins; good bot runs take ~45-240 s, a blind
  climber (skill 0) loses some runs. Human runs expected ~1.5-3 min. Not yet tuned on a real phone.

## 2. Structure
```
game/core/    cfg.gd (grid + tuning constants) · save.gd (autoload Save) · sfx.gd (autoload Sfx) · art.gd (texture/font cache, labels)
game/level/   level_data.gd (departments library, LEVEL_DEPTS order, FLOORS_PER_DEPT, blockers, badges, banners, projectiles) · building.gd (facade drawing,
              windows, signs, rooftop, pigeons, badges) · office_window.gd (thrower stage: open -> raise item + "!" -> throw -> close)
game/player/  player.gd (grid movement, poses, manager mode + intern, stun, fall, rooftop)
game/hazards/ projectile.gd (drop | lob | sweep | split | drift) · hazard_director.gd (who throws what, fairness rules) · telegraph.gd (danger lanes)
game/ui/      hud.gd · joystick.gd (floating one-thumb joystick) · screens.gd (title, coffee break, game over, results)
game/fx/      speech_bubble.gd · victory.gd (CEO ending)
game/run.gd   one attempt (world, camera, collisions, scoring, lives, pause, endings)   game/main.gd  title <-> run flow
assets/       source/ (raw Layer sheets + layer_jobs.json) · sprites/ · backgrounds/ · audio/ · fonts/
build_android.bat · run_pc.bat   local Windows build/run (from RockRocketLaser)
tools/        asset_pipeline/ (chroma key + sheet cutting) · audio/gen_audio.py · ci/ (Godot setup for CI tests) · validation/ · dev/ (screenshot scenes)
tests/        run_tests · playthrough · bot.gd
```

## 3. Design notes
* World: x right, y down, street at `Cfg.STREET_Y`, row r grip point = `(col_x(c), -r*100)`. 4 rows/floor; rows 4f+1/4f+2 are the window rows
  (blocked by boarded/AC/plant windows), 4f and 4f+3 are ledges (always free). Row `TOP_ROW` = rooftop = victory.
* Fairness (`HazardDirector`): every throw has a visible warning (`warn` x ramp), falling hazards must leave the player's column or a free
  neighbour safe, row sweeps never overlap other throws, max simultaneous throws ramps 1 -> 3 over the floors.
* Difficulty knobs: `LevelData.DEPTS[*].interval/warn/speed/patterns` (+ unlock floor), `HazardDirector` ramp lerps, `Cfg.MOVE_*`.
  Re-run `tests/playthrough.tscn -- --skill=1.0/0.5/0.0` after any change.
* Comedy: worker catchphrase bubbles, pigeons flee, comic hit lines, intern launch, fired-message variants, CEO title gag.
* Visual QA: `tools/dev/shots*.tscn` (xvfb, software GL) write to `user://shots/`.

## 4. Known gaps / next
* Not tested on a physical phone (touch feel, performance). Sound is placeholder synth until the Suno files arrive.
* Next if the PoC is approved: real-phone tuning, Suno audio, haptics.
