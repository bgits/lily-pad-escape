class_name LilyDuelFrog
extends Node3D

signal landed(frog: LilyDuelFrog)

const SIT_OFFSET := 0.6
const ARC_HEIGHT := 2.5
const DISMISS_TIME := 0.35

var pad: Node3D
var state := "sitting"
var visual: Node3D
var puff: Node3D
var clock := 0.0
var flight_time := 0.0
var flight_duration := 0.6
var flight_from := Vector3.ZERO
var flight_to := Vector3.ZERO
var squash := 0.0
var dismiss_clock := -1.0

func _ready() -> void:
	build_visual()

func build_visual() -> void:
	if visual:
		return
	visual = Node3D.new()
	add_child(visual)
	var green := LilyAvatar.material(Color("508c49"))
	var lime := LilyAvatar.material(Color("88b85a"))
	var belly := LilyAvatar.material(Color("dbe5a3"))
	var gold := LilyAvatar.material(Color("fff1a2"))
	var ink := LilyAvatar.material(Color("193d32"))
	LilyAvatar.box(visual, Vector3(0, 0.43, 0.03), Vector3(0.88, 0.55, 0.72), green)
	LilyAvatar.box(visual, Vector3(0, 0.43, -0.34), Vector3(0.72, 0.34, 0.12), belly)
	LilyAvatar.box(visual, Vector3(0, 0.63, -0.12), Vector3(0.96, 0.28, 0.65), lime)
	LilyAvatar.box(visual, Vector3(0, 0.48, -0.46), Vector3(0.60, 0.035, 0.02), ink)
	for side in [-1.0, 1.0]:
		LilyAvatar.box(visual, Vector3(side * 0.34, 0.84, -0.20), Vector3(0.32, 0.35, 0.31), green)
		LilyAvatar.box(visual, Vector3(side * 0.34, 0.85, -0.365), Vector3(0.25, 0.23, 0.04), gold)
		LilyAvatar.box(visual, Vector3(side * 0.34, 0.85, -0.39), Vector3(0.09, 0.15, 0.02), ink)
		LilyAvatar.box(visual, Vector3(side * 0.52, 0.19, 0.23), Vector3(0.36, 0.32, 0.48), green)
		LilyAvatar.box(visual, Vector3(side * 0.48, 0.07, -0.17), Vector3(0.42, 0.14, 0.47), lime)
		LilyAvatar.box(visual, Vector3(side * 0.29, 0.11, -0.44), Vector3(0.14, 0.24, 0.25), green)
	for x in [-0.24, 0.0, 0.24]:
		LilyAvatar.box(visual, Vector3(x, 0.72, 0.21), Vector3(0.13, 0.04, 0.16), green)
	puff = Node3D.new()
	puff.visible = false
	add_child(puff)
	var smoke := LilyAvatar.material(Color(0.9, 1.0, 0.8, 0.8))
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 5:
		LilyAvatar.box(puff, Vector3.ZERO, Vector3.ONE * 0.22, smoke)

func sit_position(target: Node3D) -> Vector3:
	var centre: Vector3 = target.call("surface_center")
	var outward := Vector3(centre.x, 0, centre.z)
	outward = outward.normalized() if outward.length() > 0.5 else Vector3.BACK
	return centre + outward * SIT_OFFSET

func outward_of(target: Node3D) -> Vector3:
	var centre: Vector3 = target.call("surface_center")
	var outward := Vector3(centre.x, 0, centre.z)
	return outward.normalized() if outward.length() > 0.5 else Vector3.BACK

func set_world_position(point: Vector3) -> void:
	if is_inside_tree():
		global_position = point
	else:
		position = point

func place(target: Node3D) -> void:
	build_visual()
	pad = target
	state = "sitting"
	dismiss_clock = -1.0
	visible = true
	puff.visible = false
	visual.scale = Vector3.ONE
	visual.rotation = Vector3.ZERO
	visual.position = Vector3.ZERO
	set_world_position(sit_position(target))
	rotation.y = atan2(outward_of(target).x, outward_of(target).z)
	reset_physics_interpolation()

func launch_to(target: Node3D, duration := 0.6) -> void:
	build_visual()
	flight_from = global_position if is_inside_tree() else position
	flight_to = sit_position(target)
	flight_duration = maxf(duration, 0.05)
	flight_time = 0.0
	pad = target
	state = "flying"
	dismiss_clock = -1.0
	visible = true
	puff.visible = false
	var heading := flight_to - flight_from
	if Vector2(heading.x, heading.z).length() > 0.1:
		rotation.y = atan2(-heading.x, -heading.z)

func dismiss() -> void:
	build_visual()
	if state == "gone":
		return
	state = "gone"
	dismiss_clock = 0.0
	puff.visible = true

func advance(delta: float) -> void:
	if not visual:
		return
	clock += delta
	if state == "gone":
		if dismiss_clock >= 0.0:
			dismiss_clock += delta
			var t := clampf(dismiss_clock / DISMISS_TIME, 0.0, 1.0)
			visual.scale = Vector3.ONE * maxf(0.001, 1.0 - t)
			visual.position.y = t * 0.4
			var spread := 0.2 + t * 0.9
			for i in puff.get_child_count():
				var angle := i * TAU / 5.0
				puff.get_child(i).position = Vector3(cos(angle) * spread, 0.45 + t * 0.4, sin(angle) * spread)
				puff.get_child(i).scale = Vector3.ONE * (1.0 - t * 0.6)
			if t >= 1.0:
				dismiss_clock = -1.0
				visible = false
				puff.visible = false
		return
	if state == "flying":
		flight_time += delta
		var t := clampf(flight_time / flight_duration, 0.0, 1.0)
		var point := flight_from.lerp(flight_to, t) + Vector3.UP * sin(t * PI) * ARC_HEIGHT
		set_world_position(point)
		visual.rotation = Vector3(t * TAU, 0, 0)
		visual.position = Vector3(0, 0.45, 0) - Basis(Vector3.RIGHT, t * TAU) * Vector3(0, 0.45, 0)
		visual.scale = Vector3(0.93, 1.12, 0.93)
		if t >= 1.0:
			state = "sitting"
			squash = 1.0
			visual.rotation = Vector3.ZERO
			visual.position = Vector3.ZERO
			set_world_position(flight_to)
			rotation.y = atan2(outward_of(pad).x, outward_of(pad).z)
			landed.emit(self)
		return
	squash = maxf(0.0, squash - delta * 4.0)
	var pulse := sin(clock * 4.4) * 0.025
	visual.scale = Vector3(1.0 + pulse + squash * 0.16, 1.0 - pulse * 1.4 - squash * 0.25, 1.0 + squash * 0.12)
	visual.position = Vector3.ZERO
