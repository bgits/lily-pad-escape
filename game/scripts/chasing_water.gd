class_name ChasingWater
extends Node3D

const START_Z := 8.0
const HEAD_START := 6.0
var front_z := START_Z
var grace := HEAD_START
var speed := 1.8
var elapsed := 0.0
var crest: MeshInstance3D
var rear_camera: Camera3D
var rear_view: SubViewport

func _ready() -> void:
	# The broad sheet floods everything behind a clearly visible white crest.
	var water := LilyAvatar.material(Color(0.12,0.62,0.72,0.82))
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	LilyAvatar.box(self,Vector3(0,1.35,60),Vector3(70,2.4,120),water)
	crest = LilyAvatar.box(self,Vector3(0,2.6,0),Vector3(70,0.45,1.0),LilyAvatar.material(Color("dcfff2")))
	for i in 18:
		LilyAvatar.box(self,Vector3(-34+i*4,2.4,0.5),Vector3(2.5,0.9,1.3),LilyAvatar.material(Color("7ae3d6")))
	reset()

func reset() -> void:
	front_z = START_Z
	grace = HEAD_START
	elapsed = 0.0
	position.z = front_z

func advance(delta: float, player_position: Vector3 = Vector3.ZERO) -> void:
	elapsed += delta
	var moving_time := maxf(0.0,delta-grace)
	grace = maxf(0.0,grace-delta)
	# Accelerate smoothly when left behind, without teleporting the front.
	var gap := front_z-player_position.z
	var catch_up := clampf((gap-14.0)*0.8,0.0,5.2)
	front_z -= (speed+catch_up)*moving_time
	position.z = front_z
	crest.position.y = 2.6+sin(elapsed*4.0)*0.12

func has_caught(player_position: Vector3) -> bool:
	return grace <= 0 and player_position.z >= front_z

func make_rear_view(hud: Control) -> void:
	var panel := VBoxContainer.new()
	hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -282
	panel.offset_right = -26
	panel.offset_top = -225
	panel.offset_bottom = -60
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := Label.new()
	caption.text = "CHASING WATER · REAR VIEW"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",13)
	panel.add_child(caption)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(256,144)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(picture)
	rear_view = SubViewport.new()
	rear_view.size = Vector2i(256,144)
	rear_view.world_3d = get_world_3d()
	rear_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	picture.add_child(rear_view)
	picture.texture = rear_view.get_texture()
	rear_camera = Camera3D.new()
	rear_camera.fov = 75
	rear_camera.far = 90
	rear_view.add_child(rear_camera)
	rear_camera.current = true

func update_rear_view(player_position: Vector3) -> void:
	if is_instance_valid(rear_camera):
		rear_camera.position = Vector3(player_position.x,4.5,player_position.z-3.0)
		rear_camera.look_at(Vector3(player_position.x,1.5,player_position.z+12.0))
