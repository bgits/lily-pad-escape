class_name LilyDuelHud
extends CanvasLayer

signal resume_requested
signal rematch_requested
signal exit_requested

const NAVY := Color(0.078, 0.137, 0.231, 0.88)
const NAVY_DEEP := Color(0.047, 0.09, 0.16, 0.94)
const CREAM := Color("fff6de")
const MUTED := Color("93a6c4")
const GOLD := Color("ffd75e")
const CYAN := Color("6fd3ff")
const WARN := Color("ff7d6b")
const POISON := Color("9be85f")
const SHADOW := Color(0.02, 0.04, 0.09, 0.9)
const CARD_SIZE := Vector2(330, 78)

const PHASE_NAMES := {
	"countdown": "GET READY",
	"dusk": "DUSK",
	"midnight": "MIDNIGHT",
	"flood": "THE FLOOD",
	"sudden_death": "SUDDEN DEATH",
	"over": "FINAL",
}

var root: Control
var clock_label: Label
var phase_label: Label
var toast_label: Label
var countdown_label: Label
var hint_label: Label
var pause_root: Control
var result_root: Control
var result_title_label: Label
var result_detail_label: Label

var resume_button: Button
var pause_rematch_button: Button
var pause_exit_button: Button
var result_rematch_button: Button
var result_exit_button: Button

var name_labels: Array[Label] = []
var banked_labels: Array[Label] = []
var carried_labels: Array[Label] = []
var poison_boxes: Array[Control] = []
var health_bars: Array[ProgressBar] = []
var queen_labels: Array[Label] = []

var names := ["P1", "P2"]
var toast_time := 0.0
var queen_holder := -1
var clock_text := "3:00"
var phase_text := "GET READY"

func _init() -> void:
	layer = 10
	build()

func accent(index: int) -> Color:
	return GOLD if index == 0 else CYAN

func style(color: Color, radius := 12, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(2)
	return s

func make_label(parent: Node, text: String, size: int, color := CREAM, shadow := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow:
		l.add_theme_color_override("font_shadow_color", SHADOW)
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l

func place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)

func make_button(parent: Node, text: String, primary: bool, signal_to_emit: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 48)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 19)
	var ink := Color("14233b") if primary else CREAM
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, ink)
	var base := GOLD if primary else Color("2a4268")
	b.add_theme_stylebox_override("normal", style(base))
	b.add_theme_stylebox_override("hover", style(base.lightened(0.18)))
	b.add_theme_stylebox_override("pressed", style(base.darkened(0.15)))
	b.add_theme_stylebox_override("focus", style(base))
	b.pressed.connect(func(): signal_to_emit.emit())
	parent.add_child(b)
	return b

func build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	for i in 2:
		build_card(i)
	build_clock()
	hint_label = make_label(root, "P1  WASD move · Space jump · F bat      P2  Arrows move · Enter jump · / bat      Esc pause", 14, CREAM, true)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -34
	hint_label.offset_bottom = -10
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Kept just under the clock so messages never cover the pads in the middle of the pond.
	toast_label = make_label(root, "", 27, CREAM, true)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.anchor_left = 0.0
	toast_label.anchor_right = 1.0
	toast_label.offset_left = 40
	toast_label.offset_right = -40
	toast_label.offset_top = 92
	toast_label.offset_bottom = 132
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.visible = false
	countdown_label = make_label(root, "", 150, CREAM, true)
	countdown_label.add_theme_constant_override("shadow_offset_x", 4)
	countdown_label.add_theme_constant_override("shadow_offset_y", 4)
	countdown_label.anchor_right = 1.0
	countdown_label.offset_top = 190
	countdown_label.offset_bottom = 400
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.visible = false
	build_pause()
	build_result()

