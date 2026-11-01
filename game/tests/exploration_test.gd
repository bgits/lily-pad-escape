extends SceneTree

var game: Node3D
var player: LilyPlayer
var passed := 0
var failures: Array[String] = []
const SAVE := "user://lily_qa_exploration.cfg"

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ",message)
	else:
		failures.append(message)
		push_error("FAIL: "+message+" "+str(game.debug_snapshot()))

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = SAVE
	DirAccess.remove_absolute(SAVE)
	root.add_child(game)
	player = game.player
	check(game.profile.firefly_masks == [0,0,0],"A new profile has no collected fireflies")
	game.start_run()
	await frames(75)
	var pad: LilyDriftingPad = game.world.drifting_pads[0]
	player.respawn(pad.position+Vector3(0,0.75,0))
	await frames(20)
	var relative := player.position-pad.position
	var before := player.position
	await frames(110)
	check(player.is_on_floor() and player.position.distance_to(before)>1.0,"A moving pad physically carries a standing player")
	check((player.position-pad.position).distance_to(relative)<0.12,"The rider stays aligned with the moving surface")
	check(game.profile.has_firefly(0,0) and game.world.fireflies[0].collected,"Contact collects the moving firefly and records its unique identity")
	var clock: float = pad.clock
	var paused_position := pad.position
	game.pause()
	await frames(40)
	check(pad.clock == clock and pad.position == paused_position and player.is_on_floor(),"Pause freezes the moving pad and rider")
	game.open_customization()
	await frames(30)
	check(pad.position == paused_position and pad.clock == clock,"Customization also freezes platform motion")
	game.close_customization()
	game.resume()
	await frames(20)
	check(pad.clock>clock,"Resume continues the same motion phase")
	var offset := player.position-pad.position
	await frames(480)
	check(player.is_on_floor() and (player.position-pad.position).distance_to(offset)<0.15 and game.falls == 0,"The rider survives a complete eight-second platform cycle")
	key(KEY_SPACE,true)
	await frames(8)
	key(KEY_SPACE,false)
	check(not player.is_on_floor() and player.velocity.y>0,"Jump detaches the player from the drifting pad")
	check(Vector2(player.velocity.x,player.velocity.z).length()<0.01,"Jumping does not inherit a surprise sideways launch")
	game.start_run()
	await frames(8)
	check(pad.position.distance_to(pad.home)<0.01,"Restart returns the drifting pad to its near endpoint")
	check(game.profile.firefly_count(0) == 1 and game.world.fireflies[0].collected,"Restart preserves a previously found firefly")
	for level in 3:
		game.show_title()
		game.select_level(level)
		game.start_run()
		await frames(8)
		check(game.world.fireflies.size() == 3 and game.world.drifting_pads.size() == 1,"Level %d has exactly three fireflies and one drifting pad" % (level+1))
		for fly in game.world.fireflies:
			if fly.collected:
				continue
			game.pause()
			player.respawn(fly.global_position-Vector3.UP*0.7)
			await frames(10)
			check(not fly.collected,"Paused contact does not collect Level %d firefly %d" % [level+1,fly.index+1])
			game.resume()
			await frames(3)
			check(fly.collected and game.profile.has_firefly(level,fly.index),"Level %d firefly %d collects once on live contact" % [level+1,fly.index+1])
			await frames(6)
		check(game.profile.firefly_count(level) == 3 and game.ui.firefly_label.text == "Fireflies  3 / 3","Level %d displays its complete unique collection" % (level+1))
	check(game.profile.firefly_masks == [7,7,7],"All nine collectible identities remain independent")
	game.profile.player_name = "Firefly Finder"
	game.profile.save_customization()
	game.profile.unlock_secret()
	var restored := LilyProfile.new()
	restored.storage_path = SAVE
	restored.load_progress()
	check(restored.firefly_masks == [7,7,7] and restored.secret_perch and restored.player_name == "Firefly Finder","Saving clothing and the secret preserves collections across reload")
	check(LilyProfile.sanitize_fireflies([true,-1,8]) == [0,0,0],"Invalid collection masks are rejected")
	check(LilyProfile.sanitize_fireflies([1.5,3.0,"7"]) == [0,3,0],"Only valid integral masks load from JSON")
	check(LilyProfile.sanitize_fireflies({"0":7}) == [0,0,0],"Malformed collection shapes fall back safely")
	restored.storage_path = "user://missing_exploration_folder/profile.cfg"
	check(not restored.collect_firefly(0,1) and restored.has_firefly(0,1),"A failed save retains the firefly for this visit")
	game.show_title()
	game.select_level(1)
	game.start_run()
	var frog: LilyFrog = game.world.frogs[0]
	var phases: Array[String] = []
	var max_height := 0.0
	var min_x := frog.position.x
	var max_x := frog.position.x
	for i in 295:
		await frames(1)
		if phases.is_empty() or phases.back() != frog.behavior:
			phases.append(frog.behavior)
		if frog.behavior == "crouching":
			check(frog.landing_marker.visible and frog.position.y<0.65,"Crouch telegraphs the landing before the physical hop")
			game.pause()
			var frozen_clock := frog.clock
			var frozen_position := frog.position
			await frames(20)
			check(frog.clock == frozen_clock and frog.position == frozen_position,"Pause freezes a frog's telegraph and movement")
			game.resume()
			# Record this check only once; keep advancing normally on later frames.
			while frog.behavior == "crouching":
				await frames(1)
		max_height = maxf(max_height,frog.position.y)
		min_x = minf(min_x,frog.position.x)
		max_x = maxf(max_x,frog.position.x)
		if phases.has("resting"):
			break
	check(phases == ["watching","crouching","hopping","resting"],"Frog phases follow watch, crouch, hop, recovery in order")
	check(max_height>1.3 and max_x-min_x>0.8,"The frog's actual body follows its visible sideways hop")
	check(not frog.landing_marker.visible and frog.position.y<0.65,"Recovery is grounded and clears the landing marker")
	# Wait in the attack window, then hit through the real bat event.
	player.respawn(frog.position+Vector3(0,0.05,1.5))
	await frames(8)
	key(KEY_F,true)
	await frames(12)
	key(KEY_F,false)
	check(not frog.alive and game.health == 100 and not game.poisoned,"A recovery-window bat hit defeats the frog and fully heals")
	var death_position := frog.position
	await frames(45)
	check(frog.position == death_position and not frog.visible and not frog.landing_marker.visible,"Defeat cancels future hops and the telegraph")
	check(game.world.decoys.all(func(p): return p.marker.position == Vector3(0,game.level.surface_height,-0.25)),"Red markers do not acquire enemy movement")
	print("RESULT: %d passed, %d failed" % [passed,failures.size()])
	game.stop_sounds()
	game.queue_free()
	await frames(3)
	DirAccess.remove_absolute(SAVE)
	quit(0 if failures.is_empty() else 1)
