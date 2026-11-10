extends SceneTree

var game: Node3D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ",description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func steer(fast: bool) -> void:
	var ride: HoverRide = game.player.ride
	var course: RiverRapids = game.world.rapids
	var target := 0.0
	for obstacle in course.hazards:
		if int(obstacle.leg) == ride.leg and float(obstacle.distance)-ride.distance < 32 and float(obstacle.distance)-ride.distance > -9:
			target = -signf(obstacle.lateral)*2.1
	if ride.leg == 2 and ride.distance < 50: target = 2.6
	if fast and ride.leg == 6 and ride.distance > 25 and ride.distance < 95: target = 1.3
	if ride.leg == 13 and ride.distance > 10 and ride.distance < 65: target = -2.6
	if ride.leg == 4 and ride.distance > course.path_length(4)-30: target = -3.0 if fast else 3.0
	if ride.leg == 5: target = -8.0 if fast else 8.0
	var axis := clampf(((target-ride.lateral)*3.5-ride.lateral_velocity*0.8)/7.5,-1,1)
	Input.action_press("move_right",maxf(0,axis))
	Input.action_press("move_left",maxf(0,-axis))
	Input.action_press("move_forward")

func traverse(fast: bool, boost_jumps := false) -> float:
	game.start_run()
	var maximum := 0.0
	var airborne := 0
	var last_leg := -1
	for i in 10000:
		steer(fast)
		if boost_jumps:
			var r: HoverRide = game.player.ride
			if game.world.rapids.legs[r.leg].kind == "gap" or (r.leg in [0,9,11] and r.distance > game.world.rapids.path_length(r.leg)-45):
				Input.action_press("boost")
			else: Input.action_release("boost")
		await frames(1)
		var ride: HoverRide = game.player.ride
		maximum = maxf(maximum,ride.speed)
		if not ride.attached: airborne += 1
		if ride.leg != last_leg:
			print("LEG ",ride.leg," time=",game.attempt_seconds," lateral=",ride.lateral," position=",game.player.position," speed=",ride.speed)
			last_leg = ride.leg
		if game.state == "won" or game.falls > 0: break
	game.player.clear_input()
	if game.falls > 0: print("FAILURE SNAPSHOT ",game.debug_snapshot()," reason=",game.player.ride.reason)
	check(game.state == "won" and game.falls == 0,"%s route finishes without a fall" % ("Fast" if fast else "Wide"))
	check(game.player.ride.loop_inverted,"Rider physically travels upside down through the loop")
	check(game.player.ride.spiral_completed,"Rider completes the full rising spiral")
	check(game.player.launch_count == 3 and airborne > 90,"Three gap launches use airborne trajectories")
	check(maximum > 24 and maximum <= 34.01,"Board cruises much faster than walking with bounded speed")
	check(game.player.ride.route_taken == ("fast" if fast else "wide"),"Lane choice selects the intended separated branch")
	print("ROUTE RESULT ",fast," seconds=",game.attempt_seconds," peak=",maximum)
	return game.attempt_seconds

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_hoverboard.cfg"
	if FileAccess.file_exists(game.profile.storage_path): DirAccess.remove_absolute(game.profile.storage_path)
	root.add_child(game)
	game.select_level(4)
	check(game.player.ride.board.visible,"Hoverboard is equipped only in River Rapids")
	check(game.player.camera.get_parent() == game.player and game.player.camera.top_level,"Board camera is independent of the walking SpringArm")
	check(game.world.rapids.total_distance > 1800,"Course is substantially longer than the original 290 m")
	var course: RiverRapids = game.world.rapids
	var clean_branches := true
	for a in course.legs[6].path.frames:
		for b in course.legs[6].shortcut.frames:
			if Vector3(a.p).distance_to(b.p) < (float(a.width)+float(b.width))*0.5+2: clean_branches = false
	check(clean_branches,"Split branches remain visibly separated with no overlapping decks")
	var continuous := true
	for i in range(course.legs.size()-1):
		if course.legs[i].kind in ["fork","split"]: continue
		var end: Dictionary = course.frame(i,course.path_length(i))
		var start: Dictionary = course.frame(i+1,0)
		if Vector3(end.p).distance_to(start.p) > 0.001: continuous = false
	check(continuous,"Loop, spiral, ramps, and ordinary track join at matching endpoints")
	var wide := await traverse(false)
	var fast := await traverse(true)
	check(game.profile.firefly_masks[4] == 7,"All three optional fireflies can be collected while riding")
	check(fast < wide,"Narrow branch rewards skill with a faster finish")
	check(fast > 65,"Fast full run has substantially more sustained play")
	var restored := LilyProfile.new()
	restored.storage_path = game.profile.storage_path
	restored.load_progress()
	check(is_equal_approx(restored.rapids_time,fast),"New-course personal best persists separately from walking records")
	var boosted_time := await traverse(true,true)
	check(boosted_time < fast,"Well-timed boosts clear every gap and improve the finish time")
	game.start_run()
	Input.action_press("move_forward")
	var hopped := false
	for i in 500:
		if game.player.ride.distance > 85 and not hopped:
			Input.action_press("jump")
			hopped = true
		await frames(1)
		if game.player.ride.distance > 115 or game.falls > 0: break
	check(game.falls == 0 and game.player.ride.distance > 115 and game.player.ride.attached,"A timed hop physically clears a coral block and lands")
	check(game.player.jump_count == 1,"Holding hop does not cause automatic repeated jumps")
	game.start_run()
	Input.action_press("move_back")
	for i in 1200:
		steer(false)
		await frames(1)
		if game.falls > 0: break
	check(game.falls > 0 and "wave caught" in game.ui.toast.text,"Staying on the brake lets the course-following wave catch the rider")
	game.start_run()
	Input.action_press("move_forward")
	Input.action_press("boost")
	await frames(110)
	check(game.player.ride.energy < 30 and game.player.ride.speed > 30,"Boost spends energy and produces a real speed increase")
	Input.action_release("boost")
	game.pause()
	var p: Vector3 = game.player.position
	var wave: float = game.world.rapids.wave_progress
	var energy: float = game.player.ride.energy
	await frames(60)
	check(game.player.position == p and game.world.rapids.wave_progress == wave and game.player.ride.energy == energy,"Pause freezes rider, wave, and boost energy")
	game.resume()
	Input.action_press("move_back")
	await frames(60)
	check(game.player.ride.speed < 15,"Braking lowers speed substantially")
	game.start_run()
	Input.action_press("move_right")
	await frames(180)
	check(game.falls > 0,"Steering off an edge causes a real fall and retry")
	game.start_run()
	# The centre line now contains readable obstacles; doing nothing cannot win.
	await frames(400)
	check(game.falls > 0,"Coral blocks require steering or jumping")
	game.show_title()
	game.select_level(0)
	game.start_run()
	await frames(15)
	Input.action_press("move_forward")
	await frames(30)
	check(not game.player.ride.board.visible and game.player.camera.get_parent() == game.player.arm and absf(game.player.velocity.z+5.4) < 0.01,"Original levels retain the walking controller and no board")
	game.player.clear_input()
	game.queue_free()
	await frames(2)
	print("RESULT: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
