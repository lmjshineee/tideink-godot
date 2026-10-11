extends Node3D

# Visual-only original assets. Existing map JSON owns all 82 prop collisions.
const MatchSetup := preload("res://src/core/match_setup.gd")
const CLOTH = preload("res://shaders/characters/tidewater_cloth.gdshader")
const SEA = preload("res://shaders/world/tidewater_sea.gdshader")
const MURAL = preload("res://shaders/world/tidewater_mural.gdshader")
const PAD = preload("res://shaders/world/tidewater_spawn_pad.gdshader")
const TeamPalette = preload("res://src/core/team_palette.gd")
const InkView = preload("res://src/world/surface_ink_view.gd")
var visual_meshes := 0
var mural_count := 0


func _ready() -> void:
	var id := preload("res://src/core/map_catalog.gd").scenery_id()
	if id in ["sunset_park","lantern_depot"]:
		var authored := Node3D.new();authored.name="OriginalModels";add_child(authored)
		visual_meshes=preload("res://src/world/curated_scenery.gd").new().build(authored,id)
		call_deferred("_theme_light",id)
	else:
		var packed := load("res://assets/scenery/%s_visuals.glb" % preload("res://src/core/map_catalog.gd").scenery_id()) as PackedScene
		if packed == null:
			push_error("Missing exported Tidewater visuals")
			return
		var models := packed.instantiate()
		models.name = "OriginalModels"
		add_child(models)
		_prepare_materials(models)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(5000,5000)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	sea.mesh = plane
	sea.position.y = -1.6 # PLAYER.waterY in original config.js.
	var material := ShaderMaterial.new()
	if id in ["sunset_park","lantern_depot"]:
		material.shader=preload("res://shaders/world/calm_water.gdshader")
	else:
		material.shader = SEA
	sea.material_override = material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	# Parent map loads its source surfaces in _ready, after its children.
	call_deferred("_add_murals")


func _prepare_materials(node: Node) -> void:
	if node is MeshInstance3D:
		visual_meshes += 1
		for index in range(node.mesh.get_surface_count()):
			var material := node.mesh.surface_get_material(index) as StandardMaterial3D
			if material == null:
				continue
			var label := material.resource_name
			if "cloth" in label or "props:flags" in label or "props:banners" in label:
				var cloth := ShaderMaterial.new()
				cloth.shader = CLOTH
				cloth.set_shader_parameter("artwork",material.albedo_texture)
				node.set_surface_override_material(index,cloth)
		# Far scenery never needs to cast shadows over the playable arena.
		if node.get_aabb().size.length() > 250.0:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_prepare_materials(child)


func _add_murals() -> void:
	var map: Node3D = get_parent()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s.json" % preload("res://src/core/map_catalog.gd").asset_id()))
	var atlas: Texture2D = load("res://assets/scenery/murals.png")
	for team in range(2):
		var values: Array = data["spawnPads"][team]
		var pad := MeshInstance3D.new()
		pad.name = "SpawnPad_%d" % team
		var plane := PlaneMesh.new()
		plane.size = Vector2(3.9,3.9)
		pad.mesh = plane
		pad.position = Vector3(values[0],values[1]+0.078,values[2])
		var pad_material := ShaderMaterial.new()
		pad_material.shader = PAD
		pad_material.set_shader_parameter("team_color",TeamPalette.color(team))
		pad.material_override = pad_material
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pad)
	for block in data["blocks"]:
		for mural in block.get("mural",[]):
			var direction := Vector3(mural["n"][0],mural["n"][1],mural["n"][2])
			for face in map.get("surfaces"):
				if int(face["block"]) != int(block["id"]):
					continue
				var normal := Vector3(face["n"][0],face["n"][1],face["n"][2])
				if normal.dot(direction) < 0.99:
					continue
				var visual := MeshInstance3D.new()
				visual.name = "Mural_%d" % int(face["id"])
				visual.mesh = InkView._face_mesh(face)
				# Keep murals 4 mm above the wall and below the separate wet-ink plane.
				visual.position = normal * (0.004 - InkView.face_offset(face))
				var material := ShaderMaterial.new()
				material.shader = MURAL
				material.set_shader_parameter("artwork",atlas)
				material.set_shader_parameter("surface_size",Vector2(face["su"],face["sv"]))
				material.set_shader_parameter("mural_id",float(mural["id"]))
				material.set_shader_parameter("new_art",true)
				material.set_shader_parameter("theme",1 if MatchSetup.map_id=="lantern_depot" else 0)
				visual.material_override = material
				visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(visual)
				mural_count += 1

func _theme_light(id: String) -> void:
	var park := id=="sunset_park"
	var lighting := get_parent().get_node_or_null("Lighting")
	if lighting==null:lighting=get_parent().get_parent()
	var env_node: WorldEnvironment
	for child in lighting.get_children():
		if child is WorldEnvironment:env_node=child;break
	if env_node==null:return
	var env: Environment=env_node.environment.duplicate(true);env_node.environment=env
	if env.sky==null:
		env.sky=Sky.new();env.sky.sky_material=ProceduralSkyMaterial.new();env.background_mode=Environment.BG_SKY
	var sky: ProceduralSkyMaterial=env.sky.sky_material
	sky.sky_top_color=Color("76889b") if park else Color("233b62")
	sky.sky_horizon_color=Color("f2c59b") if park else Color("a2879f")
	env.ambient_light_color=Color("ffe6cf") if park else Color("b9cee0")
	env.ambient_light_energy=.56 if park else .65
	env.fog_light_color=sky.sky_horizon_color
	var sun: DirectionalLight3D=lighting.get_node_or_null("Sun")
	if sun==null:
		for child in lighting.get_children():
			if child is DirectionalLight3D:sun=child;break
	if sun==null:return
	sun.light_color=Color("ffd3a3") if park else Color("ffe4ca")
	sun.light_energy=.95 if park else .70
	sun.rotation_degrees=Vector3(-28,-40,0) if park else Vector3(-38,25,0)
