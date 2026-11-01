# Lily Pad Escape — implementation-agent handoff

This package contains a build prompt and visual references. It is not a playable game and does not contain ready-made 3D models, animations, textures, or sound effects.

## Use

Extract this folder into the implementation agent's accessible workspace. Ask the agent to read `IMPLEMENTATION_PROMPT.md` and implement it. The paths in the prompt are relative to this folder; adapt them when placing the folder inside an existing repository.

Suggested kickoff message:

> Read IMPLEMENTATION_PROMPT.md and inspect reference/01_chosen_gameplay.png. Implement the first playable version described there, test it with the tools available to you, and report what actually works. Treat original-notes/ as background rather than additional milestone requirements.

## Included files

`IMPLEMENTATION_PROMPT.md`: the complete build specification.

`reference/01_chosen_gameplay.png`: the chosen standalone third-person 3D concept image from this conversation. This is the visual target, not a game asset to use as the gameplay background.

`original-notes/01_level_sketch.jpeg`: the original stranded-character/lily-pad sketch.

`original-notes/02_character_ideas.jpeg`: original notes about character appearance and customization, with future level-sharing ideas.

`original-notes/03_gameplay_ideas.jpeg`: original objective, level, and future-upgrade notes.

The three-camera comparison image is deliberately omitted: third-person 3D has already been chosen.

## Assumptions, not additional approved decisions

The user chose third-person 3D with a chunky/pixel-like visual style. The brief proposes desktop browser, keyboard/mouse, Godot/GDScript, ordinary fixed-strength jumping, one equipment-free level, and immediate retries as implementation defaults. These choices have not separately been confirmed by the daughter. “Lily Pad Escape” is only a working title. The illustrated character's outfit is a visual reference, not a required likeness of the daughter.

## Technical references

These official pages were checked on October 27, 2026. The implementation agent should use documentation matching its chosen installed stable version.

- Web export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
- Third-person camera: https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html
- Character body: https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html

Use the full prompt as the scope authority. The screenshot's energy bar, on-screen buttons, and decorative trajectory arc are not requirements.
