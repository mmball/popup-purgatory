# Telemetry schema

Two kinds of records, both JSON lines.

## Run rows (`runs/*.jsonl`, one per run)

Written by the autoplay bot (`--jsonl=path`). Shape is `RunState.summary()`:

| field | type | meaning |
| --- | --- | --- |
| seed | int | the run seed; replays the run with `--seed` |
| policy | string | `greedy`, `random`, `external`, or `human` |
| reason | string | `OUT_OF_MEMORY`, `SHUTDOWN`, `MAX_WAVE`, `MAX_SECONDS` |
| wave | int | wave the run ended in |
| score | int | total bytes earned |
| bytes | int | unspent bytes at the end |
| elapsed | float | seconds of game time |
| spawned, closed, completed | int | pop-up counts |
| player_closes, imp_closes | int | who closed them |
| imps_hired, buildings_built | int | |
| buildings | [string] | building ids in build order |
| upgrades | [string] | upgrade ids in pick order |
| ram_max | int | final RAM capacity |
| tune | string | the `--tune` override spec in force, or empty |
| waves | [wave snapshot] | one per completed wave, see below |

Wave snapshot: `wave, score, bytes, ram_max, ram_used, spawned, closed, completed,
player_closes, imp_closes, imps, trained, buildings, elapsed`, all cumulative at the moment
the wave's break began.

## Event rows (`user://telemetry/<unix>_<seed>.jsonl`, or `--telemetry-dir`)

Written by `Telemetry` for every run, bot or human. Every row has
`seq` (0-based), `t` (seconds into the run), `wave`, `ev`, then event fields:

| ev | fields | when |
| --- | --- | --- |
| run_start | seed, policy, perks[], tune | desktop opens |
| popup_spawned | type, ram_cost, clustered (bool), ram_used | a window appears |
| popup_closed | type, completed, by_imp, age, reward, ram_used | a window closes with reward |
| popup_timeout | type, kind, timeouts | lifetime elapsed (multiply/spawn/escalate) |
| trap | type, kind | player fell for a dark pattern |
| remind_later | type | update dismissed without reward, requeued |
| build | id, cell, cost, bytes_after, owned_after | building placed |
| wave_end | snapshot fields (as above) | break begins |
| upgrade_offered | ids[] | break dialog shown |
| upgrade_picked | id | card chosen |
| overload | active, seconds_left | RAM crossed the limit, or recovered |
| train_start | imp, closes | an untrained imp sets off for a dojo |
| train_done | imp, trained_total | it comes out trained (6 s later) |
| demolish | id, cell, refund, bytes_after, owned_after | building sold (hut: its imp leaves) |
| relocate | id, from, to | building dragged to a new cell during a break |
| recycled | type, age, ram_used, bin_items | pop-up dropped into the Recycle Bin (no reward, RAM freed) |
| bin_emptied | (none) | "Empty Recycle Bin" finished, 2 s after the double-click |
| run_end | reason + `RunState.summary()` minus waves | run over |

`popup_closed` also carries `streak` (manual completion streak after the close). Run rows
carry `banked_score`, `final_score` and `best_streak`, plus `bin_items` (windows in the
Recycle Bin at the end) and `popups_recycled` (never counted in `closed`).

## Rules

- Keep it append-only: add fields or events, never rename or repurpose them.
- Aggregate before you reason. `tools/balance.py` turns run rows and event rows into
  per-wave survival, pick rates with conditional outcomes, never-picked lists, pop-up
  type tables and crash context. Hand those tables to a reviewer, not the raw rows.
- A hosted sink (GameAnalytics, PostHog) is a later step: it needs an account and keys
  you hold, and it should receive the same event names as above.
