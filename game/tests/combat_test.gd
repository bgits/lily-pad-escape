extends SceneTree

var game: Node3D
var player: LilyPlayer
var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ",message)
	else:
		failures.append(message)
		push_error("FAIL: " + message + " " + str(game.debug_snapshot()))

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func key(code: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func face_frog(frog: LilyFrog, distance := 1.75, yaw := 0.0, height := 0.0) -> void:
	player.respawn(frog.position+Vector3(0,height,distance))
	player.yaw = yaw
	player.pivot.rotation.y = yaw
	player.avatar.rotation.y = yaw
	await frames(2)

func swing() -> void:
	key(KEY_F)
	await frames(32)
	key(KEY_F,false)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_combat.cfg"
	DirAccess.remove_absolute(game.profile.storage_path)
	root.add_child(game)
	player = game.player
	await frames(2)
	game.select_level(1)
	game.start_run()
	await frames(8)
	check(game.level_index == 1 and player.has_bat and player.avatar.bat.visible,"Level 2 spawns with the visible bat equipped")
	check(game.world.frogs_remaining() == 6 and player.swing_count == 0,"Six frogs spawn with no accidental initial swing")
	await swing()
	check(game.hit_count == 0 and game.world.frogs_remaining() == 6,"Distant swing cannot damage frogs")
	var frog: LilyFrog = game.world.frogs[0]
	await face_frog(frog,1.75,PI)
	await swing()
	check(frog.alive,"A frog behind the attack direction is not hit")
	await face_frog(frog,2.45)
	key(KEY_F)
	await frames(9)
	key(KEY_F,false)
	check(frog.alive,"A frog outside 2.3 m remains alive")
	await face_frog(frog,1.75,0,2.8)
	key(KEY_F)
	await frames(9)
	key(KEY_F,false)
	check(frog.alive,"A swing too high above a frog cannot hit it")
	await face_frog(frog)
	key(KEY_F)
	await frames(3)
	key(KEY_F,false)
	check(frog.alive,"Wind-up precedes the impact frame")
	key(KEY_F)
	key(KEY_F,true,true)
	await frames(7)
	key(KEY_F,false)
	check(not frog.alive and game.hit_count == 1,"A forward bat impact defeats the frog exactly once")
	check(frog.collision_layer == 0 and frog.collider.disabled,"Defeated frog immediately releases its physical obstruction")
	var swings: int = player.swing_count
	key(KEY_F)
	await frames(3)
	key(KEY_F,false)
	check(player.swing_count == swings,"Attack cooldown rejects repeated presses and autorepeat")
	await frames(25)
	check(not frog.visible,"Defeat animation removes the frog after its puff")
	await swing()
	check(game.hit_count == 1,"An already defeated frog cannot be counted twice")
	frog = game.world.frogs[1]
	await face_frog(frog)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await frames(65)
	click.pressed = false
	Input.parse_input_event(click)
	check(game.state == "playing" and not frog.alive,"Left click attacks instead of pausing in Level 2")
	check(player.swing_count == swings+2,"Holding the mouse does not repeat attacks")
	frog = game.world.frogs[2]
	await face_frog(frog)
	key(KEY_F)
	await frames(3)
	key(KEY_F,false)
	game.pause()
	var remaining := player.swing_remaining
	var frog_clock := frog.clock
	await frames(30)
	check(frog.alive and player.swing_remaining == remaining and frog.clock == frog_clock,"Pause freezes attack wind-up and frog animation")
	game.resume()
	await frames(10)
	check(not frog.alive,"Resumed swing delivers its pending hit once")
	player.position = Vector3(10,-0.3,0)
	await frames(65)
	check(game.state == "playing" and game.world.frogs_remaining() == 3 and player.has_bat,"Water retry keeps defeated frogs cleared and the bat equipped")
	check(player.swing_remaining == 0 and not player.impact_pending,"Water retry clears unfinished attack state")
	game.start_run()
	await frames(8)
	check(game.world.frogs_remaining() == 6 and player.swing_count == 0 and game.hit_count == 0,"Restart restores all frogs and clears combat counters")
	frog = game.world.frogs[0]
	var p := frog.position
	var obstruction := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3(0,0.4,2),p+Vector3(0,0.4,-2),4))
	check(not obstruction.is_empty() and obstruction.collider == frog,"Living frog has real physical collision on its pad")
	player.respawn(game.level.flag_position)
	await frames(12)
	check(game.state == "playing" and game.victories == 0 and game.ui.toast.text == "The crossing isn't clear yet.","Flag cannot finish Level 2 while frogs remain")
	for target in game.world.frogs:
		await face_frog(target)
		await swing()
	check(game.world.frogs_remaining() == 0 and game.hit_count == 6,"All six frogs can be defeated through the melee input")
	player.respawn(game.level.flag_position)
	await frames(12)
	check(game.state == "won" and game.victories == 1,"Cleared river finishes on the grounded flag island")
	check(game.ui.next_button.visible and game.ui.next_button.text.contains("Lucky lagoon"),"Frog river offers the new Lucky lagoon level")
	game.start_run()
	await frames(5)
	check(game.level_index == 1 and game.world.frogs_remaining() == 6,"Replay stays in Level 2 and restores enemies")
	game.show_title()
	game.select_level(0)
	game.start_run()
	await frames(5)
	check(not player.has_bat and not player.avatar.bat.visible and game.world.frogs.is_empty(),"Selecting Level 1 removes all combat equipment and enemies")
	game.ui.name_input.text = "Pip"
	game.ui.select_color(1)
	game.win()
	check(game.ui.next_button.visible,"Level 1 victory offers the next level")
	game.next_level()
	await frames(5)
	check(game.level_index == 1 and game.state == "playing" and game.world.frogs_remaining() == 6,"Next level starts a fresh Frog river run")
	check(game.ui.name_input.text == "Pip" and player.avatar.hoodie.albedo_color.to_html(false) == "e58f76","Level transition retains adventurer name and hoodie choice")
	print("RESULT: %d passed, %d failed" % [passed,failures.size()])
	game.stop_sounds()
	await frames(8)
	game.queue_free()
	await frames(3)
	DirAccess.remove_absolute("user://lily_qa_combat.cfg")
	quit(0 if failures.is_empty() else 1)
