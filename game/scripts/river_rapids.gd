class_name RiverRapids
extends Node3D

# Every section has an arc-length path and an oriented running surface. Progress
# follows the course, not world Z (which reverses in the loop and spiral).
var legs: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var total_distance := 0.0
var progress := 0.0
var furthest := 0.0
var wave_progress := -38.0
var wave_grace := 4.0
var wave_enabled := true
var wave: Node3D
var wave_fronts: Array[Node3D] = []
var best_marker: Node3D
var beginner := false
var cruise_speed := 21.0
var throttle_speed := 25.0
var boost_speed := 33.0
var speed_limit := 34.0
var steer_speed := 7.5
var wave_speed := 21.0
var start_grace := 4.0
var loop_camera := Vector3(108,43,-355)
var loop_focus := Vector3(39,30,-400)

func build(world: LilyWorld) -> void:
	beginner = world.level.rapids_beginner
	if beginner:
		cruise_speed = 19
		throttle_speed = 23
		boost_speed = 29
		speed_limit = 30
		steer_speed = 6
		wave_speed = 13
		start_grace = 8
		loop_camera = Vector3(78,43,-295)
		loop_focus = Vector3(9,26,-340)
		build_beginner_path()
	else:
		build_expert_path()
	for i in legs.size():
		var leg := legs[i]
		if leg.kind != "gap":
			make_track(leg.path,leg.kind,i,false)
			if leg.has("shortcut"): make_track(leg.shortcut,"shortcut",i,true)
	if beginner:
		# Leave a clear central line while offering optional steering practice.
		make_hazard(0,135,4)
		make_hazard(4,75,-4)
		signpost(Vector3(0,22,-14),"RIVER GLIDE\nA / D steer • W accelerate • S brake\nSPACE hop • SHIFT boost",0.009)
		signpost(Vector3(0,14,-310),"YOUR FIRST LOOP\nStay on the board and enjoy the ride",0.008)
	else:
		decorate_expert()
	make_scenery(world)
	make_finish(world)
	world.build_exploration()
	best_marker = signpost(Vector3.ZERO,"PERSONAL BEST",0.008)
	wave = Node3D.new()
	add_child(wave)
	for i in 2:
		var front := Node3D.new()
		wave.add_child(front)
		LilyAvatar.box(front,Vector3(0,1.5,0),Vector3(1,3,1.2),LilyAvatar.material(Color("41bdcf")))
		LilyAvatar.box(front,Vector3(0,3,0),Vector3(1,0.25,1.3),LilyAvatar.material(Color("d9fff0")))
		wave_fronts.append(front)
	reset()

func build_expert_path() -> void:
	add_leg("BOARDWALK • GET UP TO SPEED",curve([Vector3(0,18,8),Vector3(0,18,-22),Vector3(0,15,-62),Vector3(-10,7,-112),Vector3(-15,15,-170),Vector3(8,6,-225),Vector3(30,9.4,-255),Vector3(30,10,-270)],9.0,0.15))
	add_gap("FIRST FLIGHT",Vector3(30,10,-270),Vector3(30,7,-287),10.0)
	add_leg("LOOP APPROACH",curve([Vector3(30,7,-287),Vector3(30,6,-320),Vector3(30,8,-365),Vector3(30,8,-400)],8.0,0))
	add_leg("MAGNETIC LOOP",loop_path(Vector3(30,8,-400),22.0),"loop")
	add_leg("RIVER SWEEP",curve([Vector3(48,8,-400),Vector3(48,8,-445),Vector3(63,12,-500),Vector3(65,12,-540)],8.0,0.25))
	add_leg("CHOOSE A LANE • LEFT FAST / RIGHT WIDE",curve([Vector3(65,12,-540),Vector3(65,12,-560)],24.0,0),"fork")
	var wide := curve([Vector3(73,12,-560),Vector3(73,12,-572),Vector3(95,7,-590),Vector3(125,6,-625),Vector3(107,8,-660),Vector3(73,12,-680),Vector3(73,12,-690)],8.0,0.30)
	var fast := curve([Vector3(57,12,-560),Vector3(57,12,-572),Vector3(45,17,-590),Vector3(45,17,-635),Vector3(57,12,-680),Vector3(57,12,-690)],4.8,-0.20)
	add_leg("SPLIT RIVER",wide,"split",fast)
	add_leg("THE REJOIN",curve([Vector3(65,12,-690),Vector3(65,12,-710),Vector3(85,10,-750),Vector3(100,10,-782),Vector3(100,10,-795)],24.0,0),"merge")
	# Spiral begins tangent to the approach, and successive turns are separated vertically.
	add_leg("SKY SPIRAL",spiral_path(Vector3(60,10,-795),40.0,1.5,36.0),"spiral")
	add_leg("HIGH BANKS",curve([Vector3(20,46,-795),Vector3(20,44,-755),Vector3(-30,36,-725),Vector3(-85,25,-775),Vector3(-100,14,-870),Vector3(-100,17,-920)],7.0,0.32))
	add_gap("CANYON JUMP",Vector3(-100,17,-920),Vector3(-100,10,-944),11.0)
	add_leg("SLALOM RUN",curve([Vector3(-100,10,-944),Vector3(-100,7,-980),Vector3(-122,9,-1020),Vector3(-80,12,-1070),Vector3(-105,8,-1120),Vector3(-100,9.3,-1138),Vector3(-100,10,-1150)],6.5,0.32))
	add_gap("FINAL FLIGHT",Vector3(-100,10,-1150),Vector3(-100,6,-1172),10.5)
	add_leg("HOME STRETCH",curve([Vector3(-100,6,-1172),Vector3(-100,5,-1210),Vector3(-100,7,-1250),Vector3(-100,5,-1300)],8.0,0.10))

