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

## Core loop (one run)

```
wave N (40s + 5s per wave)
  pop-ups spawn on a shrinking interval
  player: drag, X, or complete   ->  bytes
  imps:   walk, stand on the X, dismiss (untrained) or complete (trained)
  open pop-ups occupy RAM; > RAM max for 3s -> crash -> BSOD summary
  bytes -> Start menu -> buildings on the wallpaper
coffee break
  pick 1 of 3 upgrades
wave N+1
```

Score is total bytes earned. Spending doesn't reduce score, so building is never a
sacrifice; the only pressure is time and your one cursor.

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

Spawn interval: `max(0.7, 2.8 - 0.25 * (wave - 1))` seconds, jittered 0.7x to 1.3x,
scaled by the run's `interval_mult` (firewalls and the ad-blocker upgrade raise it).

## Imps

- Hired by Imp Huts. Idle near home, claim the oldest-ish nearby pop-up, walk to its X
  button, stand there for a work timer, close it.
- Untrained imps dismiss (0.6s, X reward). Trained imps complete (per-type time, full
  completion reward). Dojos add two training slots each.
- Target assignment is exclusive (no two imps on one window), scored by
  `age * 25 - distance * 0.5`.
- Imps ride along if you drag the window they're working on.

## Buildings (Start menu, number keys 1-7)

| building | base cost | max | effect |
| --- | --- | --- | --- |
| Imp Hut | 20 | 12 | +1 imp |
| Imp Dojo | 50 | 6 | +2 training slots |
| Coffee Cart | 40 | 4 | imps 25% faster |
| RAM Stick | 35 | 6 | +32 RAM |
| Firewall | 70 | 3 | spawns 15% slower |
| Antivirus Shrine | 60 | 1 | timeouts no longer multiply |
| Pointer Shrine | 60 | 3 | +1 byte per manual close |

Cost grows 50% per copy owned (`cost * (1 + 0.5 * owned)`).

## Upgrades (coffee break, pick 1 of 3)

Bigger X Buttons, Memory Upgrade (+24 RAM), Espresso Shots (imp speed), Quick Hands (imp
work speed), Reflex Clicking (X pays double), Thoroughness (completion +50%), Ad Blocker
trial (spawn slower), Stray Imp (free imp), Lean Windows (-2 RAM per pop-up), Mouse Blessing
(+1 per manual close), Hotfix KB98 (no multiplication), Found Change (+40 bytes).

## Meta-progression

Lifetime bytes go into a bank. Perks bought once from the main menu: Company Imp (start
with a hut), Factory RAM (+20), Pocket Change (15 starting bytes), Veteran Imps (+20% speed).
Saved to `user://meta.json`.

## Fail state

RAM over the limit for 3 seconds. The taskbar RAM readout blinks red with the countdown.
The BSOD lists wave, bytes, closes by you vs imps, imps hired, buildings built, time.

## Balance notes (untested guesses)

- Wave 1 spawns ~14 pop-ups; a player who completes half earns ~30 bytes: one hut, maybe
  two. The first imp should arrive in wave 1 or early wave 2.
- Errors multiplying on timeout is the main early snowball. Antivirus Shrine / Hotfix are
  the answer; both are deliberately a bit pricey so a run has to earn them.
- Completion times for imps (1.5s to 4s) make trained imps roughly 3x the throughput value
  of untrained ones at the cost of a 50-byte dojo.
- Numbers to watch in playtesting: starting hut cost (20), RAM base (100), the 3s grace.

## Roadmap

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
