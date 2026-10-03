extends SceneTree

# Bounded native graphical QA with real input + physics. Starting positions,
# paint/refill and lethal damage are fixtures; intro/respawn/results waits are
# shortened explicitly. This is not manual play or a full-duration match.
var scene: Node3D
var walker: CharacterBody3D
var combat: Node3D
var checks: Array[String] = []
var output_label := "candidate"


func _initialize() -> void:
	preload("res://src/core/match_setup.gd").team_size = 1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			output_label = argument.trim_prefix("--label=").validate_filename()
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("native graphical display required")
		return
	root.size = Vector2i(1280, 720)
	seed(20260930)
	scene = (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	walker = scene.get_node("World/Walker")
	combat = scene.get_node("Combat")
	await _frames(8)
	_key(KEY_ENTER, true)
	await _frames(1)
	_key(KEY_ENTER, false)
	await _frames(2)
	if scene.get("phase") != "intro":
		_fail("Enter did not start intro")
		return
	scene.set("phase_time", 4.1)
	await _frames(8)
	if scene.get("phase") != "playing":
		_fail("intro did not enter playing")
		return
	# Reassert pointer state once when the new graphical window receives focus.
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _frames(1)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _frames(15)
	var start := walker.global_position
	_key(KEY_W, true)
	await _frames(15)
	_key(KEY_W, false)
	if walker.global_position.distance_to(start) < 0.5:
		_fail("W input did not move the live walker")
		return
	checks.append("Enter intro and WASD movement")
	walker.set("camera_pitch", -0.35)
	var ink_before := float(combat.get("ink_amount"))
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _frames(20)
	_mouse(MOUSE_BUTTON_LEFT, false)
	if float(combat.get("ink_amount")) >= ink_before or float(scene.get("turf_total")) <= 0.0:
		_fail("shooting input did not consume ink and paint turf")
		return
	checks.append("live shooter input and turf HUD")
	scene.call("paint_at_world", walker.global_position + Vector3.UP * 0.06, 0, 2.0, 0.5)
	combat.set("ink_amount", 20.0)
	combat.set("last_fire_time", 99.0)
	_key(KEY_SHIFT, true)
	await _frames(20)
	if not bool(walker.get("squid_form")) or float(combat.get("ink_amount")) <= 20.0:
		_fail("Shift did not submerge/refill on prepared friendly ink")
		return
	checks.append("live Shift submerge and ink refill")
	_key(KEY_SHIFT, false)
	await _frames(5)
	# Select roller through the permitted respawn loadout input.
	scene.call("damage_player", 1000.0, true)
	if float(scene.get("player_respawn")) <= 0.0:
		_fail("lethal damage fixture did not enter respawn")
		return
	_key(KEY_2, true)
	await _frames(1)
	_key(KEY_2, false)
	await _frames(2)
	if scene.get("selected_weapon") != "roller":
		_fail("respawn loadout input did not select roller")
		return
	scene.set("player_respawn", 0.05)
	await _frames(8)
	if not walker.visible or float(scene.get("player_health")) != 100.0 or float(scene.get("player_respawn")) > 0.0:
		_fail("respawn did not restore the player")
		return
	checks.append("lethal damage, respawn selection and restoration")
	_mouse(MOUSE_BUTTON_LEFT, true)
	_key(KEY_W, true)
	await _frames(25)
	if not bool(combat.get("rolling")):
		_fail("roller input did not engage rolling")
		return
	_key(KEY_W, false)
	_mouse(MOUSE_BUTTON_LEFT, false)
	checks.append("live roller input")
	await _save(output_label + "-live")
	# Exercise a visible isolated 0.35m curb through the unchanged live controller.
	_box(Vector3(0, 99.5, 0), Vector3(30, 1, 30))
	_box(Vector3(0, 100.175, 0), Vector3(10, 0.35, 2))
	walker.global_position = Vector3(0, 100.05, -4)
	walker.call("reset_movement_state")
	walker.set("camera_yaw", 0.0)
	await _frames(12)
	_key(KEY_W, true)
	var reached := false
	for i in range(55):
		await physics_frame
		if walker.global_position.z > -0.4 and walker.global_position.y > 100.3:
			reached = true
			break
	if not reached:
		_fail("live walker did not ascend 0.35m curb")
		return
	for i in range(35):
		await physics_frame
		if walker.global_position.z > 1.6:
			break
	_key(KEY_W, false)
	await _frames(10)
	if walker.global_position.z <= 1.0 or absf(walker.global_position.y - 100.0) > 0.05 or not bool(walker.get("grounded")):
		_fail("live walker did not descend curb to grounded floor")
		return
	checks.append("live step up/down on isolated visible 0.35m curb")
	# Return to the map before displaying the result screen.
	walker.global_position = scene.get_node("World/Map").get("spawn_pads")[0] + Vector3.UP * 0.05
	walker.call("reset_movement_state")
	scene.set("round_left", 0.05)
	await _frames(5)
	if scene.get("phase") != "finish":
		_fail("timer did not finish round")
		return
	scene.set("phase_time", 2.55)
	await _frames(5)
	if scene.get("phase") != "results":
		_fail("finish did not directly reach results")
		return
	await _save(output_label + "-results")
	_key(KEY_ENTER, true)
	await _frames(1)
	_key(KEY_ENTER, false)
	await _frames(8)
	if current_scene == scene or current_scene.get("phase") != "setup":
		_fail("results Enter did not reload a fresh setup scene")
		return
	checks.append("accelerated finish directly to results and Enter restart")
	await _save(output_label + "-restart")
	var report := {"checks": checks, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info()["string"],
		"note": "Native automated input/physics smoke; injected fixtures and shortened waits; not manual or full-duration/thermal acceptance."}
	var file := FileAccess.open("res://render-evidence/" + output_label + "-qa.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PASS: ", JSON.stringify(report))
	quit()


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	# Standalone --script trees do not route the synthetic window event to root.
	# Dispatch through the viewport as well as updating the Input singleton.
	root.push_input(event)


func _mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	root.push_input(event)


func _box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	body.add_child(mesh)
	scene.add_child(body)


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.save_png("res://render-evidence/" + label + ".png") != OK:
		_fail("could not save " + label)


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
