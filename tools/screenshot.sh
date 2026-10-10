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
# Each render is capped at 120 s so a hung renderer fails the step instead of
# stalling CI; the full engine output of every render is kept in $OUT/*.log.
run() {
  local name="$1"; shift
  local log="$OUT/$name.log"
  if ! LIBGL_ALWAYS_SOFTWARE=1 timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . \
      --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 -- --clock="12:00 AM" --noboot --fresh-meta --no-telemetry "$@" >"$log" 2>&1; then
    echo "render failed or timed out: $name (see $log)"; tail -20 "$log"; return 1
  fi
  grep -E "^screenshot|SCRIPT ERROR" "$log" || true
}
run menu --screen=menu --screenshot="$OUT/menu.png" --delay=1
run desktop --screen=desktop --demo=1 --seed=1 --screenshot="$OUT/desktop.png" --delay=3
run start_menu --screen=desktop --demo=1 --seed=1 --ui=start --screenshot="$OUT/start_menu.png" --delay=1
run break --screen=desktop --demo=1 --seed=1 --ui=break --screenshot="$OUT/break.png" --delay=1
run bsod --screen=bsod --screenshot="$OUT/bsod.png" --delay=1
