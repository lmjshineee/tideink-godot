extends SceneTree
const Visual := preload("res://tidewater_character_visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for style in 4:
		var visual := Visual.new()
		visual.style_index = style
		root.add_child(visual)
		visual.set_physics_process(false)
		if visual.skeleton.get_bone_count()!=87 or not visual.original_rig.is_visible_in_tree():
			fail("default character is not the original web rig");return
		for mesh in meshes(visual.original_rig):
			if mesh.get_meta("procedural_equipment", false): continue
			var semantic := mesh.mesh.surface_get_material(0).resource_name
			if semantic == "Eyes" and (not mesh.is_visible_in_tree() or mesh.material_override.shader != Visual.EYE_SURFACE):
				fail("original face eyes are hidden or replaced");return
			if not semantic in ["Skin","Cloth"]:continue
			var arrays := mesh.mesh.surface_get_arrays(0)
			var custom: PackedFloat32Array = floats(arrays[Mesh.ARRAY_CUSTOM0])
			var clothing: PackedFloat32Array = floats(arrays[Mesh.ARRAY_CUSTOM1])
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if custom.size()!=points.size()*4 or clothing.size()!=points.size()*4:
				fail("lost bind-space fragment attributes");return
			for i in points.size():
				if points[i].distance_to(Vector3(custom[i*4],custom[i*4+1],custom[i*4+2]))>0.0001:
					fail("source bind positions changed during import");return
			if semantic=="Cloth":
				var material := mesh.material_override as ShaderMaterial
				if material.shader!=Visual.CLOTH_SURFACE or material.get_shader_parameter("shorts_color")!=Color(Visual.OUTFITS[style][1]):
					fail("source clothing palette not applied");return
		for weapon in ["shooter","roller","charger","blaster"]:
			visual.set_weapon(weapon)
			visual.moving = false
			visual.anim_speed = 0.0
			animate(visual,30)
			var source_idle: Transform3D = visual._gaits[weapon]["idle"][0]["bones"][0]
			var hip := visual.skeleton.find_bone("hips")
			if visual.skeleton.get_bone_pose_position(hip).distance_to(source_idle.origin)>0.001:
				fail("default stance does not converge to original web pose");return
			for i in visual._face_bones.size():
				var bone: int = visual._face_bones[i]
				var source_index: int = visual._action_data["bones"].find(visual.skeleton.get_bone_name(bone))
				var values: Array = visual._action_data["expressions"][weapon]["idle"]["bones"][i]
				var expected := visual.skeleton.get_bone_rest(bone).origin+Vector3(values[0],values[1],values[2])-visual._action_rest[source_index].origin
				if visual.skeleton.get_bone_pose_position(bone).distance_to(expected)>0.001:
					fail("facial pose snapped back to the uncorrected head anchors");return
			visual.moving = true
			visual.anim_speed = 5.5
			var high := 0.0
			for i in 90:
				animate(visual,1)
				for name_text in ["footL","footR"]:
					var pose := visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone(name_text))
					if not pose.is_finite() or pose.origin.y < -0.04:
						fail("source gait foot penetrated floor");return
					high = maxf(high,pose.origin.y)
			if high<0.11:
				fail("source gait never raises a foot");return
		visual.moving = false
		visual.anim_speed = 0.0
		visual.set_reaction("spawn")
		animate(visual,8)
		# A variant's hair anchors must be retained when the style-0 action is applied.
		var strand := visual.skeleton.find_bone("hair0_0")
		var source_index: int = visual._action_data["bones"].find("hair0_0")
		var source_rest: Transform3D = visual._action_rest[source_index]
		if strand>=0 and source_rest.origin.distance_to(visual.skeleton.get_bone_rest(strand).origin)>0.01:
			if visual.skeleton.get_bone_pose_position(strand).distance_to(visual.skeleton.get_bone_rest(strand).origin)>0.02:
				fail("one-shot moved hair to another variant's anchors");return
		visual.queue_free()
		await process_frame
	print("PASS: original web rig is default, source bind/clothing attributes survive import, original palette, source idle/gait and floor height, per-variant hair anchors")
	quit()

func floats(value: Variant) -> PackedFloat32Array:
	return value.to_float32_array() if value is PackedByteArray else PackedFloat32Array(value)

func meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:found.append(node)
	for child in node.get_children():found.append_array(meshes(child))
	return found

func animate(visual: Node3D,count: int) -> void:
	for i in count:visual.call("_animate",1.0/30.0)

func fail(message: String) -> void:
	printerr("FAIL: "+message)
	quit(1)
