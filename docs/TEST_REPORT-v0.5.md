# Verification report — version 0.5 — 28 October 2026

## Result
Secret Perch is implemented in the source and exported Web game. All **157 native checks** passed (21 movement, 29 combat, 41 decoy, 41 health/chance, 25 secret). The final browser run passed **133 checks** (53 lagoon, 46 combat/health, 17 chance, 17 secret), with no browser or engine errors.

## Secret achievement
- The existing five stone pillars immediately left of the starting pad retain their positions, sizes, and colors. Their stone collision is now separate from the surrounding scenery, so only a grounded top contact awards the secret. Airborne flyovers, side contact, and normal start-pad landings do not count.
- A real landing grants **Secret Perch** once, shows an original gold/purple badge and confetti, plays the celebration sound, and equips a purple **Moonflower** hoodie. Standing or re-landing cannot repeat the award. The pillar remains solid; the secret does not advance route progress or complete the level.
- Native physics checks cover real top/side/airborne contact, stable support, single awarding, pause/resume, restart, water retry, all three levels, wardrobe selection, fresh-instance save/load, and a failed write.
- Browser acceptance reaches the pillar from spawn using ordinary camera movement, Arrow Up, and Space. No teleport or game-state setter is used. The character stands safely on the pillar and earns exactly one badge. A second real jump checks the denied-storage case.
- The title-screen card retains the earned badge and offers the unlocked hoodie alongside the original color choices. Actual screenshots confirm the badge artwork, outfit, celebration, and 1024×640 layout. The initial font-based star was replaced with original SVG artwork after visual review found an unsupported glyph.

## Saving
Only the achievement flag persists. Web builds use localStorage on the same browser/origin; native builds use `user://achievements.cfg`. Browser refresh and a new native game instance both retain availability without replaying the award. Clearing site data removes the browser unlock. Names, equipped outfit, and course progress remain session-local.

If storage is blocked or a native write fails, the achievement and hoodie are still granted for the current visit. A browser test denies localStorage access, then earns the badge through normal input; the game continues without errors and the celebration explains that saving is unavailable. Native tests use a separate test save and remove it afterward.

## Regression
All prior movement, camera, combat, red-decoy, health/poison, and yellow-chance native checks pass. All three browser courses finish with ordinary controls, including six green-frog defeats, poison death and healing, red-pad collapse, and both Next level transitions. This run completed Lucky Lagoon in 1 course attempt(s) and 1 additional sink probe(s), observing both genuine random outcomes. Browser chance-test counts vary with the draws.

Engine: Godot 4.6 stable, Compatibility, 60 Hz physics, single-thread Web export. Browser: Chrome 156 via Playwright 1.62.1, Apple M2 Max / 32 GiB RAM, 1280×720 and 1024×640, DPR 1. The secret landing reported 60 FPS; this is a short sample, not a broad performance benchmark. Safari, Firefox, mobile, controllers, and high-DPI layouts remain untested. Audio wiring was checked without a human speaker listening review.

## Reproduction and evidence
Run `./scripts/test-native.sh` and, with the local server running and Chrome installed, `npm run test:browser`. `npm run test:secret` runs the new browser checks alone. The browser bridge behind `?qa` is read-only and sends no data anywhere.

Evidence: `native-test-results-v0.5.txt`, `browser-test-results-v0.5.log`, the four browser result JSON files, and screenshots `34-secret-locked.png` through `39-secret-storage-unavailable.png`. Earlier reports are preserved under their versioned filenames. Current source and Web build are packaged in `LilyPadEscape-v0.5.zip`.
