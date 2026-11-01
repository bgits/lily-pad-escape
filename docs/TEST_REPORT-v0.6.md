# Verification report — version 0.6 — 28 October 2026

## Result
The character wardrobe is implemented and exported. **211 native checks** passed, including **34 new wardrobe checks**. All six browser suites passed **183 checks** (53 lagoon, 46 combat/health, 28 chance, 18 secret, 15 facing, 23 wardrobe), with no browser or engine errors.

## Customization
A Customize button is available beside the title-screen name field and in the pause screen. The wardrobe has an independent, animated 3D preview, smooth turn buttons, mouse dragging, and Character/Hair/Tops/Pants/Shoes tabs.

Choices include Boy/Girl/Neutral character options, six skin tones, six hairstyles and hair colors, three tops, three pants styles, and three shoe styles. Each clothing category has six colors. Every hairstyle and outfit is available to every character option. Moonflower requires the existing Secret Perch badge. The original title color shortcuts still work and preserve other choices.

Editing updates only a preview until Save outfit is clicked. Cancel and Escape discard the draft. Saving applies the name and all ten appearance fields. Native checks cover every style family, preview isolation, actual avatar rebuilding, and locked reward selection. Browser checks select every category and color field through normal UI actions, rotate the model with buttons and dragging, save, refresh, and verify the chosen outfit and a quoted name.

## Game behavior
The avatar's existing root orientation, animation clocks, equipment state, and physics capsule are preserved when its appearance is rebuilt. Clothing does not affect movement speed, jump height, hitboxes, or attack direction.

Opening Customize from pause freezes the run. Save and Cancel return to pause without moving or resuming the player. Native checks pause a real poisoned character during attack wind-up, change its clothes, verify the frozen position/heading/collision/attack state, then resume and defeat the frog with full healing. Browser checks edit from pause, resume, jump, swing the bat, restart, and change levels while retaining the outfit.

All earlier native suites pass: movement 21, combat 29, swing-facing 20, red decoys 41, health/chance 41, and secret 25. All three courses also complete through normal browser controls. Lucky Lagoon required 6 actual random course attempts, observing both outcomes. The full river crossing defeats all six frogs, and the previously reported backward-swing regression still passes.

## Persistence and fallback
Outfit indices and the optional name are saved locally. The Web build retains the old achievement key and stores customization in a separate versioned localStorage key. Native Godot uses the existing achievements.cfg file, preserving the achievement flag alongside the new fields. Existing achievement-only saves migrate to a default outfit without losing the badge.

Validation rejects unknown, out-of-range, fractional, or incorrectly typed selections and prevents a locked Moonflower selection. Missing/corrupt saved data falls back to usable defaults. Names are limited to 18 characters and encoded safely when stored through the Web bridge. Native and browser tests cover reload, quoted names, corrupt data, and unavailable storage. A failed write keeps the outfit active for the current visit and displays that saving is unavailable. Browser clearing of site data removes local preferences.

The secret browser suite earns the badge with a real jump and then verifies Moonflower is enabled in the full wardrobe. Native tests now use isolated temporary profile files and remove them afterward.

## Presentation and evidence
Reviewed actual screenshots of the entry button, default character, ponytail and color choices, a complete jacket/joggers/high-tops outfit, in-game appearance, and the smaller 1024×640 wardrobe. Text and controls fit, and the smaller-window category controls were exercised. The preview's render target is disabled while the wardrobe is closed.

Environment: Godot 4.6 stable, Compatibility renderer, 60 Hz physics; installed Chrome via Playwright 1.62.1 on Apple M2 Max, DPR 1. Safari, Firefox, mobile, controllers, and high-DPI layouts remain untested. Audio wiring was checked without a human speaker listening review.

Reproduce with `./scripts/test-native.sh` and `npm run test:browser` while the local server is running. `npm run test:wardrobe` runs the new browser acceptance checks. The QA bridge is read-only; gameplay and customization tests use normal keyboard/mouse controls. An isolated browser's saved-data fixture is deliberately corrupted to verify recovery; no game-state setter is provided.

Evidence: `native-test-results-v0.6.txt`, `browser-test-results-v0.6.log`, the six browser result JSON files, and screenshots `42-customize-button.png` through `48-customized-gameplay.png`. Previous reports remain under versioned filenames. Source and playable Web files are packaged in `LilyPadEscape-v0.6.zip`.
