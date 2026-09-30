extends Node3D

# Visual-only original assets. Existing map JSON owns all 82 prop collisions.
const MatchSetup := preload("res://match_setup.gd")
const CLOTH = preload("res://tidewater_cloth.gdshader")
const SEA = preload("res://tidewater_sea.gdshader")
const MURAL = preload("res://tidewater_mural.gdshader")
const PAD = preload("res://tidewater_spawn_pad.gdshader")
const TeamPalette = preload("res://team_palette.gd")
const InkView = preload("res://surface_ink_view.gd")
var visual_meshes := 0
var mural_count := 0


func _ready() -> void:
	var packed := load("res://assets/scenery/%s_visuals.glb" % MatchSetup.map_id) as PackedScene
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
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s.json" % MatchSetup.map_id))
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
				# Below ink (0.012 m) but above the wall, so paint hides murals.
				visual.position = -normal * 0.008
				var material := ShaderMaterial.new()
				material.shader = MURAL
				material.set_shader_parameter("artwork",atlas)
				material.set_shader_parameter("surface_size",Vector2(face["su"],face["sv"]))
				material.set_shader_parameter("mural_id",float(mural["id"]))
				visual.material_override = material
				visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(visual)
				mural_count += 1
