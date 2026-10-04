extends SceneTree
func _initialize() -> void:
	var scene: Node=load("res://experiments/character-sculpt/sculpt-head.glb").instantiate()
	_scan(scene)
	scene.free()
	quit()
func _scan(node: Node) -> void:
	if node is MeshInstance3D:
		var item:=node as MeshInstance3D
		for surface in item.mesh.get_surface_count():
			if item.mesh.surface_get_material(surface).resource_name!="SculptSkin":continue
			var arrays:=item.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for i in vertices.size():
				if absf(vertices[i].x-.075)<.003 and absf(vertices[i].y-1.223)<.003 and vertices[i].z>.09:
					print("position ",vertices[i]," UV ",uv[i]);break
	for child in node.get_children():_scan(child)