func decorate_expert() -> void:
	# Clear lane challenges: blocks can be steered around or jumped over.
	for entry in [[0,95.0,-1.0],[0,185.0,1.0],[2,55.0,-1.0],[4,55.0,1.0],[8,90.0,-0.9],[8,210.0,0.9],[8,320.0,-0.9],[9,110.0,-1.0],[11,55.0,1.0],[11,135.0,-1.0],[13,55.0,1.0]]:
		make_hazard(int(entry[0]),float(entry[1]),float(entry[2]))
	for i in [2,4,7,9,11,13]:
		var p: Vector3 = frame(i,8.0).p
		signpost(p+Vector3.UP*5,legs[i].label,0.006)
	signpost(Vector3(0,22,-12),"HOVERBOARD\nA / D steer • W accelerate • S brake\nSPACE hop • SHIFT boost",0.009)
	signpost(Vector3(30,14,-373),"MAGNETIC LOOP\nKeep your line — the board holds on",0.008)
	# The fork has two distinct portals; there is no overlapping road geometry.
	for x in [57.0,73.0]:
		signpost(Vector3(x,15,-553),"FAST" if x < 65 else "WIDE",0.008)
	for x in [57.0,73.0]:
		for z in [-546.0,-551.0,-556.0]:
			for side in [-1,1]:
				var arrow := LilyAvatar.box(self,Vector3(x+side*0.55,12.04,z),Vector3(0.16,0.04,1.5),LilyAvatar.material(Color("fff0b5")))
				arrow.rotation.y = side*0.8

func build_beginner_path() -> void:
	add_leg("FIND YOUR FLOW",curve([Vector3(0,18,8),Vector3(0,18,-30),Vector3(-8,12,-85),Vector3(10,8,-140),Vector3(0,12,-205),Vector3(0,10,-230),Vector3(0,10,-240)],14.0,0.08))
	add_gap("LITTLE LEAP",Vector3(0,10,-240),Vector3(0,8,-246),16.0)
	add_leg("A GENTLE LANDING",curve([Vector3(0,8,-246),Vector3(0,8,-300),Vector3(0,8,-340)],14.0,0))
	var loop := loop_path(Vector3(0,8,-340),18.0)
	for f in loop.frames: f.width = 12.0
	add_leg("YOUR FIRST LOOP",loop,"loop")
	add_leg("WIDE RIVER BEND",curve([Vector3(18,8,-340),Vector3(18,8,-380),Vector3(42,10,-430),Vector3(70,10,-475),Vector3(70,10,-500)],14.0,0.10))
	var spiral := spiral_path(Vector3(25,10,-500),45.0,0.5,14.0)
	for f in spiral.frames:
		f.width = 12.0
		# Gentler banking on the introductory spiral.
		f.right = Vector3(f.f).cross(Vector3.UP).normalized()
		f.up = Vector3(f.right).cross(Vector3(f.f)).normalized()
	add_leg("SKY SWEEP",spiral,"spiral")
	add_leg("CRUISE TO THE FINISH",curve([Vector3(-20,24,-500),Vector3(-20,24,-460),Vector3(-65,22,-455),Vector3(-115,16,-510),Vector3(-130,10,-580),Vector3(-130,8,-650),Vector3(-130,6,-720)],14.0,0.10))

