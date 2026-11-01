#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -x .tools/Godot.app/Contents/MacOS/Godot ]]; then
  ./scripts/setup-macos.sh
fi
exec .tools/Godot.app/Contents/MacOS/Godot --path game --editor
