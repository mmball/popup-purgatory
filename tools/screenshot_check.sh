#!/usr/bin/env bash
# Screenshot regression: render the fixed UI states and compare each against the
# committed baseline in tests/screenshots/ with a pixel-share tolerance.
# Usage: tools/screenshot_check.sh [godot-binary] [--update]
#   --update  overwrite the baselines with the freshly rendered screens
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
MODE="${2:-check}"
TOL="${TOLERANCE:-2.0}"
OUT=screenshots
BASE=tests/screenshots

tools/screenshot.sh "$GODOT" "$OUT"
status=0
for png in "$OUT"/menu.png "$OUT"/desktop.png "$OUT"/start_menu.png "$OUT"/break.png "$OUT"/bsod.png; do
  name=$(basename "$png")
  if [ "$MODE" = "--update" ] || [ ! -f "$BASE/$name" ]; then
    cp "$png" "$BASE/$name"; echo "baseline updated: $BASE/$name"; continue
  fi
  printf "%-16s " "$name"
  if ! "$GODOT" --headless --path . -s tools/compare_images.gd -- "$png" "$BASE/$name" "$TOL" "$OUT/diff_$name" 2>&1 | grep -E "^diff=|diff image|mismatch"; then
    echo "  (compare failed to run)"; status=1
  fi
  [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
done
[ "$status" -eq 0 ] && echo "screenshots: all within ${TOL}% of baseline" || echo "screenshots: REGRESSION (see $OUT/diff_*.png)"
exit $status
