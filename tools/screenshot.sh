#!/usr/bin/env bash
# Renders the game under a virtual X display with software GL and saves PNGs.
# Deterministic: fixed frame rate, frozen taskbar clock, fixed seed, no boot text.
# Usage: tools/screenshot.sh [godot-binary] [out-dir]
# Needs: xvfb-run, Mesa (llvmpipe).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
OUT="${2:-screenshots}"
mkdir -p "$OUT"
run() {
  LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . \
    --rendering-driver opengl3 --fixed-fps 60 -- --clock="12:00 AM" --noboot "$@" 2>&1 \
    | grep -E "^screenshot|SCRIPT ERROR" || true
}
run --screen=menu --screenshot="$OUT/menu.png" --delay=1
run --screen=desktop --demo=1 --seed=1 --screenshot="$OUT/desktop.png" --delay=3
run --screen=desktop --demo=1 --seed=1 --ui=start --screenshot="$OUT/start_menu.png" --delay=1
run --screen=desktop --demo=1 --seed=1 --ui=break --screenshot="$OUT/break.png" --delay=1
run --screen=bsod --screenshot="$OUT/bsod.png" --delay=1
