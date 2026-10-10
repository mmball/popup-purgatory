#!/usr/bin/env python3
"""Turn run rows and telemetry event rows into balancing tables.

Usage:
  tools/balance.py runs/*.jsonl                    # run-level tables
  tools/balance.py runs/*.jsonl --events DIR       # plus pop-up type tables from event logs
  tools/balance.py ... --markdown                  # emit Markdown tables (for a reviewer or an LLM)

Tables:
  survival        share of runs alive at the start of each wave, per policy (death-by-wave)
  upgrades        offered, picked, pick rate, mean final score when picked vs not, never-picked
  buildings       build count, share of runs that built it, mean final score with vs without
  popups          per type: spawned, closed, completion rate, player vs imp, mean age, timeouts, traps
  crashes         wave and RAM context at OUT_OF_MEMORY deaths
Standard library only.
"""
import glob
import json
import os
import signal
import statistics
import sys
from collections import Counter, defaultdict

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

MD = "--markdown" in sys.argv


def mean(xs):
    return statistics.mean(xs) if xs else float("nan")


def table(title, header, rows):
    print(f"\n## {title}" if MD else f"\n== {title}")
    if not rows:
        print("(no data)")
        return
    widths = [max(len(str(h)), *(len(str(r[i])) for r in rows)) for i, h in enumerate(header)]
    if MD:
        print("| " + " | ".join(str(h) for h in header) + " |")
        print("|" + "|".join("---" for _ in header) + "|")
        for r in rows:
            print("| " + " | ".join(str(c) for c in r) + " |")
    else:
        print("  ".join(str(h).ljust(w) for h, w in zip(header, widths)))
        for r in rows:
            print("  ".join(str(c).ljust(w) for c, w in zip(r, widths)))


def f1(x):
    return "nan" if x != x else f"{x:.1f}"


def pct(n, d):
    return f"{100.0 * n / d:.0f}%" if d else "-"


def load_runs(paths):
    rows = []
    for p in paths:
        with open(p) as f:
            rows.extend(json.loads(l) for l in f if l.strip())
    return rows


def load_events(dirpath):
    runs = []
    for p in sorted(glob.glob(os.path.join(dirpath, "*.jsonl"))):
        with open(p) as f:
            evs = [json.loads(l) for l in f if l.strip()]
        if evs:
            runs.append(evs)
    return runs


def survival(runs):
    rows = []
    by_pol = defaultdict(list)
    for r in runs:
        by_pol[r.get("policy", "?")].append(r)
    max_wave = max(r["wave"] for r in runs)
    for pol, rs in sorted(by_pol.items()):
        for w in range(1, max_wave + 1):
            alive = sum(1 for r in rs if r["wave"] >= w)
            died_here = sum(1 for r in rs if r["wave"] == w and r["reason"] == "OUT_OF_MEMORY")
            rows.append([pol, w, len(rs), pct(alive, len(rs)), died_here])
    table("survival: share of runs reaching each wave", ["policy", "wave", "n", "reached", "died_in_wave"], rows)


def picks(runs, key, catalog_ids):
    rows = []
    n = len(runs)
    for pid in catalog_ids:
        with_ = [r["score"] for r in runs if pid in r.get(key, [])]
        without = [r["score"] for r in runs if pid not in r.get(key, [])]
        count = sum(r.get(key, []).count(pid) for r in runs)
        rows.append([pid, count, pct(len(with_), n), f1(mean(with_)), f1(mean(without)), "NEVER" if count == 0 else ""])
    rows.sort(key=lambda r: -r[1])
    return rows


def crashes(runs):
    dead = [r for r in runs if r["reason"] == "OUT_OF_MEMORY"]
    if not dead:
        print("\n(no OUT_OF_MEMORY deaths in this batch)")
        return
    c = Counter((r.get("policy", "?"), r["wave"]) for r in dead)
    rows = [[pol, w, n, f1(mean([r["elapsed"] for r in dead if r["wave"] == w and r.get("policy") == pol])),
             f1(mean([r["ram_max"] for r in dead if r["wave"] == w and r.get("policy") == pol]))]
            for (pol, w), n in sorted(c.items())]
    table("crashes: OUT_OF_MEMORY by policy and wave", ["policy", "wave", "deaths", "mean_elapsed_s", "mean_ram_max"], rows)


def popups(event_runs):
    spawned = Counter(); closed = Counter(); completed = Counter(); by_imp = Counter()
    ages = defaultdict(list); timeouts = Counter(); traps = Counter(); clustered = Counter()
    for evs in event_runs:
        for e in evs:
            t = e.get("type")
            ev = e["ev"]
            if ev == "popup_spawned":
                spawned[t] += 1
                if e.get("clustered"):
                    clustered[t] += 1
            elif ev == "popup_closed":
                closed[t] += 1
                ages[t].append(e["age"])
                if e.get("completed"):
                    completed[t] += 1
                if e.get("by_imp"):
                    by_imp[t] += 1
            elif ev == "popup_timeout":
                timeouts[t] += 1
            elif ev == "trap":
                traps[t] += 1
    rows = []
    for t in sorted(spawned, key=lambda k: -spawned[k]):
        rows.append([t, spawned[t], pct(clustered[t], spawned[t]), closed[t], pct(completed[t], closed[t]),
                     pct(by_imp[t], closed[t]), f1(mean(ages[t])), timeouts[t], traps[t]])
    table("pop-ups by type (event logs)", ["type", "spawned", "clustered", "closed", "completed", "by_imp", "mean_age_s", "timeouts", "traps"], rows)


def main(argv):
    paths = [a for a in argv if a.endswith(".jsonl")]
    events_dir = argv[argv.index("--events") + 1] if "--events" in argv else None
    runs = load_runs(paths)
    if not runs:
        print("no run rows; pass runs/*.jsonl")
        return 1
    print(f"{len(runs)} runs from {len(paths)} file(s); policies: {dict(Counter(r.get('policy','?') for r in runs))}")
    tunes = Counter(r.get("tune", "") for r in runs)
    if len(tunes) > 1 or (tunes and list(tunes)[0]):
        print(f"tune specs: {dict(tunes)}")
    survival(runs)
    up_ids = sorted({u for r in runs for u in r.get("upgrades", [])} | {
        "bigger_x", "more_ram", "fast_imps", "quick_hands", "dismiss_bonus", "complete_bonus",
        "spawn_slower", "free_imp", "lean_popups", "click_bonus", "antivirus_patch", "bytes_now"})
    table("upgrades: pick count, share of runs, mean final score with vs without",
          ["upgrade", "picked", "runs_with", "score_with", "score_without", "flag"], picks(runs, "upgrades", up_ids))
    b_ids = ["hut", "dojo", "coffee", "ram", "firewall", "antivirus", "shrine"]
    table("buildings: build count, share of runs, mean final score with vs without",
          ["building", "built", "runs_with", "score_with", "score_without", "flag"], picks(runs, "buildings", b_ids))
    crashes(runs)
    if events_dir:
        ev_runs = load_events(events_dir)
        print(f"\n{len(ev_runs)} event logs from {events_dir}")
        popups(ev_runs)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
