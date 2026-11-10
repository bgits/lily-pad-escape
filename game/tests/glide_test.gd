extends SceneTree

var game: Node3D
var checks := 0
var failures := 0
const SAVE := "user://lily_qa_glide.cfg"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ",message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func ride(boosted: bool) -> float:
	game.start_run()
	if boosted:
		Input.action_press("move_forward")
		Input.action_press("boost")
	var peak := 0.0
	var airborne := 0
	for i in 6000:
		await frames(1)
		peak = maxf(peak,game.player.ride.speed)
		if not game.player.ride.attached: airborne += 1
		if game.state == "won" or game.falls > 0: break
	if game.falls > 0: print("FAILED SNAPSHOT ",game.debug_snapshot()," reason ",game.player.ride.reason)
	check(game.state == "won" and game.falls == 0,"Beginner course finishes without precision steering%s" % (" at boosted speed" if boosted else " at automatic cruise"))
	check(game.player.ride.loop_inverted and game.player.ride.spiral_completed,"Beginner ride includes a complete loop and gentle spiral")
	check(game.player.launch_count == 1 and airborne > 15,"Short beginner gap has a real airborne launch and landing")
	check(peak > 18 and peak <= 30.01,"Beginner board stays fast with a gentler speed limit")
	print("GLIDE RUN boosted=",boosted," time=",game.attempt_seconds," distance=",game.world.rapids.total_distance," peak=",peak)
	return game.attempt_seconds

func run() -> void:
	# Start from the actual previous release's native save format.
	var old := ConfigFile.new()
	old.set_value("collection","fireflies",[1,2,3,7])
	old.set_value("rapids","record",{"version":2,"distance":2141.3743,"time":84.23})
	old.set_value("achievements","secret_perch",true)
	old.set_value("customization","name","Glider")
	old.save(SAVE)
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = SAVE
	root.add_child(game)
	check(game.LEVELS.size() == 5 and game.ui.level_buttons.size() == 5,"Five courses are selectable")
	check(game.profile.firefly_masks == [1,2,3,0,7],"Old fourth-level collectibles move to Level 5, leaving Level 4 uncollected")
	check(is_equal_approx(game.profile.rapids_time,84.23) and game.profile.glide_time == 0,"Existing hard-course time survives and beginner starts a separate record")
	check(game.profile.secret_perch and game.profile.player_name == "Glider","Migration preserves the achievement and character name")
	game.select_level(3)
	check(game.level.rapids_beginner and game.level.title == "River glide","Level 4 selects the introductory hoverboard course")
	check(game.world.rapids.hazards.size() == 2 and game.world.rapids.wave_speed < 15 and game.world.rapids.start_grace == 8,"Beginner course has fewer hazards and much more breathing room")
	var widths_ok := true
	for i in game.world.rapids.legs.size():
		for f in game.world.rapids.legs[i].path.frames:
			if f.width < 12: widths_ok = false
	check(widths_ok,"Every beginner track section is at least twelve metres wide")
	var cruise := await ride(false)
	check(cruise > 35 and cruise < 70,"Beginner crossing is substantially shorter than the hard course")
	check(game.profile.firefly_masks == [1,2,3,7,7],"Three beginner fireflies are reachable while riding without disturbing old collections")
	check(game.ui.next_button.visible and "River rapids" in game.ui.next_button.text,"Beginner finish offers Next level to the harder course")
	game.next_level()
	check(game.level_index == 4 and not game.level.rapids_beginner and game.world.rapids.legs.size() == 14 and game.world.rapids.hazards.size() == 11,"Level 5 preserves the full hard course")
	check(game.profile.rapids_time == 84.23 and game.profile.glide_time == cruise,"Easy finish never replaces the existing hard personal best")
	game.show_title()
	game.select_level(3)
	var boosted := await ride(true)
	check(boosted < cruise,"Throttle and boost still reward a faster beginner run")
	game.start_run()
	Input.action_press("move_right")
	await frames(330)
	check(game.falls == 0 and game.player.ride.attached and game.player.ride.lateral > 5,"Beginner edge rails catch sustained steering mistakes")
	game.start_run()
	# Deliberately steer into the off-centre obstacle to test forgiving contact.
	for i in 750:
		var r: HoverRide = game.player.ride
		var axis := clampf(((4-r.lateral)*3.5-r.lateral_velocity*0.8)/6,-1,1)
		Input.action_press("move_right",maxf(0,axis))
		Input.action_press("move_left",maxf(0,-axis))
		await frames(1)
		if r.distance > 142 or game.falls > 0: break
	check(game.falls == 0 and game.player.ride.distance > 142,"Beginner coral contact slows and nudges the board instead of restarting")
	game.pause()
	var position: Vector3 = game.player.position
	var wave: float = game.world.rapids.wave_progress
	await frames(60)
	check(game.player.position == position and game.world.rapids.wave_progress == wave,"Beginner pause freezes the rider and wave")
	var restored := LilyProfile.new()
	restored.storage_path = SAVE
	restored.load_progress()
	check(restored.firefly_masks == [1,2,3,7,7] and is_equal_approx(restored.glide_time,boosted) and is_equal_approx(restored.rapids_time,84.23),"Both course records and migrated collections survive native reload")
	check(LilyProfile.sanitize_fireflies([1,2,3,0,7]) == [1,2,3,0,7],"Five-slot saves do not migrate a second time")
	game.player.clear_input()
	game.queue_free()
	await frames(2)
	print("GLIDE RESULT: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
