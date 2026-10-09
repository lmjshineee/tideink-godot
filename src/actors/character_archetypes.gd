extends RefCounted

# Visual-only authored silhouettes. Shared combat capsules stay in actor rules.
const IDS := ["reef_runner", "fin_drifter", "dock_worker", "spark_writer"]
const LABELS := ["礁跑 · 短发轻装", "鳍影 · 长发长衣", "港工 · 厚实工装", "电涂 · 不对称夹克"]
const SCALE := [.94, 1.04, 1.0, .98]
const SKIN_TINT := [Color("fff7ef"), Color("ead7cc"), Color("d1b498"), Color("ebc5ba")]
const COLORS := [Color("3b6772"), Color("514866"), Color("b2a375"), Color("9b4c53")]
const DARK := Color("202c3c")
const LIGHT := Color("e9dfc5")

static func path(index: int) -> String:
	return "res://assets/characters/archetypes/%s.glb" % IDS[posmod(index, IDS.size())]

static func dress(visual: Node3D) -> void:
	var i := posmod(visual.style_index, IDS.size())
	visual.original_rig.scale = Vector3.ONE * SCALE[i]
	var s: Skeleton3D = visual.skeleton
	var body := _attachment(s, "chest", "Streetwear")
	var accent := preload("res://src/core/team_palette.gd").color(visual.team).lightened(.12)
	var cloth: Color = COLORS[i]
	match i:
		0:
			# Cropped vest, short visor and a small hip messenger pouch.
			_trim(body, "Zip", Vector3(0,-.01,.091), Vector3(.008,.19,.008), LIGHT)
			var head := _attachment(s,"head","RunnerVisor")
			_loft(head,"VisorBand",[[.211,.174,.137],[.230,.178,.141]],DARK)
			_trim(head,"SweptBrim",Vector3(0,.216,.153),Vector3(.30,.019,.10),accent)
			var hip := _attachment(s,"hips","MessengerPouch")
			_loft(hip,"SideBag",[[-.09,.065,.036],[.04,.073,.040]],DARK,Vector3(.158,0,.035))
		1:
			# Narrow long coat, visible split tails, scarf and tall slim boots.
			_trim(body,"AsymmetricZip",Vector3(.043,-.055,.093),Vector3(.012,.30,.01),accent)
			var neck := _attachment(s,"neck","HighCollar")
			_loft(neck,"Collar",[[-.035,.069,.061],[.029,.074,.064]],DARK)
			var head := _attachment(s,"head","HairClip")
			_trim(head,"FinClip",Vector3(.157,.232,.085),Vector3(.028,.08,.014),accent)
			for side in ["L","R"]:
				var thigh := _attachment(s,"thigh"+side,"CoatTail"+side)
				_loft(thigh,"Tail",[[-.30,.075,.026],[-.06,.089,.034]],cloth,Vector3(0,0,-.096))
				var shin := _attachment(s,"shin"+side,"TallBoot"+side)
				_loft(shin,"BootShaft",[[-.215,.054,.057],[-.018,.056,.053]],DARK)
		2:
			# Broad work vest, earmuffs, cargo pockets and thick protective boots.
			for side in [-1.0,1.0]:
				_trim(body,"ReflectiveStripe",Vector3(side*.10,-.02,.104),Vector3(.023,.22,.012),accent)
				_loft(body,"ChestPocket",[[-.11,.044,.023],[-.025,.043,.023]],DARK,Vector3(side*.102,0,.114))
			var head := _attachment(s,"head","EarDefenders")
			for side in [-1.0,1.0]:
				_loft(head,"EarCup",[[.06,.037,.071],[.19,.037,.075]],DARK,Vector3(side*.197,0,-.006))
				_trim(head,"EarCupPlate",Vector3(side*.228,.128,-.006),Vector3(.015,.072,.078),accent)
			_arc(head,"HeadBand",DARK)
			for side in ["L","R"]:
				var thigh := _attachment(s,"thigh"+side,"Cargo"+side)
				_loft(thigh,"ToolPocket",[[-.19,.030,.043],[-.08,.033,.043]],DARK,Vector3(.089 if side=="L" else -.089,0,.013))
				var foot := _attachment(s,"foot"+side,"SafetyBoot"+side)
				_loft(foot,"Boot",[[-.039,.081,.137],[.026,.084,.137],[.085,.066,.107]],DARK,Vector3(0,0,.045))
				_trim(foot,"ToeGuard",Vector3(0,.031,.145),Vector3(.14,.05,.06),LIGHT)
		3:
			# Loose asymmetric bomber, one high sleeve and a sharp raised crest.
			_trim(body,"DiagonalLapel",Vector3(-.066,.035,.092),Vector3(.087,.033,.013),LIGHT,Vector3(0,0,-.45))
			var head := _attachment(s,"head","Crest")
			_loft(head,"FinCrest",[[.19,.034,.083],[.285,.012,.067]],accent,Vector3(-.038,0,-.031))
			var foot := _attachment(s,"footR","HighTop")
			_loft(foot,"AnkleCollar",[[.018,.063,.067],[.13,.064,.071]],DARK)
	visual.set_meta("archetype", IDS[i])

