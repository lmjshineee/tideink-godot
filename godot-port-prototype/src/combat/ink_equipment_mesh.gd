extends RefCounted

static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = 0.32
	return result

static func part(root: Node3D, mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.set_meta("procedural_equipment", true)
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	root.add_child(node)
	return node

static func rod(root: Node3D, start: Vector3, finish: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(finish)
	mesh.radial_segments = 8
	var node := part(root, mesh, mat, (start + finish) * 0.5)
	node.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	return node

static func bow(team: int) -> Node3D:
	var root := Node3D.new()
	var ink := material(preload("res://src/core/team_palette.gd").color(team), 0.35)
	var metal := material(Color("dce9ec"), 0.7)
	var dark := material(Color("263045"), 0.2)
	var points := [Vector3(0,-0.59,-0.16),Vector3(0,-0.43,0.03),Vector3(0,-0.19,0.14),Vector3.ZERO,Vector3(0,0.19,0.14),Vector3(0,0.43,0.03),Vector3(0,0.59,-0.16)]
	for i in range(points.size()-1):
		rod(root, points[i], points[i+1], 0.028 if i in [2,3] else 0.045, ink if i in [1,4] else metal)
	rod(root, Vector3(0,-.14,0),Vector3(0,.14,0),.047,dark)
	var strings := Node3D.new()
	strings.name="BowString"
	root.add_child(strings)
	rod(strings,points[0],Vector3(0,0,-.28),.006,metal)
	rod(strings,points[-1],Vector3(0,0,-.28),.006,metal)
	# The support rest sits in the left hand's foregrip position.
	rod(root,Vector3(0,-.06,.08),Vector3(0,-.06,.22),.025,dark)
	var arrows := Node3D.new()
	arrows.name="LoadedArrows"
	root.add_child(arrows)
	for x in [-.035,0,.035]:
		var arrow := bolt(team)
		arrows.add_child(arrow)
		arrow.scale.z = 1.5
		# The nock meets the rear string, and the tip clears the rest at full draw.
		arrow.position = Vector3(x,0,.095)
	return root

static func set_bow_charge(root: Node3D, amount: float) -> void:
	var pull := -.28-.18*clampf(amount,0,1)
	var strings:Node3D=root.get_node("BowString")
	for i in 2:
		var end:=Vector3(0,-.59 if i==0 else .59,-.16)
		var start:=Vector3(0,0,pull)
		var string:MeshInstance3D=strings.get_child(i)
		(string.mesh as CylinderMesh).height=start.distance_to(end)
		string.position=(start+end)*.5
		string.quaternion=Quaternion(Vector3.UP,(end-start).normalized())
	root.get_node("LoadedArrows").position.z=pull+.28

static func bolt(team: int) -> Node3D:
	var root := Node3D.new()
	var ink := material(preload("res://src/core/team_palette.gd").color(team).lightened(.18), .25)
	var metal := material(Color("e8f3f5"), .6)
	rod(root,Vector3(0,0,-.25),Vector3(0,0,.20),.015,metal)
	var tip := CylinderMesh.new()
	tip.top_radius = 0
	tip.bottom_radius = .046
	tip.height = .14
	tip.radial_segments = 6
	part(root,tip,ink,Vector3(0,0,.27)).rotation.x = PI/2
	for angle in [0,PI/2]:
		var fin := BoxMesh.new()
		fin.size = Vector3(.1,.01,.12)
		part(root,fin,ink,Vector3(0,0,-.2)).rotation.z = angle
	return root

static func canopy(team: int, opened: bool = false) -> Node3D:
	var root := Node3D.new()
	var ink := material(preload("res://src/core/team_palette.gd").color(team), .2)
	var metal := material(Color("d8e4e8"), .65)
	var dark := material(Color("283045"))
	if not opened:
		rod(root,Vector3(0,0,-.18),Vector3(0,0,.65),.035,metal)
		rod(root,Vector3(0,0,-.16),Vector3(0,0,.08),.06,dark)
		for i in 8:
			var angle := i*TAU/8
			rod(root,Vector3(cos(angle)*.11,sin(angle)*.11,.1),Vector3(0,0,.7),.026,ink)
		return root
	# A domed octagonal fabric face; collisions use its full rectangular frame.
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 8:
		var a := i*TAU/8
		var b := (i+1)*TAU/8
		var first := Vector3(cos(a)*1.15,sin(a)*.85,0)
		var last := Vector3(cos(b)*1.15,sin(b)*.85,0)
		var center := Vector3(0,0,.24)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in [center,first,last]: st.add_vertex(p)
		st.generate_normals()
		part(root,st.commit(),ink if i%2==0 else dark)
		rod(root,center,first,.018,metal)
		rod(root,first,last,.015,metal)
	rod(root,Vector3(0,0,-.4),Vector3(0,0,.24),.025,metal)
	return root
