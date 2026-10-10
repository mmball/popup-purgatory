# Popup Purgatory

A Windows 98 desktop roguelite. Pop-ups keep appearing. You close them. Completing what a
pop-up asks (rate the survey, install the update, uncheck the newsletter boxes) pays more
than X-ing it out. Spend what you earn on a village of imps who close pop-ups for you.
Run out of system resources and the machine blue-screens. That's the run.

Built with [Godot 4.7](https://godotengine.org). No image assets: every window, button,
imp and building is drawn in code.

![desktop](docs/img/desktop.png)

## Play

1. Install Godot 4.7 (standard build, not .NET).
2. Open `project.godot` in the editor and press F5, or run from a terminal:

   ```sh
   godot --path .
   ```

Controls are mouse-first. **Start** button or **B** opens the build menu, **1-7** picks a
building directly, **Esc** cancels placement, right-click also cancels. Drag windows by
their title bar.

The full design is in [`docs/DESIGN.md`](docs/DESIGN.md).

## Layout

```
project.godot
src/
  main.tscn, main.gd        root; swaps screens, hosts the screenshot tool
  autoload/game.gd          "Game" singleton: current run, meta save, screen flow
  core/                     pure logic, no nodes (unit tested)
    run_state.gd            bytes, RAM, waves, modifiers, crash
    popup_catalog.gd        every pop-up type and its numbers
    building_catalog.gd     every building and its cost curve
    upgrade_catalog.gd      between-wave picks
    spawn_schedule.gd       when and what spawns
    target_assigner.gd      imps claim pop-ups without collisions
    meta_save.gd            records, bank, perks (user://meta.json)
  ui/                       Win98 toolkit: palette/theme, bevels, buttons, window frame
  popups/                   PopupBase window, PopupContent base, spawner, content/*.gd
  imps/                     Imp (state machine + drawing), ImpManager
  village/                  Village grid, Building sprites, DesktopIcon
  desktop/                  Desktop screen, Taskbar, StartMenu, BreakDialog, ConfirmDialog
  screens/                  MainMenu (boot + unlock shop), BsodScreen (run summary)
  dev/autoplay.gd           bot that drives the real GUI with synthetic clicks
tests/                      headless unit tests + runner
tests/screenshots/          committed baselines for screenshot regression
tools/lint.sh               bans Godot 3 APIs, Python idioms, global RNG in gameplay
tools/test.sh               lint + import + tests + bot smoke run + determinism check (what CI runs)
tools/botrun.sh             batch of seeded bot runs -> runs/*.jsonl -> summary table
tools/summarize_runs.py     aggregates run JSONL into per-policy and per-wave tables
tools/screenshot.sh         render the fixed UI states under Xvfb (frozen clock, fixed fps)
tools/screenshot_check.sh   render + compare against tests/screenshots (2% pixel tolerance)
tools/compare_images.gd     the pixel comparer, pure GDScript, no dependencies
CLAUDE.md                   agent rules: engine pin, static typing, conventions, verification loop
```

## Dev tooling

Everything runs headless, so the whole loop works in CI and in a container.

```sh
tools/test.sh /path/to/godot          # lint, import, 21 unit tests, bot smoke run, determinism check
godot --headless --path . -s tests/run_tests.gd
```

Static typing is enforced by the engine: `project.godot` turns the `untyped_declaration`
warning into a parse error, so an untyped variable fails the build.

Every run is reproducible from one integer. Type a seed on the main menu, pass `--seed=N`,
or read it off the BSOD after a crash. Two runs with the same seed and `--fixed-fps 60`
end in the same state; `tools/test.sh` checks that on every push.

**Bot batches.** The autoplay bot plays whole runs through the real GUI under two policies:
`greedy` (oldest pop-up first, prefers completion, buys the first affordable building) and
`random` (uniformly random legal clicks). A batch writes one JSON line per run with the end
state, every wave's snapshot, and the buildings and upgrades picked:

```sh
tools/botrun.sh /path/to/godot 20 greedy 100 3   # 20 runs, seeds 100..119, 3 waves each
tools/botrun.sh /path/to/godot 20 random 200 3
python3 tools/summarize_runs.py runs/*.jsonl       # per-policy, per-wave, pick-rate tables
```

Headless runs are fast (roughly 4,000 frames per second here), so a 20-run batch takes
seconds. This is the input for balancing in roadmap phase 4.

**Screenshot regression.** Five fixed UI states (menu, desktop with the demo layout, Start
menu, wave break, BSOD) render deterministically under a frozen clock and fixed frame rate.
`tools/screenshot_check.sh` compares them with the baselines in `tests/screenshots/` at a
2% mismatched-pixel tolerance and writes `screenshots/diff_*.png` on failure. After an
intentional visual change, re-baseline with `--update` and commit the PNGs.

Command-line dev options go after `--`:

| flag | effect |
| --- | --- |
| `--screen=menu\|desktop\|bsod` | start on that screen |
| `--demo=1` | pre-build six buildings, spawn six pop-ups, grant 400 bytes |
| `--autoplay=1` | the bot plays: closes pop-ups through their real buttons, builds, picks upgrades |
| `--policy=greedy\|random` | bot policy (default greedy) |
| `--runs=N --jsonl=path` | the bot chains N runs (seed, seed+1, ...) and appends one JSON line per run |
| `--max-wave=N`, `--max-seconds=S` | end a run early (bot batches) |
| `--clock="12:00 AM"` | freeze the taskbar clock (screenshot regression) |
| `--seed=N` | deterministic run (spawns, upgrades, captcha words, imp wandering) |
| `--ui=start\|break` | open the Start menu or the wave-break dialog immediately |
| `--noboot` | skip the boot text on the menu |
| `--screenshot=path.png --delay=S --shots=N` | save N screenshots S seconds apart, then quit |

Example, a rendered run with the bot under a virtual display:

```sh
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 -- --screen=desktop --autoplay=1 --screenshot=screenshots/play.png --delay=9 --shots=6
```

## Status

Vertical slice. Every system in the design doc exists and is wired together: eight pop-up
types with completion tasks and traps, RAM pressure and the crash, waves with upgrade picks,
seven buildings, imps with training, meta-progression with four perks. Numbers are a first
guess and have not been playtested by a human yet. See `docs/DESIGN.md` for the roadmap.
