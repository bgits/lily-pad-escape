# Verification report — version 0.3 — 28 October 2026

## Result
Frog River now has four fake lily pads marked by red frogs, beside the existing safe route with six green enemies. The final native suites passed **91/91** checks (21 movement, 29 combat, 41 decoy). The final browser suites passed **85/85** checks (53 lagoon/transition, 32 river/decoy), with **zero browser or engine errors**. Godot import and Web export succeeded.

Both full courses were completed using ordinary mouse and keyboard inputs with no falls. In a separate deliberate failure during the same browser run, an arrow-key jump onto the first red-frog pad triggered its collapse, a water splash, pause/resume, and recovery. The final safe crossing defeated all six green frogs and won with all four red warning markers left alone.

## Trap behavior verified
- Four red markers and six required green enemies. Decoy pads do not overlap safe surfaces.
- Real landing contact triggers each of the four decoys exactly once and removes its collision support.
- Red markers have no solid collision, cannot be defeated by the bat, and never increment the enemy counter.
- Merely flying above a fake pad does not trigger it. Once landed, buffered or late jump input cannot escape the collapse.
- The pad and its red marker sink under the water; the player falls under gravity and enters one normal splash/retry.
- Pause freezes the collapsing pad and player. Resume continues the fall; a splash pause also freezes the pad.
- Retry restores all fake pads and normal controls while retaining previously defeated green frogs.
- Restart during collapse resets trap/fall/attack counters and all green enemies. Returning to Level 1 removes hazards and color instructions.
- The flag requires only the six green enemies. Leaving all red warning markers untouched permits victory.

## Regression coverage
Movement, normal and diagonal speed, jump buffering/coyote timing, pad mesh and camera collision, bat range/facing/vertical limits, held-input rejection, cooldown, pause/resume, repeated retries, focus and pointer-lock loss, customization, mute, Level 1 → Level 2, replay, and 1024×640 viewport fit. The browser trap jump specifically used ArrowUp with Space; the previous focused arrow-control check also covered all four directions in both levels.

Browser tests use read-only telemetry to select normal input. No position setters or teleports are used for either course or the deliberate browser trap landing. Native tests position the character to isolate mechanics and reach every decoy.

## Visual and runtime review
Reviewed exported-game screenshots of the four red-frog branches, green enemies, updated HUD/color legend, title instructions, first collapse, water splash, and final safe crossing. Red and green frog palettes are visibly distinct. The collapse message and retry hint are readable, and the bat and control hints remain visible.

Environment: Godot 4.6 stable, Compatibility renderer, 60 Hz physics; Chrome 156 via Playwright 1.62.1 on Apple M2 Max / 32 GiB RAM, 1280×720, DPR 1. Settled lagoon samples and six river landing snapshots were all 60 FPS. These are brief local samples, not a general performance benchmark.

## Limits
Chrome is the tested browser. Safari, Firefox, mobile, controllers, low-end devices, and high-DPI layouts remain untested. Audio file/wiring/mute checks do not replace a human speaker listening review. Progress is session-only. Red frogs are decorative warning markers; green enemies obstruct the route but do not chase or use a health system.

## Evidence and reproduction
Run `./scripts/test-native.sh`, then `npm run test:browser` with the preview server running and Chrome installed. `npm run test:combat` runs the river/decoy browser suite only.

- `native-test-results-v0.3.txt`: all 91 native checks.
- `browser-test-results.json`, `playthrough.json`: current lagoon crossing and level transition.
- `combat-browser-results.json`: 32 river checks and six safe combat landings.
- `20-red-frog-decoys.png`, `21-decoy-collapse.png`, `22-decoy-splash.png`: new trap evidence.
- `arrow-controls-checks.json`: focused arrow-key verification.
- Earlier version reports/logs are retained as historical evidence. Current source and `LilyPadEscape-v0.3.zip` include both arrow controls and decoys.
