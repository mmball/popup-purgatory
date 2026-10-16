# Popup Purgatory: roadmap to a finished, published game

Written 2026-10-16 against commit `1a6483a` (phase 5 done). This replaces the short
roadmap at the end of `docs/DESIGN.md` and the phase list in the research report. It is
the plan of record; update it when reality disagrees with it.

## Where we are

Done: a complete core loop (one workday of eight waves, clock out or overtime), eleven
pop-up types, nine buildings, fifteen upgrades, a Service Pack ladder, sideways unlocks,
telemetry on every run, and a harness that lints, tests, renders, plays and balances the
game headless in CI. Not done: a single human has played it, every number is bot-tuned,
there is no sound, no animation beyond float text, no settings, no tutorial, no builds,
no store presence, and the title is a working title.

## The one rule

Nothing in milestones 2 to 7 is worth doing until milestone 1 says the loop is fun. Polish
applied to a loop that is not fun is wasted; content added to a loop that is not fun is
more of the thing that is not fun. Every later milestone keeps a playtest in it for the
same reason.

## Definition of "finished"

A player who has never seen the game can start it, understand it in one run without
reading anything, play a full workday in about ten minutes, lose in a way that feels like
their fault, want to try again, and keep finding new things for ten or more runs. It runs
on Windows, macOS and Linux without a crash report in the first week, has sound, settings
and the basic accessibility tier, and a Steam page whose screenshots and trailer were made
from the real game. That is the bar for 1.0. Early Access can ship before all of it is true;
the EA notes must say which parts.

## Milestones

Estimates are for one person part-time (evenings and weekends, say 10 to 15 hours a week)
with an agent doing most of the implementation. Calendar time, not effort. "Owner" says who
has to make the call or do the thing that cannot be delegated.

### M1. Find the fun (weeks 1 to 3)

Goal: establish with real people that the core tension works, and lock the first-hour
feel.

- You play three runs on SP0 and write down, per run, the moment you were bored and the
  moment you were stressed. (Owner: you.)
- Five to ten playtests by other people, watched silently, same two notes plus "what did
  you think X was for". Friends are fine for this round. Their telemetry goes into
  `tools/balance.py --events` next to the bot baseline in `docs/BALANCE.md`.
- Questions this milestone must answer, with evidence:
  - Is complete-versus-dismiss an interesting choice, or does everyone X everything?
  - Is the first imp arriving in hour 1 or hour 2? (The design says hour 1 or early 2.)
  - Does RAM ever threaten a human in SP0? (Bots say it never does; humans may differ.)
  - Is 50 to 85 seconds per hour right, and is ten minutes the right run length?
  - Does anyone want to play again immediately after a loss?
- Tune only through `--tune` sweeps on the human seeds, then change catalog numbers in the
  same commit as the sweep table.
- Exit: three of five testers ask to play again unprompted, and the first-hour numbers are
  committed. If this does not happen, M1 repeats with a design change (candidates: fewer,
  bigger pop-ups; a slower first hour; imps earlier) before anything else is built.

Risk: friends are kind. Watch what they do, not what they say; the telemetry will say it
anyway.

### M2. Feel and feedback (weeks 3 to 7)

Status 2026-10-16: first pass shipped ahead of M1 at the owner's request (window pop-in
and fold-out, title flash, imp squash/hop/alert/sulk, trauma shake, static-and-shake crash,
overload darkening and rising tone, scaled reward text, hour tally, typed-out BSOD, and
thirteen procedural sounds plus two chiptune loops from `tools/make_audio.py`). Still open:
a watched playtest reacting to it, music that a person has judged, and tuning of every
timing once M1 has run.

Goal: every player action has at least three feedback channels, and the game sounds like
1998.

- Window animation: pop in with a scale bounce; shatter or fold on close; title bar flash
  on raise; a brief red flash when a pop-up multiplies or a leak grows.
- Imps: squash on arrival, hop on completion, idle fidgets, a tiny "!" when they target a
  window, a sulk when a chat widget dodges them.
- The crash: screen shake with trauma-squared decay, a half-second of static, the BSOD
  types itself out. Overload warning: taskbar RAM readout pulses, wallpaper darkens.
