extends SceneTree
const Original := preload("res://tidewater_character_visual.gd")
const Candidate := preload("res://character-sample/visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for team in 2:
		var original := Original.new()
		original.team = team
		root.add_child(original)
		original.set_physics_process(false)
		var sample := Candidate.new()
		sample.team = team
		root.add_child(sample)
		sample.set_physics_process(false)
		if sample.skeleton.get_bone_count() != 87:
			_fail("sample rig did not import");return
		var head := sample.skeleton.find_bone("head")
		if sample.skeleton.get_bone_rest(head).origin.y >= original.skeleton.get_bone_rest(head).origin.y-.04:
			_fail("candidate head/neck change missing");return
		if original.face_material.shader != Original.SKIN_SURFACE or original.eye_material.shader != Original.EYE_SURFACE:
			_fail("candidate changed original face material");return
		if sample.face_material.shader != Candidate.SAMPLE_SKIN or sample.eye_material.shader != Candidate.SAMPLE_EYES:
			_fail("candidate face material missing");return
		for mesh in _meshes(sample.original_rig):
			var imported := mesh.mesh.surface_get_material(0)
			if imported != null and imported.resource_name == "TeamHair":
				if mesh.mesh.get_surface_count() != 2:
					_fail("new ribbon geometry missing");return
				if mesh.material_override.get_shader_parameter("team_color") != Original.TeamPalette.color(team):
					_fail("candidate team tint missing");return
		var peak := 0.0
		for state in ["idle","run","shoot","low","tired","blink"]:
			sample.moving = state == "run"
			sample.anim_speed = 5.5 if state == "run" else 0.0
			sample.set_aim(state == "shoot")
			sample.set_expression_state(.05 if state == "low" else 1.0,.15 if state == "tired" else 1.0,0.0,false)
			if state == "shoot":sample.set_action("shoot")
			if state == "blink":sample.set("_blink_elapsed",0.0)
			for frame in 60:
				sample.call("_animate",1.0/30.0)
				for bone in sample.skeleton.get_bone_count():
					if not sample.skeleton.get_bone_global_pose(bone).is_finite():
						_fail("nonfinite sample pose: "+state);return
				for foot in ["footL","footR"]:
					var height := sample.skeleton.get_bone_global_pose(sample.skeleton.find_bone(foot)).origin.y
					if height < -.04:
						_fail("sample foot below floor: "+state);return
					if state == "run":peak = maxf(peak,height)
		if peak < .11:
			_fail("sample run does not lift feet");return
		sample.queue_free()
		original.queue_free()
		await process_frame
	print("PASS: sample GLB/87-bone rig, shorter neck, two-surface authored hair, independent materials, both team tints, finite idle/run/shoot/low/tired/blink poses and gait foot clearance")
	quit()

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:result.append(node)
	for child in node.get_children():result.append_array(_meshes(child))
	return result

func _fail(message: String) -> void:
	printerr("FAIL: "+message)
	quit(1)
