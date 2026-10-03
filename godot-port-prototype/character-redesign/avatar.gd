extends "res://tidewater_character_visual.gd"

const Head := preload("res://character-redesign/visual.gd")
var head_visual: Node3D
var head_attachment: BoneAttachment3D
var removed_head_triangles := 0
var kept_body_triangles := 0

func _install_original() -> void:
	super._install_original()
	# Keep original vertices, skin weights and body rig. Only discard triangles
	# belonging to the old head; ArrayMesh is local to this avatar instance.
	_remove_old_head(original_rig)
	head_attachment = BoneAttachment3D.new()
	head_attachment.bone_name = "head"
	skeleton.add_child(head_attachment)
	head_visual = Head.new()
	head_visual.team = team
	head_visual.scale = Vector3.ONE*.78
	# New head centre aligns with original centre (0,1.214,.012).
	# The original head bone's global rest is (0,1.04304,-.00088).
	head_visual.position = Vector3(0,-1.03904,.01288)
	head_attachment.add_child(head_visual)

func _remove_old_head(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var source: Mesh = mesh_node.mesh
		var imported: Material = source.surface_get_material(0)
		var semantic := imported.resource_name if imported != null else ""
		if semantic in ["Eyes","TeamHair"]:
			mesh_node.visible = false
		elif semantic == "Skin" and mesh_node.skin != null:
			var replacement := ArrayMesh.new()
			for surface in source.get_surface_count():
				var arrays := source.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var bone_indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var width := weights.size()/points.size()
				var is_head: Array[bool] = []
				var head_bone := skeleton.find_bone("head")
				for vertex in points.size():
					var head_weight := 0.0
					for slot in width:
						var bind := bone_indices[vertex*width+slot]
						var bone := mesh_node.skin.get_bind_bone(bind)
						var named := mesh_node.skin.get_bind_name(bind)
						if named != "": bone=skeleton.find_bone(named)
						if _belongs_to_head(bone,head_bone):
							head_weight+=weights[vertex*width+slot]
					is_head.append(head_weight>.5)
				var kept := PackedInt32Array()
				for triangle in indices.size()/3:
					var a:=indices[triangle*3]
					var b:=indices[triangle*3+1]
					var c:=indices[triangle*3+2]
					if is_head[a] or is_head[b] or is_head[c]: removed_head_triangles+=1
					else:
						kept.append(a);kept.append(b);kept.append(c)
						kept_body_triangles+=1
				arrays[Mesh.ARRAY_INDEX]=kept
				if not kept.is_empty():
					replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},source.surface_get_format(surface))
					assert(replacement.get_surface_count()>0,"Body surface reconstruction failed")
					replacement.surface_set_material(replacement.get_surface_count()-1,source.surface_get_material(surface))
			mesh_node.mesh=replacement
	for child in node.get_children(): _remove_old_head(child)

func _belongs_to_head(bone: int,head_bone: int) -> bool:
	while bone >= 0:
		if bone == head_bone: return true
		bone = skeleton.get_bone_parent(bone)
	return false
