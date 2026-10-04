extends SceneTree

func _initialize() -> void:
	# Historical fixture timings are measured at 60 Hz; match runtime is 30 Hz.
	Engine.physics_ticks_per_second = 60
	call_deferred("_check")

func _check() -> void:
	var packed := load("res://scenes/world/tidewater_walk.tscn") as PackedScene
	if packed == null:
		printerr("FAIL: traversal scene did not load")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var walker: CharacterBody3D = scene.get_node("Walker")
	for i in range(12):
		await physics_frame
	if not bool(walker.get("grounded")) or absf(walker.position.y - 2.2) > 0.15:
		printerr("FAIL: walker did not land on spawn deck: ", walker.position)
		quit(1)
		return
	var start_z := walker.position.z
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(25):
		await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	if walker.position.z < start_z + 1.5 or not bool(walker.get("grounded")):
		printerr("FAIL: walker did not move along spawn deck: ", walker.position)
		quit(1)
		return
	walker.position = Vector3(-8.4, 2.28, -39.2)
	walker.velocity = Vector3.ZERO
	for i in range(10):
		await physics_frame
	# Facing +Z, screen-right (D) points toward the -X spawn ramp.
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(60):
		await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	if walker.position.x > -13.0 or walker.position.y > 1.3 or not bool(walker.get("grounded")):
		printerr("FAIL: walker did not descend source ramp: ", walker.position)
		quit(1)
		return
	print("PASS: Tidewater walker lands, crosses spawn deck and descends a source ramp")
	quit()
