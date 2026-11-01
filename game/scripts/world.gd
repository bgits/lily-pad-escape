class_name LilyWorld
extends Node3D

var level: LilyLevel
var flag: Node3D
var elapsed := 0.0
var scenery := SurfaceTool.new()
var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var foam: Array[MeshInstance3D] = []
var frogs: Array[LilyFrog] = []
var decoys: Array[LilyDecoyPad] = []
var chance_pads: Array[LilyDecoyPad] = []
var bypass_pads: Array[StaticBody3D] = []
var drifting_pads: Array[LilyDriftingPad] = []
var fireflies: Array[LilyFirefly] = []
var chance_rng := RandomNumberGenerator.new()
var goal_ring: MeshInstance3D
var secret_perches: Array[StaticBody3D] = []

func advance_exploration(delta: float) -> void:
	for pad in drifting_pads:
		pad.advance(delta)
	for fly in fireflies:
		fly.advance(delta)

func reset_motion() -> void:
	for pad in drifting_pads:
		pad.reset_motion()

func set_motion_paused(paused: bool) -> void:
	for body in drifting_pads+frogs:
		var frozen: Transform3D = body.transform
		body.sync_to_physics = not paused
		if paused:
			# Discard a transform queued for the next physics tick, keeping the
			# physical support exactly where it was when play stopped.
			body.transform = frozen

func reset_decoys() -> void:
	for pad in decoys+chance_pads:
		pad.reset_trap()

func advance_decoys(delta: float) -> void:
	for pad in decoys+chance_pads:
		pad.advance(delta)

func animate_frogs(delta: float, player_position: Vector3) -> void:
	for frog in frogs:
		frog.animate(delta,player_position)
	for pad in decoys+chance_pads:
		if not pad.collapsed:
			pad.marker.animate(delta,player_position)

func reset_frogs() -> void:
	for frog in frogs:
		remove_child(frog)
		frog.queue_free()
	frogs.clear()
	for index in level.frog_pads:
		var frog := LilyFrog.new()
		frog.pad_index = index
		var pad := level.pads[index]
		frog.position = Vector3(pad.x,level.surface_height,pad.y-0.25)
		add_child(frog)
		frogs.append(frog)
	update_goal()

func frogs_remaining() -> int:
	var count := 0
	for frog in frogs:
		if frog.alive:
			count += 1
	return count

func update_goal() -> void:
	if is_instance_valid(goal_ring):
		goal_ring.material_override.albedo_color = Color("ebaa78") if frogs_remaining() > 0 else Color("fff0a5")

func frog_puff(pos: Vector3) -> void:
	var impact := Label3D.new()
	impact.text = "BONK!"
	impact.font_size = 48
	impact.outline_size = 10
	impact.pixel_size = 0.006
	impact.modulate = Color("fff0a5")
	impact.outline_modulate = Color("183f3b")
	impact.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	impact.no_depth_test = true
	impact.position = pos+Vector3.UP*2.2
	add_child(impact)
	particles.append({"node":impact,"velocity":Vector3.UP*0.8,"life":0.55,"gravity":0.0})
	for i in 18:
		var colors := [Color("fff1b5"),Color("dbe6b3"),Color("faf4dc")]
		var piece := LilyAvatar.box(self,pos+Vector3.UP*0.6,Vector3.ONE*rng.randf_range(0.08,0.18),LilyAvatar.material(colors[i%3]))
		particles.append({"node":piece,"velocity":Vector3(rng.randf_range(-2,2),rng.randf_range(1,3),rng.randf_range(-2,2)),"life":0.45})

func poison_burst(pos: Vector3) -> void:
	for i in 16:
		var piece := LilyAvatar.box(self,pos+Vector3.UP*0.8,Vector3.ONE*rng.randf_range(0.08,0.16),LilyAvatar.material(Color("be94d4")))
		particles.append({"node":piece,"velocity":Vector3(rng.randf_range(-1.5,1.5),rng.randf_range(1,3),rng.randf_range(-1.5,1.5)),"life":0.7})

static func vertex_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = false
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	st.set_normal(normal)
	st.set_color(color.srgb_to_linear())
	for v in [a, c, b, a, d, c]:
		st.add_vertex(v)

