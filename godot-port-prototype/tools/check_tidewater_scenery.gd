extends SceneTree

func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var map := (load("res://tidewater_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var scenery: Node3D = map.get_node("Scenery")
	if scenery.visual_meshes != 27 or scenery.mural_count != 18:
		_fail("original visual meshes / source mural count: %d / %d" % [scenery.visual_meshes,scenery.mural_count])
		return
	if not scenery.find_children("*","CollisionObject3D",true,false).is_empty():
		_fail("visual assets introduced duplicate gameplay collision")
		return
	var cloth_count := 0
	for node in scenery.get_node("OriginalModels").find_children("*","MeshInstance3D",true,false):
		for i in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(i)
			if material is ShaderMaterial:
				if material.get_shader_parameter("artwork") == null:
					_fail("cloth lost source artwork")
					return
				cloth_count += 1
	if cloth_count != 2:
		_fail("cloth texture/team color adapters not applied: %d" % cloth_count)
		return
	# The same geometry still owns hit queries, floor sampling and scoring.
	if map.block_count != 145 or map.turf_count != 61:
		_fail("visual dressing changed map rules")
		return
	for team in range(2):
		var pad: MeshInstance3D = scenery.get_node("SpawnPad_%d" % team)
		if pad.position.distance_to(map.spawn_pads[team]+Vector3.UP*0.078) > 0.001:
			_fail("spawn pad visual does not match source location")
			return
	print("PASS: original props and harbor loaded; murals/cloth textures/pads aligned; no visual collision added")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ",message)
	quit(1)
