# Verification report — version 0.11 — 4 November 2026

## Five-level progression

Added **Level 4: River Glide**, a forgiving introduction to hoverboarding. Moved the existing difficult River Rapids course to **Level 5**. River Glide's finish offers the Next level transition into River Rapids; Lucky Lagoon now leads into River Glide.

The new course is 1,162 m, with 12–14 m tracks, one six-metre automatic gap jump and broad landing, a full wide loop, a gently rising half-turn spiral, and a continuous route. Visible rails protect grounded steering mistakes. Two off-centre coral blocks slow and nudge the rider instead of restarting the run, leaving the central line clear. Cruise/throttle/boost targets are 19/23/29 m/s, with a 30 m/s riding limit. The wave gets eight seconds of grace and moves at 13 m/s. Airborne misses can still cause a fall.

Level 5 retains the previous 2,141 m layout, both branches, three gap jumps, eleven obstacles, narrow spiral, 21/25/33 m/s speed targets, and its original wave pressure. Shared movement code reads the course's tuning values; beginner rail/contact assistance applies only to River Glide.

## Saved progress

The existing Rapids v2 record key remains attached to the hard course, preserving the user's previously earned time. Beginner records use a separate key. Native saves retain the existing `rapids` section and add `glide`. Four-slot firefly saves migrate from `[A,B,C,hard]` to `[A,B,C,0,hard]`; five-slot saves are already migrated. Collection, name, clothing, and achievement storage remain available, including honest session-only behavior when writes fail.

## Verification

**26 new native checks passed.** Two full normal-input beginner rides finish without precision steering: automatic cruise in 61.30 s and throttle/held boost in 49.67 s. Checks cover the actual loop and spiral, gravity-driven gap flight and landing, speed bounds, all three collectibles, protective rails under held steering, forgiving obstacle contact, pause, Level 4 → Level 5 progression, separate records, old-save migration, reload, and migration idempotence.

The existing **37 hard-course checks passed at Level 5**, including both routes and boosted jumps. All twelve original native test programs also passed. Some existing tests emit shutdown resource/ObjectDB diagnostics; no gameplay assertions failed. The UI control-hint follow-up was checked in the exported browser.

**14 beginner browser acceptance checks passed with zero script/engine errors.** The normal-keyboard course completed in 50.77 s. Browser checks cover old four-slot saves, the unchanged hard personal best, a separate beginner record, all three pickups, Next level, reload without repeated migration, edge-rail protection, pause, and denied beginner writes without damaging the hard record.

Visual inspection covers the five-course menu at 1280×720 and 1024×640, beginner hills, gap flight, loop, spiral, rails, finish, and victory. Tests use real keyboard/mouse events and read-only QA telemetry, with no movement setters or teleports.

**21 Level 5 browser checks passed with zero script/engine errors.** Both original routes completed without falls: 85.97 s wide and 84.23 s fast. Checks include loop/spiral completion, all three launches, steering/branch selection, all hard-course collectibles, pause, boost/brake, reload, and malformed/blocked storage. Results are recorded separately in `rapids-level5-browser-results.json`.

Environment: macOS arm64, Godot 4.6 stable / Compatibility / 60 Hz physics; Playwright 1.57.0 and Chromium 143.0.7499.4, headless. Original-level browser suites, Safari, and Firefox were not rerun; the original levels were covered by native regression. Automated completion verifies reachability and regression behavior, not the player's subjective difficulty or enjoyment.

## Evidence

- `native-regression-v0.11.txt`: all fourteen native test programs.
- `glide-browser-results.json`, `glide-*.png`: introductory course and save migration.
- `rapids-level5-browser-results.json`, `rapids-level5-*.png`: both hard-course routes after reordering.
- `game/tests/glide_test.gd`, `game/tests/rapids_test.gd`, `tests/glide_browser_test.cjs`, `tests/rapids_browser_test.cjs`: repeatable tests.

Run `./scripts/test-native.sh`, `npm run test:glide`, and `npm run test:rapids` with the local server running. Play at http://127.0.0.1:8765/ and select **4 · River glide** or **5 · River rapids**.
