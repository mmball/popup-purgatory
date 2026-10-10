#!/usr/bin/env bash
# Static checks that need no engine: banned Godot 3 / pre-4.0 APIs, Python idioms,
# and global RNG use in gameplay code. See CLAUDE.md for the rationale.
set -uo pipefail
cd "$(dirname "$0")/.."
status=0

check() {  # check <label> <grep-regex> <paths...>
  local label="$1" re="$2"; shift 2
  local hits
  hits=$(grep -rnE --include='*.gd' "$re" "$@" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "LINT: $label"; echo "$hits" | sed 's/^/    /'; status=1
  fi
}

check "Godot 3 math API"        '\b(deg2rad|rad2deg|stepify|linear_interpolate|rand_range)\s*\(' src tests
check "Godot 3 instancing"      '\.instance\(\)' src tests
check "Godot 3 yield"           '\byield\s*\(' src tests
check "Godot 3 export/onready"  '^\s*(export|onready)\s+var\b|^\s*tool\s*$' src tests
check "Godot 3 string connect"  '\.connect\(\s*"' src tests
check "Godot 3 empty/invert"    '\.(empty|invert)\(\)' src tests
check "Godot 3 OS ticks"        '\bOS\.get_ticks_(msec|usec)\b' src tests
check "Godot 3 class names"     '\b(KinematicBody2D|KinematicBody|Spatial|PoolStringArray|PoolVector2Array|Reference)\b' src tests
check "Python len()"            '\blen\s*\(' src tests
check "Python f-string"         'print\(f"' src tests
check "global RNG in gameplay"  '(^|[^.A-Za-z_])(randf|randi|randf_range|randi_range|randomize)\s*\(' src --exclude-dir=dev

if [ "$status" -eq 0 ]; then echo "lint: clean"; fi
exit $status
