extends SceneTree

const Settings = preload("res://tidewater_settings.gd")


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var path := "/tmp/inkwave-settings-%d.cfg" % OS.get_process_id()
	var saved := Settings.new()
	saved.fps_cap = 45
	saved.ui_scale = 1.1
	saved.mouse_sensitivity = 0.0035
	if saved.save_to(path) != OK:
		_fail("could not save settings fixture")
		return
	var loaded := Settings.new()
	if not loaded.load_from(path) or loaded.fps_cap != 45 or not is_equal_approx(loaded.ui_scale, 1.1) \
			or not is_equal_approx(loaded.mouse_sensitivity, 0.0035):
		_clean(path)
		_fail("frame cap and mouse sensitivity did not persist")
		return
	var scene := (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var walker: CharacterBody3D = scene.get_node("Walker")
	loaded.apply_to(walker)
	walker.call("apply_look_delta", Vector2(100.0, 0.0))
	if Engine.max_fps != 45 or not is_equal_approx(float(walker.get("camera_yaw")), -0.35):
		_clean(path)
		_fail("loaded settings did not control the frame cap and camera")
		return
	var invalid := ConfigFile.new()
	invalid.set_value("display", "fps_cap", 999)
	invalid.set_value("display", "ui_scale", 3.0)
	invalid.set_value("controls", "mouse_sensitivity", -1.0)
	if invalid.save(path) != OK or not loaded.load_from(path):
		_clean(path)
		_fail("could not load invalid settings fixture")
		return
	_clean(path)
	if loaded.fps_cap != Settings.DEFAULT_FPS or not is_equal_approx(loaded.ui_scale, Settings.DEFAULT_UI_SCALE) \
			or not is_equal_approx(loaded.mouse_sensitivity, Settings.MIN_LOOK_SENSITIVITY):
		_fail("invalid settings were not normalized to safe values")
		return
	print("PASS: FPS, UI scale and sensitivity persist and validate; frame cap/camera apply")
	quit()


func _clean(path: String) -> void:
	DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
