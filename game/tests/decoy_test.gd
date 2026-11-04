extends SceneTree

var game: Node3D
var player: LilyPlayer
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
		push_error("FAIL: " + message + " " + str(game.debug_snapshot()))

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func land_on(pad: LilyDecoyPad) -> void:
	player.respawn(pad.home_position+Vector3(0,0.95,-0.25))
	for i in 30:
		await frames(1)
		if pad.collapsed:
			return

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_decoy.cfg"
	DirAccess.remove_absolute(game.profile.storage_path)
	game.tide_enabled = false
	root.add_child(game)
	player = game.player
	await frames(3)
	check(game.world.decoys.is_empty(),"The introductory lagoon has no decoy hazards")
	game.select_level(1)
	game.start_run()
	await frames(8)
	check(game.world.decoys.size() == 4 and game.world.frogs_remaining() == 6,"Frog river has four decoys and six required green frogs")
	var separated := true
	for fake in game.level.decoy_pads:
		for safe in game.level.pads:
			separated = separated and Vector2(fake.x-safe.x,fake.y-safe.y).length() > fake.z+safe.z+0.3
	check(separated,"Decoys do not overlap safe landing surfaces")
	var pad: LilyDecoyPad = game.world.decoys[0]
	check(pad.marker.is_decoy and pad.marker.collision_layer == 0 and pad.marker.collider.disabled,"Red warning frogs cannot be used as solid footholds")
	pad.marker.defeat()
	check(pad.marker.alive and game.world.frogs_remaining() == 6,"Red markers cannot be defeated and do not change the enemy count")
	player.respawn(pad.marker.global_position+Vector3(0,0.6,1.6))
	key(KEY_F)
	await frames(9)
	key(KEY_F,false)
	check(pad.marker.alive and game.hit_count == 0 and game.ui.toast.text == "Miss!","A real bat swing leaves the red marker with ordinary miss feedback")
	game.start_run()
	await frames(8)
	player.respawn(pad.home_position+Vector3(0,2.6,0))
	player.velocity.y = 8.0
	await frames(12)
	check(not pad.collapsed and game.decoy_trips == 0,"Flying above a decoy without landing does not trigger it")
	# Clear one green frog first; trap retries must restore it.
	var green: LilyFrog = game.world.frogs[0]
	player.respawn(green.global_position+Vector3(0,0,1.75))
	await frames(3)
	key(KEY_F)
	await frames(32)
	key(KEY_F,false)
	check(game.hit_count == 1 and game.world.frogs_remaining() == 5,"Green enemies still defeat normally beside the decoy branches")
	for i in game.world.decoys.size():
		pad = game.world.decoys[i]
		var progress_before: int = game.furthest_pad
		await land_on(pad)
		check(pad.collapsed and player.falling_through and game.decoy_trips == i+1,"Landing triggers decoy %d exactly once" % (i+1))
		check(pad.collision_layer == 0 and game.furthest_pad == progress_before,"Decoy %d removes support without advancing route progress" % (i+1))
		key(KEY_SPACE)
		await frames(1)
		key(KEY_SPACE,false)
		check(player.jump_count == 0 and player.velocity.y < 0 and player.buffered == 0,"A late jump cannot rescue a collapsed pad %d" % (i+1))
		if i == 0:
			game.pause()
			var frozen_player := player.position
			var frozen_pad := pad.position
			await frames(20)
			check(player.position.is_equal_approx(frozen_player) and pad.position.is_equal_approx(frozen_pad),"Pause freezes both the sinking pad and the falling character")
			game.resume()
		for tick in 40:
			await frames(1)
			if game.state == "splash":
				break
		check(game.state == "splash" and game.falls == i+1 and game.ui.toast.text == "A splash, then another chance.","Decoy %d drops the player into one water failure with ordinary splash feedback" % (i+1))
		await frames(25)
		check(not pad.visible and pad.marker.global_position.y < game.level.water_height,"Collapsed pad %d and its warning frog sink under the water" % (i+1))
		await frames(50)
		check(game.state == "playing" and not pad.collapsed and pad.visible and pad.collision_layer == 1 and not player.falling_through,"Retry restores decoy %d and ordinary movement" % (i+1))
		check(game.hit_count == 0 and game.world.frogs_remaining() == 6,"Trap retry %d restores all green frogs" % (i+1))
	key(KEY_SPACE)
	await frames(4)
	key(KEY_SPACE,false)
	check(player.jump_count == 1 and player.velocity.y > 0,"Jump controls work again after a decoy retry")
	await land_on(game.world.decoys[0])
	game.start_run()
	await frames(8)
	check(game.decoy_trips == 0 and game.falls == 0 and game.hit_count == 0 and game.world.frogs_remaining() == 6,"Restart during collapse resets hazards, failures, and all green enemies")
	check(not game.world.decoys[0].collapsed and not player.falling_through and player.is_on_floor(),"Restart during collapse returns to a supported practice pad")
	game.show_title()
	game.select_level(0)
	check(game.world.decoys.is_empty() and not game.ui.frog_legend.visible,"Returning to Level 1 removes the decoys and their instructions")
	print("RESULT: %d passed, %d failed" % [passed,failures.size()])
	game.stop_sounds()
	await frames(8)
	game.queue_free()
	await frames(3)
	DirAccess.remove_absolute("user://lily_qa_decoy.cfg")
	quit(0 if failures.is_empty() else 1)
