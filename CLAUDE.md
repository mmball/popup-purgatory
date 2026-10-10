# Popup Purgatory — agent instructions

Read this before touching anything. It pins the engine, the conventions, and the
verification loop. The rules exist because agents drift toward Godot 3 APIs, Python
idioms, and "it compiles so it works". The harness in `tools/` is the feedback channel
you otherwise lack: you cannot see the rendered game, so run it.

## Engine: Godot 4.3 stable, GDScript 2.0. Not Godot 3. Not 4.4+.

- Binary used in CI: `Godot_v4.3-stable_linux.x86_64` (see `.github/workflows/ci.yml`).
- Do not use APIs that first appeared after 4.3 or that were removed in 4.0. If unsure
  whether an API exists in 4.3, check the docs for 4.3 specifically, then write a tiny
  headless probe before relying on it.
- No `.uid` sidecar files exist in this project (they arrive with 4.4). Do not create
  them by hand. An engine upgrade is a deliberate, single-commit event (roadmap phase 2),
  never a side effect of another task.

### Banned (Godot 3 / pre-4.0) — `tools/lint.sh` fails the build on these

| Banned | Use instead |
| --- | --- |
| `deg2rad`, `rad2deg` | `deg_to_rad`, `rad_to_deg` |
| `rand_range`, `randi() % n`, `randomize()` in gameplay code | the run's `RandomNumberGenerator` (see Determinism) |
| `stepify`, `linear_interpolate`, `move_toward` on Vector (3.x) | `snappedf`, `lerp`, `Vector2.move_toward` |
| `instance()` | `instantiate()` |
| `yield(...)` | `await` |
| `export var`, `onready var`, `tool` | `@export`, `@onready`, `@tool` |
| `connect("signal", obj, "method")` string style | `signal_name.connect(callable)` |
| `.empty()`, `.invert()` | `.is_empty()`, `.reverse()` |
| `OS.get_ticks_msec` | `Time.get_ticks_msec` |
| `KinematicBody2D`, `Spatial`, `PoolStringArray`, `Reference` | `CharacterBody2D`, `Node3D`, `PackedStringArray`, `RefCounted` |
| `get_node(...)` in `_process`, `get_tree().get_nodes_in_group()` per frame | cache the reference once |

### Python idioms that are not GDScript

- No `len(x)` on arrays: use `x.size()`. No list comprehensions. No `elif x in (a, b)`
  with tuples. No `print(f"...")`: use `"%s" % v` or `str()`.
- `match` is not `switch` with fallthrough; no `break` needed.
- Dictionaries: `d.get("k", default)`; a missing key with `d["k"]` is an error.

## Static typing is mandatory

`project.godot` sets `debug/gdscript/warnings/untyped_declaration = 2` (error), so an
untyped `var x = ...` fails the parse. Every `var`, parameter and return type is declared.
Use `:=` only when the right side's type is unambiguous to the parser (a constructor,
a literal, a typed call); otherwise write the type. Variants that are genuinely dynamic
(`claim()` returning an id or null) are declared as `Variant` with a comment saying why.
This turns hallucinated APIs and wrong types into parse errors instead of runtime nulls.

## One error-handling pattern

- **Invariants in pure logic** (`src/core/`): `assert(cond, "message")`. These classes
  hold no nodes and are unit tested.
- **Programmer errors at runtime** (unknown id, missing node): `push_error("Context: what")`
  and return early. Never swallow with a bare `return`.
- **Recoverable environment problems** (save file unreadable, missing dev arg):
  `push_warning(...)` and fall back to the documented default.
- No `try`-like constructs exist; don't emulate them with `is_instance_valid` sprinkled
  everywhere. Check validity at the boundary where a reference enters (`Imp._target_valid()`).
- Signals report outcomes; return values report data. Don't mix (a function either emits
  or returns, not both).

## Folder layout (fixed)

