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

func jump_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = pressed
	Input.parse_input_event(event)

# Aim and press controls only. Never place the player on a destination pad.
func jump_to(target: Vector2) -> void:
	var offset := target-Vector2(player.position.x,player.position.z)
	player.yaw = atan2(-offset.x,-offset.y)
	player.pivot.rotation.y = player.yaw
	Input.action_press("move_forward")
	await frames(maxi(4,roundi((offset.length()-4.0)/player.move_speed*60)+5))
	jump_key(true)
	for i in 50:
		await frames(1)
		if Vector2(player.position.x,player.position.z).distance_to(target) < 0.55:
			Input.action_release("move_forward")
		if i == 2:
			jump_key(false)
	Input.action_release("move_forward")
	await frames(15)

func strike(frog: LilyFrog) -> void:
	for attempt in 4:
		if not frog.alive:
			break
		var target := Vector2(frog.position.x,frog.position.z)
		var offset := target-Vector2(player.position.x,player.position.z)
		player.yaw = atan2(-offset.x,-offset.y)
		player.pivot.rotation.y = player.yaw
		Input.action_press("move_forward")
		await frames(maxi(2,roundi((offset.length()-1.5)/player.move_speed*60)))
		Input.action_release("move_forward")
		await frames(6)
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F
		event.keycode = KEY_F
		event.pressed = true
		Input.parse_input_event(event)
		await frames(32)
		event.pressed = false
		Input.parse_input_event(event)
	check(not frog.alive and game.health == 100 and not game.poisoned,"Route combat defeats frog and heals without teleporting")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_long_routes.cfg"
	DirAccess.remove_absolute(game.profile.storage_path)
	root.add_child(game)
	player = game.player
	for level_index in [0,1]:
		game.show_title()
		game.select_level(level_index)
		game.start_run()
		await frames(12)
		if level_index == 0:
			var perch: StaticBody3D = game.world.secret_perches[0]
			for candidate in game.world.secret_perches:
				if candidate.position.x > perch.position.x:
					perch = candidate
			await jump_to(Vector2(perch.position.x,perch.position.z))
			check(player.is_on_floor() and game.profile.secret_perch and game.falls == 0,"The secret pillar remains reachable from spawn with an ordinary jump")
			game.start_run()
			await frames(12)
		check(game.level.pads.size() == 18,"Level %d has 18 main-route pads" % (level_index+1))
		for index in range(1,game.level.pads.size()):
			var p: Vector3 = game.level.pads[index]
			var frog: LilyFrog = null
			for enemy in game.world.frogs:
				if enemy.pad_index == index:
					frog = enemy
			var target := Vector2(p.x,p.y+(1.1 if frog != null else 0.0))
			await jump_to(target)
			var landed := player.is_on_floor() and Vector2(player.position.x,player.position.z).distance_to(target) < 1.4
			check(landed and game.falls == 0,"Level %d pad %d is reachable with ordinary movement" % [level_index+1,index+1])
			if not landed or game.falls > 0:
				break
			if frog != null:
				await strike(frog)
		var shore: Vector3 = game.level.fireflies[2]
		await jump_to(Vector2(shore.x,shore.z))
		check(game.profile.has_firefly(level_index,2),"Level %d far-shore firefly remains reachable" % (level_index+1))
		await jump_to(Vector2(game.level.flag_position.x,game.level.flag_position.z))
		check(game.state == "won" and game.victories == 1 and game.falls == 0,"Level %d entire extended crossing wins without falls" % (level_index+1))
	print("RESULT: %d passed, %d failed" % [passed,failures.size()])
	game.stop_sounds()
	game.queue_free()
	await frames(3)
	DirAccess.remove_absolute("user://lily_qa_long_routes.cfg")
	quit(0 if failures.is_empty() else 1)
