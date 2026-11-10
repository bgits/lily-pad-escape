extends SceneTree

var hud: LilyDuelHud
var passed := 0
var failures: Array[String] = []
var fired := {"resume": 0, "rematch": 0, "exit": 0}

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message + " " + str(hud.debug_snapshot()))

func buttons_under(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		buttons_under(child, out)

func run() -> void:
	hud = LilyDuelHud.new()
	root.add_child(hud)
	hud.resume_requested.connect(func(): fired["resume"] += 1)
	hud.rematch_requested.connect(func(): fired["rematch"] += 1)
	hud.exit_requested.connect(func(): fired["exit"] += 1)
	await frames(4)
	var s := hud.debug_snapshot()
	check(not s["pause_visible"] and not s["result_visible"] and s["toast"] == "" and s["countdown"] == "", "Overlays start hidden")
	check(s["poison_visible"] == [false, false] and s["queen"] == -1, "No poison or queen marker at start")

	# Clock uses ceil: 3:00 at the start, 0:01 during the last second.
	hud.set_time(102.4, "dusk")
	s = hud.debug_snapshot()
	check(s["clock"] == "1:43" and s["phase"] == "DUSK", "102.4 s dusk reads 1:43 DUSK")
	hud.set_time(180.0, "countdown")
	check(hud.debug_snapshot()["clock"] == "3:00" and hud.debug_snapshot()["phase"] == "GET READY", "180 s reads 3:00 GET READY")
	hud.set_time(0.0, "flood")
	check(hud.debug_snapshot()["clock"] == "0:00", "0 s flood reads 0:00")
	hud.set_time(0.4, "flood")
	check(hud.debug_snapshot()["clock"] == "0:01", "0.4 s left reads 0:01")
	hud.set_time(9.2, "flood")
	check(hud.debug_snapshot()["clock"] == "0:10" and hud.debug_snapshot()["phase"] == "THE FLOOD", "9.2 s flood reads 0:10 THE FLOOD")
	hud.set_time(75.0, "midnight")
	check(hud.debug_snapshot()["phase"] == "MIDNIGHT" and hud.debug_snapshot()["clock"] == "1:15", "Midnight phase name")
	hud.set_time(0.0, "sudden_death")
	check(hud.debug_snapshot()["clock"] == "—" and hud.debug_snapshot()["phase"] == "SUDDEN DEATH", "Sudden death shows a dash")
	hud.set_time(0.0, "over")
	check(hud.debug_snapshot()["phase"] == "FINAL", "Over phase reads FINAL")
	check(hud.clock_label.get_theme_color("font_color") == LilyDuelHud.CREAM, "Clock is cream outside the flood")
	hud.set_time(30.0, "flood")
	check(hud.clock_label.get_theme_color("font_color") == LilyDuelHud.CREAM, "Clock is cream early in the flood")
	hud.set_time(10.0, "flood")
	check(hud.clock_label.get_theme_color("font_color") == LilyDuelHud.WARN, "Clock warns at 10 s of flood")

	hud.set_scores([3, 11], [2, 0])
	s = hud.debug_snapshot()
	check(s["banked"] == [3, 11] and s["carried"] == [2, 0], "Scores appear in the snapshot")
	check(hud.banked_labels[0].text == "3" and hud.banked_labels[1].text == "11", "Banked labels show the numbers")
	check(hud.carried_labels[0].text == "carrying 2" and hud.carried_labels[1].modulate.a < 1.0, "Carrying line shown, dimmed at zero")

	hud.set_health(1, 40.0, true)
	check(hud.debug_snapshot()["poison_visible"] == [false, true], "Only P2 shows poison")
	check(is_equal_approx(hud.health_bars[1].value, 40.0), "P2 health bar at 40")
	hud.set_health(1, 100.0, false)
	check(hud.debug_snapshot()["poison_visible"] == [false, false], "Poison hides when cured")

	hud.set_queen(0)
	check(hud.debug_snapshot()["queen"] == 0 and hud.queen_labels[0].visible and not hud.queen_labels[1].visible, "Queen marker on P1")
	hud.set_queen(1)
	check(hud.debug_snapshot()["queen"] == 1 and not hud.queen_labels[0].visible and hud.queen_labels[1].visible, "Queen marker on P2")
	hud.set_queen(-1)
	check(hud.debug_snapshot()["queen"] == -1 and not hud.queen_labels[0].visible and not hud.queen_labels[1].visible, "Queen marker cleared")

	hud.show_toast("Queen captured!", 1.5)
	check(hud.debug_snapshot()["toast"] == "Queen captured!", "Toast appears")
	hud.advance(1.0)
	check(hud.debug_snapshot()["toast"] == "Queen captured!", "Toast persists before its duration")
	hud.show_toast("Flood!", 1.0)
	hud.advance(0.6)
	check(hud.debug_snapshot()["toast"] == "Flood!", "A new toast replaces the old one and restarts the timer")
	hud.advance(0.6)
	check(hud.debug_snapshot()["toast"] == "", "Toast disappears after its duration")

	hud.show_countdown("3")
	check(hud.debug_snapshot()["countdown"] == "3", "Countdown shows 3")
	hud.show_countdown("")
	check(hud.debug_snapshot()["countdown"] == "", "Empty countdown hides it")

	hud.show_pause(true)
	check(hud.debug_snapshot()["pause_visible"], "Pause overlay shows")
	hud.show_pause(false)
	check(not hud.debug_snapshot()["pause_visible"], "Pause overlay hides")

	hud.show_result("P1 wins!", "14 to 9 fireflies")
	s = hud.debug_snapshot()
	check(s["result_visible"] and s["result_title"] == "P1 wins!" and s["result_detail"] == "14 to 9 fireflies", "Result overlay shows title and detail")
	hud.hide_result()
	check(not hud.debug_snapshot()["result_visible"], "Result overlay hides")

	hud.resume_button.pressed.emit()
	check(fired["resume"] == 1, "Resume button emits resume_requested")
	hud.pause_rematch_button.pressed.emit()
	hud.result_rematch_button.pressed.emit()
	check(fired["rematch"] == 2, "Both Rematch buttons emit rematch_requested")
	hud.pause_exit_button.pressed.emit()
	hud.result_exit_button.pressed.emit()
	check(fired["exit"] == 2, "Both Back to title buttons emit exit_requested")

	var all_buttons := []
	buttons_under(hud, all_buttons)
	var focus_ok := all_buttons.size() == 5
	for b in all_buttons:
		if b.focus_mode != Control.FOCUS_NONE:
			focus_ok = false
	check(focus_ok, "All five buttons have FOCUS_NONE")

	hud.set_names("Averyveryverylongname", "")
	await frames(2)
	s = hud.debug_snapshot()
	check(s["names"][0] == "Averyveryverylongname" and s["names"][1] == "P2", "Long name kept, empty name falls back to P2")
	check(hud.name_labels[0].clip_text and hud.name_labels[0].size.x <= 130.0, "Name label is clipped to its box")
	hud.set_names("Ann", "Bob")
	check(hud.name_labels[0].text == "Ann" and hud.name_labels[1].text == "Bob", "Custom names apply")

	print("DUEL HUD RESULT: %d passed, %d failed" % [passed, failures.size()])
	quit(1 if failures.size() > 0 else 0)