```
src/core/      pure logic, RefCounted, no nodes, unit tested, no `Game` autoload access
src/ui/        reusable Win98 widgets (Win98, Win98Button, BevelPanel, WindowFrame, FloatText)
src/popups/    PopupBase, PopupContent, PopupSpawner; content/<type>_content.gd per pop-up type
src/imps/      Imp, ImpManager
src/village/   Village grid, Building, DesktopIcon
src/desktop/   the gameplay screen and its chrome (Taskbar, StartMenu, BreakDialog, ConfirmDialog)
src/screens/   MainMenu, BsodScreen
src/dev/       dev-only tooling (Autoplay); must never be required at runtime
src/autoload/  game.gd only ("Game" singleton: run, meta, screen flow, dev args)
tests/         test_*.gd extending TestCase; run_tests.gd runner
tools/         test.sh, lint.sh, screenshot.sh
docs/          DESIGN.md (the design doc), img/ (curated screenshots)
```

- New pop-up type: add a `DEFS` entry in `src/core/popup_catalog.gd` and a content script
  in `src/popups/content/`. Nothing else should need to change; `test_catalog_is_well_formed`
  checks the script path exists.
- New building: `BuildingCatalog.DEFS` + `ORDER`, a `_draw` branch in `Building`, and an
  effect branch in `Desktop._build`.
- New upgrade: `UpgradeCatalog.DEFS` + `apply`. If it needs scene access, return an effect
  tag and handle it in `Desktop._on_upgrade_chosen`.
- All UI is built in code. The only scene file is `src/main.tscn`. Do not add `.tscn` files
  for new windows; extend `WindowFrame` or `PopupContent`.
- Rendering order in `Desktop` is child order: wallpaper, village, pop-ups, imps, float
  text, taskbar, start menu, break dialog. Keep it.

## Moves and renames

Do not move, rename or delete a script or scene without, in the same change: grepping
for every `res://` path and `class_name` that references it, re-running `tools/test.sh`,
and reading the import log for "not found". `src/main.tscn` references `res://src/main.gd`
by path; catalogs reference content scripts by path.

## Determinism

Every run is reproducible from one integer, `RunState.seed`.

- `Game.start_run()` sets it from `--seed=N` or draws a random one and records it. The
  taskbar tooltip and the BSOD show the seed; log lines start with `seed=`.
- All gameplay randomness goes through one `RandomNumberGenerator` owned by `Desktop`
  (`Desktop.rng`) and passed down (spawner, schedule, upgrades, captcha, imps). Never call
  the global `randf()`/`randi()`/`randomize()` in gameplay code; `tools/lint.sh` fails on it
  outside `tests/` and `src/dev/`.
- Timing still depends on frame delta. For bit-identical replays run with `--fixed-fps 60`.
- `tests/test_spawn_schedule.gd::test_deterministic_with_seed` guards the schedule; keep a
  determinism test alongside any new random system.

## Verification loop (run it, don't trust yourself)

```sh
tools/test.sh /path/to/godot      # lint -> import -> unit tests -> seeded bot smoke run
tools/screenshot.sh /path/to/godot  # renders menu/desktop/start menu/break/BSOD to screenshots/
```

- Exit codes lie: Godot returns 0 with `SCRIPT ERROR` lines in stderr. `test.sh` greps the
  logs. Do the same for any ad-hoc run (`2>&1 | grep -E "SCRIPT ERROR|ERROR:"`).
- Headless runs cannot render or receive real input. The autoplay bot (`--autoplay=1`)
  injects synthetic mouse events so GUI code paths execute; anything visual needs the
  Xvfb screenshot path and a look at the PNG.
- Dev flags (after `--`): `--screen=`, `--demo=1`, `--autoplay=1`, `--seed=N`,
  `--ui=start|break`, `--noboot`, `--screenshot=path --delay=S --shots=N`.
- Before claiming a visual change works, produce a screenshot and look at it. Before
  claiming a bug is fixed, reproduce it with a seed first.
- Keep tasks small. One system per change. Run the loop before every commit.

## Scope rules for agents

- Don't widen a task. Balance numbers live in the catalogs and `docs/DESIGN.md`; change
  them only when asked, and update the design doc's table in the same commit.
- `raw`-style immutability applies to `docs/img/`: regenerate, don't hand-edit.
- Never add third-party addons without a note in README "Status" and a lint/test pass.
- No model identifiers in commits or code comments.
