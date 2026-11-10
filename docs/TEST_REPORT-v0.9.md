# Verification report — version 0.9 — 4 November 2026

## River Rapids

The fourth selectable crossing includes two hilltop approach pads, rolling downhill terrain, a bowl, a root launch, a broad sloping leaf, a banked turn, an upper shortcut, a wider lower channel, an upper-miss recovery channel, three final pads, and a flag island. Downhill momentum is bounded at 9.7 m/s. Automatic launch lips, opposing-input braking, camera height/pitch smoothing, launch/landing audio, speed-sensitive wind, three fireflies, a course-distance chasing wave, quick retries, and saved records complete the loop. Existing movement is restored when leaving this level.

The wave gives six seconds of grace, starts twenty course metres behind the terrain entrance, and advances at 6.8 m/s without rubber-banding. Separate visible fronts cover elevated branches and launch gaps. The player earns a lead by moving well. Route joins have exactly level heights and tapered banks; decorative skirts do not add invisible collision walls.

## Verification

**29 River Rapids native checks passed.** Actual physics/input traversal completes the lower route, upper route, and deliberate recovery route without falls. Additional checks cover bounded downhill speed, actual airborne launches, slow ramp approaches, one launch per passage, pause freezing, visible wave/catch behavior, fresh attempt resets, records from an empty save and reload, old collection migration, return to ordinary movement, and Lucky Lagoon → River Rapids transition.

All twelve pre-existing native test programs passed in the regression run: chasing water, music, controller, combat, facing, decoys, health/chance, long routes, skill routes, exploration/saves, secrets, and wardrobe. Expected fixtures were updated for four collection slots and the new next-level button. Some native programs emit pre-existing shutdown resource/ObjectDB warnings; they reported no failed checks. No such runtime errors were observed in the browser.

**20 browser acceptance checks passed** using actual keyboard/mouse input and read-only game telemetry. All three routes completed with zero falls; the upper shortcut was faster; all three Rapids fireflies were reachable while moving. Pause, replay, persisted records, malformed records, blocked-storage session fallback, and no false persistence claims passed. Screenshots cover title, hilltop, descent, crest, banked bend, fork, landing, victory, and 1024×640 layout. The browser console had zero errors.

| Browser route | Attempt time | Mean FPS sample | Lowest FPS sample |
|---|---:|---:|---:|
| Lower channel | 41.98 s | 59.8 | 44 |
| Upper shortcut | 38.78 s | 59.7 | 52 |
| Recovery after upper-route miss | 41.40 s | 59.0 | 47 |

FPS is sampled from the in-game HUD telemetry with the rear-view viewport active, not a continuous frame-time benchmark. Median samples were 60 FPS on all routes. The final tiny follow-up added the upper-gap wave front and was covered by native visibility validation and a successful final export; the recorded browser runs used the same final route geometry and gameplay rules.

Environment: macOS arm64, Godot 4.6 stable / Compatibility / 60 Hz physics; Playwright 1.57.0 and Chromium 143.0.7499.4 in a visible, focused window. The test shell could not capture the pointer; bringing full Chromium to the foreground resolved mouse capture without weakening the game's pause/focus behavior. Safari and Firefox were not tested in this release. The existing three levels' browser suites were updated but not rerun; their native suites were rerun.

## Evidence and reproduction

- `rapids-browser-results.json`: checks, route timings, speed/FPS samples, and actual gameplay snapshots.
- `rapids-native-results.txt`: final 29-check focused run.
- `native-regression-v0.9.txt`: full native regression run, including an earlier Rapids pass.
- `rapids-*.png`: screenshots from the exported game.
- `game/tests/rapids_test.gd` and `tests/rapids_browser_test.cjs`: repeatable verification.

Run `./scripts/test-native.sh`, serve with `./scripts/serve.sh`, and run `npm run test:rapids`. Install Playwright Chromium first with `npx playwright install chromium`. On macOS, use `PLAYWRIGHT_HEADLESS=false npm run test:rapids` for genuine foreground mouse capture. Other browser tests support `PLAYWRIGHT_CHANNEL=chromium` if Chrome is unavailable.

The source, regenerated browser package, and checksum manifest are ready locally. Play at http://127.0.0.1:8765/ and choose **4 · River rapids**. Hands-on feedback is still needed to judge engagement and camera comfort; automated completion is not a substitute for that judgment.