func build_card(index: int) -> void:
	var mirror := index == 1
	var color := accent(index)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", style(NAVY, 14, Color(color.r, color.g, color.b, 0.55)))
	card.custom_minimum_size = CARD_SIZE
	if mirror:
		card.anchor_left = 1.0
		card.anchor_right = 1.0
		card.offset_left = -12 - CARD_SIZE.x
		card.offset_right = -12
	else:
		card.offset_left = 12
		card.offset_right = 12 + CARD_SIZE.x
	card.offset_top = 8
	card.offset_bottom = 8 + CARD_SIZE.y
	root.add_child(card)
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.custom_minimum_size = CARD_SIZE - Vector2(32, 20)
	card.add_child(inner)
	var iw := CARD_SIZE.x - 32
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
	var name_label := make_label(inner, names[index], 14, color)
	place(name_label, 0 if not mirror else iw - 130, -2, 130, 20)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.horizontal_alignment = align
	name_labels.append(name_label)
	var banked := make_label(inner, "0", 40, color, true)
	place(banked, 0 if not mirror else iw - 110, 14, 110, 50)
	banked.horizontal_alignment = align
	banked.clip_text = true
	banked_labels.append(banked)
	var col_w := 170.0
	var col_x := iw - col_w if not mirror else 0.0
	var carried := make_label(inner, "carrying 0", 14, MUTED)
	place(carried, col_x, -2, col_w, 20)
	carried.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if not mirror else HORIZONTAL_ALIGNMENT_LEFT
	carried_labels.append(carried)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(box, col_x, 22, col_w, 24)
	box.visible = false
	inner.add_child(box)
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if not mirror else ProgressBar.FILL_END_TO_BEGIN
	var bar_back := style(Color(0.02, 0.05, 0.1, 0.8), 4)
	var bar_fill := style(POISON, 4)
	for sb in [bar_back, bar_fill]:
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", bar_back)
	bar.add_theme_stylebox_override("fill", bar_fill)
	place(bar, 0, 0, col_w, 8)
	box.add_child(bar)
	health_bars.append(bar)
	var poison := make_label(box, "Poisoned!", 13, POISON)
	place(poison, 0, 8, col_w, 18)
	poison.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if not mirror else HORIZONTAL_ALIGNMENT_LEFT
	poison_boxes.append(box)
	var queen := make_label(inner, "♛ Queen ×2", 15, GOLD)
	place(queen, col_x, 46, col_w, 20)
	queen.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if not mirror else HORIZONTAL_ALIGNMENT_LEFT
	queen.visible = false
	queen_labels.append(queen)

func build_clock() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.offset_left = -150
	holder.offset_right = 150
	holder.offset_top = 6
	holder.offset_bottom = 86
	root.add_child(holder)
	clock_label = make_label(holder, "3:00", 48, CREAM, true)
	place(clock_label, 0, 0, 300, 58)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label = make_label(holder, "GET READY", 16, MUTED, true)
	place(phase_label, 0, 56, 300, 22)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func make_overlay(width: float, height: float) -> Array:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.visible = false
	root.add_child(screen)
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.03, 0.08, 0.62)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(veil)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -width / 2.0
	panel.offset_right = width / 2.0
	panel.offset_top = -height / 2.0
	panel.offset_bottom = height / 2.0
	var ps := style(NAVY_DEEP, 18, Color(CREAM.r, CREAM.g, CREAM.b, 0.22))
	ps.content_margin_left = 34
	ps.content_margin_right = 34
	ps.content_margin_top = 26
	ps.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", ps)
	screen.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	return [screen, stack]

