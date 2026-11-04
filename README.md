# Lily Pad Escape · three playable levels

A small third-person 3D platformer with three longer crossings. Sunlit Lagoon and Frog River each have **18 main-route lily pads**, including the starting pad. Lucky Lagoon has seven risky yellow-frog pads along its main route, each with a safer path around it. **Sunlit lagoon** introduces lily-pad jumping. **Frog river** adds a baseball bat and some unfamiliar river residents. **Lucky lagoon** offers precise jumping routes and optional risky shortcuts. Pick any crossing on the title screen, or use **Next level** after completing each course. Frog River leaves the color rules and strategy for players to discover; controls, health, and immediate results remain visible.

<details>
<summary>Gameplay mechanics and secrets (spoilers)</summary>

Green frogs have physical collision, idle hops, and a cartoony flip-and-puff defeat. Landing on an occupied green-frog pad poisons you: health drains at 20 percentage points per second, including after jumping away. Defeating a green frog cures poison and restores exactly **100% health**. At zero, the character collapses and retries after 1.2 seconds at full health. Poison does not stack, and pause freezes it. Face a nearby green frog and swing. The bat follows the character’s current facing direction; attacking never turns the character toward the camera. **Red frogs mark fake pads:** landing on one makes it collapse and drops you into the water. Red frogs are warning markers, cannot be defeated or stood on, and do not count toward victory. The safe route uses the green-frog pads. Green enemies now repeat a readable 4.8-second pattern: watch, crouch for 0.7 seconds, hop sideways for 0.7 seconds, then recover on the ground for 1.8 seconds. A small gold ring marks the landing before the hop. The actual collision body moves with the frog; bat range and facing still matter. A hit can land during the hop or the long grounded opening. Red and yellow markers retain their earlier behavior.

**Yellow frogs** are chance markers on Level 3. Each yellow pad draws one independent random result on its first landing in an attempt: 50% sink, 50% solid. A solid result lasts for that attempt, including re-landings. Retry/restart resets all yellow pads for fresh rolls. Yellow markers do not poison and are not enemies. Seven yellow pads sit along the main route, all the way to the final island. Smaller, permanently solid pads form bypasses around every yellow pad. You can mix the risky main route and the safer bypasses; the level remains completable without any lucky rolls.

Missing a landing or choosing a sinking pad gives you a splash and a quick retry. All green frogs reappear after any death or water fall; fake pads reset for the next try. Restart or replay restores all enemies and traps. Name, hoodie color, sound/mute, pause/resume, and replay work in all three levels.

**Secret Perch achievement:** jump onto a stone pillar just left of the starting lily pad. Landing on its top awards a badge and immediately equips the purple **Moonflower** hoodie. The badge card on the title screen lets you wear it again. The unlock survives restarts, level changes, and browser refreshes on the same browser/origin; clearing site data removes it. If storage is unavailable, it remains earned for the current visit. The pillar stays solid, and earning the badge does not finish the course.

</details>

## Find the fireflies

There are **three hidden fireflies in each level**, nine in total. Explore side branches and the far shore, and walk or jump close to a glowing firefly to collect it. Each pickup gives a small burst and chime. The HUD and crossing buttons show your collection count. Fireflies are optional: reaching the flag uses the same completion rules as before.

Each level also has a **drifting lily pad** on an exploration branch. Its fixed eight-second cycle pauses for one second at each end, with three-second eased journeys between them. It carries you while you stand still. Watch its path, wait for a good moment, and jump; jumping keeps the familiar movement control without an extra sideways launch. Motion freezes during pause and customization and resets on restart/retry. All original crossing routes remain available, including Lucky Lagoon's permanently solid bypasses.

Found fireflies save immediately and stay collected after a fall, restart, level change, or reload in the same browser at the same address. Saving preserves your character and Secret Perch unlock. If browser storage is blocked, the game says saving is unavailable and retains finds for the current visit. Clearing site data removes local saves. Level completion, best times, and sound/mute still do not persist.

## Customize your character

Click **Customize** beside the name field on the title screen, or in the top-right corner of the pause screen. Choose your shirt color in **Tops**. The wardrobe has a large live preview; drag the character or use the Turn buttons to see every side.

- **Character:** Boy, Girl, or Neutral; six skin tones; an optional name.
- **Hair:** Short, Bob, Ponytail, Curls, Buzz, or No hair; six colors.
- **Tops:** Hoodie, T-shirt, or Jacket; six colors, including the earned Moonflower color.
- **Pants:** Shorts, Jeans, or Joggers; six colors.
- **Shoes:** Sneakers, Boots, or High-tops; six colors.

