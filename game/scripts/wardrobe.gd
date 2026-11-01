class_name LilyWardrobe
extends Control

signal saved(outfit: Dictionary, player_name: String)
signal canceled

const INK := Color("183f3b")
const CREAM := Color("fff6de")
const MUTED := Color("5b766a")
const GOLD := Color("f3cc58")

var ui: CanvasLayer
var draft: Dictionary = LilyAppearance.DEFAULTS.duplicate()
var unlocked := false
var category := "Character"
var name_field: LineEdit
var preview: LilyAvatar
var preview_viewport: SubViewport
var target_rotation := -0.25
var dragging := false
var panels: Dictionary = {}
var controls: Dictionary = {}
var option_buttons: Dictionary = {}
var color_labels: Dictionary = {}
var heading: Label

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := ColorRect.new()
	paper.color = Color("f5f2dc")
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	var eyebrow: Label = ui.label(self,"THE DRESSING PAD",12,MUTED)
	eyebrow.position = Vector2(46,34)
	var title: Label = ui.label(self,"Your adventurer",44)
	title.position = Vector2(46,62)
	var detail: Label = ui.label(self,"Mix a look that's all your own.",18,MUTED)
	detail.position = Vector2(48,122)
	var divider := ColorRect.new()
	divider.position = Vector2(598,32)
	divider.size = Vector2(2,646)
	divider.color = Color("dbe2c9")
	add_child(divider)
	make_preview()
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(630,58)
	tabs.add_theme_constant_override("separation",8)
	add_child(tabs)
	for title_text in ["Character","Hair","Tops","Pants","Shoes"]:
		var b: Button = ui.button(tabs,title_text,func():select_category(title_text))
		b.custom_minimum_size = Vector2(112,44)
		b.add_theme_font_size_override("font_size",14)
		controls["tab_"+title_text] = b
		tabs.size.x = 600
	heading = ui.label(self,"Character",32)
	heading.position = Vector2(644,133)
	for title_text in ["Character","Hair","Tops","Pants","Shoes"]:
		var panel := VBoxContainer.new()
		panel.position = Vector2(644,196)
		panel.size.x = 556
		panel.add_theme_constant_override("separation",12)
		add_child(panel)
		panels[title_text] = panel
		if title_text == "Character":
			ui.label(panel,"NAME",12,MUTED)
			name_field = LineEdit.new()
			name_field.max_length = 18
			name_field.placeholder_text = "Name (optional)"
			name_field.custom_minimum_size = Vector2(556,46)
			name_field.add_theme_stylebox_override("normal",ui.style(Color("e6ebd7"),8))
			name_field.add_theme_stylebox_override("focus",ui.style(Color("eef1df"),8,INK))
			name_field.add_theme_color_override("font_color",INK)
			name_field.add_theme_color_override("font_placeholder_color",MUTED)
			name_field.add_theme_color_override("caret_color",INK)
			panel.add_child(name_field)
			controls["name"] = name_field
			make_options(panel,"character","CHARACTER")
			make_options(panel,"skin","SKIN TONE",true)
		elif title_text == "Hair":
			make_options(panel,"hair_style","HAIRSTYLE")
			make_options(panel,"hair_color","HAIR COLOR",true)
		elif title_text == "Tops":
			make_options(panel,"top_style","TOP")
			make_options(panel,"top_color","COLOR",true)
			ui.label(panel,"Moonflower is earned with the Secret Perch badge.",13,MUTED)
		elif title_text == "Pants":
			make_options(panel,"pants_style","PANTS")
			make_options(panel,"pants_color","COLOR",true)
		else:
			make_options(panel,"shoe_style","SHOES")
			make_options(panel,"shoe_color","COLOR",true)
	var cancel: Button = ui.button(self,"Cancel",func():canceled.emit())
	cancel.position = Vector2(644,626)
	cancel.custom_minimum_size = Vector2(168,52)
	controls["cancel"] = cancel
	var save: Button = ui.button(self,"Save outfit",func():saved.emit(draft.duplicate(),name_field.text),true)
	save.position = Vector2(832,626)
	save.custom_minimum_size = Vector2(368,52)
	controls["save"] = save
	select_category("Character")
	visible = false

func make_options(parent: Node, key: String, title: String, colors := false) -> void:
	var caption: Label = ui.label(parent,title,12,MUTED)
	if colors:
		color_labels[key] = {"label":caption,"title":title}
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	parent.add_child(grid)
	option_buttons[key] = []
	for index in LilyAppearance.OPTIONS[key].size():
		var b: Button = ui.button(grid,LilyAppearance.OPTIONS[key][index],func():choose(key,index))
		b.custom_minimum_size = Vector2(178,46)
		b.add_theme_font_size_override("font_size",16)
		b.tooltip_text = LilyAppearance.OPTIONS[key][index]
		controls[key+"_"+str(index)] = b
		option_buttons[key].append(b)

