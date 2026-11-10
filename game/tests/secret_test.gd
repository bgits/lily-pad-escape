extends SceneTree

const TEST_SAVE := "user://secret_perch_test.cfg"
var game: Node3D
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
		push_error("FAIL: "+message+" "+str(game.debug_snapshot()))

func new_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = TEST_SAVE
	game.tide_enabled = false
	root.add_child(game)
	await frames(3)

func nearest_perch() -> Vector3:
	var best := Vector3(-100,0,0)
	for perch in game.world.secret_perches:
		if perch.position.x > best.x:
			best = Vector3(perch.position.x,perch.get_meta("top"),perch.position.z)
	return best

func run() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	await new_game()
	check(not game.profile.secret_perch and not game.ui.secret_equip.visible,"New profile hides the secret reward")
	var original: Color = game.player.avatar.hoodie.albedo_color
	game.ui.select_color(3)
	check(game.player.avatar.hoodie.albedo_color == original,"Locked reward cannot be equipped")
	game.start_run()
	await frames(15)
	check(not game.profile.secret_perch,"Ordinary start-pad contact does not award a badge")
	check(game.world.secret_perches.size() == 5,"Existing five left-hand rocks have dedicated collision")
	var perch := nearest_perch()
	print("NEAREST SECRET PERCH: ",perch)
	game.player.respawn(perch+Vector3.UP*4)
	game.player.velocity.y = 8
	await frames(10)
	check(not game.profile.secret_perch,"Passing above a pillar without landing does not unlock")
	game.player.respawn(perch+Vector3(0.9,-0.5,0))
	Input.action_press("move_left")
	await frames(10)
	game.player.clear_input()
	check(not game.profile.secret_perch,"Touching a pillar side does not unlock")
	game.player.respawn(perch+Vector3.UP*1.4)
	await frames(45)
	check(game.profile.secret_perch and game.player.is_on_floor(),"Actual pillar-top landing earns Secret Perch")
	check(game.secret_unlock_count == 1 and game.secret_saved,"One award is saved successfully")
	check(game.ui.secret_popup.visible and game.ui.secret_equip.visible,"Badge celebration and wardrobe reward become available")
	check(game.player.avatar.hoodie.albedo_color == LilyUI.MOONFLOWER,"Moonflower hoodie equips immediately")
	check(game.victories == 0 and game.furthest_pad == 0,"Secret badge does not complete the level or advance route progress")
	await frames(60)
	check(game.player.is_on_floor() and absf(game.player.position.y-perch.y)<0.03 and game.falls == 0,"Pillar remains a stable place to stand")
	check(game.secret_unlock_count == 1,"Standing on the pillar cannot repeat the award")
	game.pause()
	var remaining: float = game.secret_notice_time
	await frames(12)
	check(game.secret_notice_time == remaining and not game.ui.secret_popup.visible,"Pause freezes and hides the celebration")
	game.resume()
	await frames(2)
	check(game.ui.secret_popup.visible,"Resume restores the celebration")
	game.start_run()
	await frames(10)
	check(game.profile.secret_perch and not game.ui.secret_popup.visible,"Restart keeps the badge without replaying its celebration")
	game.player.respawn(perch+Vector3.UP*1.4)
	await frames(45)
	check(game.secret_unlock_count == 1 and game.secret_notice_time == 0,"Re-landing cannot award the badge a second time")
	game.player.respawn(Vector3(0,-1,8))
	await frames(75)
	check(game.state == "playing" and game.profile.secret_perch,"Water retry retains the unlocked reward")
	for index in [1,2]:
		game.show_title()
		game.select_level(index)
		game.start_run()
		game.player.respawn(nearest_perch()+Vector3.UP*1.4)
		await frames(45)
		check(game.player.is_on_floor() and game.profile.secret_perch and game.secret_unlock_count == 1,"Level %d also supports its left pillar and preserves the badge" % (index+1))
	game.show_title()
	game.ui.select_color(1)
	check(game.player.avatar.hoodie.albedo_color == Color("e58f76"),"Original hoodie colors remain selectable")
	game.ui.select_color(3)
	check(game.player.avatar.hoodie.albedo_color == LilyUI.MOONFLOWER,"Unlocked hoodie can be re-equipped from the title")
	game.queue_free()
	await frames(4)
	await new_game()
	check(game.profile.secret_perch and game.secret_unlock_count == 0 and game.ui.secret_equip.visible,"A new game instance reloads the earned badge without another award")
	game.ui.select_color(3)
	check(game.player.avatar.hoodie.albedo_color == LilyUI.MOONFLOWER,"Reloaded reward remains wearable")
	var unavailable := LilyProfile.new()
	unavailable.storage_path = "user://missing-secret-test-directory/achievements.cfg"
	check(not unavailable.unlock_secret() and unavailable.secret_perch,"Unavailable storage still grants the reward for this session")
	DirAccess.remove_absolute(TEST_SAVE)
	print("SECRET RESULT: ",passed," passed; ",failures.size()," failed")
	quit(1 if not failures.is_empty() else 0)
