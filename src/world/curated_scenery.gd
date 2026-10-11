extends RefCounted
# Read-only dressing: structural collision and paint faces live in map assets.
const FACADE := preload("res://shaders/world/city_facade.gdshader")
const SIGN := preload("res://shaders/world/street_sticker.gdshader")
var host: Node3D
var materials: Dictionary = {}
var mesh_count := 0

func build(parent: Node3D, id: String) -> int:
	host=parent
	var park := id=="sunset_park"
	box(Vector3(0,-1.18,0),Vector3(40.12,.18,64.12),Color("65757b"))
	var ink := Color("426b72") if park else Color("334955")
	for side in [-1,1]:
		# Continuous quays anchor the skyline; the arena is a civic waterfront.
		box(Vector3(side*33,-1.0,0),Vector3(22,1.7,78),Color("a58e79") if park else Color("617c83"))
		box(Vector3(side*22.35,-.30,0),Vector3(.30,.30,78),ink)
		# Skyline stays outside the playable bounds; no phantom prop collision.
		for i in 5:
			var height := 6.0+float((i*7)%5)*2.0
			var at := Vector3(side*(32+i%2*4),height*.5-1.5,(i-2.0)*16)
			var mesh := BoxMesh.new();mesh.size=Vector3(9,height+3,10)
			var building := instance(mesh,at,Color.WHITE)
			var facade := ShaderMaterial.new();facade.shader=FACADE
			facade.set_shader_parameter("base_color",Color("b69780") if park else Color("425e70"))
			facade.set_shader_parameter("night",not park);building.material_override=facade
			box(at+Vector3(0,(height+3)*.5,0),Vector3(9.4,.28,10.4),ink)
			box(at+Vector3(0,(height+3)*.5+.45,0),Vector3(2.2,.7,3),ink)
		for z in [-24,-12,0,12,24]:
			cylinder(Vector3(side*22,2.9,z),.10,5.8,ink)
			box(Vector3(side*22,5.9,z),Vector3(1.0,.28,.7),Color("ffe4b5"),1.0 if not park else 0.0)
		if park:
			var turn := 0.0 if side>0 else PI
			arc_line(16.0,deg_to_rad(-65)+turn,deg_to_rad(65)+turn,2.215,Color("ede1c4"),32,.06)
			arc_line(13.3,deg_to_rad(-65)+turn,deg_to_rad(65)+turn,2.215,Color("c88769"),32,.07)
			for z in [-24,24]:
				# Vegetation belongs to the exterior landscape, beyond collision bounds.
				for i in 3:
					cylinder(Vector3(side*(24.0+i*1.5),1.2,z),.14,2.4,ink)
					cylinder(Vector3(side*(24.0+i*1.5),2.6,z),.7,1.3,Color("798d66"))
			box(Vector3(side*21.5,1.8,0),Vector3(.18,3.6,10),ink)
			signboard(Vector3(side*21.38,2.0,0),Vector2(8,2.4),side*PI*.5,0)
		else:
			var turn := 0.0 if side>0 else PI
			# Emissive ceiling edges trace the actual crescent roof geometry.
			arc_line(13.0,deg_to_rad(-37)+turn,deg_to_rad(37)+turn,6.685,Color("ffe4b5"),32,.09,.7)
			arc_line(17.7,deg_to_rad(-37)+turn,deg_to_rad(37)+turn,6.685,Color("8fd5d0"),32,.09,.5)
			# Diagonal rails are integral to the concourse; no legacy tram props.
			for lateral in [-1.7,1.7]:
				var yaw: float = atan(.55)*side
				var mesh := BoxMesh.new();mesh.size=Vector3(.07,.014,26)
				var rail := instance(mesh,Vector3(lateral*cos(yaw),3.409,-lateral*sin(yaw)),Color("e1b674"));rail.rotation.y=yaw
			for sign in [-1,1]:
				signboard(Vector3(side*15.1,4.9,sign*8.46),Vector2(3.7,1.2),0 if sign<0 else PI,1)
	if park:
		arc_line(6.9,0,TAU,1.61,Color("f2e8cc"),64,.065)
		floor_type("SUNSET",Vector3(0,1.61,-1.1),Color("466e73"),.015)
		floor_type("LOOP  /  01",Vector3(0,1.61,1.2),Color("466e73"),.006)
	else:
		floor_type("CROSSING",Vector3(0,3.41,-.6),Color("355960"),.009)
		floor_type("01   /   02",Vector3(0,3.41,1.0),Color("355960"),.006)
	# A unique landmark makes orientation readable from either base.
	box(Vector3(0,6.4,park_z(park)),Vector3(13,.4,.4),ink)
	for x in [-6.5,6.5]:cylinder(Vector3(x,3.1,park_z(park)),.14,6.2,ink)
	signboard(Vector3(0,5.1,park_z(park)-.05),Vector2(10,1.8),0,0 if park else 1)
	return mesh_count

func park_z(park: bool) -> float:return -34.0 if park else -35.0

func material(color: Color, glow: float) -> StandardMaterial3D:
	var key := color.to_html()+str(glow)
	if not materials.has(key):
		var mat := StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.72
		if glow>0:mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=glow
		materials[key]=mat
	return materials[key]

func instance(mesh: Mesh, at: Vector3, color: Color, glow: float=0) -> MeshInstance3D:
	var node := MeshInstance3D.new();node.mesh=mesh;node.position=at;node.material_override=material(color,glow)
	host.add_child(node);mesh_count+=1;return node

func box(at: Vector3, size: Vector3, color: Color, glow: float=0) -> void:
	var mesh := BoxMesh.new();mesh.size=size;instance(mesh,at,color,glow)

func cylinder(at: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=10
	instance(mesh,at,color)

func signboard(at: Vector3, size: Vector2, angle: float, theme: int) -> void:
	var mesh := QuadMesh.new();mesh.size=size
	var node := instance(mesh,at,Color.WHITE);node.rotation.y=angle
	var mat := ShaderMaterial.new();mat.shader=SIGN;mat.set_shader_parameter("theme",theme);node.material_override=mat

func arc_line(radius: float, begin: float, end: float, y: float, color: Color, segments: int, width: float, glow: float=0) -> void:
	for i in segments:
		var a := begin+(end-begin)*float(i)/segments
		var b := begin+(end-begin)*float(i+1)/segments
		var p := Vector3(cos(a)*radius,y,sin(a)*radius)
		var q := Vector3(cos(b)*radius,y,sin(b)*radius)
		var mesh := BoxMesh.new();mesh.size=Vector3(width,.025,p.distance_to(q)+.02)
		var line := instance(mesh,(p+q)*.5,color,glow);line.look_at(q,Vector3.UP)

func floor_type(text: String, at: Vector3, color: Color, scale: float) -> void:
	var label := Label3D.new();label.text=text;label.position=at;label.rotation.x=-PI*.5
	label.font_size=100;label.pixel_size=scale;label.modulate=color;label.outline_size=0
	label.no_depth_test=false;label.shaded=true;host.add_child(label)