static func _attachment(skeleton: Skeleton3D, bone: String, label_text: String) -> BoneAttachment3D:
	var node := BoneAttachment3D.new(); node.name = label_text; node.bone_name = bone
	skeleton.add_child(node)
	return node

static func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new(); result.albedo_color = color; result.roughness = .82
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

static func _trim(parent: Node3D, label_text: String, at: Vector3, dimensions: Vector3, color: Color, turn := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new(); mesh.size = dimensions
	var part := MeshInstance3D.new(); part.name = label_text; part.mesh = mesh; part.position = at; part.rotation = turn
	part.material_override = _material(color); part.set_meta("procedural_equipment",true); parent.add_child(part)

static func _loft(parent: Node3D, label_text: String, rings: Array, color: Color, offset := Vector3.ZERO) -> void:
	# Rounded rectangular cross-sections; tapered profiles give each garment a real contour.
	var profile: Array = []
	var first: Array = rings[0]; var last: Array = rings[-1]
	profile.append([float(first[0])-.012,float(first[1])*.89,float(first[2])*.89])
	profile.append_array(rings)
	profile.append([float(last[0])+.012,float(last[1])*.89,float(last[2])*.89])
	rings = profile
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_smooth_group(0)
	var vertices: Array[Vector3] = []
	const SEGMENTS := 24
	for ring in rings:
		for index in SEGMENTS:
			var angle := TAU * index / SEGMENTS
			var cx := cos(angle); var cz := sin(angle)
			vertices.append(Vector3(signf(cx)*pow(absf(cx),.88)*float(ring[1]),float(ring[0]),signf(cz)*pow(absf(cz),.88)*float(ring[2])) + offset)
	for row in rings.size() - 1:
		for column in SEGMENTS:
			var a := row*SEGMENTS+column; var b := row*SEGMENTS+(column+1)%SEGMENTS
			for index in [a,b,a+SEGMENTS,b,b+SEGMENTS,a+SEGMENTS]: tool.add_vertex(vertices[index])
	for end in [0,rings.size()-1]:
		var center := Vector3(0,float(rings[end][0]),0)+offset
		for column in SEGMENTS:
			tool.add_vertex(center);tool.add_vertex(vertices[end*SEGMENTS+column]);tool.add_vertex(vertices[end*SEGMENTS+(column+1)%SEGMENTS])
	tool.generate_normals();tool.index()
	var part := MeshInstance3D.new(); part.name = label_text; part.mesh = tool.commit()
	part.material_override = _material(color); part.set_meta("procedural_equipment",true);parent.add_child(part)

static func _arc(parent: Node3D, label_text: String, color: Color) -> void:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_smooth_group(0)
	var vertices:Array[Vector3]=[]
	for index in 25:
		var angle:=PI*index/24
		var center:=Vector3(cos(angle)*.197,.12+sin(angle)*.157,-.026)
		var normal:=Vector3(cos(angle),sin(angle),0)
		for side in 8:
			var theta:=TAU*side/8
			vertices.append(center+normal*cos(theta)*.012+Vector3(0,0,sin(theta)*.020))
	for row in 24:
		for column in 8:
			var a:=row*8+column;var b:=row*8+(column+1)%8
			for index in [a,b,a+8,b,b+8,a+8]:tool.add_vertex(vertices[index])
	tool.generate_normals();tool.index()
	var part:=MeshInstance3D.new();part.name=label_text;part.mesh=tool.commit();part.material_override=_material(color)
	part.set_meta("procedural_equipment",true);parent.add_child(part)