Mix any hairstyle and outfit with any character option. **Save outfit** equips your choices and stores them locally; **Cancel** or Escape discards the preview. Saving from pause returns to pause with your position and run intact. Names and clothing survive refreshes on the same browser/origin. Clearing site data clears those choices. If storage is unavailable, the outfit remains usable for the current visit. Existing Secret Perch saves are preserved. Clothing does not change movement, jumping, or hitboxes.

A wave chases you through every level after a six-second head start. A rear-view window shows the taller foaming wave behind you. It speeds up smoothly when you get far ahead, then slows to its normal pace nearby. Watch the distance in the HUD and keep moving: the advancing front catches you even on a lily pad. Pause freezes the wave; retry resets it and brings every defeated frog back. Frog River gives you a slower wave to allow time for combat.

## Play now

On this Mac, double-click **Play Lily Pad Escape.command**. It opens the local browser build and starts a server if needed. Keep its Terminal window open while playing.

Or from this folder:

```sh
./scripts/serve.sh
```

Open **http://127.0.0.1:8765/** in desktop Chrome or Firefox. The game needs WebGL 2 and WebAssembly. Opening `build/web/index.html` directly with a `file://` URL will not work. The server binds only to your own computer.

- **WASD or arrow keys**: move relative to the camera
- **Mouse**: orbit the camera
- **Space**: jump once per press
- **Left click or F**: swing the baseball bat in Level 2 (once per press)
- **Escape**: pause and release the mouse (left click also pauses in Levels 1 and 3)
- **R**: restart

Level 1 plays “Platformer Rush”, Level 2 plays “Bouncing Beat pt2”, and Level 3 plays “Lily Pad Rush”; the sound control also mutes the music.

Click **Let's hop!**, **Resume**, **Next level**, or **Play again** to capture the mouse. Click the sound button on the title or pause/victory panel to mute. Focus loss or mouse-lock loss pauses the game. If a browser declines mouse capture, the game pauses safely; click Resume after focusing its window.

## Edit and export

Engine: **Godot 4.6.stable.official.89cea1439**, standard GDScript build. Renderer: **Compatibility**. Physics: **60 Hz**. Web export: **single-threaded**, with version-matched `web_nothreads_*` templates. No backend or external runtime service.

Double-click **Edit Game.command**, or open `game/project.godot` in Godot 4.6 and press F6/F5. All visible 3D geometry is constructed from editable GDScript and the level resource when the scene starts.

The local engine and templates live under the ignored `.tools/` directory. To set up a fresh Mac from the source package:

```sh
./scripts/setup-macos.sh
./scripts/export.sh
./scripts/serve.sh
```

The setup script downloads the official macOS universal engine and matching export-template archive (about 1.35 GB combined). It extracts only the two Web templates needed here. On another OS, install the same Godot version, put the two matching Web template ZIPs under `.tools/templates/`, and set `GODOT_BIN` to your executable.

Exact engine commands, with `GODOT_BIN` set to your engine path:

```sh
"$GODOT_BIN" --headless --path game --editor --import --quit
"$GODOT_BIN" --headless --path game --export-release Web ../build/web/index.html
"$GODOT_BIN" --path game --editor
```

Keep every companion file in `build/web/` together. The prepared browser build has no dependency on Node or an installed Godot editor.

## Tune the game

