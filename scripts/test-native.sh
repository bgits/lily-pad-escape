#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
LILY_GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$LILY_GODOT_BIN" --headless --path game --editor --import --quit
"$LILY_GODOT_BIN" --headless --path game --script res://tests/controller_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/combat_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/swing_facing_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/decoy_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/health_luck_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/skill_route_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/exploration_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/secret_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/wardrobe_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/duel_arena_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/duel_entities_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/duel_hud_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/duel_smoke_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/duel_rules_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/duel_feel_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/duel_water_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/duel_atmosphere_test.gd
"$LILY_GODOT_BIN" --headless --path game --script res://tests/duel_fx_test.gd
