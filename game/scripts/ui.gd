class_name LilyUI
extends CanvasLayer

signal play_requested
signal resume_requested
signal restart_requested
signal pause_requested
signal home_requested
signal color_changed(color: Color)
signal mute_changed(muted: bool)
signal level_selected(index: int)
signal next_requested
signal customize_requested

const INK := Color("183f3b")
const CREAM := Color("fff6de")
const MUTED := Color("5b766a")
const GOLD := Color("f3cc58")
const MOONFLOWER := Color("b69add")
var root: Control
var start_screen: Control
var pause_screen: Control
var victory_screen: Control
var hud: Control
var name_input: LineEdit
var progress_label: Label
var toast: Label
var victory_detail: Label
var mute_button: Button
var muted := false
var panels: Array[Control] = []
var level_label: Label
var hints: Label
var objective_label: Label
var frog_legend: Label
var health_box: PanelContainer
var health_label: Label
var health_status: Label
var health_bar: ProgressBar
var health_fill: StyleBoxFlat
var start_detail: Label
var next_button: Button
var replay_button: Button
var level_buttons: Array[Button] = []
var level_title := "Sunlit lagoon"
var pad_total := 8
var combat := false
var lucky := false
var secret_unlocked := false
var selected_color := 0
var secret_badge: Label
var secret_badge_icon: TextureRect
var secret_detail: Label
var secret_equip: Button
var secret_popup: PanelContainer
var secret_reward_detail: Label
var wardrobe: LilyWardrobe
var customize_button: Button
var pause_customize_button: Button
var profile_note: Label
var pause_detail: Label
var tide_label: Label
var firefly_label: Label

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 18
	root.theme = theme
	make_start()
	make_hud()
	make_secret_popup()
	pause_screen = make_center_panel("TAKE A BREATHER", "Paused", "Your next lily pad will wait.", false)
	victory_screen = make_center_panel("YOU MADE IT TO SHORE", "Level complete!", "Every adventure starts with a little leap.", true)
	wardrobe = LilyWardrobe.new()
	wardrobe.ui = self
	root.add_child(wardrobe)
	wardrobe.build()
	show_state("title")

func style(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(2)
	return s

func label(parent: Node, text: String, font_size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func button(parent: Node, text: String, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0,52)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",20)
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_color_override("font_focus_color",INK)
	b.add_theme_stylebox_override("normal",style(GOLD if primary else Color("e6ebd7")))
	b.add_theme_stylebox_override("hover",style(Color("ffe18a") if primary else Color("d5e2c9")))
	b.add_theme_stylebox_override("pressed",style(Color("e4bb43") if primary else Color("c7d7b8")))
	b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,12,INK))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func gap(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)