- `game/levels/sunlit_lagoon.tres`, `game/levels/frog_river.tres`, and `game/levels/lucky_lagoon.tres`: pad X/Z/radius triples, green-frog and yellow-chance pad indices, permanent bypass/exploration X/Z/radius triples, drifting-pad home/travel, firefly locations, poison damage rate, decoy X/Z/radius triples, equipment, spawn, island, flag, water, and landing height. Open the resource in Godot's Inspector to edit it.
- `game/scripts/player.gd`: exposed movement speed (5.4 m/s), acceleration (32), braking (42), air steering (16), jump speed (8.4 m/s), gravity (22 m/s²), coyote time (0.10 s), jump buffer (0.12 s), mouse sensitivity, and camera distance/pitch limits.
- `game/scripts/avatar.gd`: modular procedural character, hairstyles, tops, pants, shoes, bat, and idle/run/jump/landing/swing animation. Appearance rebuilds preserve the root orientation and animation clocks.
- `game/scripts/drifting_pad.gd` and `game/scripts/firefly.gd`: physical repeating platform motion, endpoint pauses, pickup proximity, wing flutter, and glow. Drifting platforms carry the player through Godot's moving-platform support.
- `game/scripts/decoy_pad.gd`: contact-triggered support removal, a single 50/50 draw per yellow pad per attempt, sinking animation, and reset. The chance RNG is independent of scenery and freshly randomized when building a world. Landing triggers actual gravity-driven falling; flying over a pad does not activate it.
- `game/scripts/frog.gd`: green enemy, red warning-marker, and yellow chance-marker geometry, physical obstruction, telegraphed side-to-side hops with grounded recovery, warning-marker idle motion, and defeat animation. Melee timing lives in `player.gd`; range/facing checks and finish requirements live in `game.gd`. Swing duration is 0.48 s, impact at 0.12 s, range 2.3 m, facing dot at least 0.20, vertical tolerance 1.1 m.
- `game/scripts/world.gd` and `game/shaders/water.gdshader`: geometry, palette, lighting, water, particles, scenery. Platform colliders come from the same mesh as their visible surfaces.
- `game/scripts/game.gd`: title, playing, splash, poison defeat, paused, and won state transitions, level switching, combat, health/poison, and reset policy.
- `game/scripts/ui.gd` and `game/scripts/wardrobe.gd`: menus, customization preview, category controls, progress, and save/cancel behavior. The wardrobe uses its own 3D viewport and pauses the active run.
- `game/scripts/appearance.gd` and `game/scripts/profile.gd`: allowed style/color choices, validation, name/outfit storage, unique per-level firefly masks, and the achievement flag. Web saves use localStorage; native saves use `user://achievements.cfg`. Old achievement-only and wardrobe saves load correctly, and storage failure keeps the outfit and collected fireflies available for the visit.

The typical jump stays airborne for about 0.76 s and covers about 4.1 m at full speed. Start from partway across a pad rather than its center for longer gaps. The final route has been completed with ordinary mouse/keyboard inputs; the numbers alone are not the reachability evidence.

## Verification

```sh
./scripts/test-native.sh
npm install
npm run test:browser  # keep ./scripts/serve.sh running; requires installed Chrome
```

The native suite checks movement, jump edge cases, actual platform collision, retries, reset, camera collision, melee range/facing/timing, frog collision, the gated finish, decoy contact, jump escape prevention, sinking/pause behavior, trap recovery, health damage/healing/death, chance outcomes, and one-roll-per-attempt behavior. Controller-driven tests complete all three extended courses with ordinary movement, including all six frog fights and all relocated far-shore fireflies. The Level 3 test removes all yellow supports before the first jump and completes the entire solid route without falls or any random draw. The browser suite uses mouse/keyboard input for all three full courses, including all six bat attacks, an intentional red-pad fall with arrow keys, poison death and recovery, both a zero-roll solid-route Level 3 crossing and a genuinely random shortcut crossing, and both Next level transitions. It also checks the secret pillar using a normal jump, saved badge/hoodie availability after refresh, storage-denied fallback, menus, focus, input capture, replay, and viewport fit. `npm run test:secret` runs just the achievement acceptance checks. `npm run test:facing` reproduces backward and sideways attacks using normal controls and verifies an actual backward frog defeat. `npm run test:wardrobe` checks every customization category, preview rotation, save/cancel, refresh, paused editing, smaller-window controls, and storage fallback. `npm run test:exploration` collects all nine fireflies with normal controls, rides every moving pad, completes all three levels, and checks reload persistence. `npm run test:collection-storage` checks malformed/blocked browser storage and captures the frog telegraph and hop. `?qa` exposes read-only local telemetry to the browser tests; it provides no movement setters or teleport methods and sends no data anywhere.

See `docs/TEST_REPORT.md`, `docs/native-test-results-v0.8.txt`, `docs/browser-test-results.json`, `docs/combat-browser-results.json`, `docs/lucky-browser-results.json`, `docs/secret-browser-results.json`, `docs/wardrobe-browser-results.json`, `docs/exploration-browser-results.json`, `docs/collection-storage-browser-results.json`, and `docs/playthrough.json` for actual results. PNGs under `docs/` are captured from the running implementation.

## Scope and assets

This version has three levels for desktop keyboard and mouse, with a baseball bat in Level 2. Touch, controller, shared levels, an in-game editor, gameplay upgrades, other weapons, saved course progress, and multiplayer are not implemented. The supplied reference art guided the style; all runtime art and sound were created for the game. See `docs/ASSET_CREDITS.md` for provenance and engine notices. Review and implementation decisions are in `docs/EXECUTION_PLAN.md`.
