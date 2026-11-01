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
		print("FAIL: ",message)

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_swing_facing.cfg"
	DirAccess.remove_absolute(game.profile.storage_path)
	root.add_child(game)
	player = game.player
	game.select_level(1)
	for direction in [KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		game.start_run()
		await frames(8)
		key(direction)
		await frames(12)
		key(direction,false)
		await frames(12)
		var facing := player.avatar.rotation.y
		var attack := Vector3.FORWARD.rotated(Vector3.UP,facing)
		check(absf(angle_difference(facing,player.yaw)) > 1,"Movement turns the character away from the camera for key %d" % direction)
		if direction == KEY_LEFT:
			click(true)
		else:
			key(KEY_F)
		await frames(1)
		check(absf(angle_difference(player.avatar.rotation.y,facing)) < 0.0001,"Swing start preserves character facing for key %d" % direction)
		check(player.attack_direction.dot(attack)>0.9999,"Hit direction matches character facing for key %d" % direction)
		key(KEY_F,false)
		click(false)
		# Orbiting the camera during wind-up must not redirect this swing.
		player.yaw = -0.8
		player.pivot.rotation.y = player.yaw
		await frames(10)
		check(absf(angle_difference(player.avatar.rotation.y,facing)) < 0.0001 and player.attack_direction.dot(attack)>0.9999,"Camera orbit does not redirect the impact for key %d" % direction)
		await frames(22)
		check(absf(angle_difference(player.avatar.rotation.y,facing)) < 0.0001,"Swing recovery keeps the original facing for key %d" % direction)
	game.start_run()
	await frames(8)
	var frog: LilyFrog = game.world.frogs[0]
	# Start beyond the frog, then turn back toward it using the real movement key.
	player.respawn(frog.position+Vector3(0,0.05,-1.8))
	await frames(8)
	key(KEY_DOWN)
	await frames(12)
	key(KEY_DOWN,false)
	await frames(10)
	var back_facing := player.avatar.rotation.y
	check(frog.alive and game.poisoned and player.position.z < frog.position.z,"A live poisoning frog is behind the camera after turning back toward it")
	key(KEY_F)
	await frames(10)
	key(KEY_F,false)
	check(not frog.alive and game.hit_count == 1,"Backward-facing swing hits the frog behind the camera")
	check(absf(angle_difference(player.avatar.rotation.y,back_facing)) < 0.0001,"Successful backward hit does not rotate the character")
	check(game.health == 100 and not game.poisoned,"Backward hit still restores full health and cures poison")
	await frames(24)
	key(KEY_RIGHT)
	await frames(12)
	key(KEY_RIGHT,false)
	check(absf(angle_difference(player.avatar.rotation.y,back_facing)) > 0.5,"Movement can turn the character normally after recovery")
	print("SWING FACING RESULT: %d passed, %d failed" % [passed,failures.size()])
	game.stop_sounds()
	game.queue_free()
	await frames(3)
	DirAccess.remove_absolute("user://lily_qa_swing_facing.cfg")
	quit(0 if failures.is_empty() else 1)