func make_start() -> void:
	start_screen = Control.new()
	start_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(start_screen)
	# The live world remains the visual anchor; a soft paper-colored rail keeps text clear.
	var paper := ColorRect.new()
	paper.color = Color("f5f2dc")
	paper.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	paper.offset_right = 444
	start_screen.add_child(paper)
	var rail := ColorRect.new()
	rail.color = GOLD
	rail.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	rail.offset_left = 444
	rail.offset_right = 449
	start_screen.add_child(rail)
	var stack := VBoxContainer.new()
	stack.position = Vector2(46,39)
	stack.size.x = 352
	stack.add_theme_constant_override("separation",6)
	start_screen.add_child(stack)
	label(stack,"FIELD TRIP  /  THREE LITTLE ADVENTURES",13,MUTED)
	gap(stack,9)
	var title := label(stack,"LILY PAD\nESCAPE",65)
	title.add_theme_constant_override("line_spacing",-12)
	gap(stack,7)
	label(stack,"A little leap. A big adventure.",20)
	gap(stack,6)
	start_detail = label(stack,"Hop across the lagoon.\nStay ahead of the chasing water.",17,MUTED)
	gap(stack,16)
	label(stack,"YOUR ADVENTURER",12,MUTED)
	var adventurer_row := HBoxContainer.new()
	adventurer_row.add_theme_constant_override("separation",10)
	stack.add_child(adventurer_row)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Name (optional)"
	name_input.max_length = 18
	name_input.custom_minimum_size.y = 46
	name_input.add_theme_color_override("font_color",INK)
	name_input.add_theme_color_override("font_placeholder_color",MUTED)
	name_input.add_theme_color_override("caret_color",INK)
	name_input.add_theme_stylebox_override("normal",style(Color("e6ebd7"),8))
	name_input.add_theme_stylebox_override("focus",style(Color("eef1df"),8,Color("8fae77")))
	name_input.custom_minimum_size.x = 200
	adventurer_row.add_child(name_input)
	customize_button = button(adventurer_row,"Customize",func():customize_requested.emit())
	customize_button.custom_minimum_size = Vector2(142,46)
	customize_button.add_theme_font_size_override("font_size",16)
	gap(stack,36)
	gap(stack,13)
	button(stack,"Let's hop!",func(): play_requested.emit(),true)
	gap(stack,13)
	label(stack,"WASD / Arrows   Move     SPACE   Jump",14,MUTED)
	label(stack,"MOUSE   Look      ESC   Pause      R   Restart",12,MUTED)
	var footer := label(start_screen,"LITTLE LEAPS.  BIG ADVENTURES.",10,MUTED)
	profile_note = footer
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 46
	footer.offset_top = -31
	footer.offset_right = 430
	footer.offset_bottom = -12
	mute_button = button(start_screen,"Sound: on",toggle_mute)
	mute_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mute_button.offset_left = -166
	mute_button.offset_right = -28
	mute_button.offset_top = 26
	mute_button.offset_bottom = 74
	mute_button.add_theme_font_size_override("font_size",16)
	var choices := VBoxContainer.new()
	choices.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	choices.offset_left = -290
	choices.offset_right = -28
	choices.offset_top = -251
	choices.offset_bottom = -28
	choices.add_theme_constant_override("separation",8)
	start_screen.add_child(choices)
	var caption := label(choices,"CROSSINGS  /  FIREFLIES",13,CREAM)
	caption.add_theme_color_override("font_shadow_color",INK)
	caption.add_theme_constant_override("shadow_offset_y",2)
	for i in 3:
		var choice := button(choices,["1  ·  Sunlit lagoon","2  ·  Frog river","3  ·  Lucky lagoon"][i],func():level_selected.emit(i))
		choice.add_theme_font_size_override("font_size",15)
		level_buttons.append(choice)
	var collection := PanelContainer.new()
	start_screen.add_child(collection)
	collection.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	collection.offset_left = -334
	collection.offset_right = -28
	collection.offset_top = 110
	collection.offset_bottom = 272
	collection.add_theme_stylebox_override("panel",style(CREAM,12))
	var badge_stack := VBoxContainer.new()
	badge_stack.add_theme_constant_override("separation",8)
	collection.add_child(badge_stack)
	label(badge_stack,"SECRET ACHIEVEMENT",12,MUTED)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation",10)
	badge_stack.add_child(badge_row)
	secret_badge_icon = badge_icon(badge_row)
	secret_badge_icon.visible = false
	secret_badge = label(badge_row,"?  Undiscovered",24)
	secret_detail = label(badge_stack,"A little exploring has its rewards.",13,MUTED)
	secret_equip = button(badge_stack,"Moonflower hoodie",func():select_color(3))
	secret_equip.add_theme_font_size_override("font_size",16)
	secret_equip.custom_minimum_size.y = 42
	secret_equip.add_theme_stylebox_override("normal",style(MOONFLOWER,7))
	secret_equip.add_theme_stylebox_override("hover",style(MOONFLOWER.lightened(0.14),7,INK))
	secret_equip.visible = false

