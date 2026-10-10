# Balance baseline (bot play, phase 4)

First tables from the harness, recorded so later changes can be compared against them.
Produced by `tools/balance.py` from three batches on the committed numbers, 4 waves max:
20 greedy runs (seeds 100 to 119), 10 random runs (200 to 209), 10 heuristic-driver runs
(300 to 309). Regenerate with:

```sh
tools/botrun.sh GODOT 20 greedy 100 4
tools/botrun.sh GODOT 10 random 200 4
python3 tools/policy_driver.py GODOT --backend heuristic --runs 10 --seed 300 --max-wave 4
python3 tools/balance.py runs/*.jsonl --events runs/telemetry --markdown
```

## What the bots can and cannot do

Read the tables with this in mind. The greedy and heuristic bots complete only the
one-click pop-ups (error OK, update Install, the small links on the ad and the virus
warning). They always X the survey, newsletter, captcha and toolbar wizard, so the 0%
completion rates on those types measure the bots, not the design. Trained imps do complete
them (the `by_imp` column). No bot ever builds a Firewall, Antivirus Shrine or Pointer
Shrine, so the NEVER flags on those are a policy gap to fix before reading them as a design
problem. The random policy is a floor: uniformly random legal clicks.

## Reading of the baseline

- **RAM is not a threat to a competent player at the current numbers.** Greedy and heuristic
  reach wave 5 in every run; a sweep with `run.base_ram=80` produced identical outcomes to
  base, meaning the bots never get near the limit. Random dies in wave 1 in 8 of 10 runs.
  The pressure is attention, as designed, but a human is slower than a bot that clicks every
  0.35 s. Human playtests decide whether 100 RAM is right; the bots say it is not binding.
- **Faster spawning raises score, not deaths.** `spawn.first_interval=2.0,spawn.min_interval=0.5`
  lifted the greedy mean score from 170 to 273 over the same seeds with one death in ten.
  More pop-ups means more bytes. If the early game feels slow to humans, this is the knob.
- **Hut cost matters more than RAM.** `building.hut.cost=30` cut score by 8% and produced
  the only other death. The first hut is the pacing gate.
- **Imps are a small share of closes (1 to 25%)** because the bot out-clicks them. Against a
  human the share will be higher; this is the number to watch in human telemetry.
- **Errors multiply.** 30 timeouts in 461 error spawns even with bots; for humans this will
  be the main early snowball, as the design doc predicted.
- **Conditional scores favour early economy picks** (`more_ram`, `free_imp`, `fast_imps`) but
  with 40 runs these differences are not significant; treat the table as a smoke test of
  the tooling until batches are in the hundreds.

## Next experiments (sweeps to run, numbers to leave alone until then)

1. Give the heuristic a cost model for Firewall, Antivirus and Pointer Shrine so the NEVER
   rows carry information.
2. Teach the bots the multi-step completions (survey, newsletter, captcha, toolbar) so
   completion rates measure the design.
3. Human telemetry: ten runs by a person, then rerun `balance.py --events` on the
   `user://telemetry` folder and compare the pop-up table against the bot table.
4. Sweep `run.overload_grace` (2, 3, 5) and `run.base_ram` (80, 100, 140) on human-speed
   policies, once a slower bot (`--decision-interval` 1.5 to 3 s) exists.

## Tables

40 runs from 3 file(s); policies: {'greedy': 20, 'random': 10, 'external': 10}

## survival: share of runs reaching each wave
| policy | wave | n | reached | died_in_wave |
|---|---|---|---|---|
| external | 1 | 10 | 100% | 0 |
| external | 2 | 10 | 100% | 0 |
| external | 3 | 10 | 100% | 0 |
| external | 4 | 10 | 100% | 0 |
| external | 5 | 10 | 100% | 0 |
| greedy | 1 | 20 | 100% | 0 |
| greedy | 2 | 20 | 100% | 0 |
| greedy | 3 | 20 | 100% | 0 |
| greedy | 4 | 20 | 100% | 0 |
| greedy | 5 | 20 | 100% | 0 |
| random | 1 | 10 | 100% | 8 |
| random | 2 | 10 | 20% | 2 |
| random | 3 | 10 | 0% | 0 |
| random | 4 | 10 | 0% | 0 |
| random | 5 | 10 | 0% | 0 |

## upgrades: pick count, share of runs, mean final score with vs without
| upgrade | picked | runs_with | score_with | score_without | flag |
|---|---|---|---|---|---|
| more_ram | 19 | 38% | 199.1 | 112.2 |  |
| free_imp | 18 | 32% | 204.1 | 116.3 |  |
| fast_imps | 13 | 32% | 187.6 | 124.2 |  |
| quick_hands | 12 | 25% | 180.6 | 132.9 |  |
| complete_bonus | 11 | 28% | 186.5 | 129.0 |  |
| lean_popups | 11 | 25% | 171.8 | 135.8 |  |
| spawn_slower | 9 | 20% | 155.9 | 142.0 |  |
| antivirus_patch | 7 | 18% | 166.7 | 140.2 |  |
| bytes_now | 7 | 18% | 203.6 | 132.3 |  |
| bigger_x | 6 | 12% | 165.0 | 141.9 |  |
| dismiss_bonus | 5 | 12% | 210.4 | 135.4 |  |
| click_bonus | 4 | 10% | 210.0 | 137.6 |  |

## buildings: build count, share of runs, mean final score with vs without
| building | built | runs_with | score_with | score_without | flag |
|---|---|---|---|---|---|
| hut | 93 | 75% | 190.0 | 9.1 |  |
| ram | 30 | 75% | 190.0 | 9.1 |  |
| coffee | 18 | 45% | 218.8 | 84.3 |  |
| dojo | 5 | 12% | 258.0 | 128.6 |  |
| firewall | 0 | 0% | nan | 144.8 | NEVER |
| antivirus | 0 | 0% | nan | 144.8 | NEVER |
| shrine | 0 | 0% | nan | 144.8 | NEVER |

## crashes: OUT_OF_MEMORY by policy and wave
| policy | wave | deaths | mean_elapsed_s | mean_ram_max |
|---|---|---|---|---|
| random | 1 | 8 | 30.6 | 100.0 |
| random | 2 | 2 | 48.5 | 100.0 |

30 event logs from runs/telemetry

## pop-ups by type (event logs)
| type | spawned | clustered | closed | completed | by_imp | mean_age_s | timeouts | traps |
|---|---|---|---|---|---|---|---|---|
| ad | 571 | 10% | 468 | 72% | 4% | 0.9 | 0 | 29 |
| error | 461 | 7% | 396 | 64% | 2% | 0.9 | 30 | 0 |
| survey | 237 | 0% | 236 | 0% | 8% | 1.2 | 0 | 0 |
| update | 207 | 0% | 206 | 3% | 6% | 1.4 | 0 | 0 |
| newsletter | 148 | 0% | 147 | 0% | 11% | 1.2 | 0 | 0 |
| captcha | 92 | 0% | 91 | 0% | 8% | 1.2 | 0 | 7 |
| toolbar | 60 | 0% | 60 | 0% | 15% | 1.3 | 0 | 0 |
