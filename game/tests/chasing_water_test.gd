extends SceneTree

var game: Node3D
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_chasing_water.cfg"
	root.add_child(game)
	check(not game.tide.visible,"Title hides the chasing wave")
	game.start_run()
	await frames(60)
	check(game.tide.visible and game.tide.front_z == ChasingWater.START_Z,"A fresh attempt gives a head start")
	game.pause()
	var grace: float = game.tide.grace
	await frames(60)
	check(game.tide.grace == grace,"Pause freezes the head-start countdown")
	game.open_customization()
	await frames(20)
	check(game.tide.grace == grace,"The wardrobe keeps the wave frozen")
	game.close_customization()
	game.resume()
	await frames(360)
	check(game.tide.front_z < ChasingWater.START_Z,"The wave advances after the head start")
	game.pause()
	var front: float = game.tide.front_z
	await frames(60)
	check(game.tide.front_z == front,"Pause freezes an advancing wave")
	game.resume()
	# Stay on the starting pad: being on land must not defeat the chase.
	for i in 900:
		await frames(1)
		if game.state == "splash":
			break
	check(game.state == "splash" and game.falls == 1,"The advancing water catches a stationary player on a pad")
	await frames(65)
	check(game.state == "playing" and game.tide.grace > 4 and game.tide.front_z == ChasingWater.START_Z,"Retry restores a safe head start")
	game.show_title()
	game.select_level(1)
	game.start_run()
	await frames(5)
	for frog in game.world.frogs.slice(0,2):
		frog.defeat()
	game.hit_count = 2
	check(game.world.frogs_remaining() == 4,"Fixture clears two frogs before being caught")
	game.tide.grace = 0
	game.tide.front_z = game.player.position.z - 0.1
	await frames(3)
	check(game.state == "splash","Chasing water also catches the player in Frog River")
	await frames(65)
	check(game.world.frogs_remaining() == 6 and game.hit_count == 0,"Death restores both defeated frogs and resets combat progress")
	check(game.health == 100 and not game.poisoned,"Retry restores full health")
	game.show_title()
	game.select_level(0)
	game.start_run()
	game.win()
	front = game.tide.front_z
	await frames(60)
	check(not game.tide.visible and game.tide.front_z == front,"Victory ends the chase")
	game.show_title()
	check(not game.tide.visible,"Returning home hides the wave")
	# A running player must not leave the wave off in the distance.
	game.tide.reset()
	game.tide.grace = 0
	game.tide.speed = 1.8
	var runner := Vector3.ZERO
	var biggest_step := 0.0
	for i in 1200:
		runner.z -= 5.4/60.0
		var previous: float = game.tide.front_z
		game.tide.advance(1.0/60.0,runner)
		biggest_step = maxf(biggest_step,previous-game.tide.front_z)
	var gap: float = game.tide.front_z-runner.z
	check(gap > 6 and gap < 22,"The wave keeps a visible, escapable gap behind a running player")
	check(biggest_step < 0.12,"Catch-up advances smoothly without teleporting")
	game.tide.update_rear_view(runner)
	check(game.tide.rear_view.world_3d == game.get_world_3d(),"Rear view renders the actual game world")
	check(game.tide.rear_camera.is_position_in_frustum(Vector3(runner.x,2.6,game.tide.front_z)),"The pursuing crest is inside the rear camera view")
	game.level_music.stop()
	game.stop_sounds()
	game.queue_free()
	await frames(3)
	DirAccess.remove_absolute("user://lily_qa_chasing_water.cfg")
	print("CHASE RESULT: ", failures, " failed")
	quit(1 if failures else 0)