func curve(points: Array, width: float, bank: float) -> Dictionary:
	var positions: Array[Vector3] = []
	for i in range(points.size()-1):
		var a: Vector3 = points[maxi(0,i-1)]
		var b: Vector3 = points[i]
		var c: Vector3 = points[i+1]
		var d: Vector3 = points[mini(points.size()-1,i+2)]
		var count := maxi(2,ceili(b.distance_to(c)))
		for j in count:
			var t := float(j)/count
			var p := 0.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
			p.y = clampf(p.y,minf(b.y,c.y),maxf(b.y,c.y))
			positions.append(p)
	positions.append(points[-1])
	var frames: Array[Dictionary] = []
	for i in positions.size():
		var f := (positions[mini(i+1,positions.size()-1)]-positions[maxi(i-1,0)]).normalized()
		if i == 0: f = (Vector3(points[1])-Vector3(points[0])).normalized()
		if i == positions.size()-1: f = (Vector3(points[-1])-Vector3(points[-2])).normalized()
		var right := f.cross(Vector3.UP).normalized()
		var up := right.cross(f).normalized()
		var fade := sin(PI*float(i)/(positions.size()-1))
		up = up.rotated(f,bank*fade)
		right = f.cross(up).normalized()
		frames.append({"p":positions[i],"f":f,"up":up,"right":right,"width":width})
	return finish_path(frames)

func loop_path(origin: Vector3, radius: float) -> Dictionary:
	var frames: Array[Dictionary] = []
	for i in 221:
		var t := float(i)/220*TAU
		var u := t/TAU
		var f := Vector3(18.0*6*u*(1-u)/TAU,radius*sin(t),-radius*cos(t)).normalized()
		var up := Vector3(0,cos(t),sin(t))
		frames.append({"p":origin+Vector3(18.0*u*u*(3-2*u),radius*(1-cos(t)),-radius*sin(t)),"f":f,"up":up,"right":f.cross(up).normalized(),"width":6.5})
	return finish_path(frames)

func spiral_path(center: Vector3, radius: float, turns: float, rise: float) -> Dictionary:
	var frames: Array[Dictionary] = []
	for i in 451:
		var t := float(i)/450*TAU*turns
		var u := float(i)/450
		var f := Vector3(-radius*sin(t),rise*(1-cos(TAU*u))/(TAU*turns),-radius*cos(t)).normalized()
		var right := f.cross(Vector3.UP).normalized()
		var bank_fade := clampf(minf(t,TAU*turns-t)/0.45,0,1)
		var up := right.cross(f).normalized().rotated(f,-0.30*bank_fade)
		frames.append({"p":center+Vector3(radius*cos(t),rise*(u-sin(TAU*u)/TAU),-radius*sin(t)),"f":f,"up":up,"right":f.cross(up).normalized(),"width":5.6})
	return finish_path(frames)

func finish_path(frames: Array[Dictionary]) -> Dictionary:
	var length := 0.0
	for i in frames.size():
		if i > 0: length += Vector3(frames[i].p).distance_to(frames[i-1].p)
		frames[i].s = length
	return {"frames":frames,"length":length}

func add_leg(label: String, path: Dictionary, kind := "track", shortcut := {}) -> void:
	var leg := {"label":label,"path":path,"kind":kind,"start":total_distance,"length":path.length}
	if not shortcut.is_empty(): leg.shortcut = shortcut
	legs.append(leg)
	total_distance += float(path.length)

func add_gap(label: String, a: Vector3, b: Vector3, width: float) -> void:
	add_leg(label,curve([a,b],width,0),"gap")

