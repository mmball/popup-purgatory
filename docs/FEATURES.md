# Gameplay feature plan

Written 2026-10-16 from the owner's question about selling huts and the pop-up review.
Each entry: the idea, whether it is actually a good idea, how to build it, and what it
costs the harness. Ordered by the phases at the end, not by how exciting they are.

## 0. Make training visible (legibility fix, do first) — DONE 2026-10-16

**Problem.** A dojo adds two training slots and the next two untrained imps flip to
trained instantly, wherever they are. The only cues are a 16-pixel mortarboard and the
taskbar count. The owner did not know dojos train imps he already has; players won't
either.

**Verdict.** Not optional. The hut/dojo relationship is the core of the automation half of
the game and it is currently invisible.

**Design.**
- A dojo with a free slot pulls the nearest idle untrained imp: the imp walks to the dojo,
  steps inside (hidden), a progress bar fills above the dojo for 6 seconds, the imp pops
  out wearing the hat with a "graduated!" float and a chime. The dojo shows "1/2" on its
  sign. Training costs the imp 6 seconds of work, which is the price of the upgrade and
  also the thing that makes it legible.
- Trained imps get a bigger, unmistakable look: the hat stays, plus a black belt band
  across the body and a slightly larger body (radius 8 to 9). While working on a
  completion they show a small book instead of the pointer.
- Copy: hut "Hires one imp (dismisses pop-ups)"; dojo "Trains two of your imps to complete
  pop-ups instead of dismissing them"; Start menu item detail shows "0/2 trained" on dojos.
- First time an imp graduates in a profile, a one-line hint: "Trained imps complete
  pop-ups for the full reward."

**Implementation.** `Imp` gets a TRAIN state (walk to dojo, wait inside with `visible =
false`, emerge). `ImpManager._apply_training` becomes a queue: a dojo `Building` holds
`slots`, `occupied`, `progress`; the manager assigns an idle untrained imp to a dojo with a
free slot. `Building._draw` draws the bar and the sign. Telemetry: `train_start`,
`train_done`. Six seconds is deterministic (no RNG), so the determinism check is
unaffected; `test_phase5` gains a slot-accounting test on a pure helper.

## 1. Demolish and relocate buildings — DONE 2026-10-16

**Verdict.** Good, with the correction that dojos do not replace huts; the real uses are
respec (you built RAM Sticks before the cookie banners arrived and now want a Help Desk)
and grid space on long overtime runs. Its value doubles once placement matters (item 2).

**Design.**
- Start menu: "Demolish..." enters a mode where hovering an owned building tints it red
  and shows "Sell for N". Click sells; Esc or right-click leaves the mode. Refund is 50%
  of the price paid, 75% during a coffee break (sell in the calm, not the panic).
- Reversals: hut, the most recently hired untrained idle imp walks off the screen edge
  (a veteran, item 6, is never the one chosen); dojo, two training slots go, graduates
  stay trained; coffee, speed back down; RAM Stick refused if removing it would put
  ram_used over the new max ("would crash"), otherwise max drops; firewall, interval back;
  antivirus, timeouts multiply again unless the Hotfix upgrade was taken; shrine, click
  bonus down; help desk, imps forget the trick; screensaver off.
- Relocate: during a break only, drag a building to a free cell for free. Needed only if
  item 2 ships.

**Implementation.** `Building` stores `price_paid` and `cell`. `Village` gains a demolish
mode mirroring placement mode (hover cell, click, cancel) and a drag-to-relocate mode the
desktop enables during breaks. `Desktop.demolish(cell)` reverses the effect switch in
`_build`; `BuildingCatalog.refund` holds the rates. Telemetry `demolish` and `relocate`.
External policy gains `sell:<x>,<y>` moves; greedy and random never sell.

*Shipped as designed, with one change: a hut sale fires the imp homed at that hut (least
valuable first), not "the most recent untrained imp", because imps now belong to huts
(item 2).*

## 2. Placement that matters: radius effects — DONE 2026-10-16 (step one)

**Verdict.** The biggest upgrade to the "build a town" half of the pitch, and the
riskiest: it adds a layer to a ten-minute game, needs new UI, and re-tunes everything.
Stage it. Step one is radius effects with rings; adjacency bonuses only if step one
earns its place in playtests.

