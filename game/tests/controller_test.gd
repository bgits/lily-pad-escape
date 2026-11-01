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
		print("SNAPSHOT: ",game.debug_snapshot(), " coyote=",player.coyote," buffer=",player.buffered)
		push_error("FAIL: " + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func jump(pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func fresh() -> void:
	game.start_run()
	await frames(8)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_controller.cfg"
	DirAccess.remove_absolute(game.profile.storage_path)
	root.add_child(game)
	player = game.player
	await fresh()
	check(player.is_on_floor(),"Spawn settles on visible starting surface")
	check(absf(player.position.y - 0.6) < 0.02,"Feet match platform height")
	Input.action_press("move_forward")
	await frames(20)
	var straight := Vector2(player.velocity.x,player.velocity.z).length()
	await fresh()
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await frames(20)
	var diagonal := Vector2(player.velocity.x,player.velocity.z).length()
	check(absf(straight-diagonal) < 0.01 and absf(straight-5.4) < 0.01,"Diagonal speed equals straight-line speed")
	await fresh()
	jump()
	await frames(60)
	check(player.jump_count == 1 and player.is_on_floor(),"Holding jump produces one jump and returns to ground")
	jump(true,true)
	await frames(15)
	check(player.jump_count == 1,"Keyboard autorepeat does not trigger another jump")
	jump(false)
	await fresh()
	player.position = Vector3(0,0.62,-2.35)
	Input.action_press("move_forward")
	var off_edge := false
	for i in 24:
		await frames(1)
		if not player.is_on_floor():
			off_edge = true
			break
	await frames(2)
	jump()
	await frames(2)
	check(off_edge and player.jump_count == 1 and player.velocity.y > 0,"Coyote jump works shortly after leaving a real pad edge")
	jump(false)
	await fresh()
	player.position = Vector3(0,0.62,-2.35)
	Input.action_press("move_forward")
	for i in 24:
		await frames(1)
		if not player.is_on_floor():
			break
	await frames(8)
	jump()
	await frames(2)
	check(player.jump_count == 0,"Expired coyote time cannot create a midair jump")
	jump(false)
	await fresh()
	jump()
	await frames(2)
	jump(false)
	for i in 60:
		await frames(1)
		if player.velocity.y < -2 and player.position.y < 1.05:
			break
	jump()
	await frames(9)
	check(player.jump_count == 2 and player.velocity.y > 0,"Buffered press just before landing produces one new jump")
	jump(false)
	await fresh()
	jump()
	await frames(12)
	game.pause()
	var paused_position := player.position
	var paused_velocity := player.velocity
	await frames(20)
	check(game.state == "paused" and player.position.is_equal_approx(paused_position),"Pause freezes the character in midair")
	game.resume()
	await frames(2)
	check(not player.position.is_equal_approx(paused_position) and player.velocity.y < paused_velocity.y,"Resume continues the frozen jump")
	jump(false)
	await fresh()
	for retry in 3:
		player.position = Vector3(9,-0.3,0)
		await frames(2)
		var fall_count: int = game.falls
		await frames(20)
		check(game.state == "splash" and game.falls == fall_count,"One splash event per fall %d" % (retry+1))
		await frames(44)
		check(game.state == "playing" and player.position.distance_to(game.level.spawn) < 0.12,"Quick respawn returns to start %d" % (retry+1))
	check(player.velocity.length() < 0.01 and player.buffered == 0.0,"Respawn clears velocity and buffered input")
	# These raycasts check actual rendered platform geometry, including its missing wedge.
	var space := player.get_world_3d().direct_space_state
	var center_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,-1,0),1))
	var notch_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(1.9,2,0.115),Vector3(1.9,-1,0.115),1))
	check(not center_hit.is_empty() and notch_hit.is_empty(),"Pad collider matches the visible notched surface")
	# A real obstacle in the camera sweep verifies spring-arm contraction.
	var obstacle := StaticBody3D.new()
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,5,0.4)
	shape_node.shape = box
	obstacle.add_child(shape_node)
	obstacle.position = Vector3(0,2.5,3.6)
	game.add_child(obstacle)
	await frames(5)
	check(player.arm.get_hit_length() < 4.0 and player.arm.get_hit_length() > 0.1,"Camera retracts before an obstacle and excludes the player")
	check(player.camera.global_position.y > game.level.water_height,"Camera stays above water")
	obstacle.queue_free()
	game.furthest_pad = 8
	game.victories = 1
	await fresh()
	check(game.furthest_pad == 0 and game.victories == 0 and game.falls == 0 and player.jump_count == 0,"Restart resets all session progress")
	print("RESULT: %d passed, %d failed" % [passed,failures.size()])
	DirAccess.remove_absolute("user://lily_qa_controller.cfg")
	quit(0 if failures.is_empty() else 1)