func frame(index: int, distance: float, shortcut := false) -> Dictionary:
	var leg := legs[clampi(index,0,legs.size()-1)]
	var path: Dictionary = leg.shortcut if shortcut and leg.has("shortcut") else leg.path
	var frames: Array = path.frames
	var lo := 0
	var hi := frames.size()-1
	while hi-lo > 1:
		var mid := (lo+hi)/2
		if float(frames[mid].s) < distance: lo = mid
		else: hi = mid
	var a: Dictionary = frames[lo]
	var b: Dictionary = frames[hi]
	var t := clampf(inverse_lerp(float(a.s),float(b.s),distance),0,1)
	var f: Vector3 = Vector3(a.f).lerp(b.f,t).normalized()
	var up: Vector3 = Vector3(a.up).lerp(b.up,t).normalized()
	var right := f.cross(up).normalized()
	up = right.cross(f).normalized()
	var width := lerpf(float(a.width),float(b.width),t)
	if leg.kind == "merge": width = lerpf(24,8,clampf((distance-15)/28,0,1))
	if index > 0 and legs[index-1].kind in ["loop","spiral"]:
		width = lerpf(float(legs[index-1].path.frames[-1].width),width,clampf(distance/18,0,1))
	if index+1 < legs.size() and legs[index+1].kind == "fork":
		width = lerpf(width,24,clampf((distance-float(path.length)+25)/25,0,1))
	if index+1 < legs.size() and legs[index+1].kind in ["loop","spiral"]:
		var next_width: float = legs[index+1].path.frames[0].width
		width = lerpf(width,next_width,clampf((distance-float(path.length)+18)/18,0,1))
	return {"p":Vector3(a.p).lerp(b.p,t),"f":f,"up":up,"right":right,"width":width,"basis":Basis(right,up,-f)}

func path_length(index: int, shortcut := false) -> float:
	return float(legs[index].shortcut.length) if shortcut and legs[index].has("shortcut") else float(legs[index].length)

func course_progress(index: int, distance: float, shortcut := false) -> float:
	return float(legs[index].start)+clampf(distance/path_length(index,shortcut),0,1)*float(legs[index].length)

func location(s: float, shortcut := false) -> Dictionary:
	for i in legs.size():
		if s <= float(legs[i].start)+float(legs[i].length):
			var d := (s-float(legs[i].start))/float(legs[i].length)*path_length(i,shortcut)
			return {"leg":i,"distance":d,"frame":frame(i,d,shortcut)}
	return {"leg":legs.size()-1,"distance":path_length(legs.size()-1),"frame":frame(legs.size()-1,path_length(legs.size()-1))}

func at_distance(s: float) -> Vector3:
	return location(s).frame.p

func make_track(path: Dictionary, kind: String, index: int, shortcut: bool) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frames: Array = path.frames
	var base := Color("7dbb63")
	if kind in ["loop","spiral"]: base = Color("345877")
	if shortcut: base = Color("c5a46a")
	if kind == "split" and not shortcut: base = Color("6bbaac")
	for i in range(frames.size()-1):
		var a := frame(index,frames[i].s,shortcut)
		var b := frame(index,frames[i+1].s,shortcut)
		for j in 4:
			var u := float(j)/4-0.5
			var v := float(j+1)/4-0.5
			var pa: Vector3 = a.p+a.right*float(a.width)*u
			var pb: Vector3 = b.p+b.right*float(b.width)*u
			var pc: Vector3 = b.p+b.right*float(b.width)*v
			var pd: Vector3 = a.p+a.right*float(a.width)*v
			LilyWorld.quad(mesh,pa,pd,pc,pb,a.up,base.lightened(0.035*sin(i*0.35)))
		# Raised luminous edges establish the width without invisible collision walls.
		for side in [-1,1]:
			var pa: Vector3 = a.p+a.right*float(a.width)*0.5*side
			var pb: Vector3 = b.p+b.right*float(b.width)*0.5*side
			LilyWorld.quad(mesh,pa,pa+a.up*(0.65 if beginner else 0.15),pb+b.up*(0.65 if beginner else 0.15),pb,a.up,Color("b8ffe2") if kind in ["loop","spiral"] else Color("d3ed90"))
			LilyWorld.quad(mesh,pa,pa-a.up*0.65,pb-b.up*0.65,pb,a.right*side,base.darkened(0.3))
	var node := MeshInstance3D.new()
	node.mesh = mesh.commit()
	node.material_override = LilyWorld.vertex_material()
	add_child(node)
	# Collision queries and analytic board support use the same visible surface.
	node.create_trimesh_collision()
	if kind == "spiral":
		for i in range(0,frames.size(),35):
			var p: Vector3 = frames[i].p+frames[i].right*(float(frames[i].width)*0.5+1.7)
			var h := maxf(0.5,p.y-0.6)
			LilyAvatar.box(self,Vector3(p.x,p.y-h*0.5-0.7,p.z),Vector3(0.55,h,0.55),LilyAvatar.material(Color("527078")))
	# Launch stripes on the actual takeoff lip.
	if index+1 < legs.size() and legs[index+1].kind == "gap":
		for d in [1.0,2.0,3.0]:
			var f := frame(index,float(path.length)-d,shortcut)
			var stripe := LilyAvatar.box(self,f.p+f.up*0.025,Vector3(float(f.width)*0.85,0.04,0.17),LilyAvatar.material(Color("ffe88b")))
			stripe.basis = f.basis

