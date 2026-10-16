# Popup Purgatory, design

## One line

A Windows 98 desktop roguelite where you close pop-ups, earn more for *completing* them
than for dismissing them, and grow a village of imps that close them for you.

## Pillars

1. **The X is never the best answer, only the fastest.** Every pop-up has a real task.
   Doing it pays several times more than clicking the X. The tension is attention: you
   can't complete everything, so you triage.
2. **The desktop is the town.** The wallpaper is a build grid. Imps live there and walk
   up onto the windows to work. The city builder is not a separate screen.
3. **The computer is the health bar.** Open pop-ups occupy RAM. Over the limit for three
   seconds and you get a blue screen. The run summary *is* the BSOD.
4. **Every dark pattern you've ever seen is an enemy type.** Giant prize buttons, pre-checked
   boxes, bundled installers, scareware with a locked X. Falling for one spawns more.

## Core loop (one run = one workday)

```
9 AM .. 5 PM: eight hours, one wave per hour (50s + 5s per hour, about 10 minutes)
  pop-ups spawn on a shrinking interval
  player: drag, X, or complete   ->  bytes
  imps:   walk, stand on the X, dismiss (untrained) or complete (trained)
  open pop-ups occupy RAM; > RAM max for 3s -> crash -> BSOD summary
  bytes -> Start menu -> buildings on the wallpaper
coffee break between hours
  pick 1 of 3 upgrades
5 PM: clock out (a win, recorded) or stay for Overtime (endless, escalating, score only)
```

Score is total bytes earned. Spending doesn't reduce score, so building is never a
sacrifice; the only pressure is time and your one cursor. The taskbar clock shows the
in-game time of day, so the run length is legible without a timer.

Streak: each consecutive manual completion adds 10% to manual completion rewards, capped
at +50%; a manual X resets it; imp closes neither add nor reset.

Overtime: pays 1.5x, the spawn interval tightens 10% per overtime hour on top of the
normal step, breaks offer one card, and the 5 PM score is banked: a crash in overtime
counts the banked score plus half of what came after.

### Difficulty ladder: Service Packs

Opt-in from the main menu. Clocking out on SP n unlocks SP n+1. Each tier stacks on the
ones below: SP1 spawns 15% faster, SP2 starts with 20 less RAM, SP3 doubles timeout
multiplication, SP4 raises building costs 25%, SP5 slows imp work 25%, SP6 cuts the crash
grace to 2 s. The tier is stamped on every telemetry row, so batches stratify by it.

### Meta-progression: sideways unlocks

Achievements add content to the pools. They never add stats, so a fresh profile can win
SP0 with the same numbers a veteran has. The four starting perks bought with banked bytes
are the only stat bonuses and are small and one-time.

| achievement | how | adds to the pools |
| --- | --- | --- |
| Clocked Out | survive to 5 PM once | Cookie banner (pop-up), Screensaver (building), Consent Manager (upgrade) |
| Inbox Zero | 100 pop-ups closed, lifetime | Live Chat (pop-up), Help Desk (building), Do Not Disturb (upgrade) |
| Sensei | build an Imp Dojo | Memory Leak (pop-up), Garbage Collector (upgrade) |
| Patched | clock out on SP2+ | nothing but the badge; SP3 to SP6 open through the ladder |

### Targeted challenges

Each unlockable pop-up punishes one build and has a counter in the same unlock bundle:

| pop-up | targets | the punishment | the counter |
| --- | --- | --- | --- |
| Cookie banner | X-everything builds (Reflex Clicking, Pointer Shrine) | dismissing it spawns two more; Reject All is three clicks deep | Consent Manager makes it one click |
| Live Chat | imp automation | hops away when an imp arrives; imps ignore it for 8 s after | Help Desk teaches imps to close it |
| Memory Leak | RAM stacking (RAM Sticks, Memory Upgrade) | +3 RAM every 5 s until the three-step cleanup; X pays 0 | Garbage Collector halves the growth |

## Resources

| name | role | notes |
| --- | --- | --- |
| Bytes | currency and score | earned per close; score counts total earned |
| RAM | health | base 100; each open pop-up occupies its `ram_cost`; crash after 3s over the limit |
| Wave clock | pacing | spawner stops during the break |

## Pop-up catalog

