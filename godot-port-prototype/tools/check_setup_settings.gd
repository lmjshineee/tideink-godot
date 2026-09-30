extends SceneTree

const MatchSetup := preload("res://match_setup.gd")
const TeamPalette := preload("res://team_palette.gd")


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	MatchSetup.duration_index = 0
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var duration: OptionButton = scene.get("duration_select")
	var payload: Dictionary = scene.get_node("Combat").get("weapon_data")
	var options: Array = payload["match"]["durations"]
	if duration.item_count != options.size() or float(scene.get("round_time")) != float(options[0]):
		_fail("duration UI does not use exported choices/initial option")
		return
	duration.select(1)
	duration.item_selected.emit(1)
	if float(scene.get("round_time")) != float(options[1]) or float(scene.get("round_left")) != float(options[1]):
		_fail("duration selection did not update setup clock")
		return
	# Nondefault values distinguish a data-driven duration from another 90/180 copy.
	payload["match"]["durations"] = [45, 60]
	duration.item_selected.emit(0)
	if float(scene.get("round_time")) != 45.0:
		_fail("injected match duration did not affect clock")
		return
	if MatchSetup.duration({"durations": [], "defaultDuration": 75}) != 75.0:
		_fail("empty duration list did not use configured fallback")
		return
	payload["match"]["durations"] = options
	duration.select(1)
	duration.item_selected.emit(1)
	(scene.get("weapon_buttons")["charger"] as Button).pressed.emit()
	(scene.get("bot_weapon_button") as Button).pressed.emit()
	if scene.get("selected_weapon") != "charger" or scene.get("selected_bot_weapon") != "roller":
		_fail("weapon button signals did not equip player/bot")
		return
	var selector: OptionButton = scene.get("palette_select")
	selector.select(1)
	selector.item_selected.emit(1)
	await _frames(4)
	scene = current_scene
	if TeamPalette.palette_index != 1 or scene.get("selected_weapon") != "charger" \
		or scene.get("selected_bot_weapon") != "roller" or float(scene.get("round_time")) != float(options[1]):
		_fail("palette rebuild lost setup/loadout/duration")
		return
	var hair: MeshInstance3D = scene.get_node("World/Walker/Body/Kid/HairCap")
	if (hair.material_override as StandardMaterial3D).albedo_color != TeamPalette.color(0):
		_fail("palette rebuild did not recolor newly created character")
		return
	var toggle: CheckButton = scene.get("colorblind_toggle")
	toggle.button_pressed = true
	await _frames(4)
	scene = current_scene
	if not TeamPalette.use_colorblind or not (scene.get("colorblind_toggle") as CheckButton).button_pressed:
		_fail("colorblind toggle/rebuild did not retain checkbox state")
		return
	hair = scene.get_node("World/Walker/Body/Kid/HairCap")
	if (hair.material_override as StandardMaterial3D).albedo_color != TeamPalette.color(0):
		_fail("colorblind rebuild did not recolor character")
		return
	scene.call("_begin_intro")
	if (scene.get("setup_options") as HBoxContainer).visible:
		_fail("setup preferences remained visible in intro")
		return
	scene.call("_change_duration", 0)
	scene.call("_change_palette", 0)
	scene.call("_change_colorblind", false)
	if float(scene.get("round_time")) != float(options[1]) or TeamPalette.palette_index != 1 or not TeamPalette.use_colorblind:
		_fail("setup settings changed after intro started")
		return
	scene.call("_start_round")
	(scene.get("weapon_buttons")["blaster"] as Button).pressed.emit()
	(scene.get("bot_weapon_button") as Button).pressed.emit()
	if scene.get("selected_weapon") != "charger" or scene.get("selected_bot_weapon") != "roller":
		_fail("button callbacks allowed live loadout change")
		return
	scene.call("damage_player", 1000.0, true)
	scene.call("_update_hud")
	if not (scene.get("menu_panel") as Panel).visible or (scene.get("setup_options") as HBoxContainer).visible:
		_fail("respawn did not expose only loadout controls")
		return
	(scene.get("weapon_buttons")["blaster"] as Button).pressed.emit()
	scene.call("_change_duration", 0)
	if scene.get("selected_weapon") != "blaster" or float(scene.get("round_time")) != float(options[1]):
		_fail("respawn weapon selection or duration guard regressed")
		return
	TeamPalette.select(0)
	TeamPalette.set_colorblind(false)
	MatchSetup.duration_index = 0
	print("PASS: exported/injected duration choices, GUI loadouts, palette/colorblind rebuild persistence, live/respawn guards")
	quit()


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
