#!/usr/bin/env bash
# Runs the headless checks: import, unit tests, and a smoke run of the real game.
# Usage: tools/test.sh [path-to-godot-binary]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"

echo "== import"
"$GODOT" --headless --path . --import >/dev/null 2>import.log || true
if grep -E "SCRIPT ERROR|ERROR:" import.log | grep -v -i "audio\|alsa"; then
  echo "import reported errors"; exit 1
fi

echo "== unit tests"
"$GODOT" --headless --path . -s tests/run_tests.gd 2>&1 | tee tests.log
grep -q " 0 failed" tests.log

echo "== smoke run (desktop, demo mode, 600 frames)"
"$GODOT" --headless --path . --quit-after 600 -- --screen=desktop --demo=1 --autoplay=1 --seed=1 2>&1 | tee smoke.log
if grep -E "SCRIPT ERROR|ERROR:" smoke.log | grep -v -i "audio\|alsa"; then
  echo "smoke run reported errors"; exit 1
fi
echo "== all good"