| type | unlock | RAM | X | complete | task | trap / timeout |
| --- | --- | --- | --- | --- | --- | --- |
| Congratulations (ad) | w1 | 8 | 1 | 4 | click tiny "no thanks" link | big CLAIM button spawns 2 ads |
| Error | w1 | 6 | 1 | 2 | click OK | 12s timeout: multiplies |
| Quick Survey | w2 | 10 | 1 | 5 | pick a rating, Submit | |
| Update Available | w2 | 10 | 1 | 6 | Install (3s progress bar) | "Remind me later" returns in 8s, no reward |
| Newsletter | w3 | 10 | 1 | 6 | uncheck 3 boxes, Continue | any box left checked: 2 ads |
| Security Check (captcha) | w3 | 12 | 1 | 8 | type 5 letters | 20s timeout: +4 RAM each time |
| Toolbar Setup | w4 | 14 | 1 | 7 | 3-page wizard, uncheck bundle | bundle left checked: 1 ad |
| Virus Warning | w5 | 16 | 2 | 10 | tiny "ignore warning" link | X locked 3s; SCAN spawns 2 errors; 15s timeout spawns 2 errors |
| Cookie banner (unlock) | w2 | 9 | 1 | 7 | Manage, uncheck 3, Confirm | X spawns 2 cookies; ACCEPT ALL spawns 2 ads |
| Live Chat (unlock) | w3 | 7 | 1 | 6 | type a reply, Send | imp-proof without a Help Desk |
| Memory Leak (unlock) | w4 | 6 | 0 | 9 | three cleanup clicks | +3 RAM every 5 s while open |

Spawn interval: `max(0.7, 2.8 - 0.25 * (wave - 1))` seconds, jittered 0.7x to 1.3x,
scaled by the run's `interval_mult` (firewalls and the ad-blocker upgrade raise it).
Unlockable types only enter the pool once their achievement is earned.

## Imps

- Hired by Imp Huts; an imp remembers its hut as its home. A dojo with a free slot (two
  per dojo) pulls the nearest idle untrained imp whose hut is within 2 cells (imps hired
  by upgrades have no hut and train anywhere): it walks in, a bar fills over the dojo for
  6 s, and it comes out trained (bigger body, black belt, mortarboard; it reads a book
  while completing).
- Experience: each close adds 2% speed, capped at +30% (15 closes); ten closes earn a
  service stripe. Idle near home, claim the oldest-ish nearby pop-up, walk to its X
  button, stand there for a work timer, close it.
- Untrained imps dismiss (0.6s, X reward). Trained imps complete (per-type time, full
  completion reward). Dojos add two training slots each.
- Coffee Carts are local: an imp moves 25% faster per cart within 2 cells of its hut
  (carts stack). Selling the hut fires its imp: it walks off the edge of the desk.
- Target assignment is exclusive (no two imps on one window), scored by
  `age * 25 - distance * 0.5`.
- Imps ride along if you drag the window they're working on.

## Buildings (Start menu, number keys 1-7)

| building | base cost | max | effect |
| --- | --- | --- | --- |
| Imp Hut | 20 | 12 | +1 imp, homed at this cell |
| Imp Dojo | 50 | 6 | +2 training slots for huts within 2 cells |
| Coffee Cart | 40 | 4 | imps from huts within 2 cells 25% faster (stacks) |
| RAM Stick | 35 | 6 | +32 RAM |
| Firewall | 70 | 3 | no pop-up spawns within 3 cells (a window may not overlap the ring) |
| Antivirus Shrine | 60 | 1 | timeouts no longer multiply |
| Pointer Shrine | 60 | 3 | +1 byte per manual close |
| Help Desk (unlock) | 45 | 1 | imps can close Live Chat |
| Screensaver (unlock) | 55 | 1 | every 30 s, 6 s with no spawns |

Cost grows 50% per copy owned (`cost * (1 + 0.5 * owned)`).

Radius effects (dojo 2, coffee 2, firewall 3, Chebyshev cells) are drawn as square rings
while placing and while the Start menu is open. The other buildings stay global.

### Demolish and relocate

- Start menu, "Demolish...": hovering an owned building tints it red and shows
  "Sell for N"; click sells, right-click or Escape leaves the mode. Refund is 50% of the
  price paid, 75% during a coffee break.
- Reversals: hut fires that hut's imp (the least valuable one homed there, untrained
  before trained, fewest closes); dojo loses its two slots and kicks out a trainee
  untrained (graduates stay trained); coffee and firewall effects vanish with the
  building; RAM Stick is refused while removing it would put RAM over the new max
  ("would crash"); antivirus lets timeouts multiply again unless Hotfix KB98 was taken;
  shrine drops the click bonus; help desk and screensaver switch off.
- Relocate: during a break only, drag a building to a free cell for free. A moved hut
  takes its imp's home with it. Firewall rings and cart coverage follow the building.

### Recycle Bin

- Drag any pop-up over the Recycle Bin icon (the icon tints while a window hovers it)
  and release: the window is deleted with no reward and no penalty. No bytes, no cookie
  spawn, no remind-later, no timeout consequence, streak untouched; its RAM is freed
  like a normal close. It never counts as closed or completed (run rows carry
  `popups_recycled` and `bin_items` separately).
- Capacity three. The icon shows one crumpled sheet per item and an "n/3" count; a fourth
  drop is refused ("Recycle Bin is full") and the window is nudged 40 px off the icon.
- "Empty Recycle Bin": double-click the icon. It takes 2 s of game time (a bar fills
  under the icon; drops are refused meanwhile; paused by a break), then the bin is
  clear and the paper-crunch sound plays.
- Imps never use it. The bots: greedy and random never recycle; the external policy
  gets `recycle:<id>` and `empty_bin` moves with the capacity in state, and the
  heuristic driver recycles a cookie banner only above 85% RAM.