func centered(parent: Node, text: String, size: int, color := CREAM) -> Label:
	var l := make_label(parent, text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func build_pause() -> void:
	var parts := make_overlay(560, 470)
	pause_root = parts[0]
	var stack: VBoxContainer = parts[1]
	centered(stack, "Paused", 40)
	centered(stack, "Carry fireflies home to your lantern to score.", 16, MUTED)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(grid)
	var rows := [["", "P1", "P2"], ["Move", "W A S D", "Arrow keys"], ["Jump", "Space", "Enter"], ["Swing bat", "F", "/"]]
	for r in rows.size():
		for c in 3:
			var col := MUTED if c == 0 else (GOLD if c == 1 else CYAN)
			var cell := make_label(grid, rows[r][c], 17, col)
			cell.custom_minimum_size.x = 120
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if c == 0 else HORIZONTAL_ALIGNMENT_CENTER
			if r == 0:
				cell.add_theme_font_size_override("font_size", 18)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(spacer)
	resume_button = make_button(stack, "Resume", true, resume_requested)
	pause_rematch_button = make_button(stack, "Rematch", false, rematch_requested)
	pause_exit_button = make_button(stack, "Back to title", false, exit_requested)
	centered(stack, "Esc resume · R rematch", 13, MUTED)

func build_result() -> void:
	var parts := make_overlay(520, 280)
	result_root = parts[0]
	var stack: VBoxContainer = parts[1]
	result_title_label = centered(stack, "", 46)
	result_detail_label = centered(stack, "", 18, MUTED)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(spacer)
	result_rematch_button = make_button(stack, "Rematch", true, rematch_requested)
	result_exit_button = make_button(stack, "Back to title", false, exit_requested)
	centered(stack, "R rematch", 13, MUTED)

# --- public contract -------------------------------------------------------

func set_names(p1: String, p2: String) -> void:
	var given := [p1.strip_edges(), p2.strip_edges()]
	for i in 2:
		names[i] = given[i] if given[i] != "" else "P%d" % (i + 1)
		name_labels[i].text = names[i]

func set_time(seconds_left: float, phase: String) -> void:
	phase_text = PHASE_NAMES.get(phase, phase.to_upper().replace("_", " "))
	phase_label.text = phase_text
	if phase == "sudden_death":
		clock_text = "—"
	else:
		var whole := maxi(0, int(ceil(seconds_left)))
		clock_text = "%d:%02d" % [whole / 60, whole % 60]
	clock_label.text = clock_text
	var warn := phase == "flood" and seconds_left <= 10.0
	clock_label.add_theme_color_override("font_color", WARN if warn else CREAM)

func set_scores(banked: Array, carried: Array) -> void:
	for i in 2:
		var b := int(banked[i]) if i < banked.size() else 0
		var c := int(carried[i]) if i < carried.size() else 0
		banked_labels[i].text = str(b)
		carried_labels[i].text = "carrying %d" % c
		carried_labels[i].modulate.a = 1.0 if c > 0 else 0.35

func set_health(player_index: int, health: float, poisoned: bool) -> void:
	if player_index < 0 or player_index > 1:
		return
	health_bars[player_index].value = clampf(health, 0.0, 100.0)
	poison_boxes[player_index].visible = poisoned

func set_queen(holder_index: int) -> void:
	queen_holder = holder_index if holder_index == 0 or holder_index == 1 else -1
	for i in 2:
		queen_labels[i].visible = i == queen_holder

func show_toast(text: String, seconds := 2.0) -> void:
	toast_label.text = text
	toast_label.visible = text != ""
	toast_time = seconds if text != "" else 0.0

func show_countdown(text: String) -> void:
	countdown_label.text = text
	countdown_label.visible = text != ""

func show_pause(visible_now: bool) -> void:
	pause_root.visible = visible_now

func show_result(title: String, detail: String) -> void:
	result_title_label.text = title
	result_detail_label.text = detail
	result_root.visible = true

func hide_result() -> void:
	result_root.visible = false

func advance(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast_time = 0.0
			toast_label.visible = false
			toast_label.text = ""

func debug_snapshot() -> Dictionary:
	return {
		"clock": clock_label.text,
		"phase": phase_label.text,
		"banked": [int(banked_labels[0].text), int(banked_labels[1].text)],
		"carried": [int(carried_labels[0].text.trim_prefix("carrying ")), int(carried_labels[1].text.trim_prefix("carrying "))],
		"names": [name_labels[0].text, name_labels[1].text],
		"toast": toast_label.text if toast_label.visible else "",
		"countdown": countdown_label.text if countdown_label.visible else "",
		"pause_visible": pause_root.visible,
		"result_visible": result_root.visible,
		"result_title": result_title_label.text,
		"result_detail": result_detail_label.text,
		"queen": queen_holder,
		"poison_visible": [poison_boxes[0].visible, poison_boxes[1].visible],
	}
