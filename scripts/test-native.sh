#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
LILY_GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$LILY_GODOT_BIN" --headless --path game --editor --import --quit
# Advance at the game's 60 Hz timestep without waiting for wall-clock frames.
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/music_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/controller_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/combat_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/swing_facing_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/decoy_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/health_luck_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/long_routes_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/skill_route_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/exploration_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/secret_test.gd
"$LILY_GODOT_BIN" --headless --fixed-fps 60 --path game --script res://tests/wardrobe_test.gd
