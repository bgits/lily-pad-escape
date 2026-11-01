#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=4.6-stable
mkdir -p .tools/downloads .tools/templates
if [[ ! -x .tools/Godot.app/Contents/MacOS/Godot ]]; then
  curl -fL --retry 2 "https://github.com/godotengine/godot-builds/releases/download/$VERSION/Godot_v${VERSION}_macos.universal.zip" -o .tools/downloads/godot.zip
  unzip -q .tools/downloads/godot.zip -d .tools
  rm .tools/downloads/godot.zip
fi
if [[ ! -f .tools/templates/web_nothreads_release.zip || ! -f .tools/templates/web_nothreads_debug.zip ]]; then
  if [[ ! -f .tools/downloads/templates.tpz ]]; then
    curl -fL --retry 2 "https://github.com/godotengine/godot-builds/releases/download/$VERSION/Godot_v${VERSION}_export_templates.tpz" -o .tools/downloads/templates.tpz
  fi
  unzip -j -o -q .tools/downloads/templates.tpz templates/web_nothreads_debug.zip templates/web_nothreads_release.zip -d .tools/templates
  rm .tools/downloads/templates.tpz
fi
# Keep editor settings alongside the locally downloaded engine.
touch .tools/Godot.app/Contents/MacOS/_sc_
.tools/Godot.app/Contents/MacOS/Godot --version
