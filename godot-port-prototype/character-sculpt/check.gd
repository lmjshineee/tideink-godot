extends SceneTree

func _initialize() -> void:
	for path in ["res://character-sculpt/visual.gd","res://character-sculpt/wardrobe.gd","res://character-sculpt/avatar.gd","res://character-sculpt/studio.gd","res://character-sculpt/gallery.gd"]:
		var script := load(path) as GDScript
		if script == null or script.reload() != OK:
			push_error("Parse failed: "+path)
			quit(1)
			return
	call_deferred("_check")

func _check() -> void:
	for team in 2:
		var character := load("res://character-sculpt/avatar.gd").new() as Node3D
		character.team=team
		character.ornament_seed=41
		root.add_child(character)
		character.set_physics_process(false)
		character.configure_animation({"runSpeed":6.0})
		var head: Node3D=character.head_visual
		if character.skeleton.get_bone_count()!=87 or head.skeleton.get_bone_count()!=31:
			_fail("Original body/new head rigs missing");return
		if character.removed_head_triangles<100 or character.kept_body_triangles<100:
			_fail("Old head removal discarded the body or kept the old head");return
		if head.meshes.size()!=7 or not head.player.has_animation("idle"):
			_fail("New head meshes/animation missing");return
		if head.hair.get_shader_parameter("team_color")!=(Color("ff681d") if team==0 else Color("2587ee")):
			_fail("Head team color missing");return
		var minimum_gap:=10.0
		var maximum_gap:=-10.0
		var minimum_connection:=10.0
		var maximum_connection:=0.0
		for state in ["idle","run","shoot"]:
			character.moving=state=="run"
			character.anim_speed=5.5 if state=="run" else 0.0
			character.set_aim(state=="shoot")
			if state=="shoot": character.set_action("shoot")
			for frame in 90:
				character.call("_animate",1.0/30.0)
				head.pose_at("idle",frame/30.0)
				var rig: Skeleton3D=character.skeleton
				var head_matrix: Transform3D=rig.get_bone_global_pose(rig.find_bone("head"))*head.transform
				var chest_matrix:=rig.get_bone_global_pose(rig.find_bone("chest"))*rig.get_bone_global_rest(rig.find_bone("chest")).affine_inverse()
				var collar: Vector3=chest_matrix*Vector3(0,.990,.0318)
				var chin: Vector3=head_matrix*Vector3(0,1.018,.062*.92)
				var gap: float=chin.y-collar.y
				var connection: float=(head_matrix*Vector3(0,.985,.029*.92)).distance_to(collar)
				minimum_gap=minf(minimum_gap,gap);maximum_gap=maxf(maximum_gap,gap)
				minimum_connection=minf(minimum_connection,connection);maximum_connection=maxf(maximum_connection,connection)
				if gap<-.025 or gap>.080 or connection>.065:
					_fail("Shoulder-neck connection leaves the tested fitting range: "+str([state,gap,connection]));return
				for active_rig in [character.skeleton,head.skeleton]:
					for bone in active_rig.get_bone_count():
						var pose: Transform3D=active_rig.get_bone_global_pose(bone)
						if not pose.is_finite() or pose.basis.determinant()<=.01:
							_fail("Invalid pose: "+state);return
				for foot in ["footL","footR"]:
					if character.skeleton.get_bone_global_pose(character.skeleton.find_bone(foot)).origin.y<-.04:
						_fail("Original foot below floor");return
		print("body triangles kept ",character.kept_body_triangles," / old head removed ",character.removed_head_triangles)
		print("chin/collar vertical gap ",minimum_gap,"..",maximum_gap,"; neck/collar distance ",minimum_connection,"..",maximum_connection)
		if not _check_uv(head):return
		if character.wardrobe_materials.is_empty():_fail("Tee material missing");return
		for design in 8:
			character.set_shirt_design(design)
			if not character.wardrobe_active(character.original_rig):_fail("Old whole-mesh override hides the new tee");return
			for material in character.wardrobe_materials:
				if material.get_shader_parameter("tee_design")!=design:
					_fail("Tee design not applied");return
		var sibling:=load("res://character-sculpt/avatar.gd").new() as Node3D
		sibling.ornament_seed=41
		sibling.team=team
		sibling.shirt_design=2
		root.add_child(sibling)
		sibling.set_physics_process(false)
		character.set_shirt_design(5)
		if sibling.wardrobe_materials[0].get_shader_parameter("tee_design")!=2:
			_fail("Tee change leaked into another avatar");return
		sibling.queue_free()
		character.queue_free()
		await process_frame
	print("PASS: scripts parse; original 87-bone body + 31-bone/14-strand head; idle/run/shoot, both teams; eight isolated tee styles")
	quit()

func _check_uv(head: Node3D) -> bool:
	for item in head.meshes:
		for surface in item.mesh.get_surface_count():
			if item.mesh.surface_get_material(surface).resource_name!="SculptSkin":continue
			var arrays: Array=item.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for i in points.size():
				var author_point:=Vector2(points[i].x/.92,1.018+(points[i].y-1.018)/.80)
				if absf(author_point.x-.020)<.005 and absf(author_point.y-1.250)<.005 and points[i].z>.08:
					if absf(uv[i].x-author_point.x)>.0002 or absf(1-uv[i].y-author_point.y)>.0002:
						_fail("Sculpt-space ink UV lost during export/import: "+str([points[i],uv[i]]));return false
					return true
	_fail("No face sample available for UV validation");return false

func _fail(message: String) -> void:
	printerr("FAIL: "+message)
	quit(1)