- Sound (the biggest single jump in perceived quality): dial-up on boot, a click per
  close, a richer chime per completion, the Windows error chord on errors, a rising tone
  as RAM fills, a short fanfare at 5 PM, the shutdown sound on clock-out. Generated in the
  sfxr family and hand-edited; two or three chiptune loops composed or commissioned in a
  tracker. No generative audio tools, so the Steam disclosure box stays empty.
  (Owner: you choose the music route: commission ~$100 to $300 per loop, or compose.)
- Numbers that pop: reward float text scales with reward; a wave-end tally.
- Harness: screenshot baselines updated deliberately per visual commit; a `--no-juice`
  flag so bots and determinism tests are unaffected by tween timing.
- Exit: a watched playtest where the tester reacts audibly to a close, a crash and a
  clock-out. Screenshot regression green.

### M3. Onboarding, settings, accessibility (weeks 7 to 9)

Goal: a stranger can play it without being told anything, and nobody is locked out.

- First run only: a scripted hour 1 with two slow pop-ups that explain themselves (one
  says "click the X", the next says "or do what it asks for more"), a nudge to the Start
  menu when bytes reach the first hut, and a one-line hint when the first imp arrives.
  Skippable, never repeated, teaches by doing.
- Settings window in the Win98 style: master/music/SFX volume, fullscreen, resolution,
  screen-shake and flash toggles, key rebinding for the hotkeys, language placeholder.
- Pause (Esc), confirm on quit mid-run, save-and-quit between hours (resume from the break).
- Accessibility basic tier: no flashing by default (the virus header), readable font-size
  option, colour-blind-safe reward colours, full keyboard operation of menus, mouse-only
  play already works.
- Save-file versioning: `meta.json` carries a schema version and migrates forward.
- Exit: a tester who has never seen the game completes hour 3 without asking a question.

### M4. Content depth (weeks 9 to 15, overlapping M5)

Goal: run ten feels different from run one. This is where the roguelite lives or dies.

- Pop-ups: aim for 18 to 20 types. Candidates with distinct counterplay: fake download
  bar (completes slowly, cheap to X, but cancelling early spawns a "corrupt file"), printer
  driver wizard (long, pays a lot, blocks the Start menu while open), "your session has
  expired" (locks the Start menu until you re-type a password shown on screen), a chain
  letter (must be forwarded to three imps), a screensaver that steals your cursor for two
  seconds. Each with a counter in the build pool.
- Bosses: at 12 PM and 4 PM, a full-screen modal with a multi-step task (a ten-step
  installer, a captcha gauntlet) while normal spawns pause; the whole desk works on it.
- Imp subtypes via buildings: Reader (completes captchas instantly), Bouncer (blocks one
  spawn near its home every N seconds), Janitor (deletes timed-out windows), Intern
  (cheap, slow, dismiss only).
- More upgrades aimed at build identity: three rough archetypes should emerge (manual
  clicker, imp automation, RAM fortress) and each unlockable pop-up should threaten one.
- Service Packs 7 to 10, and a daily seed with a local leaderboard.
- Meta: more sideways unlocks tied to specific plays, never stats; an unlock screen that
  shows what each run earned.
- Balance: `tools/sweep.py` on every content batch; `docs/BALANCE.md` updated each time.
  Watch the never-picked table; anything never built after twenty human runs is cut or
  changed.
- Exit: ten human runs in a row with no two identical build paths, and every pop-up type
  and building shows up in the pick tables.

### M5. Store presence and wishlists (start week 9, parallel with M4)

Goal: a Steam page that gathers wishlists for months before launch.

- Decide the title (Owner: you). Check Steam, itch, trademark search. "Popup Purgatory" is
  a fine working title; decide whether it ships.
- Capsule art in all Steam sizes, five or more screenshots from the real game, a 30 to 60
  second gameplay-first trailer with the hook inside fifteen seconds. Code-drawn or
  hand-drawn art only; no generated imagery anywhere a player can see.
  (Owner: you, or a commission of a few hundred dollars for the capsule.)
- Steamworks account ($100, tax and bank forms, a week or so of page review). Page copy:
  the one-line pitch, a feature list, the AI content survey answered per
  `docs/DISCLOSURE.md` (to be written at this milestone from the research checklist).
- itch.io page with a free demo build first: the cheapest way to find the first few hundred
  players and get telemetry from strangers.