func make_preview() -> void:
	var container := SubViewportContainer.new()
	container.position = Vector2(24,166)
	container.size = Vector2(550,442)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(550,442)
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(preview_viewport)
	var scene := Node3D.new()
	preview_viewport.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("f5f2dc")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff6e8")
	env.environment.ambient_light_energy = 0.65
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-35,0)
	sun.light_energy = 0.8
	scene.add_child(sun)
	var platform := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.05
	cylinder.bottom_radius = 1.05
	cylinder.height = 0.14
	cylinder.radial_segments = 12
	platform.mesh = cylinder
	platform.position.y = -0.10
	platform.material_override = LilyAvatar.material(Color("91b96a"))
	scene.add_child(platform)
	preview = LilyAvatar.new()
	scene.add_child(preview)
	preview.rotation.y = target_rotation
	var camera := Camera3D.new()
	camera.position = Vector3(2.5,1.8,-4.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0,0.90,0))
	camera.fov = 30
	camera.current = true
	var drag_surface := Control.new()
	drag_surface.position = container.position
	drag_surface.size = container.size
	drag_surface.mouse_default_cursor_shape = Control.CURSOR_DRAG
	drag_surface.gui_input.connect(preview_input)
	add_child(drag_surface)
	controls["preview"] = drag_surface
	var turn_left: Button = ui.button(self,"< Turn",func():target_rotation -= PI/4)
	turn_left.position = Vector2(138,626)
	turn_left.custom_minimum_size = Vector2(145,44)
	var turn_right: Button = ui.button(self,"Turn >",func():target_rotation += PI/4)
	turn_right.position = Vector2(299,626)
	turn_right.custom_minimum_size = Vector2(145,44)
	controls["turn_left"] = turn_left
	controls["turn_right"] = turn_right
	var hint: Label = ui.label(self,"Drag the character to look around",13,MUTED)
	hint.position = Vector2(177,604)

func preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		target_rotation += event.relative.x*0.012
		accept_event()

func open_editor(outfit: Dictionary, player_name: String, secret_unlocked: bool) -> void:
	unlocked = secret_unlocked
	draft = LilyAppearance.sanitize(outfit,unlocked)
	name_field.text = player_name
	target_rotation = -0.25
	preview.rotation.y = target_rotation
	preview.apply_appearance(draft)
	dragging = false
	select_category("Character")
	refresh_options()
	visible = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	controls["tab_Character"].grab_focus()

func close_editor() -> void:
	visible = false
	dragging = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func select_category(value: String) -> void:
	category = value
	heading.text = value
	for title: String in panels:
		panels[title].visible = title == value
		controls["tab_"+title].add_theme_stylebox_override("normal",ui.style(GOLD if title == value else Color("e6ebd7"),8))

func choose(key: String, index: int) -> void:
	if not LilyAppearance.OPTIONS.has(key) or index < 0 or index >= LilyAppearance.OPTIONS[key].size() or (key == "top_color" and index == 3 and not unlocked):
		return
	draft[key] = index
	preview.apply_appearance(draft)
	refresh_options()

func refresh_options() -> void:
	for key: String in option_buttons:
		for index in option_buttons[key].size():
			var b: Button = option_buttons[key][index]
			var color := Color(LilyAppearance.COLORS[key][index]) if LilyAppearance.COLORS.has(key) else Color("e6ebd7")
			var selected: bool = draft[key] == index
			var ink := CREAM if LilyAppearance.COLORS.has(key) and color.get_luminance() < 0.50 else INK
			b.add_theme_stylebox_override("normal",ui.style(color,8,INK if selected else Color.TRANSPARENT))
			b.add_theme_stylebox_override("hover",ui.style(color.lightened(0.12),8,INK))
			b.add_theme_stylebox_override("pressed",ui.style(color.darkened(0.06),8,INK))
			for state_name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
				b.add_theme_color_override(state_name,ink)
			b.disabled = key == "top_color" and index == 3 and not unlocked
			b.text = "Moonflower · locked" if b.disabled else LilyAppearance.OPTIONS[key][index]
			if b.disabled:
				b.add_theme_font_size_override("font_size",13)
				b.add_theme_stylebox_override("disabled",ui.style(color,8))
				b.add_theme_color_override("font_disabled_color",MUTED)
	for key: String in color_labels:
		color_labels[key].label.text = color_labels[key].title+"  /  "+LilyAppearance.OPTIONS[key][draft[key]]

func _process(delta: float) -> void:
	if visible and is_instance_valid(preview):
		preview.rotation.y = lerp_angle(preview.rotation.y,target_rotation,minf(delta*10,1))
		preview.animate(delta,0,true,0)

func debug_snapshot() -> Dictionary:
	var buttons: Dictionary = {}
	if visible:
		for key: String in controls:
			var control: Control = controls[key]
			if control.is_visible_in_tree():
				var rect := control.get_global_rect()
				buttons[key] = {"x":rect.get_center().x,"y":rect.get_center().y,"disabled":control is Button and control.disabled}
	return {"visible":visible,"category":category,"draft":draft,"name":name_field.text,"name_focused":name_field.has_focus(),"preview_rotation":preview.rotation.y,"controls":buttons}
