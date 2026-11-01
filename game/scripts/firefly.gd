class_name LilyFirefly
extends Node3D

var index := 0
var collected := false
var clock := 0.0
var visual: Node3D
var wings: Array[MeshInstance3D] = []
var halo: MeshInstance3D

func _ready() -> void:
	clock = index*1.7
	visual = Node3D.new()
	add_child(visual)
	var glow := LilyAvatar.material(Color("ffe775"))
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color("ffdc54")
	var cream := LilyAvatar.material(Color("fff9d6"))
	cream.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	LilyAvatar.box(visual,Vector3.ZERO,Vector3(0.19,0.22,0.27),glow)
	LilyAvatar.box(visual,Vector3(0,0.035,-0.17),Vector3(0.15,0.15,0.13),LilyAvatar.material(Color("705c32")))
	for side in [-1,1]:
		wings.append(LilyAvatar.box(visual,Vector3(side*0.17,0.10,0),Vector3(0.23,0.035,0.27),cream))
	halo = MeshInstance3D.new()
	var ring := SphereMesh.new()
	ring.radius = 0.34
	ring.height = 0.68
	ring.radial_segments = 12
	ring.rings = 6
	halo.mesh = ring
	var aura := LilyAvatar.material(Color(1.0,0.88,0.32,0.12))
	aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.material_override = aura
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(halo)

func advance(delta: float) -> void:
	if collected:
		return
	clock += delta
	visual.position.y = sin(clock*2.6)*0.13
	visual.rotation.y = sin(clock*0.7)*0.5
	halo.scale = Vector3.ONE*(1.0+sin(clock*3.2)*0.15)
	for i in wings.size():
		wings[i].rotation.z = sin(clock*22.0)*(0.65 if i == 0 else -0.65)

func can_collect(feet: Vector3) -> bool:
	var offset := global_position-(feet+Vector3.UP*0.9)
	return not collected and Vector2(offset.x,offset.z).length() < 0.68 and absf(offset.y) < 0.85

func set_collected(value: bool) -> void:
	collected = value
	visible = not value
