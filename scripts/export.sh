#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
LILY_GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$LILY_GODOT_BIN" ]]; then
  echo 'Godot not found. Run ./scripts/setup-macos.sh or set GODOT_BIN to Godot 4.6 stable.' >&2
  exit 1
fi
mkdir -p build/web
"$LILY_GODOT_BIN" --headless --path game --editor --import --quit
"$LILY_GODOT_BIN" --headless --path game --export-release Web ../build/web/index.html
cp docs/GODOT_LICENSE.txt docs/GODOT_COPYRIGHT.txt build/web/
