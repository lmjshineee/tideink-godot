extends SceneTree


func _initialize() -> void:
	preload("res://src/core/match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	scene.call("show_preparation")
	_key(KEY_4, true)
	_key(KEY_4, false)
	await process_frame
	var combat: Node3D = scene.get_node("Combat")
	if scene.get("selected_weapon") != "blaster" or combat.get("selected_id") != "blaster":
		_fail("key 4 did not equip the blaster before the match")
		return
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	await process_frame
	if scene.get("phase") != "intro":
		_fail("Enter did not begin the intro")
		return
	scene.call("_physics_process", 4.3)
	if scene.get("phase") != "playing" or not bool(scene.get("pointer_locked")):
		_fail("intro did not start controllable play")
		return
	# Aim at the floor before firing: a shot aimed at the horizon bursts in the air
	# past the platform and paints nothing, so the check states the aim explicitly.
	# The SceneTree's physics_frame signal fires before nodes are processed, so more
	# than one frame is awaited before the walker's camera transform is up to date.
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	walker.set("camera_pitch", -0.55)
	for i in range(3):
		await physics_frame
	_mouse(MOUSE_BUTTON_LEFT, true)
	scene.call("_physics_process", 0.01)
	_mouse(MOUSE_BUTTON_LEFT, false)
	if (combat.get("projectiles") as Array).is_empty() or float(combat.get("ink_amount")) > 91.01:
		_fail("left mouse button did not fire: projectiles=%d ink=%.2f paused=%s locked=%s" % [
			(combat.get("projectiles") as Array).size(), float(combat.get("ink_amount")),
			str(scene.get("paused")), str(scene.get("pointer_locked"))])
		return
	for step in range(40):
		combat.call("advance_effects", 0.05)
	var ink: RefCounted = scene.get("ink")
	scene.call("_update_hud")
	if float(ink.call("coverage", 0)) <= 0.0 or float((scene.get("orange_bar") as ProgressBar).value) <= 0.0:
		_fail("mouse-fired shot did not reach turf coverage and HUD: projectiles=%d version=%d coverage=%.5f" % [
			(combat.get("projectiles") as Array).size(), int(ink.get("version")),
			float(ink.call("coverage", 0))])
		return
	_mouse(MOUSE_BUTTON_RIGHT, true)
	scene.call("_physics_process", 0.01)
	if not bool(walker.get("sub_intent")):
		_fail("right mouse hold did not reach the facing controller")
		return
	_mouse(MOUSE_BUTTON_RIGHT, false)
	scene.call("_physics_process", 0.01)
	if (combat.get("bombs") as Array).size() != 1 or float(combat.get("ink_amount")) > 21.01:
		_fail("right mouse release did not throw a bomb")
		return
	scene.call("damage_player", 200.0)
	_key(KEY_2, true)
	_key(KEY_2, false)
	await process_frame
	if float(scene.get("player_respawn")) <= 0.0 or scene.get("selected_weapon") != "roller":
		_fail("key 2 did not switch weapons during the respawn wait")
		return
	scene.call("launch_respawn")
	scene.call("_update_player_respawn", 5.6)
	if float(scene.get("player_respawn")) != 0.0 or combat.get("selected_id") != "roller":
		_fail("respawn did not retain the selected weapon")
		return
	print("PASS: input events select, start, shot-to-HUD, throw and switch on respawn")
	quit()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
