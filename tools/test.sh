#!/usr/bin/env bash
# Runs the headless checks: import, unit tests, and a smoke run of the real game.
# Usage: tools/test.sh [path-to-godot-binary]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"

echo "== lint"
tools/lint.sh

echo "== import"
"$GODOT" --headless --path . --import >/dev/null 2>import.log || true
if grep -E "SCRIPT ERROR|ERROR:" import.log | grep -v -i "audio\|alsa"; then
  echo "import reported errors"; exit 1
fi

echo "== unit tests"
"$GODOT" --headless --path . -s tests/run_tests.gd 2>&1 | tee tests.log
grep -q " 0 failed" tests.log
if grep -E "SCRIPT ERROR|ERROR:" tests.log | grep -v -i "audio\|alsa"; then
  echo "unit test run logged script errors"; exit 1
fi

echo "== smoke run (desktop, demo mode, 600 frames)"
"$GODOT" --headless --path . --quit-after 600 -- --screen=desktop --demo=1 --autoplay=1 --seed=1 2>&1 | tee smoke.log
if grep -E "SCRIPT ERROR|ERROR:" smoke.log | grep -v -i "audio\|alsa"; then
  echo "smoke run reported errors"; exit 1
fi
echo "== determinism (two seeded fixed-fps bot runs must end in the same state)"
for i in 1 2; do
  "$GODOT" --headless --fixed-fps 60 --path . --quit-after 900 -- --screen=desktop --autoplay=1 --seed=7 2>&1 \
    | grep -E "^seed=|SCRIPT ERROR" > "det_$i.log"
done
cat det_1.log
if ! diff -q det_1.log det_2.log >/dev/null; then
  echo "determinism broken: runs differ"; diff det_1.log det_2.log; exit 1
fi
grep -q "closed=[1-9]" det_1.log || { echo "determinism run closed nothing; bot input is not reaching the GUI"; exit 1; }

echo "== all good"
