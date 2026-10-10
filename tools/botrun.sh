#!/usr/bin/env bash
# Plays a batch of seeded headless runs with the autoplay bot and writes JSONL.
# Usage: tools/botrun.sh [godot-binary] [runs] [policy] [first_seed] [max_wave]
# Output: runs/<policy>_<first_seed>.jsonl, then a summary table.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
RUNS="${2:-5}"; POLICY="${3:-greedy}"; SEED="${4:-100}"; MAXW="${5:-3}"
mkdir -p runs
OUT="runs/${POLICY}_${SEED}.jsonl"
# --quit-after is a hard cap in frames in case a run never ends.
"$GODOT" --headless --fixed-fps 60 --path . --quit-after $((RUNS * MAXW * 60 * 90)) -- \
  --screen=desktop --autoplay=1 --policy="$POLICY" --runs="$RUNS" --seed="$SEED" \
  --max-wave="$MAXW" --jsonl="$OUT" 2>&1 | grep -E "^autoplay run|SCRIPT ERROR" | sed 's/: {.*//'
echo "wrote $OUT ($(wc -l < "$OUT") runs)"
python3 tools/summarize_runs.py "$OUT"
