extends SceneTree

const Settings = preload("res://src/ui/tidewater_settings.gd")
const TEST_PATH := "/tmp/inkwave-settings-ui-check.cfg"


func _initialize() -> void:
	preload("res://src/core/match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	var scene := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	scene.set("settings_path", TEST_PATH)
	root.add_child(scene)
	await process_frame
	scene.call("show_preparation")
	var panel: Panel = scene.get("settings_panel")
	var setup_button: Button = scene.get("frontend").get("settings_button")
	var pause_panel: Panel = scene.get("pause_panel")
	if not setup_button.visible or panel.visible or pause_panel.visible:
		_fail("setup settings entry has the wrong initial visibility")
		return
	_click(setup_button)
	await process_frame
	if not panel.visible or (scene.get("menu_panel") as Panel).visible or bool(scene.get("pointer_locked")):
		_fail("setup settings panel did not open with the pointer available")
		return
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	scene.call("_input", enter)
	if scene.get("phase") != "setup":
		_fail("Enter started the round while settings were open")
		return
	var fps: OptionButton = panel.get("fps_button")
	fps.select(1)
	var ui_scale: OptionButton = panel.get("ui_scale_button")
	ui_scale.select(2)
	(panel.get("sensitivity_slider") as HSlider).value = 0.0035
	_click(panel.get("save_button") as Button)
	await process_frame
	if panel.visible or Engine.max_fps != 45 or absf(float(scene.get_node("World/Walker").get("look_sensitivity")) - 0.0035) > 0.00001 \
			or absf((scene.get("hud_root") as Control).scale.x - 1.1) > 0.00001:
		_fail("saving did not close and immediately apply FPS, scale and sensitivity")
		return
	var saved := Settings.new()
	if not saved.load_from(TEST_PATH) or saved.fps_cap != 45 or absf(saved.ui_scale - 1.1) > 0.00001 \
			or absf(saved.mouse_sensitivity - 0.0035) > 0.00001:
		_fail("settings were not persisted to the config file")
		return
	_click(setup_button)
	await process_frame
	_click(panel.get("reset_button") as Button)
	await process_frame
	if fps.get_selected_id() != 30 or ui_scale.get_selected_id() != 100 \
			or absf((panel.get("sensitivity_slider") as HSlider).value - Settings.DEFAULT_LOOK_SENSITIVITY) > 0.00001:
		_fail("reset did not restore default draft values")
		return
	_click(panel.get("cancel_button") as Button)
	await process_frame
	if panel.visible or Engine.max_fps != 45 or absf((scene.get("hud_root") as Control).scale.x - 1.1) > 0.00001 \
			or not (scene.get("menu_panel") as Panel).visible:
		_fail("cancel changed applied settings or failed to return to setup")
		return
	scene.call("_start_round")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene.call("_input", escape)
	if not bool(scene.get("paused")) or not pause_panel.visible or bool(scene.get("pointer_locked")):
		_fail("Esc did not open the pause controls")
		return
	await process_frame
	_click(scene.get("pause_settings_button") as Button)
	await process_frame
	if not panel.visible or pause_panel.visible or not bool(scene.get("paused")):
		_fail("pause settings entry did not keep the round paused")
		return
	_click(panel.get("cancel_button") as Button)
	await process_frame
	if panel.visible or not pause_panel.visible or not bool(scene.get("paused")):
		_fail("closing settings did not restore the pause controls")
		return
	_click(scene.get("pause_resume_button") as Button)
	await process_frame
	if bool(scene.get("paused")) or not bool(scene.get("pointer_locked")) or pause_panel.visible:
		_fail("resume button did not return to play")
		return
	scene.call("damage_player", 200.0)
	if pause_panel.visible or setup_button.is_visible_in_tree():
		_fail("settings entry leaked into the respawn loadout")
		return
	DirAccess.remove_absolute(TEST_PATH)
	print("PASS: setup/pause settings clicks, FPS/scale/sensitivity save, reset/cancel and respawn visibility")
	quit()


func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
	event.global_position = event.position
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _fail(message: String) -> void:
	DirAccess.remove_absolute(TEST_PATH)
	printerr("FAIL: ", message)
	quit(1)
