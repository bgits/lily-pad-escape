extends SceneTree

const TEST_SAVE := "user://lily_qa_wardrobe.cfg"
const LEGACY_SAVE := "user://lily_qa_legacy.cfg"
var game: Node3D
var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ",message)
	else:
		failures.append(message)
		push_error("FAIL: "+message)

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(LEGACY_SAVE)
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = TEST_SAVE
	game.tide_enabled = false
	root.add_child(game)
	await frames(3)
	var original: Dictionary = game.profile.outfit.duplicate()
	check(game.player.avatar.outfit == original,"Starting avatar uses the validated saved outfit")
	game.open_customization()
	var editor: LilyWardrobe = game.ui.wardrobe
	check(game.state == "customizing" and not game.player.active and editor.visible,"Customize opens from the title without activating gameplay")
	check(editor.preview.outfit == original and editor.preview != game.player.avatar,"Preview uses an independent character with the current outfit")
	for value in [{"key":"character","value":1},{"key":"skin","value":4},{"key":"hair_style","value":2},{"key":"hair_color","value":3},{"key":"top_style","value":1},{"key":"top_color","value":4},{"key":"pants_style","value":1},{"key":"pants_color","value":1},{"key":"shoe_style","value":1},{"key":"shoe_color","value":2}]:
		editor.choose(value.key,value.value)
	check(editor.preview.outfit == editor.draft and editor.draft != original,"All ten choices update the visible preview")
	check(game.player.avatar.outfit == original and game.profile.outfit == original,"Unsaved previews do not change the gameplay character or profile")
	editor.choose("top_color",3)
	check(editor.draft.top_color == 4 and editor.controls.top_color_3.disabled,"Moonflower stays locked without the badge")
	key(KEY_F)
	key(KEY_F,false)
	key(KEY_R)
	key(KEY_R,false)
	key(KEY_SPACE)
	key(KEY_SPACE,false)
	await frames(5)
	check(game.state == "customizing" and game.player.swing_count == 0 and game.player.jump_count == 0,"Wardrobe typing and controls cannot attack, jump, or restart the level")
	game.close_customization()
	check(game.state == "title" and game.profile.outfit == original,"Cancel discards unsaved changes and returns to the title")
	game.open_customization()
	check(editor.draft == original,"Reopening after Cancel restores the equipped outfit")
	var chosen := {"character":1,"skin":4,"hair_style":2,"hair_color":3,"top_style":1,"top_color":4,"pants_style":1,"pants_color":1,"shoe_style":1,"shoe_color":2}
	for field: String in chosen:
		editor.choose(field,chosen[field])
	editor.name_field.text = "Pip \"Sky\" <3"
	editor.saved.emit(editor.draft.duplicate(),editor.name_field.text)
	check(game.state == "title" and game.player.avatar.outfit == chosen,"Save applies every choice to the actual character and closes the wardrobe")
	check(game.outfit_saved and game.ui.name_input.text == "Pip \"Sky\" <3","Name and outfit save successfully")
	var loaded := LilyProfile.new()
	loaded.storage_path = TEST_SAVE
	loaded.load_progress()
	check(loaded.outfit == chosen and loaded.player_name == "Pip \"Sky\" <3","A fresh profile reloads all choices and a quoted name")
	game.ui.select_color(1)
	chosen.top_color = 1
	check(game.profile.outfit == chosen and game.player.avatar.hoodie.albedo_color == Color("e58f76"),"Title color shortcuts preserve other clothing and hair choices")
	game.select_level(1)
	game.start_run()
	check(game.player.avatar.outfit == chosen and game.player.avatar.bat.visible,"Starting Frog River keeps the outfit and equips the bat")
	var frog: LilyFrog = game.world.frogs[0]
	game.player.respawn(frog.position+Vector3(0,0.1,1.75))
	await frames(12)
	key(KEY_F)
	await frames(3)
	key(KEY_F,false)
	game.pause()
	var position: Vector3 = game.player.position
	var heading: Vector3 = game.player.avatar.rotation
	var remaining: float = game.player.swing_remaining
	var animation: float = game.player.avatar.swing_time
	var health: float = game.health
	var collision: Shape3D = game.player.get_child(0).shape
	game.open_customization()
	await frames(20)
	check(game.state == "customizing" and game.player.position == position and game.health == health and game.player.swing_remaining == remaining,"Customizing from pause freezes movement, poison, and attack timing")
	editor.choose("top_style",2)
	editor.choose("pants_style",2)
	editor.choose("shoe_style",2)
	editor.choose("hair_style",3)
	editor.saved.emit(editor.draft.duplicate(),editor.name_field.text)
	chosen = game.profile.outfit.duplicate()
	check(game.state == "paused" and not game.player.active,"Saving from pause returns to pause without resuming play")
	check(game.player.position == position and game.player.avatar.rotation == heading and game.player.get_child(0).shape == collision,"Changing clothes preserves position, facing, and the collision shape")
	check(game.player.has_bat and game.player.avatar.bat.visible and game.player.avatar.swing_time == animation,"New outfit retains the equipped bat and frozen animation")
	game.resume()
	await frames(15)
	check(not frog.alive and game.health == 100 and not game.poisoned,"Resuming the customized character completes its pending hit and heals normally")
	game.start_run()
	check(game.profile.outfit == chosen and game.player.avatar.outfit == chosen,"Restart keeps the chosen outfit")
	game.show_title()
	game.select_level(2)
	game.start_run()
	check(game.player.avatar.outfit == chosen and not game.player.avatar.bat.visible,"Level changes keep the outfit and update equipment normally")
	game.show_title()
	game.open_customization()
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	await frames(2)
	check(game.state == "title" and not editor.visible,"Escape cancels the wardrobe")
	for hair in 6:
		chosen.hair_style = hair
		game.player.avatar.apply_appearance(chosen)
		check(is_instance_valid(game.player.avatar.torso) and is_instance_valid(game.player.avatar.right_arm),"Hairstyle %d builds on the animated character" % hair)
	var legacy := ConfigFile.new()
	legacy.set_value("achievements","secret_perch",true)
	legacy.save(LEGACY_SAVE)
	loaded.storage_path = LEGACY_SAVE
	loaded.load_progress()
	check(loaded.secret_perch and loaded.outfit == LilyAppearance.DEFAULTS,"Old achievement-only saves keep their badge and receive default clothing")
	loaded.outfit = chosen.duplicate()
	loaded.outfit.top_color = 3
	loaded.save_customization()
	loaded.load_progress()
	check(loaded.secret_perch and loaded.outfit.top_color == 3,"Saving clothing preserves a legacy badge and its Moonflower choice")
	var malformed := {"character":99,"hair_style":-1,"skin":"red","shoe_style":1.5,"top_color":3,"top_style":2}
	var safe := LilyAppearance.sanitize(malformed,false)
	check(safe.character == 0 and safe.hair_style == 0 and safe.skin == 1 and safe.shoe_style == 0 and safe.top_color == 0 and safe.top_style == 2,"Malformed or locked saved choices fall back safely while valid choices survive")
	check(LilyAppearance.sanitize(null,false) == LilyAppearance.DEFAULTS,"Missing outfit data loads safe defaults")
	check(LilyProfile.clean_name(42) == "" and LilyProfile.clean_name("12345678901234567890").length() == 18,"Saved names are type-checked and length-limited")
	loaded.storage_path = "user://missing-wardrobe-test-dir/profile.cfg"
	check(not loaded.save_customization() and loaded.outfit.top_color == 3,"Unavailable storage keeps the chosen outfit in memory")
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(LEGACY_SAVE)
	print("WARDROBE RESULT: %d passed, %d failed" % [passed,failures.size()])
	game.stop_sounds()
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
