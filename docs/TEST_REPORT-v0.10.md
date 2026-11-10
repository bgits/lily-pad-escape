# Verification report — version 0.10 — 4 November 2026

## Hoverboard River Rapids

Replaced the short walking course with a 2,141 m hoverboard course: rolling hills, a full vertical magnetic loop, a separated wide/fast fork, a 1.5-turn rising spiral, high banks, three ballistic gap jumps, eleven coral obstacles, and a checkered finish. The board auto-cruises at 21 m/s, throttles toward 25 m/s, and boosts toward 33 m/s, with a 34 m/s riding cap. A/D steer, W accelerates, S brakes, Space hops, and Shift uses regenerating boost energy.

The two branches enter through distinct lanes and reconnect to one shared merge. Their decks remain separated. Loop entry/exit are offset, spiral turns have vertical clearance, width/bank transitions taper, and support posts sit outside the track. Lane arrows replace the large floating fork sign. The hoverboard camera is independent of the walking SpringArm; it shows the full loop and uses a stable automatic chase view elsewhere. River Rapids does not require pointer lock. The original levels retain mouse-look and their ordinary walking controller.

The wave advances by course distance through the loop, spiral, and both branches, with four seconds of grace and a constant 21 m/s chase. The level retains quick retries, optional fireflies, pause, local records, wardrobe, and collection saves. Hoverboard records use version 2, separating them from the old, shorter walking course.

## Native checks

**37 focused checks passed**, including three complete input-driven rides: wide route, fast route, and fast route with boosted jumps. No player teleport or forced completion is used. They verify actual inversion, the complete spiral, all three airborne gap trajectories, speed limits, branch selection, branch deck separation, joined endpoints, physical obstacle hops and landings, held-jump behavior, off-edge falls, obstacle failures, wave catch while braking, boost consumption, pause freezing, collection of all three fireflies, saved records, camera parenting, and restoration of ordinary walking.

Native route times: approximately 85.97 s wide, 84.23 s fast, and 81.22 s with well-timed boosts. These use scripted input for repeatability, not a human skill benchmark.

All twelve existing native test programs also passed: chasing water, music, controller, combat, facing, decoys, health/chance, long routes, skill routes, exploration/saves, secrets, and wardrobe. The full regression log contains a 36-check Rapids pass; the subsequent focused run adds the three-firefly acceptance check. Some older native test programs retain pre-existing shutdown resource/ObjectDB warnings; they reported no failed checks.

## Browser checks

**21 browser acceptance checks passed with zero script/engine errors.** Results are recorded in `hoverboard-browser-results.json`. The repeatable test uses actual keyboard/mouse events with read-only telemetry; it has no movement setters or teleport methods. It captures the fork, merge, loop, spiral, gap-flight views, the home stretch, victory screens, and smaller-window title layout. The test deliberately follows collectible lines on the shortcut.

The browser matrix covers both full routes, inversion and spiral completion, three launches, bounded riding speed, correct branch selection, all three fireflies, faster shortcut time, pause, replay, best-time persistence, malformed records, keyboard boost/brake behavior, and denied-storage session fallback without false persistence claims.

| Route | Time | Mean sampled FPS | Lowest sampled FPS |
|---|---:|---:|---:|
| Wide branch | 85.97 s | 59.2 | 40 |
| Fast shortcut | 84.23 s | 58.6 | 45 |

FPS comes from sampled game telemetry with the rear-view viewport enabled, not a continuous frame-time benchmark. Final cosmetic follow-ups reset the board stance immediately and align the checkered tiles to the sloping deck; these were covered by a fresh focused native pass and export after the browser runs.

Environment: macOS arm64, Godot 4.6 stable / Compatibility / 60 Hz physics, Playwright 1.57.0, Chromium 143.0.7499.4. Final hoverboard acceptance runs use full Chromium headless with the automatic camera and normal keyboard controls. Real operating-system focus/tab changes are not emulated by headless Chromium; the test includes a separate tab-pause check for headed runs. Original-level browser suites, Safari, and Firefox were not rerun for this version. Original levels were covered by the native regression suite.

## Reproduction and evidence

- `hoverboard-native-results.txt`: 37 focused checks.
- `native-regression-v0.10.txt`: all original native suites and the prior 36-check Rapids pass.
- `hoverboard-browser-results.json`: final assertions, route times, speed/FPS samples, and gameplay snapshots.
- `hoverboard-*.png`: exported-game screenshots.
- `game/tests/rapids_test.gd`, `tests/rapids_browser_test.cjs`: repeatable acceptance tests.

Run `./scripts/test-native.sh`, serve using `./scripts/serve.sh`, and run `npm run test:rapids` after installing Playwright Chromium. The local prepared build is at http://127.0.0.1:8765/; choose **4 · River rapids**.

Automated reachability and visual checks do not establish engagement or camera comfort. The build is intended for hands-on feedback on speed, steering, challenge, and the desire to retry.