func select_color(index: int) -> void:
	if index < 0 or index > 3 or (index == 3 and not secret_unlocked):
		return
	sync_outfit({"top_color":index})
	color_changed.emit(Color(LilyAppearance.COLORS.top_color[index]))

func sync_outfit(outfit: Dictionary) -> void:
	var index: int = outfit.top_color
	selected_color = index
	secret_equip.text = "Moonflower · equipped" if index == 3 else "Wear Moonflower hoodie"
	secret_equip.add_theme_stylebox_override("normal",style(MOONFLOWER,7,INK if index == 3 else Color.TRANSPARENT))

func show_profile_saved(saved: bool) -> void:
	profile_note.text = "OUTFIT SAVED." if saved else "OUTFIT READY FOR THIS VISIT. SAVING UNAVAILABLE."
	pause_detail.text = "Your next lily pad will wait." if saved else "Outfit ready for this visit. Saving unavailable."

func set_secret_unlocked(unlocked: bool) -> void:
	secret_unlocked = unlocked
	secret_badge.text = "Secret Perch" if unlocked else "?  Undiscovered"
	secret_badge_icon.visible = unlocked
	secret_badge.add_theme_color_override("font_color",Color("735193") if unlocked else INK)
	secret_detail.text = "Badge earned. A new hoodie is yours!" if unlocked else "A little exploring has its rewards."
	secret_equip.visible = unlocked
	secret_equip.text = "Moonflower · equipped" if selected_color == 3 else "Wear Moonflower hoodie"

