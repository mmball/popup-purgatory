#!/usr/bin/env bash
# Renders the game under a virtual X display with software GL and saves PNGs.
# Usage: tools/screenshot.sh [godot-binary]
# Needs: xvfb-run, Mesa (llvmpipe). Output goes to screenshots/.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
mkdir -p screenshots
run() { LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -- "$@" 2>&1 | grep -E "^screenshot|SCRIPT ERROR" || true; }
run --screen=menu --screenshot=screenshots/menu.png --delay=2
run --screen=desktop --demo=1 --seed=1 --screenshot=screenshots/desktop.png --delay=4
run --screen=desktop --demo=1 --seed=1 --ui=start --screenshot=screenshots/start_menu.png --delay=2
run --screen=desktop --demo=1 --seed=1 --ui=break --screenshot=screenshots/break.png --delay=2
run --screen=bsod --screenshot=screenshots/bsod.png --delay=2