func make_hazard(index: int, distance: float, lateral: float) -> void:
	var f := frame(index,distance)
	var position: Vector3 = f.p+f.right*lateral+f.up*0.65
	var block := Node3D.new()
	block.transform = Transform3D(f.basis,position)
	add_child(block)
	LilyAvatar.box(block,Vector3.ZERO,Vector3(2.2,1.3,1.8),LilyAvatar.material(Color("d66b59")))
	LilyAvatar.box(block,Vector3(0,0.7,0),Vector3(2.3,0.12,1.9),LilyAvatar.material(Color("ffe28e")))
	hazards.append({"leg":index,"distance":distance,"lateral":lateral,"half_width":1.1,"height":1.3})

func signpost(position: Vector3, text: String, scale_size: float) -> Label3D:
	var label := Label3D.new()
	label.position = position
	label.text = text
	label.font_size = 48
	label.pixel_size = scale_size
	label.outline_size = 8
	label.modulate = Color("fff3c8")
	label.outline_modulate = Color("214b42")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return label

func make_scenery(world: LilyWorld) -> void:
	world.scenery.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,int(total_distance),45):
		var f: Dictionary = location(float(i)).frame
		for side in [-1,1]:
			var p: Vector3 = f.p+f.right*side*24
			p.y = -1
			world.make_scenic_island(p,3.5,3.2)
	var mesh := MeshInstance3D.new()
	mesh.mesh = world.scenery.commit()
	mesh.material_override = LilyWorld.vertex_material()
	add_child(mesh)

func reset() -> void:
	progress = 0
	furthest = 0
	wave_progress = -38
	wave_grace = start_grace
	update_wave()

func advance(delta: float, _position: Vector3, ride_progress := 0.0) -> bool:
	progress = ride_progress
	furthest = maxf(furthest,progress)
	var moving := maxf(0,delta-wave_grace)
	wave_grace = maxf(0,wave_grace-delta)
	if wave_enabled: wave_progress += moving*wave_speed
	update_wave()
	return wave_enabled and wave_grace <= 0 and progress <= wave_progress

func update_wave() -> void:
	if not is_instance_valid(wave): return
	wave.visible = wave_enabled and wave_progress >= 0
	var loc := location(maxf(0,wave_progress))
	for i in 2:
		var front := wave_fronts[i]
		front.visible = i == 0 or legs[loc.leg].has("shortcut")
		var f: Dictionary = location(maxf(0,wave_progress),i == 1).frame
		front.transform = Transform3D(f.basis,f.p)
		front.scale.x = float(f.width)

func show_best(s: float) -> void:
	best_marker.visible = s > 1 and s < total_distance-1
	best_marker.position = at_distance(s)+Vector3.UP*4

func section(_z := 0.0) -> String:
	return legs[location(progress).leg].label

func make_finish(world: LilyWorld) -> void:
	var finish: Vector3 = frame(legs.size()-1,path_length(legs.size()-1)-3).p
	var gold := LilyAvatar.material(Color("f6ce67"))
	for side in [-1,1]:
		LilyAvatar.box(self,finish+Vector3(side*4,3,0),Vector3(0.25,6,0.25),gold)
	LilyAvatar.box(self,finish+Vector3(0,6,0),Vector3(8.25,0.3,0.3),gold)
	for i in 12:
		for j in 2:
			var f := frame(legs.size()-1,path_length(legs.size()-1)-3-j*0.65)
			var tile := LilyAvatar.box(self,f.p+f.right*(-3.575+i*0.65)+f.up*0.045,Vector3(0.65,0.035,0.65),LilyAvatar.material(Color("fff6df") if (i+j)%2 == 0 else Color("345877")))
			tile.basis = f.basis
	signpost(finish+Vector3(0,7,0),"GLIDE FINISH" if beginner else "RAPIDS FINISH",0.009)
	world.flag = Node3D.new()
	add_child(world.flag)
