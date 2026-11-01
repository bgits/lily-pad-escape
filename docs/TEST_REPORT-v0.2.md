# Verification report — version 0.2 — 28 October 2026

## Result
Two playable levels are implemented and exported. The native suites passed **50/50** checks (21 movement regression + 29 combat/level-transition checks). The browser suites passed **77/77** checks (53 original-level/transition + 24 combat) with **zero browser console or engine errors**. Godot import and Web export completed without errors.

The original nine-gap lagoon and the new seven-gap Frog river were completed using ordinary mouse and keyboard inputs, with zero falls. In the river run, all six frogs were defeated with alternating F and left-click attacks before reaching the flag. The real Level 1 victory button started Level 2 and retained the chosen name and hoodie.

## Combat and progression
- Level selection from the title, visible baseball bat on spawn, and six frogs on distinct lily pads.
- Forward hit, behind-player miss, out-of-range miss, vertical miss, wind-up timing, cooldown, and held/auto-repeat rejection.
- Living frogs physically obstruct the player; defeated frogs lose collision immediately, animate a flip/shrink/puff, and count once.
- Escape freezes both the attack timer and frogs. Resume completes a pending swing once. Restart clears all attack state and restores all six frogs.
- Water retry keeps defeated frogs cleared and retains the bat. Restart/replay restores enemies and resets combat counters.
- The flag refuses victory while any frog remains. Clearing the river and reaching the island triggers victory once. Level 2 replay works; no nonexistent third-level button appears.
- Returning to Level 1 removes the bat and frogs. Name and hoodie survive the Next level transition.
- Existing movement, coyote time, jump buffer, actual pad-notch collision, camera collision, three water retries, focus loss, pointer-lock loss, pause/resume, sound/mute, and restart regression checks pass.

The browser playthroughs use read-only telemetry to choose normal inputs; they do not teleport or invoke movement/combat setters. Native tests deliberately position the character to isolate range, facing, pause timing, and goal conditions.

## Visual and runtime review
Reviewed the title selector, bat-equipped spawn, first frog, BONK/defeat feedback, mid-course, river-clear state, victory, and 1024×640 desktop layout from the actual exported game. The bat ready pose was adjusted to remain visible over the right shoulder. No clipped controls or page overflow were found.

Environment: Godot 4.6 stable, Compatibility renderer, 60 Hz physics; installed Chrome 156 via Playwright 1.62.1 on Apple M2 Max / 32 GiB RAM, 1280×720, DPR 1. Original-level settled FPS samples: [60, 60, 60, 60, 60, 60, 60, 60]. Frog-combat landing samples: [18, 60, 60, 60, 60, 60]. These are brief local samples, not a hardware benchmark or frame-time percentile study.

## Limits
Chrome is the tested browser. Safari, Firefox, touch, controllers, low-end devices, and high-DPI layouts remain untested. Audio files, sound calls, and mute state were checked, without a human speaker listening review. Both levels are session-only; no saved progression or extra weapons. Frogs obstruct the path and must be defeated to finish; they do not chase the player or use a health/damage system.

## Reproduce and evidence
Run `./scripts/test-native.sh`, then `npm run test:browser` with the local preview server running. Chrome must be installed. `npm run test:combat` runs only the second-level browser suite.

- `native-test-results-v0.2.txt`: all 50 native checks.
- `browser-test-results.json`, `playthrough.json`: current original-course run and Next level transition.
- `combat-browser-results.json`: all 24 river checks and six combat landings.
- `11-level-select.png` through `19-level-select-small.png`: current river screenshots.
- `TEST_REPORT-v0.1.md` and `native-test-results.txt`: historical first-version evidence.

## Arrow-key update
The current browser build also supports all four arrow keys alongside WASD in both levels. A focused Chrome check passed 23 checks for direction, stopping on release, normalized diagonals, existing WASD movement, jumping, pause/resume, and zero browser/engine errors. Title and HUD control hints were visually reviewed. Evidence: `arrow-controls-checks.json`. The version 0.2 ZIP predates this controls update; current source and `build/web/` include it.
