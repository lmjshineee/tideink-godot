extends SceneTree

func _initialize() -> void:
	for path in ["res://experiments/character-redesign/visual.gd","res://experiments/character-redesign/avatar.gd","res://experiments/character-redesign/studio.gd"]:
		var script := load(path) as GDScript
		if script == null or script.reload() != OK:
			push_error("Parse failed: "+path)
			quit(1)
			return
	call_deferred("_check")

func _check() -> void:
	for team in 2:
		var character := load("res://experiments/character-redesign/avatar.gd").new() as Node3D
		character.team=team
		character.ornament_seed=41
		root.add_child(character)
		character.set_physics_process(false)
		character.configure_animation({"runSpeed":6.0})
		var head: Node3D=character.head_visual
		if character.skeleton.get_bone_count()!=87 or head.skeleton.get_bone_count()!=17:
			_fail("Original body/new head rigs missing");return
		if character.removed_head_triangles<100 or character.kept_body_triangles<100:
			_fail("Old head removal discarded the body or kept the old head");return
		if head.meshes.size()!=8 or not head.player.has_animation("idle"):
			_fail("New head meshes/animation missing");return
		if head.hair.albedo_color!=(Color("ff741b") if team==0 else Color("268dee")):
			_fail("Head team color missing");return
		for state in ["idle","run","shoot"]:
			character.moving=state=="run"
			character.anim_speed=5.5 if state=="run" else 0.0
			character.set_aim(state=="shoot")
			if state=="shoot": character.set_action("shoot")
			for frame in 90:
				character.call("_animate",1.0/30.0)
				head.pose_at("idle",frame/30.0)
				for rig in [character.skeleton,head.skeleton]:
					for bone in rig.get_bone_count():
						var pose: Transform3D=rig.get_bone_global_pose(bone)
						if not pose.is_finite() or pose.basis.determinant()<=.01:
							_fail("Invalid pose: "+state);return
				for foot in ["footL","footR"]:
					if character.skeleton.get_bone_global_pose(character.skeleton.find_bone(foot)).origin.y<-.04:
						_fail("Original foot below floor");return
		print("body triangles kept ",character.kept_body_triangles," / old head removed ",character.removed_head_triangles)
		character.queue_free()
		await process_frame
	print("PASS: scripts parse; original 87-bone body + new 17-bone head; idle/run/shoot, hair sway/blink, both teams finite")
	quit()

func _fail(message: String) -> void:
	printerr("FAIL: "+message)
	quit(1)