func badge_icon(parent: Node) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/secret_badge.svg")
	icon.custom_minimum_size = Vector2(30,35)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func make_secret_popup() -> void:
	secret_popup = PanelContainer.new()
	root.add_child(secret_popup)
	secret_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	secret_popup.offset_left = -234
	secret_popup.offset_right = 234
	secret_popup.offset_top = -192
	secret_popup.offset_bottom = -72
	secret_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secret_popup.add_theme_stylebox_override("panel",style(CREAM,14,MOONFLOWER))
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation",6)
	secret_popup.add_child(stack)
	label(stack,"SECRET ACHIEVEMENT UNLOCKED",12,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation",10)
	stack.add_child(badge_row)
	badge_icon(badge_row)
	label(badge_row,"Secret Perch",28,Color("735193"))
	secret_reward_detail = label(stack,"Moonflower hoodie unlocked & equipped!",16)
	secret_reward_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secret_popup.visible = false

func show_secret_reward(saved: bool) -> void:
	secret_reward_detail.text = "Moonflower hoodie unlocked & equipped!" if saved else "Moonflower equipped! Saving unavailable."
	secret_popup.visible = true

func toggle_mute() -> void:
	muted = not muted
	mute_button.text = "Sound: off" if muted else "Sound: on"
	for node in get_tree().get_nodes_in_group("mute_buttons"):
		node.text = mute_button.text
	mute_changed.emit(muted)

func make_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var bg := PanelContainer.new()
	bg.position = Vector2(26,24)
	bg.add_theme_stylebox_override("panel",style(Color("fff4db"),12))
	hud.add_child(bg)
	var info := VBoxContainer.new()
	bg.add_child(info)
	level_label = label(info,"LEVEL 1",23)
	progress_label = label(info,"Sunlit lagoon  ·  Reach the flag",13,MUTED)
	firefly_label = label(info,"Fireflies  0 / 3",15,INK)
	tide_label = label(info,"Water moves in 6…",15,INK)
	objective_label = label(info,"",17)
	objective_label.visible = false
	frog_legend = label(info,"",13,MUTED)
	frog_legend.visible = false
	health_box = PanelContainer.new()
	health_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	health_box.offset_left = -330
	health_box.offset_right = -26
	health_box.offset_top = 96
	health_box.offset_bottom = 210
	health_box.add_theme_stylebox_override("panel",style(CREAM,12))
	hud.add_child(health_box)
	var health_stack := VBoxContainer.new()
	health_stack.add_theme_constant_override("separation",7)
	health_box.add_child(health_stack)
	health_label = label(health_stack,"HEALTH  100%",20)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(260,12)
	health_bar.show_percentage = false
	health_bar.max_value = 100
	health_bar.value = 100
	var health_track := StyleBoxFlat.new()
	health_track.bg_color = Color("dce4ce")
	health_track.set_corner_radius_all(5)
	health_fill = StyleBoxFlat.new()
	health_fill.bg_color = Color("6a9c50")
	health_fill.set_corner_radius_all(5)
	health_bar.add_theme_stylebox_override("background",health_track)
	health_bar.add_theme_stylebox_override("fill",health_fill)
	health_stack.add_child(health_bar)
	health_status = label(health_stack,"Healthy",13,MUTED)
	var pause_button := button(hud,"Pause",func():pause_requested.emit())
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -158
	pause_button.offset_right = -26
	pause_button.offset_top = 24
	pause_button.offset_bottom = 76
	pause_button.add_theme_font_size_override("font_size",17)
	hints = label(hud,"WASD / Arrows  Move     SPACE  Jump     MOUSE  Look     CLICK/ESC  Pause     R  Restart",14,CREAM)
	hints.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hints.offset_left = -550
	hints.offset_right = 550
	hints.offset_top = -40
	hints.offset_bottom = -15
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.add_theme_color_override("font_shadow_color",INK)
	hints.add_theme_constant_override("shadow_offset_y",2)
	toast = label(hud,"",28,CREAM)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.offset_left = -350
	toast.offset_right = 350
	toast.offset_top = 90
	toast.offset_bottom = 135
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color",INK)
	toast.add_theme_constant_override("shadow_offset_y",3)

func make_center_panel(eyebrow: String, title: String, detail: String, won: bool) -> Control:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	var veil := ColorRect.new()
	veil.color = Color(0.04,0.16,0.16,0.48)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(veil)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -252
	panel.offset_right = 252
	panel.offset_top = -220
	panel.offset_bottom = 220
	var panel_style := style(CREAM,18)
	panel_style.content_margin_left = 38
	panel_style.content_margin_right = 38
	panel_style.content_margin_top = 32
	panel_style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel",panel_style)
	screen.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	panel.add_child(stack)
	label(stack,eyebrow,12,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(stack,title,40).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var desc := label(stack,detail,16,MUTED)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if won:
		victory_detail = desc
	else:
		pause_detail = desc
		pause_customize_button = button(screen,"Customize",func():customize_requested.emit())
		pause_customize_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		pause_customize_button.offset_left = -207
		pause_customize_button.offset_right = -28
		pause_customize_button.offset_top = 26
		pause_customize_button.offset_bottom = 74
		pause_customize_button.add_theme_font_size_override("font_size",17)
	gap(stack,8)
	if won:
		next_button = button(stack,"Next level: Frog river",func():next_requested.emit(),true)
		replay_button = button(stack,"Play again",func():restart_requested.emit(),true)
	else:
		button(stack,"Resume",func():resume_requested.emit(),true)
		button(stack,"Start over",func():restart_requested.emit())
	var sound := button(stack,"Sound: on",toggle_mute)
	sound.add_to_group("mute_buttons")
	sound.add_theme_font_size_override("font_size",16)
	button(stack,"Back to title",func():home_requested.emit()).add_theme_font_size_override("font_size",16)
	return screen

func show_state(state: String, trap_fall := false) -> void:
	start_screen.visible = state == "title"
	hud.visible = state in ["playing","splash","poison_defeat","paused"]
	pause_screen.visible = state == "paused"
	victory_screen.visible = state == "won"
	toast.text = "A splash, then another chance." if state == "splash" else ""
	if state == "splash" and trap_fall and lucky:
		toast.text = "Unlucky yellow frog! New chance next try."
	if state == "poison_defeat":
		toast.text = "Poisoned! 0% health. Trying again…"

func set_progress(pad_index: int) -> void:
	progress_label.text = "%s  ·  Reach the flag" % level_title if pad_index == 0 or lucky else "%s  ·  Pad %d of %d" % [level_title,pad_index,pad_total]

func set_fireflies(profile: LilyProfile, level: int, saved: bool) -> void:
	firefly_label.text = "Fireflies  %d / 3%s" % [profile.firefly_count(level),"" if saved else "  ·  This visit"]
	for i in level_buttons.size():
		level_buttons[i].text = "%d · %s   %d/3" % [i+1,["Sunlit lagoon","Frog river","Lucky lagoon"][i],profile.firefly_count(i)]

func configure_level(index: int, data: LilyLevel) -> void:
	level_title = data.title
	pad_total = data.pads.size()-1
	combat = data.has_bat
	lucky = not data.chance_pad_indices.is_empty()
	level_label.text = "LEVEL %d  /  %s" % [index+1,"CHOOSE YOUR ROUTE" if lucky else ("BAT EQUIPPED" if combat else "LET'S HOP")]
	objective_label.visible = false
	health_box.visible = combat
	frog_legend.visible = lucky
	frog_legend.text = "Yellow: 50% sink  ·  50% stay" if lucky else ""
	hints.text = "WASD / Arrows  Move    SPACE  Jump    MOUSE  Look    CLICK / F  Swing bat    ESC  Pause    R  Restart" if combat else "WASD / Arrows  Move     SPACE  Jump     MOUSE  Look     CLICK/ESC  Pause     R  Restart"
	start_detail.text = "Clear the frogs. Reach the flag.\nStay ahead of the chasing water." if combat else "Hop across the lagoon.\nStay ahead of the chasing water."
	if lucky:
		start_detail.text = "Risk the frogs or take the tiny pads.\nStay ahead of the chasing water."
	for i in level_buttons.size():
		level_buttons[i].add_theme_stylebox_override("normal",style(GOLD if i == index else CREAM))
		level_buttons[i].add_theme_stylebox_override("hover",style(Color("ffe18a") if i == index else Color("d5e2c9")))
	set_progress(0)
	set_frogs(0,data.frog_pads.size())
	if lucky:
		set_chance_progress(0,data.chance_pad_indices.size())
	set_health(100,false)

func set_health(value: float, poisoned: bool) -> void:
	health_bar.value = value
	health_label.text = "HEALTH  %d%%" % ceili(value)
	health_status.text = "Poisoned!" if poisoned else "Healthy"
	if value <= 0:
		health_status.text = "The frog's poison got you."
	health_fill.bg_color = Color("bd5355") if value <= 25 else (Color("9262b1") if poisoned else Color("6a9c50"))
	health_status.add_theme_color_override("font_color",Color("784f91") if poisoned else MUTED)

func set_frogs(defeated: int, total: int) -> void:
	objective_label.text = "Frogs defeated  %d / %d" % [defeated,total] if defeated < total else "Crossing clear  ·  Reach the flag!"

func set_chance_progress(held: int, total: int) -> void:
	objective_label.text = "Yellow pads held  %d / %d" % [held,total]

func set_victory(player_name: String, next_title: String) -> void:
	var has_next := not next_title.is_empty()
	next_button.visible = has_next
	next_button.text = "Next level: " + next_title
	replay_button.add_theme_stylebox_override("normal",style(Color("e6ebd7") if has_next else GOLD))
	replay_button.add_theme_stylebox_override("hover",style(Color("d5e2c9") if has_next else Color("ffe18a")))
	var greeting := "Nice hopping, %s!" % player_name if not player_name.is_empty() else "Every adventure starts with a little leap."
	victory_detail.text = "You crossed the river!" if combat else greeting
	if lucky:
		victory_detail.text = "Lagoon crossed! You reached the shore."
