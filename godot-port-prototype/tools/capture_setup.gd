extends SceneTree

# Native GUI smoke: click actual weapon/bot/colorblind controls. Popup selection
# uses the PopupMenu index_pressed signal (same path as choosing its menu item).
const TeamPalette := preload("res://team_palette.gd")
var mouse_notified := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("graphical display required")
		return
	root.size = Vector2i(1280, 720)
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(8)
	await _click(scene.get("weapon_buttons")["charger"])
	await _click(scene.get("bot_weapon_button"))
	if scene.get("selected_weapon") != "charger" or scene.get("selected_bot_weapon") != "roller":
		_fail("native mouse clicks did not select player/bot weapons")
		return
	var duration: OptionButton = scene.get("duration_select")
	duration.get_popup().index_pressed.emit(1)
	if float(scene.get("round_time")) != 180.0:
		_fail("duration popup choice did not select 180 seconds")
		return
	var palette: OptionButton = scene.get("palette_select")
	palette.get_popup().index_pressed.emit(1)
	await _frames(8)
	scene = current_scene
	if scene.get("selected_weapon") != "charger" or scene.get("selected_bot_weapon") != "roller" \
		or float(scene.get("round_time")) != 180.0 or TeamPalette.palette_index != 1:
		_fail("native palette rebuild lost setup choices")
		return
	if not await _save("setup-menu"):
		return
	await _click(scene.get("colorblind_toggle"))
	await _frames(8)
	scene = current_scene
	if not TeamPalette.use_colorblind:
		_fail("native colorblind checkbox click did not rebuild")
		return
	root.size = Vector2i(960, 540)
	await _frames(8)
	var menu: Panel = scene.get("menu_panel")
	var row: HBoxContainer = scene.get("setup_options")
	for control in row.get_children():
		if not menu.get_global_rect().encloses((control as Control).get_global_rect()):
			_fail("setup option overflows menu at 960x540")
			return
	if not await _save("setup-small-colorblind"):
		return
	scene.call("_start_round")
	scene.call("damage_player", 1000.0, true)
	scene.call("_update_hud")
	await _frames(2)
	await _click(scene.get("weapon_buttons")["blaster"])
	if scene.get("selected_weapon") != "blaster" or (scene.get("setup_options") as HBoxContainer).visible:
		_fail("native respawn click did not change only the player weapon")
		return
	if not await _save("setup-respawn"):
		return
	print("PASS: native mouse loadouts/checkbox, popup-driven palette/duration, preserved selections and 960x540 layout; respawn-only weapon controls")
	quit()


func _click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	if not mouse_notified:
		root.notify_mouse_entered()
		mouse_notified = true
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(1)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _save(label: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.save_png("res://render-evidence/" + label + ".png") != OK:
		_fail("could not save " + label)
		return false
	return true


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
