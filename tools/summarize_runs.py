#!/usr/bin/env python3
"""Aggregate bot-run JSONL (one RunState.summary() per line) into tables.

Usage: tools/summarize_runs.py runs/*.jsonl
Standard library only. Prints per-policy run stats, per-wave averages, and
building/upgrade pick rates. This is the shape of table an LLM or a human
should look at instead of raw logs (roadmap phase 4).
"""
import json
import signal
import statistics
import sys

signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # quiet exit when piped into head
from collections import Counter, defaultdict


def load(paths):
    rows = []
    for p in paths:
        with open(p) as f:
            for line in f:
                line = line.strip()
                if line:
                    rows.append(json.loads(line))
    return rows


def mean(xs):
    return statistics.mean(xs) if xs else 0.0


def fmt(x):
    return f"{x:.1f}" if isinstance(x, float) else str(x)


def main(paths):
    rows = load(paths)
    if not rows:
        print("no runs")
        return 1
    by_policy = defaultdict(list)
    for r in rows:
        by_policy[r.get("policy", "?")].append(r)

    print(f"{'policy':8} {'n':>3} {'wave':>5} {'score':>7} {'closed':>7} {'compl%':>7} {'imp%':>6} {'imps':>5} {'bldg':>5} {'sec':>6}  end reasons")
    for pol, rs in sorted(by_policy.items()):
        closed = [r["closed"] for r in rs]
        compl = [100.0 * r["completed"] / r["closed"] if r["closed"] else 0.0 for r in rs]
        imp = [100.0 * r["imp_closes"] / r["closed"] if r["closed"] else 0.0 for r in rs]
        reasons = Counter(r["reason"] for r in rs)
        print(f"{pol:8} {len(rs):3d} {mean([r['wave'] for r in rs]):5.1f} {mean([r['score'] for r in rs]):7.1f} "
              f"{mean(closed):7.1f} {mean(compl):7.1f} {mean(imp):6.1f} {mean([r['imps_hired'] for r in rs]):5.1f} "
              f"{mean([r['buildings_built'] for r in rs]):5.1f} {mean([r['elapsed'] for r in rs]):6.1f}  {dict(reasons)}")

    print("\nper wave (mean at end of wave):")
    print(f"{'policy':8} {'wave':>4} {'n':>3} {'score':>7} {'bytes':>6} {'closed':>7} {'imps':>5} {'ram_max':>7}")
    for pol, rs in sorted(by_policy.items()):
        waves = defaultdict(list)
        for r in rs:
            for w in r.get("waves", []):
                waves[w["wave"]].append(w)
        for wv in sorted(waves):
            ws = waves[wv]
            print(f"{pol:8} {wv:4d} {len(ws):3d} {mean([w['score'] for w in ws]):7.1f} {mean([w['bytes'] for w in ws]):6.1f} "
                  f"{mean([w['closed'] for w in ws]):7.1f} {mean([w['imps'] for w in ws]):5.1f} {mean([w['ram_max'] for w in ws]):7.1f}")

    print("\nbuildings built (count across runs):")
    for pol, rs in sorted(by_policy.items()):
        c = Counter(b for r in rs for b in r.get("buildings", []))
        print(f"  {pol:8} {dict(c.most_common())}")
    print("upgrades picked (count across runs):")
    for pol, rs in sorted(by_policy.items()):
        c = Counter(u for r in rs for u in r.get("upgrades", []))
        print(f"  {pol:8} {dict(c.most_common())}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or ["runs/greedy_100.jsonl"]))
