extends SceneTree

var game: Node3D
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.storage_path = "user://lily_qa_music.cfg"
	root.add_child(game)
	check(not game.level_music.playing, "Title screen starts without level music")
	check(game.level_music.stream is AudioStreamMP3 and game.level_music.stream.loop, "Supplied track is configured to loop")
	game.start_run()
	check(game.level_music.playing and not game.level_music.stream_paused and game.level_music.stream == game.level_music_tracks[0], "First level starts its own track")
	game.pause()
	check(game.level_music.stream_paused, "Pause freezes the track")
	game.open_customization()
	game.close_customization()
	check(game.level_music.stream_paused, "Wardrobe opened from pause keeps the track paused")
	game.resume()
	check(game.level_music.playing and not game.level_music.stream_paused, "Resume continues the track")
	game.ui.toggle_mute()
	check(AudioServer.is_bus_mute(0), "Sound switch mutes music on the master bus")
	game.ui.toggle_mute()
	check(not AudioServer.is_bus_mute(0), "Sound switch restores audio")
	game.win()
	check(not game.level_music.playing, "Victory stops the track")
	game.next_level()
	check(game.level_index == 1 and game.level_music.playing and game.level_music.stream == game.level_music_tracks[1], "Next level plays its own background track")
	check(game.level_music.stream.loop, "Second-level track loops")
	game.pause()
	check(game.level_music.stream_paused, "Second-level music pauses")
	game.resume()
	check(game.level_music.playing and not game.level_music.stream_paused, "Second-level music resumes")
	game.show_title()
	game.select_level(2)
	game.start_run()
	check(game.level_index == 2 and game.level_music.playing and game.level_music.stream == game.level_music_tracks[2], "Third level plays its own background track")
	check(game.level_music.stream.loop, "Third-level track loops")
	game.pause()
	check(game.level_music.stream_paused, "Third-level music pauses")
	game.resume()
	check(game.level_music.playing and not game.level_music.stream_paused, "Third-level music resumes")
	game.show_title()
	game.select_level(0)
	check(not game.level_music.playing, "Selecting level one does not play music on the title")
	game.start_run()
	check(game.level_music.playing, "Replaying level one starts music again")
	game.show_title()
	check(not game.level_music.playing, "Returning home stops the track")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://lily_qa_music.cfg")
	print("MUSIC RESULT: ", failures, " failed")
	quit(1 if failures else 0)