## Upgrades (coffee break, pick 1 of 3)

Keyboard Shortcuts (Task Manager cooldown), Admin Rights (Task Manager ends 5),
Bigger X Buttons, Memory Upgrade (+24 RAM), Espresso Shots (imp speed), Quick Hands (imp
work speed), Reflex Clicking (X pays double), Thoroughness (completion +50%), Ad Blocker
trial (spawn slower), Stray Imp (free imp), Lean Windows (-2 RAM per pop-up), Mouse Blessing
(+1 per manual close), Hotfix KB98 (no multiplication), Found Change (+40 bytes).
Unlockable: Consent Manager, Do Not Disturb, Garbage Collector (see Targeted challenges).

## Abilities (keyboard chords and tray icons)

Three things the keyboard can do under pressure, each also a clickable icon in the
taskbar tray with its cooldown drawn as a rising sweep:

| ability | chord | cooldown | effect |
| --- | --- | --- | --- |
| Alt+F4 | Alt+F4 | none | dismisses the front window (a keyboard X; refuses a locked X) |
| Task Manager | Ctrl+Shift+Esc | 45 s | a Win98 Task Manager lists open pop-ups, biggest RAM first; End Task closes the selected one instantly (locked or not) for its dismiss reward, 3 times per use (5 with Admin Rights); imps keep working |
| Ctrl+Alt+Del | Ctrl+Alt+Del, held | once per hour | the desk freezes while held: no spawns, no ageing, no RAM growth, no clock; the screen dims and a bar fills; hold past 5 s and the machine resets (BSOD, reason RESET) |

Alt+F4 and End Task are manual dismisses, so they reset a streak like any X. Nothing
is ready during a break. Keyboard Shortcuts (upgrade) recharges Task Manager 25% faster
per pick; Admin Rights raises its ends to five. Cooldowns are tunable as
`ability.<id>.cooldown`, the hold limit as `ability.freeze_max`. Bots cannot hold a
key: the external policy's `ability:ctrl_alt_del` releases after 4 s; greedy opens Task
Manager above 80% RAM and clicks End Task until the uses run out.

## Meta-progression

Lifetime bytes go into a bank. Perks bought once from the main menu: Company Imp (start
with a hut), Factory RAM (+20), Pocket Change (15 starting bytes), Veteran Imps (+20% speed).
Saved to `user://meta.json`.

## Fail state

RAM over the limit for 3 seconds. The taskbar RAM readout blinks red with the countdown.
The BSOD lists wave, bytes, closes by you vs imps, imps hired, buildings built, time.

## Feel

Every state change has a visual and a sound; none of it touches game state (`Juice`,
`Sfx`, both off under `--no-juice`). Windows scale-bounce in and fold away; raising one
flashes its title bar; multiplication, leaks and traps flash red and add screen shake
(trauma squared, fast decay). Imps squash on landing, hop when they finish, show a "!"
when they pick a target and sulk when a chat widget dodges them. RAM past 75% darkens the
wallpaper and plays a rising tone that quickens with the fill; overload adds a warning
blip and shake. The crash is half a second of static and shake, then the BSOD types itself
out. Sounds: click per dismiss, chime per completion (bigger for bigger rewards), the
three-note error chord on traps, a two-tone multiply, a hop, the 5 PM fanfare, the
shutdown chord on clock-out, a dial-up on boot. All synthesised in `tools/make_audio.py`.

## Balance notes (untested guesses)

- Wave 1 spawns ~14 pop-ups; a player who completes half earns ~30 bytes: one hut, maybe
  two. The first imp should arrive in wave 1 or early wave 2.
- Errors multiplying on timeout is the main early snowball. Antivirus Shrine / Hotfix are
  the answer; both are deliberately a bit pricey so a run has to earn them.
- Completion times for imps (1.5s to 4s) make trained imps roughly 3x the throughput value
  of untrained ones at the cost of a 50-byte dojo.
- Numbers to watch in playtesting: starting hut cost (20), RAM base (100), the 3s grace.

## Roadmap

The plan of record is `docs/ROADMAP.md` (milestones M1 to M8). The list below is the
older sketch, kept for the ideas in it:

1. **Playtest and tune** (next): human play, adjust the numbers above.
2. **Juice**: window open/close animation, imp squash on arrival, crash screen flicker,
   sound (dial-up, "ding", the Win98 error chord), cursor sprite.
3. **More pop-up types**: cookie banner (reject all is 3 clicks deep), chat widget,
   "your session has expired" login, printer driver install, fake download bar.
4. **Imp types**: Clicker (fast dismisser), Reader (completes captchas instantly),
   Bouncer (prevents one spawn in a radius), Janitor (clears timed-out windows).
5. **Run modifiers**: daily seed, "dial-up mode" (everything slower, pays more),
   "IT department" (no imps, big manual multipliers).
6. **Meta**: unlock pop-up types by reaching waves; persistent wallpaper decorations.
7. **Export**: web build (itch.io), desktop builds.
