extends SceneTree
const Visual := preload("res://tidewater_character_visual.gd")
const Setup := preload("res://match_setup.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var visuals: Array[Node3D] = []
	for i in range(4):
		var visual := Visual.new()
		visual.style_index = i
		root.add_child(visual)
		visual.set_physics_process(false)
		visuals.append(visual)
		if visual.face_material == null or visual.eye_material == null or visual.skeleton.get_bone_count()!=87:
			fail("missing semantic face/eye or original rig");return
		if visual.eye_material.get_shader_parameter("iris_color") != Visual.IRIS[i]:
			fail("wrong style iris");return
		for mesh in meshes(visual.original_rig):
			var semantic := mesh.mesh.surface_get_material(0).resource_name
			var arrays := mesh.mesh.surface_get_arrays(0)
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			if uv.is_empty() or uv2.size()!=uv.size():
				fail("lost source semantic coordinates: "+semantic);return
			if semantic=="Eyes":
				var negative := false
				var center := false
				for point in uv:
					negative = negative or point.x < -0.5
					center = center or point.length()<0.001
				if not negative or not center:
					fail("eye UV must be signed and centered on zero");return
		for weapon in ["shooter","roller","charger","blaster"]:
			visual.set_weapon(weapon)
			visual.set_aim(false)
			visual.set_expression_state(1,1,0,false)
			animate(visual,30)
			var smile: Vector4 = visual.face_material.get_shader_parameter("mouth")
			visual.set_expression_state(0.05,1,0,false)
			animate(visual,30)
			var worry: Vector4 = visual.face_material.get_shader_parameter("mouth")
			if visual.face_expression!="low" or smile.distance_to(worry)<0.1:
				fail("low ink did not change expression for "+weapon);return
			visual.set_expression_state(1,0.15,0,false)
			animate(visual,30)
			if visual.face_expression!="tired":
				fail("low health did not select tired face");return
			visual.set_expression_state(1,1,1,false)
			animate(visual,30)
			if visual.face_expression!="charge":
				fail("charge expression");return
			visual.set_expression_state(1,1,0,true)
			animate(visual,30)
			if visual.face_expression!="special":
				fail("special expression");return
			visual.set_expression_state(1,1,0,false)
			visual.set_action("shoot")
			visual.call("_animate",1.0/30.0)
			if visual.face_expression!="fire":
				fail("shot expression");return
			animate(visual,30)
			var eye := visual.skeleton.find_bone("eyeL")
			var open := visual.skeleton.get_bone_pose_scale(eye).y
			visual.set("_blink_remaining",0.0)
			animate(visual,3,false)
			if visual.skeleton.get_bone_pose_scale(eye).y > open*0.6:
				fail("blink did not close eye");return
			animate(visual,12,false)
			if absf(visual.skeleton.get_bone_pose_scale(eye).y-open)>0.08:
				fail("blink did not reopen eye");return
			visual.set_reaction("hit")
			animate(visual,40)
			visual.set_aim(true)
			animate(visual,20)
			if visual.face_expression!="focus" or not visual.reaction_name.is_empty():
				fail("one-shot did not yield to continuous expression");return
	if visuals[0].face_material==visuals[1].face_material or visuals[0].eye_material==visuals[1].eye_material:
		fail("characters share mutable facial uniforms");return
	for visual in visuals:
		visual.queue_free()
	await process_frame
	for map_id in ["tidewater","kelpline"]:
		Setup.map_id = map_id
		var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
		game.set("settings_path","/private/tmp/inkwave-appearance-check.cfg")
		root.add_child(game)
		game.set_physics_process(false)
		var cinematic: Node3D = game.get("presentation").get("cinematic")
		var camera: Camera3D = cinematic.get("camera")
		var following: Camera3D = game.get_node("World/Walker/Camera3D")
		var coverage := [game.get("ink").call("coverage",0),game.get("ink").call("coverage",1)]
		game.call("_begin_intro")
		if root.get_camera_3d()!=camera or camera.global_position.distance_to(Vector3(18,26,30))>0.01:
			fail("source intro start pose");return
		game.set("phase_time",1.8)
		cinematic.call("sync")
		var pad: Vector3 = game.get_node("World/Map").get("spawn_pads")[0]
		var midpoint := Vector3(18,26,30).lerp(pad+Vector3(0,2.6,-5.2),0.5)+Vector3.UP*1.5
		if camera.global_position.distance_to(midpoint)>0.01:
			fail("source cubic path/arc midpoint");return
		game.set("phase_time",4.2)
		cinematic.call("sync")
		if camera.global_transform.origin.distance_to(following.global_position)>0.001 or camera.global_basis.get_rotation_quaternion().angle_to(following.global_basis.get_rotation_quaternion())>0.001:
			fail("intro handoff has a camera cut");return
		game.call("_start_round")
		if root.get_camera_3d()!=following or [game.get("ink").call("coverage",0),game.get("ink").call("coverage",1)]!=coverage:
			fail("gameplay camera/ink authority affected by cinematic");return
		game.queue_free()
		await process_frame
	Setup.map_id = "tidewater"
	DirAccess.remove_absolute("/private/tmp/inkwave-appearance-check.cfg")
	print("PASS: signed eye UV/semantic attributes, four independent faces, seven source expressions/four weapons, blinking/recovery, source intro path and seamless camera handoff on both maps; ink unchanged")
	quit()

func animate(visual: Node3D,count: int,suppress_blink: bool = true) -> void:
	if suppress_blink:
		visual.set("_blink_remaining",10.0)
	for i in count:
		visual.call("_animate",1.0/30.0)

func meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(meshes(child))
	return found

func fail(message: String) -> void:
	printerr("FAIL: "+message)
	quit(1)