**Design (step one).**
- Coffee Cart speeds only imps whose home hut is within 2 cells.
- Dojo trains only imps from huts within 2 cells (so a dojo in the corner trains nobody).
- Firewall becomes spatial: pop-ups do not spawn with their centre inside a 3-cell radius
  around it. Suddenly where you put it is the whole decision.
- RAM Stick, Antivirus Shrine, Pointer Shrine, Help Desk, Screensaver stay global.
- In placement mode the ghost shows the ring; existing buildings show their rings while
  the Start menu is open. Imps' homes are their huts, so the cart/dojo rules are checkable
  by eye.
- The grid stays 20 by 10 for now; if rings never constrain anything, shrink it or
  reserve more cells for desktop icons.

**Step two (maybe).** Adjacency bonuses (two huts touching share a cart; RAM Stick next to
Firewall +8) only after human playtests show step one is understood.

**Implementation.** `BuildingCatalog.radius(id)` (Tuning `building.<id>.radius`);
`Village.buildings_within(cell, r)`, `carts_in_range`, `firewall_zones`, square rings in
placement and while the Start menu is open; `ImpManager.spawn_imp` records `home_cell`;
speed (`speed_mult_for`) and training (`pick_trainee(dojo)`) consult the village. The
spawner's `_pick_position` rejects windows overlapping a firewall circle (12 retries, then
pushed outside the nearest ring). The bots place through `Village.suggest_cell(id)`
(carts and dojos where they cover the most huts, firewalls spread out near the centre).
Step two (adjacency) is still open.

## 3. Recycle Bin: drag a pop-up to delete it — DONE 2026-10-16

**Verdict.** Good: small, thematic, and it gives dragging a purpose. It must not be a free
cookie counter.

**Design.** Drag any pop-up over the Recycle Bin icon and release: the window is deleted
with no reward and no penalty (no cookie spawn, no remind-later). The bin holds three
items; a fourth cannot be dropped until "Empty Recycle Bin" (double-click the icon) which
takes 2 seconds and plays the paper-crunch sound. So it is a safety valve with a
capacity, not an exploit. Imps cannot use it.

**Implementation.** `WindowFrame` emits `drag_ended(global_pos)`; `Desktop` checks the
bin icon's rect; `DesktopIcon` "bin" draws full/empty states and a count. Telemetry
`recycled`. External policy gains `recycle:<id>` moves with the capacity in state.

*Shipped as designed: `drag_moved`/`drag_ended` on `WindowFrame`, `RunState.recycle_popup`
and `empty_bin` (pure, tested), the bin icon draws sheets, a count and the emptying bar,
telemetry `recycled` and `bin_emptied`, the `crunch` sound, and `recycle:<id>` /
`empty_bin` external-policy moves (greedy and random never recycle).*

## 4. Minimise to the taskbar

**Verdict.** Defer. It adds a hidden state (a window that still costs RAM but is off
screen and keeps ageing) that is hard to read and easy to forget, which is the opposite
of what the attention game wants. Revisit only if playtests ask for "put this away for a
moment".

## 5. Active abilities with cooldowns (system tray) — DONE 2026-10-16

**Verdict.** Yes. This is the roguelite ingredient the game lacks: a decision under
pressure beyond "which window". Thematic hooks write themselves.

**Design.**
- Alt+F4 (no cooldown): dismiss the front window. A keyboard X; also an accessibility
  win.
- Task Manager (Ctrl+Shift+Esc, 45 s cooldown): a Win98 Task Manager window lists open
  pop-ups; End Task closes the selected one instantly for its dismiss reward, up to three
  per use. Imps keep working meanwhile.
- Ctrl+Alt+Del (once per hour): spawns freeze for 5 seconds and everything on screen
  pauses ageing; the screen dims; a reset risk: holding it longer than 5 s crashes.
- Tray icons on the taskbar show the cooldowns; upgrades shorten them ("Keyboard Shortcuts
  -25% cooldowns", "Admin Rights: Task Manager ends 5"). Buildings could too (a Server
  Room halves Ctrl+Alt+Del cooldown).