static func block(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var p := center - size * 0.5
	var q := center + size * 0.5
	quad(st, Vector3(p.x,q.y,p.z), Vector3(p.x,q.y,q.z), Vector3(q.x,q.y,q.z), Vector3(q.x,q.y,p.z), Vector3.UP, color)
	quad(st, Vector3(p.x,p.y,q.z), Vector3(p.x,p.y,p.z), Vector3(q.x,p.y,p.z), Vector3(q.x,p.y,q.z), Vector3.DOWN, color.darkened(0.2))
	quad(st, Vector3(p.x,p.y,p.z), Vector3(p.x,p.y,q.z), Vector3(p.x,q.y,q.z), Vector3(p.x,q.y,p.z), Vector3.LEFT, color.darkened(0.12))
	quad(st, Vector3(q.x,p.y,q.z), Vector3(q.x,p.y,p.z), Vector3(q.x,q.y,p.z), Vector3(q.x,q.y,q.z), Vector3.RIGHT, color)
	quad(st, Vector3(q.x,p.y,p.z), Vector3(p.x,p.y,p.z), Vector3(p.x,q.y,p.z), Vector3(q.x,q.y,p.z), Vector3.FORWARD, color.darkened(0.10))
	quad(st, Vector3(p.x,p.y,q.z), Vector3(q.x,p.y,q.z), Vector3(q.x,q.y,q.z), Vector3(p.x,q.y,q.z), Vector3.BACK, color)

func build(data: LilyLevel) -> void:
	level = data
	rng.seed = 8142
	# Gameplay rolls use fresh entropy, independently of repeatable scenery colors.
	chance_rng.randomize()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("63b6df")
	sky_mat.sky_horizon_color = Color("c5e6df")
	sky_mat.ground_bottom_color = Color("7cc9d1")
	sky_mat.ground_horizon_color = Color("c5e6df")
	sky_mat.sky_curve = 0.2
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d0e0ea")
	env.ambient_light_energy = 0.45
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("a1d5d5")
	env.fog_density = 0.0035
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_color = Color("fff6ea")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(350, 350)
	water.mesh = plane
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	water.material_override = water_mat
	water.position = Vector3(0, level.water_height, -30)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	for i in level.pads.size():
		var p := level.pads[i]
		if i in level.chance_pad_indices:
			var chance := make_pad(Vector3(p.x,0,p.y),p.z,i,true) as LilyDecoyPad
			chance.is_chance = true
			chance.set_meta("pad_index",i)
			attach_marker(chance,i,true)
			chance_pads.append(chance)
		else:
			make_pad(Vector3(p.x, 0, p.y), p.z, i)
	for i in level.decoy_pads.size():
		var p := level.decoy_pads[i]
		var decoy := make_pad(Vector3(p.x,0,p.y),p.z,i,true) as LilyDecoyPad
		attach_marker(decoy,i,false)
		decoys.append(decoy)
	make_island()
	scenery.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Scenic shores are deliberately beyond jumping range.
	for side in [-1, 1]:
		for i in 9:
			var center := Vector3(side * rng.randf_range(18, 27), 0, 12 - i * 9)
			make_scenic_island(center, rng.randf_range(3, 6), rng.randf_range(2, 5))
	for i in 10:
		var center := Vector3(-44 + i * 10, 0, minf(-82, level.island_center.z - 30) - rng.randf_range(0, 12))
		make_scenic_island(center, rng.randf_range(5, 9), rng.randf_range(5, 11))
	# Foreground collision must not shift when route pads are added or resized.
	var scenery_state := rng.state
	rng.seed = 8142
	# Foreground rock/reed groups frame the starting pad without blocking it.
	for center in [Vector3(-8, 0, 0), Vector3(8, 0, 3), Vector3(-8, 0, -12), Vector3(12, 0, -23)]:
		for j in 5:
			var pos: Vector3 = center + Vector3(rng.randf_range(-1.8,1.8), 0, rng.randf_range(-1.5,1.5))
			var h := rng.randf_range(0.5, 1.6)
			var rock_center := pos + Vector3.UP * (h * 0.5 - 0.15)
			var rock_size := Vector3(0.8,h,0.9)
			var rock_color := Color("9aaca5").lightened(rng.randf_range(-0.1,0.1))
			if center == Vector3(-8,0,0):
				make_secret_perch(rock_center,rock_size,rock_color)
			else:
				block(scenery,rock_center,rock_size,rock_color)
			reeds(pos + Vector3(0.5, 0, 0.5), 4)
	rng.state = scenery_state
	for i in 20:
		var center := Vector3(rng.randf_range(-80,80), rng.randf_range(22,32), rng.randf_range(-100,-20))
		for j in 4:
			block(scenery, center + Vector3(j*2.2, rng.randf_range(-0.5,1), 0), Vector3(rng.randf_range(3,6), rng.randf_range(1.4,2.6), 3), Color("e3f1e8"))
	var combined := MeshInstance3D.new()
	combined.mesh = scenery.commit()
	combined.material_override = vertex_material()
	add_child(combined)
	combined.create_trimesh_collision()
	# Build after scenery so adding a route preserves the existing secret pillars.
	for i in level.bypass_pads.size():
		var p := level.bypass_pads[i]
		var pad := make_pad(Vector3(p.x,0,p.y),p.z,-1)
		pad.name = "BypassPad%02d" % i
		pad.set_meta("bypass_index",i)
		bypass_pads.append(pad)
	build_exploration()
	reset_frogs()

func build_exploration() -> void:
	if level.drift_pad.z > 0:
		var p := level.drift_pad
		var pad := make_pad(Vector3(p.x,0,p.y),p.z,-1,false,true) as LilyDriftingPad
		pad.home = pad.position
		pad.travel = level.drift_travel
		pad.set_meta("drifting",true)
		drifting_pads.append(pad)
		add_flowers(pad)
	for p in level.exploration_pads:
		var pad := make_pad(Vector3(p.x,0,p.y),p.z,-1)
		add_flowers(pad)
	for i in level.fireflies.size():
		var fly := LilyFirefly.new()
		fly.index = i
		if i == 0 and not drifting_pads.is_empty():
			fly.position = level.fireflies[i]-drifting_pads[0].position
			drifting_pads[0].add_child(fly)
		else:
			fly.position = level.fireflies[i]
			add_child(fly)
		fireflies.append(fly)

func add_flowers(parent: Node3D) -> void:
	for i in 3:
		var p := Vector3(-0.45+i*0.23,level.surface_height+0.05,0.35)
		LilyAvatar.box(parent,p,Vector3(0.25,0.08,0.25),LilyAvatar.material(Color("f4a6b0")))
		LilyAvatar.box(parent,p+Vector3.UP*0.05,Vector3(0.09,0.05,0.09),LilyAvatar.material(Color("fff0ad")))

func firefly_puff(pos: Vector3) -> void:
	for i in 12:
		var angle := i*TAU/12
		var piece := LilyAvatar.box(self,pos,Vector3.ONE*0.07,LilyAvatar.material(Color("ffe775")))
		particles.append({"node":piece,"velocity":Vector3(cos(angle)*1.2,1.0,sin(angle)*1.2),"life":0.5,"gravity":0.0})

func make_secret_perch(pos: Vector3, size: Vector3, color: Color) -> void:
	# Preserve the discovered rocks exactly; separate their collision from scenery.
	var body := StaticBody3D.new()
	body.name = "SecretPerch%d" % secret_perches.size()
	body.position = pos
	body.set_meta("secret_perch",true)
	body.set_meta("top",pos.y+size.y*0.5)
	add_child(body)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	block(st,Vector3.ZERO,size,color)
	var visual := MeshInstance3D.new()
	visual.mesh = st.commit()
	visual.material_override = vertex_material()
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	secret_perches.append(body)

func attach_marker(pad: LilyDecoyPad, index: int, yellow: bool) -> void:
	var frog := LilyFrog.new()
	frog.is_decoy = not yellow
	frog.is_chance = yellow
	frog.pad_index = index
	frog.position = Vector3(0,level.surface_height,-0.25)
	pad.add_child(frog)
	pad.marker = frog

func make_pad(pos: Vector3, radius: float, index: int, fake := false, drifting := false) -> StaticBody3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := 0.23
	var count := ceili(radius / cell)
	var cells: Dictionary = {}
	for x in range(-count, count):
		for z in range(-count, count):
			var v := Vector2((x + 0.5) * cell, (z + 0.5) * cell)
			# The notch faces the side, away from the intended approach/landing line.
			var notch := v.x > radius * 0.25 and absf(v.y) < (v.x - radius * 0.25) * 0.26
			if v.length() < radius and not notch:
				cells[Vector2i(x,z)] = true
	for key: Vector2i in cells:
		var x := key.x * cell
		var z := key.y * cell
		var top := level.surface_height
		var bottom := top - 0.25
		var color := Color("a5ce46").lightened(rng.randf_range(-0.12, 0.13))
		if absf(z) < cell * 0.7 or absf(z - x * 0.6) < cell * 0.5 or absf(z + x * 0.6) < cell * 0.5:
			color = Color("81af3b")
		quad(st, Vector3(x,top,z), Vector3(x,top,z+cell), Vector3(x+cell,top,z+cell), Vector3(x+cell,top,z), Vector3.UP, color)
		var edge := Color("548b3c").lightened(rng.randf_range(-0.10,0.10))
		if not cells.has(key + Vector2i(1,0)):
			quad(st, Vector3(x+cell,bottom,z+cell), Vector3(x+cell,bottom,z), Vector3(x+cell,top,z), Vector3(x+cell,top,z+cell), Vector3.RIGHT, edge)
		if not cells.has(key + Vector2i(-1,0)):
			quad(st, Vector3(x,bottom,z), Vector3(x,bottom,z+cell), Vector3(x,top,z+cell), Vector3(x,top,z), Vector3.LEFT, edge)
		if not cells.has(key + Vector2i(0,1)):
			quad(st, Vector3(x,bottom,z+cell), Vector3(x+cell,bottom,z+cell), Vector3(x+cell,top,z+cell), Vector3(x,top,z+cell), Vector3.BACK, edge)
		if not cells.has(key + Vector2i(0,-1)):
			quad(st, Vector3(x+cell,bottom,z), Vector3(x,bottom,z), Vector3(x,top,z), Vector3(x+cell,top,z), Vector3.FORWARD, edge)
	var body: StaticBody3D = LilyDriftingPad.new() if drifting else (LilyDecoyPad.new() if fake else StaticBody3D.new())
	body.name = ("DecoyPad%02d" if fake else "LilyPad%02d") % index
	body.position = pos
	if not fake and index >= 0:
		body.set_meta("pad_index", index)
	add_child(body)
	var mesh := st.commit()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = vertex_material()
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collider.shape = shape
	body.add_child(collider)
	if body is LilyDecoyPad:
		body.collider = collider
	var ripple := make_ripple(pos, radius + 0.15)
	if drifting:
		ripple.reparent(body)
	# Two small flowers on the practice pad establish scale.
	if index == 0 and not fake:
		var white := LilyAvatar.material(Color("fff4cf"))
		for flower_pos in [Vector3(-1.8,0.67,-0.6),Vector3(-1.55,0.67,-0.95)]:
			LilyAvatar.box(self, pos+flower_pos, Vector3(0.25,0.06,0.25), white)
			LilyAvatar.box(self, pos+flower_pos+Vector3.UP*0.04, Vector3(0.11,0.04,0.11), LilyAvatar.material(Color("f6c844")))
	return body

func make_ripple(pos: Vector3, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius
	mesh.outer_radius = radius + 0.035
	mesh.rings = 48
	mesh.ring_segments = 4
	node.mesh = mesh
	node.position = pos + Vector3.UP * 0.075
	node.scale.y = 0.25
	var mat := LilyAvatar.material(Color(0.66,0.91,0.83,0.42))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	foam.append(node)
	return node

func make_island() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.5
	for x in range(-7,7):
		for z in range(-7,7):
			var p := Vector2((x+0.5)*step,(z+0.5)*step)
			if p.length() > level.island_radius:
				continue
			var center := Vector3(p.x, 0.05, p.y)
			block(st, center, Vector3(step,0.95,step), Color("937955").lightened(rng.randf_range(-0.15,0.1)))
			block(st, center + Vector3.UP*0.50, Vector3(step,0.10,step), Color("80b847").lightened(rng.randf_range(-0.07,0.13)))
	var body := StaticBody3D.new()
	body.name = "FinishIsland"
	body.position = level.island_center
	body.set_meta("finish", true)
	add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = st.commit()
	visual.material_override = vertex_material()
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := visual.mesh.create_trimesh_shape()
	shape.backface_collision = true
	collider.shape = shape
	body.add_child(collider)
	LilyAvatar.box(self, level.flag_position + Vector3.UP * 1.6, Vector3(0.13,3.2,0.13), LilyAvatar.material(Color("88603a")))
	LilyAvatar.box(self, level.flag_position + Vector3.UP * 3.27, Vector3(0.22,0.18,0.22), LilyAvatar.material(Color("fff0ae")))
	flag = Node3D.new()
	flag.position = level.flag_position + Vector3(0.1,2.65,0)
	add_child(flag)
	var flag_st := SurfaceTool.new()
	flag_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		block(flag_st, Vector3(i*0.18+0.09,0,0),Vector3(0.18,0.78-i*0.10,0.055), Color("ffce46"))
	var flag_mesh := MeshInstance3D.new()
	flag_mesh.mesh = flag_st.commit()
	flag_mesh.material_override = vertex_material()
	flag.add_child(flag_mesh)
	for i in 12:
		var angle := rng.randf_range(0,TAU)
		var p := level.island_center + Vector3(cos(angle)*2.5,0.66,sin(angle)*2.5)
		LilyAvatar.box(self,p,Vector3(0.16,0.1,0.16),LilyAvatar.material(Color("fff0bc")))
	make_ripple(level.island_center, level.island_radius + 0.1)
	if level.has_bat:
		goal_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 1.3
		ring.outer_radius = 1.4
		ring.rings = 32
		ring.ring_segments = 6
		goal_ring.mesh = ring
		goal_ring.position = level.flag_position + Vector3.UP*0.08
		goal_ring.material_override = LilyAvatar.material(Color("ebaa78"))
		add_child(goal_ring)

func make_scenic_island(center: Vector3, radius: float, height: float) -> void:
	for x in range(-ceili(radius),ceili(radius)):
		for z in range(-ceili(radius),ceili(radius)):
			if Vector2(x+0.5,z+0.5).length() > radius:
				continue
			var h := height + rng.randf_range(-0.25,0.25)
			var p := center + Vector3(x+0.5,h*0.5-0.2,z+0.5)
			block(scenery,p,Vector3(1.0,h,1.0),Color("8a9985").lightened(rng.randf_range(-0.12,0.12)))
			block(scenery,p+Vector3.UP*(h*0.5+0.08),Vector3(1.0,0.24,1.0),Color("78a948").lightened(rng.randf_range(-0.1,0.1)))
	for i in 3:
		var p := center + Vector3(rng.randf_range(-radius*0.6,radius*0.6),height,rng.randf_range(-radius*0.6,radius*0.6))
		tree(p, rng.randf_range(0.8,1.4))

func tree(p: Vector3, s: float) -> void:
	block(scenery,p+Vector3(0,1.5*s,0),Vector3(0.5,3.4,0.5)*s,Color("82633e"))
	for i in 5:
		var pos := p+Vector3(rng.randf_range(-1,1),rng.randf_range(2.8,4.2),rng.randf_range(-1,1))*s
		block(scenery,pos,Vector3(2.2,1.5,2.0)*s,Color("64984c").lightened(rng.randf_range(-0.12,0.16)))

func reeds(p: Vector3, count: int) -> void:
	for i in count:
		var h := rng.randf_range(0.9,1.7)
		var pos := p + Vector3(rng.randf_range(-0.6,0.6),h*0.5,rng.randf_range(-0.6,0.6))
		block(scenery,pos,Vector3(0.07,h,0.07),Color("52874b"))
		block(scenery,pos+Vector3.UP*h*0.48,Vector3(0.15,0.35,0.15),Color("ad7845"))

func splash(pos: Vector3) -> void:
	for i in 24:
		var piece := LilyAvatar.box(self, Vector3(pos.x,0.12,pos.z),Vector3.ONE*rng.randf_range(0.08,0.16),LilyAvatar.material(Color("b8f2de")))
		var angle := rng.randf_range(0,TAU)
		particles.append({"node":piece,"velocity":Vector3(cos(angle)*rng.randf_range(1,3),rng.randf_range(2,5),sin(angle)*rng.randf_range(1,3)),"life":0.8})

func celebrate(pos: Vector3) -> void:
	for i in 50:
		var colors := [Color("f6cc48"),Color("e98165"),Color("c4e673")]
		var piece := LilyAvatar.box(self,pos+Vector3.UP*2,Vector3(0.10,0.14,0.04),LilyAvatar.material(colors[i%3]))
		particles.append({"node":piece,"velocity":Vector3(rng.randf_range(-3,3),rng.randf_range(2,6),rng.randf_range(-3,3)),"life":2.5})

func animate(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(flag):
		flag.rotation.y = sin(elapsed*2.2)*0.15
		flag.rotation.z = sin(elapsed*2.8)*0.035
	for i in foam.size():
		var s := 1.0 + sin(elapsed*1.3+i)*0.015
		foam[i].scale = Vector3(s,0.25,s)
	for i in range(particles.size()-1,-1,-1):
		var p := particles[i]
		p.life -= delta
		p.velocity.y -= delta*float(p.get("gravity",10.0))
		p.node.position += p.velocity*delta
		if not p.node is Label3D:
			p.node.rotation += Vector3(delta,delta*2,delta)
		if p.life <= 0:
			p.node.queue_free()
			particles.remove_at(i)

func clear_particles() -> void:
	for p in particles:
		p.node.queue_free()
	particles.clear()
