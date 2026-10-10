#!/usr/bin/env python3
"""Monte Carlo parameter sweep: run seeded bot batches under several --tune variants
and compare outcomes side by side.

Usage:
  tools/sweep.py GODOT [--runs N] [--seed S] [--max-wave W] [--policy P] VARIANT [VARIANT ...]
  VARIANT is a --tune spec ("run.base_ram=120,building.hut.cost=15") or "base" for no overrides.

Example:
  tools/sweep.py ./godot --runs 20 --max-wave 4 base run.base_ram=120 spawn.first_interval=3.2

Writes runs/sweep_<i>.jsonl per variant and prints: runs, mean wave, survival to the
last wave, mean score, mean closes, completion share, imp share, buildings, deaths.
Standard library only.
"""
import json
import os
import signal
import statistics
import subprocess
import sys
from collections import Counter

signal.signal(signal.SIGPIPE, signal.SIG_DFL)


def mean(xs):
    return statistics.mean(xs) if xs else float("nan")


def run_variant(godot, idx, tune, runs, seed, max_wave, policy):
    out = f"runs/sweep_{idx}.jsonl"
    args = [godot, "--headless", "--fixed-fps", "60", "--path", ".", "--quit-after", str(runs * max_wave * 60 * 120),
            "--", "--screen=desktop", "--autoplay=1", f"--policy={policy}", f"--runs={runs}", f"--seed={seed}",
            f"--max-wave={max_wave}", f"--jsonl={out}", "--no-telemetry"]
    if tune != "base":
        args.append(f"--tune={tune}")
    proc = subprocess.run(args, capture_output=True, text=True)
    errors = [l for l in proc.stdout.splitlines() + proc.stderr.splitlines() if "SCRIPT ERROR" in l]
    if errors:
        print("\n".join(errors[:5]), file=sys.stderr)
    with open(out) as f:
        return [json.loads(l) for l in f if l.strip()]


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    godot = argv[0]
    opts = {"--runs": 10, "--seed": 100, "--max-wave": 3, "--policy": "greedy"}
    variants = []
    i = 1
    while i < len(argv):
        if argv[i] in opts:
            opts[argv[i]] = type(opts[argv[i]])(argv[i + 1]) if not isinstance(opts[argv[i]], str) else argv[i + 1]
            i += 2
        else:
            variants.append(argv[i])
            i += 1
    os.makedirs("runs", exist_ok=True)
    runs, seed, max_wave, policy = opts["--runs"], opts["--seed"], opts["--max-wave"], opts["--policy"]
    print(f"sweep: {runs} runs x {len(variants)} variants, seeds {seed}..{seed + runs - 1}, up to wave {max_wave}, policy {policy}\n")
    header = ["variant", "n", "wave", f"reach_w{max_wave}", "score", "closed", "compl%", "imp%", "bldg", "deaths"]
    print("  ".join(h.ljust(w) for h, w in zip(header, [44, 3, 5, 9, 7, 7, 6, 5, 5, 6])))
    for idx, tune in enumerate(variants):
        rs = run_variant(godot, idx, tune, runs, seed, max_wave, policy)
        if not rs:
            print(f"{tune[:44]:44}  (no runs; see errors above)")
            continue
        closed = [r["closed"] for r in rs]
        compl = mean([100.0 * r["completed"] / r["closed"] for r in rs if r["closed"]])
        imp = mean([100.0 * r["imp_closes"] / r["closed"] for r in rs if r["closed"]])
        reach = sum(1 for r in rs if r["wave"] >= max_wave)
        deaths = sum(1 for r in rs if r["reason"] == "OUT_OF_MEMORY")
        row = [tune[:44], len(rs), f"{mean([r['wave'] for r in rs]):.2f}", f"{100.0 * reach / len(rs):.0f}%",
               f"{mean([r['score'] for r in rs]):.1f}", f"{mean(closed):.1f}", f"{compl:.0f}", f"{imp:.0f}",
               f"{mean([r['buildings_built'] for r in rs]):.1f}", deaths]
        print("  ".join(str(c).ljust(w) for c, w in zip(row, [44, 3, 5, 9, 7, 7, 6, 5, 5, 6])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