- Exit: page live, wishlists accumulating, demo downloadable. Do not enter Next Fest until
  pre-fest wishlists are in the thousands; the data says fest gains track pre-fest
  wishlists almost one-to-one.

### M6. Builds and release engineering (weeks 12 to 16)

Goal: every tag produces uploadable builds; crashes report themselves.

- Export presets for Windows, macOS (signed and notarised; Owner: Apple developer account
  if you want a smooth macOS launch) and Linux; a web export for the itch demo.
- CI: on a tag, build all targets, run the full harness, upload artifacts; a separate demo
  preset that shares code and locks content to SP0 and the first four hours.
- Sentry's Godot SDK in release builds (needs 4.5+; we are on 4.7), opt-in telemetry
  upload with a clear setting, and the local event log kept as it is.
- Steam depots and branches (default, beta, demo). Achievements mapped to the existing
  achievement ids; cloud save for `meta.json`.
- Exit: a stranger installs from Steam on each platform and plays a full run; a forced
  crash shows up in Sentry.

### M7. Early Access launch (week 16 to 20)

Goal: a launch that produces reviews and data, not a surprise.

- Content survey filled, EA notes written honestly (what is missing, how long, how price
  will change), price set (the research has the comparables; a small roguelite with this
  scope sits in the $5 to $10 band), launch discount decided.
- A press kit page with the one-paragraph AI statement, screenshots, GIFs, the trailer.
- Keep the demo live after launch. Build the first post-launch update before launch so it
  ships in week two whatever happens.
- Exit: live on Steam, first ten reviews read, first week's telemetry aggregated.

### M8. Live operations to 1.0 (months 5 to 9)

Goal: treat the public game as the balancing instrument and ship small updates often.

- A content drop every three to four weeks, each preceded by a sweep and followed by a
  review of live telemetry and the never-picked table.
- Community: Steam forum, a Discord if there is demand, patch notes in the Win98 voice.
- 1.0 when the "definition of finished" above is true and the reviews say the loop holds
  up past ten runs. Localisation (at least Simplified Chinese, German, French, Spanish,
  Portuguese) before 1.0 if the data shows non-English wishlists; the UI is already all
  code-drawn text, so a string table is a mechanical change.

## What the agent does and what only you can do

The agent can implement every bullet in M2, M3, M4 and M6, keep the harness green, run
sweeps, write page copy drafts and patch notes, and prepare builds. It cannot: play the
game as a human, decide the title, make the art direction call, hold the Steam or Apple
accounts, compose music you like, or judge whether the game is fun. Those items are marked
Owner above. The cadence that works: you play, you say what felt wrong, the agent changes
one system at a time and shows you a screenshot and a sweep table, repeat.

## Standing rules (carried from CLAUDE.md)

- One system per change, verified by the harness before the commit.
- Balance numbers change only with a sweep in the commit.
- Visible AI-generated art, voice or music never enters the game; code assistance is
  fine and, under Valve's 2026 rules, not disclosable.
- Screenshot baselines change deliberately, with the reason in the commit message.

## Risks, named

1. **It isn't fun.** Caught in M1 by design. The fallback is a design change, not polish.
2. **Attention tension doesn't hold against humans.** Bots never die on SP0. If humans
   don't either, the first-hour pacing moves, not the RAM number.
3. **Scope creep in M4.** The exit criterion is build diversity, not type count. Cut what
   the pick tables say nobody uses.
4. **Discoverability.** Roughly 500 AI-disclosed games launch on Steam every month and the
   median game earns about a thousand dollars. The page going up early, the itch demo, and
   a trailer that shows the gimmick in ten seconds are the only levers a solo developer has.
5. **Trade dress.** The look is a Windows 98 parody. No Microsoft marks, names or icons.
6. **Burnout.** The schedule assumes 10 to 15 hours a week for about five months to EA. If
   that is wrong, stretch the calendar; do not skip M1 or M3.

## Immediate next steps

1. You: clone, open in Godot 4.7, play three runs, send notes and the files in
   `user://telemetry/` (on macOS: `~/Library/Application Support/Godot/app_userdata/Popup Purgatory/telemetry/`).
2. Agent: compare your runs against `docs/BALANCE.md`, propose first-hour changes as a
   sweep, and start M2's "no-juice" flag so the harness stays deterministic under animation.
3. Both: decide the music route and the title by the end of M1, because M5 needs them.
