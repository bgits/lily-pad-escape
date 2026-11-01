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

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_skill_route.cfg"
	DirAccess.remove_absolute(game.profile.storage_path)
	root.add_child(game)
	player = game.player
	game.select_level(2)
	game.start_run()
	await frames(12)
	check(game.world.bypass_pads.size() == 6,"Lucky Lagoon has six permanent precision platforms")
	check(not game.ui.objective_label.visible,"HUD does not require completing yellow pads")
	# Worst-case fixture: both random supports have already sunk. No RNG override
	# or rescue is used during the crossing, and falling would reset this fixture.
	for pad in game.world.chance_pads:
		pad.resolved = true
		pad.collapse()
	await frames(36)
	check(game.world.chance_pads.all(func(pad): return pad.collapsed and not pad.visible and pad.collision_layer == 0),"Both yellow pads are absent before the first jump")
	var route: Array[Vector2] = []
	for p in game.level.bypass_pads.slice(0,3):
		route.append(Vector2(p.x,p.y))
	var rest: Vector3 = game.level.pads[2]
	route.append(Vector2(rest.x,rest.y))
	for p in game.level.bypass_pads.slice(3,6):
		route.append(Vector2(p.x,p.y))
	rest = game.level.pads[4]
	route.append(Vector2(rest.x,rest.y))
	route.append(Vector2(game.level.flag_position.x,game.level.flag_position.z))
	for i in route.size():
		await jump_to(route[i])
		var near_target := Vector2(player.position.x,player.position.z).distance_to(route[i]) < 1.2
		check(player.is_on_floor() and near_target and game.falls == 0,"Input-driven landing %d reaches its solid destination with no falls" % (i+1))
		if not near_target or game.falls > 0:
			break
		if i == 1:
			game.pause()
			var before := player.position
			await frames(30)
			check(player.position.is_equal_approx(before),"A small bypass pad supports a paused player")
			game.resume()
	check(game.state == "won" and game.victories == 1,"The entire nine-jump skill route wins with both yellow pads missing")
	check(game.chance_rolls == 0 and game.falls == 0,"Winning the skill route needs no favorable rolls or retries")
	check(game.world.chance_pads.all(func(pad): return pad.collapsed),"Neither yellow support was restored during the winning run")
	check(game.health == 100 and not game.poisoned,"The new route does not introduce poison or health damage")
	game.start_run()
	await frames(10)
	check(game.world.bypass_pads.all(func(pad): return pad.collision_layer == 1),"Restart keeps every bypass platform permanently solid")
	check(game.world.chance_pads.all(func(pad): return not pad.resolved and not pad.collapsed),"Restart restores the optional random shortcuts")
	game.show_title()
	game.select_level(0)
	check(game.world.bypass_pads.is_empty(),"Sunlit Lagoon does not gain unintended bypass platforms")
	game.select_level(1)
	check(game.world.bypass_pads.is_empty(),"Frog River does not gain unintended bypass platforms")
	print("RESULT: %d passed, %d failed" % [passed,failures.size()])
	game.stop_sounds()
	await frames(8)
	game.queue_free()
	await frames(3)
	DirAccess.remove_absolute("user://lily_qa_skill_route.cfg")
	quit(0 if failures.is_empty() else 1)