**Implementation.** `RunState` holds `abilities: {id: cooldown_left}` and `ability_ready`
(pure, tested). `Desktop._unhandled_input` maps the chords; the Task Manager is a
`WindowFrame`. Telemetry `ability` with id. External policy gains `ability:<id>` moves;
greedy uses Task Manager when RAM is above 80% so bot batches reflect the feature.

*Shipped as designed with three changes: Ctrl+Alt+Del is hold-to-freeze (release ends
it; past 5 s the machine resets with a RESET BSOD), which makes the reset a real gamble
instead of a timer; the tray icons are clickable so mouse-only play keeps every ability;
the Server Room building is not built, the two upgrades cover cooldowns for now.*

## 6. Completion streaks — DONE 2026-10-16

**Verdict.** Yes, cheap, and it rewards exactly the behaviour the design wants.

**Design.** Each consecutive manual completion adds 10% to manual rewards, capped at +50%;
any manual X resets to 0. Imp closes neither add nor reset. The taskbar shows "Streak x5"
and the completion chime rises in pitch with the streak. The cap keeps automation builds
competitive.

**Implementation.** `RunState.streak`, applied inside `reward_for` when the close is manual
(add a `manual` argument). Unit tests for build, cap and reset. Telemetry carries the
streak on `popup_closed`.

## 7. Imps that grow — DONE 2026-10-16

**Verdict.** Yes. Makes early imps worth keeping and makes selling a hut hurt.

**Design.** +2% speed per close, capped at +30% at 15 closes; a veteran (10+) gets a
stripe on the body. Training keeps experience. Demolish never fires a veteran if an
untrained rookie exists.

**Implementation.** `Imp.closes` and a speed multiplier in `speed()`; drawn in `_draw`.
Deterministic. Shows up in the per-wave table as a rising imp share.

## 8. Overtime as a gamble — DONE 2026-10-16

**Verdict.** Yes, small. Today overtime is free points until you die.

**Design.** Overtime hours pay 1.5x, but the spawn interval tightens 10% per overtime
hour on top of the normal step, breaks are shorter (one upgrade card instead of three),
and the clock-out score is banked: a crash in overtime keeps the 5 PM score plus half of
what was earned after. Then the choice at 5 PM is a real one.

**Implementation.** `RunState.banked_score`, `overtime_mult`; `SpawnSchedule` reads an
extra overtime step; `BreakDialog` takes a card count. Tests for the banking rule.

## 9. Bosses at noon and 4 PM — DONE 2026-10-16

**Verdict.** Yes, but it is the largest content item and belongs in roadmap M4 after the
above. A full-screen "Service Pack Install" modal with ten steps (uncheck, type, wait,
find the tiny link) while spawns pause; trained imps can each take one step; a big
reward and a guaranteed counter-upgrade card afterwards. It gives the day a shape and
makes 12 PM and 4 PM landmarks on the clock.

*Shipped as designed: `BossWindow` (ten pages, 75 s, traps spawn an ad), opened by the
desktop at the start of waves 4 and 8, never in overtime. Trained imps take one page
each through `ImpManager.request_boss`. The win pays 60 bytes and a free pick of three
upgrades, counters to unlocked pop-ups first; a timeout spawns three errors. The upgrade
pool is not rolled from a separate "counter" list: counters are the upgrades that gate
on an achievement. Bots: greedy and random click through it, the external policy gets a
`boss_step` move. Telemetry boss_start / boss_step / boss_end.*

## Phases

| phase | items | why together |
| --- | --- | --- |
| A, legibility and cheap wins | 0 training visible, 6 streaks, 7 imp growth, 8 overtime gamble | small, deterministic, no new UI modes; fix the thing the owner misread |
| B, the town | 1 demolish and relocate, 2 radius effects | one system: buildings as spatial objects you place, move and remove; bots need a radius-aware placer first |
| C, the desk | 3 Recycle Bin, 5 abilities | both are "what else can the mouse and keyboard do"; both need external-policy moves |
| D, later | 9 bosses; 4 minimise only if asked for | content-sized; M4 |

Every phase ends with the loop, a greedy and heuristic batch on the full pool, the
balance tables, and re-baselined screenshots where chrome changed. Phase A first, because
item 0 answers the question that prompted this plan.
