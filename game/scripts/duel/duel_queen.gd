class_name LilyDuelQueen
extends Node3D

const RETURN_TIME := 1.0
const RAY_COUNT := 7

var state := "hidden"
var holder: LilyDuelPlayer
var perch_point := Vector3.ZERO
var clock := 0.0
var orbit := 0.0
var return_clock := 0.0
var return_from := Vector3.ZERO
var visual: Node3D
var wings: Array[MeshInstance3D] = []
var halo: MeshInstance3D
var light: OmniLight3D
var halo_sprite: MeshInstance3D
var ray_pivot: Node3D
var ray_spin: Node3D
var rays: Array[MeshInstance3D] = []
var trail: LilyDuelFx.Trail

func _ready() -> void:
	visible = state != "hidden"
	visual = Node3D.new()
	add_child(visual)
	var glow := LilyAvatar.material(Color("ffd23c"))
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color("ffc21f")
	var cream := LilyAvatar.material(Color("fff4c4"))
	cream.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var crown_mat := LilyAvatar.material(Color("fff0a0"))
	crown_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crown_mat.emission_enabled = true
	crown_mat.emission = Color("ffe680")
	LilyAvatar.box(visual, Vector3.ZERO, Vector3(0.38, 0.44, 0.54), glow)
	LilyAvatar.box(visual, Vector3(0, 0.07, -0.34), Vector3(0.30, 0.30, 0.26), LilyAvatar.material(Color("8a6a22")))
	for side in [-1, 1]:
		wings.append(LilyAvatar.box(visual, Vector3(side * 0.34, 0.20, 0), Vector3(0.46, 0.05, 0.54), cream))
	# Tiny crown: a band and three points.
	LilyAvatar.box(visual, Vector3(0, 0.30, 0.0), Vector3(0.26, 0.07, 0.26), crown_mat)
	for x in [-0.09, 0.0, 0.09]:
		LilyAvatar.box(visual, Vector3(x, 0.38, 0.0), Vector3(0.06, 0.09, 0.06), crown_mat)
	halo = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.62
	sphere.height = 1.24
	sphere.radial_segments = 12
	sphere.rings = 6
	halo.mesh = sphere
	var aura := LilyAvatar.material(Color(1.0, 0.82, 0.25, 0.14))
	aura.albedo_color = Color(1.0, 0.82, 0.25, 0.24)
	aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.material_override = aura
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(halo)
	# Big warm sprite, slowly turning light rays and a golden ribbon trail (additive, no bloom needed).
	halo_sprite = LilyDuelFx.add_glow_sprite(visual, 3.4, Color(1.0, 0.66, 0.12, 0.5), true)
	ray_pivot = Node3D.new()
	add_child(ray_pivot)
	ray_spin = Node3D.new()
	ray_pivot.add_child(ray_spin)
	var ray_mat := LilyDuelFx.additive_material(Color(1.0, 0.72, 0.18, 0.95), false, true)
	for i in RAY_COUNT:
		var ray := MeshInstance3D.new()
		ray.mesh = LilyDuelFx.ray_quad()
		ray.material_override = ray_mat
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ray.rotation.z = TAU * i / RAY_COUNT
		ray.scale = Vector3(0.4, 3.2, 1.0)
		ray_spin.add_child(ray)
		rays.append(ray)
	trail = LilyDuelFx.Trail.new(1, 28, 0.8, 0.26)
	trail.interval = 0.03
	trail.head_color = Color(1.0, 0.86, 0.30, 0.95)
	trail.tail_color = Color(1.0, 0.55, 0.12, 0.0)
	add_child(trail)
	light = OmniLight3D.new()
	light.light_color = Color("ffd45a")
	light.light_energy = 2.8
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)

func set_world_position(point: Vector3) -> void:
	if is_inside_tree():
		global_position = point
	else:
		position = point

func current_position() -> Vector3:
	return global_position if is_inside_tree() else position

func appear(perch: Vector3) -> void:
	perch_point = perch
	holder = null
	state = "perched"
	visible = true
	set_world_position(perch)
	if trail != null:
		trail.clear()
	reset_physics_interpolation()

func give_to(player: LilyDuelPlayer) -> void:
	if not is_instance_valid(player):
		return
	holder = player
	state = "held"
	visible = true
	if current_position() == Vector3.ZERO:
		set_world_position(player.global_position + Vector3(0, 2.3, 0))

func return_to_perch() -> void:
	if state == "hidden":
		return
	holder = null
	state = "returning"
	return_clock = 0.0
	return_from = current_position()

func hide_queen() -> void:
	state = "hidden"
	holder = null
	visible = false
	if trail != null:
		trail.clear()

func can_be_taken_by(player: LilyDuelPlayer) -> bool:
	if state != "perched" or not is_instance_valid(player):
		return false
	var offset := current_position() - player.global_position
	return Vector2(offset.x, offset.z).length() <= 1.2 and absf(offset.y) <= 2.5

func advance(delta: float) -> void:
	clock += delta
	if not is_instance_valid(visual):
		return
	visual.position.y = sin(clock * 2.4) * 0.10
	visual.rotation.y = sin(clock * 0.7) * 0.4
	halo.scale = Vector3.ONE * (1.0 + sin(clock * 3.0) * 0.12)
	for i in wings.size():
		wings[i].rotation.z = sin(clock * 20.0) * (0.6 if i == 0 else -0.6)
	if state == "held" and not is_instance_valid(holder):
		holder = null
		return_to_perch()
	match state:
		"perched":
			set_world_position(perch_point + Vector3(sin(clock * 0.9) * 0.12, 0, cos(clock * 0.7) * 0.12))
		"held":
			orbit += delta * 3.2
			var wanted := holder.global_position + Vector3(cos(orbit) * 0.5, 2.3 + sin(clock * 3.0) * 0.08, sin(orbit) * 0.5)
			set_world_position(current_position().lerp(wanted, 1.0 - exp(-14.0 * delta)))
		"returning":
			return_clock += delta
			var t := clampf(return_clock / RETURN_TIME, 0.0, 1.0)
			var eased := t * t * (3.0 - 2.0 * t)
			set_world_position(return_from.lerp(perch_point, eased) + Vector3.UP * sin(t * PI) * 0.7)
			if t >= 1.0:
				state = "perched"
				set_world_position(perch_point)
	update_fx(delta)

func update_fx(delta: float) -> void:
	if state == "hidden" or not is_instance_valid(trail):
		return
	var pos := current_position()
	if state == "held" or state == "returning":
		trail.track(0, pos)
	trail.advance(delta)
	for i in rays.size():
		rays[i].scale = Vector3(0.4 + sin(clock * 1.7 + i * 1.3) * 0.06, 3.2 + sin(clock * 1.1 + i * 2.1) * 0.5, 1.0)
	ray_spin.rotation.z = clock * 0.45
	if is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			ray_pivot.global_transform = Transform3D(Basis.looking_at(pos - cam.global_position, Vector3.UP), pos + Vector3(0, visual.position.y, 0))
