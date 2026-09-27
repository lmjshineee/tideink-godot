extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	var camera: Camera3D = walker.get_node("Camera3D")
	var initial_forward := -camera.global_transform.basis.z
	if initial_forward.dot(Vector3.BACK) < 0.95:
		_fail("camera does not initially aim toward the opposing +Z side")
		return
	var move_forward: Vector2 = walker.call("_camera_relative_axis", Vector2(0.0, 1.0))
	var move_right: Vector2 = walker.call("_camera_relative_axis", Vector2(1.0, 0.0))
	if move_forward.distance_to(Vector2(0.0, 1.0)) > 0.01 or move_right.distance_to(Vector2(-1.0, 0.0)) > 0.01:
		_fail("movement is not relative to the initial camera heading")
		return
	if _camera_overlaps_map(scene, camera):
		_fail("initial camera intersects spawn geometry")
		return
	walker.call("apply_look_delta", Vector2(-PI * 0.5 / 0.0021, 0.0))
	var turned_forward := -camera.global_transform.basis.z
	move_forward = walker.call("_camera_relative_axis", Vector2(0.0, 1.0))
	if turned_forward.dot(Vector3.RIGHT) < 0.98 or move_forward.distance_to(Vector2(1.0, 0.0)) > 0.01:
		_fail("mouse yaw does not rotate aim and forward movement together")
		return
	walker.call("apply_look_delta", Vector2(PI * 0.5 / 0.0021, -2000.0))
	if absf(float(walker.get("camera_pitch")) - 1.15) > 0.001:
		_fail("camera pitch was not clamped")
		return
	if _camera_overlaps_map(scene, camera):
		_fail("camera entered spawn geometry when looking upward")
		return
	scene.call("_start_round")
	if not bool(scene.get("pointer_locked")) or not bool(walker.get("look_enabled")) or not scene.get("crosshair").visible:
		_fail("round start did not enable mouse look and show crosshair")
		return
	await process_frame
	var crosshair: Label = scene.get("crosshair")
	var crosshair_center := crosshair.global_position + crosshair.size * 0.5
	var viewport_center := scene.get_viewport().get_visible_rect().size * 0.5
	if crosshair_center.distance_to(viewport_center) > 5.0:
		_fail("crosshair is not centered: %s vs %s" % [crosshair_center, viewport_center])
		return
	var remaining := float(scene.get("round_left"))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene.call("_input", escape)
	scene.call("_physics_process", 0.5)
	if not bool(scene.get("paused")) or float(scene.get("round_left")) != remaining or bool(walker.get("active")):
		_fail("Escape did not pause movement and the match timer")
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	scene.call("_input", click)
	if bool(scene.get("paused")) or not bool(scene.get("pointer_locked")) or not bool(walker.get("active")):
		_fail("click did not resume the match")
		return
	scene.call("_finish_round")
	if bool(scene.get("pointer_locked")) or bool(walker.get("look_enabled")) or scene.get("crosshair").visible:
		_fail("finish did not release mouse and hide crosshair")
		return
	print("PASS: camera orbit, relative movement, wall clearance, pitch clamp and mouse lock lifecycle")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)


func _camera_overlaps_map(scene: Node3D, camera: Camera3D) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), camera.global_position)
	query.collision_mask = 1
	return not scene.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
