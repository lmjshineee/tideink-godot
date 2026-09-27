extends SceneTree

const SurfaceInk = preload("res://surface_ink.gd")


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var walker: CharacterBody3D = scene.get_node("Walker")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater_surfaces.json"))
	var ink = SurfaceInk.new(data)
	walker.set("ink", ink)
	walker.global_position = Vector3(5.5, 0.1, 0.0)
	await physics_frame
	var inward := Vector2(-1.0, 0.0)
	if bool(walker.call("_update_climb", 1.0 / 30.0, true, inward)) or bool(walker.get("climbing")):
		_fail("dry wall should not attach")
		return
	ink.splat_face(5, 5.0, 1.4, 3.0, 1, 0.5)
	if bool(walker.call("_update_climb", 1.0 / 30.0, true, inward)):
		_fail("enemy ink wall should not attach")
		return
	ink.splat_face(5, 5.0, 1.4, 3.0, 0, 0.5)
	if not bool(walker.call("_update_climb", 1.0 / 30.0, true, inward)) or not bool(walker.get("climbing")):
		_fail("own ink wall should attach")
		return
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift.duplicate())
	var left := InputEventKey.new()
	left.physical_keycode = KEY_A
	left.pressed = true
	Input.parse_input_event(left.duplicate())
	var start_y := walker.global_position.y
	for i in range(12):
		await physics_frame
	if walker.global_position.y < start_y + 0.3:
		_fail("own ink wall did not lift walker: " + str(walker.global_position))
		return
	shift.pressed = false
	Input.parse_input_event(shift.duplicate())
	for i in range(2):
		await physics_frame
	if bool(walker.get("climbing")):
		_fail("releasing squid should detach")
		return
	left.pressed = false
	Input.parse_input_event(left.duplicate())
	walker.call("reset_movement_state")
	walker.global_position = Vector3(5.5, 0.1, 0.0)
	shift.pressed = true
	Input.parse_input_event(shift.duplicate())
	left.pressed = true
	Input.parse_input_event(left.duplicate())
	var peak := walker.global_position.y
	var popped := false
	for i in range(65):
		await physics_frame
		peak = maxf(peak, walker.global_position.y)
		popped = popped or float(walker.get("climb_exit")) > 0.0 and peak > 2.0
	shift.pressed = false
	Input.parse_input_event(shift)
	left.pressed = false
	Input.parse_input_event(left)
	if peak < 2.6 or not popped:
		_fail("own ink did not carry walker over the ledge: peak=" + str(peak) + " pos=" + str(walker.global_position))
		return
	print("PASS: dry/enemy walls reject; own ink climbs; squid release detaches; ledge pops")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
