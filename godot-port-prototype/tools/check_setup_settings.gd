extends SceneTree
func _initialize() -> void: call_deferred("_check")
func _check() -> void:
	var setup := preload("res://match_setup.gd")
	setup.duration_index = 0
	var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.show_preparation()
	var front: Control = game.frontend
	var payload: Dictionary = game.get_node("Combat").get("weapon_data")
	var durations: Array = payload["match"]["durations"]
	if front.duration_choice.item_count!=durations.size():
		fail("duration options must come from export");return
	front.duration_choice.item_selected.emit(1)
	if game.round_time!=float(durations[1]):
		fail("duration choice not applied");return
	payload["match"]["durations"] = [45,60]
	front.duration_choice.item_selected.emit(0)
	if game.round_time!=45:
		fail("injected duration ignored");return
	payload["match"]["durations"] = durations
	front.duration_choice.item_selected.emit(1)
	game.weapon_buttons["charger"].pressed.emit()
	front.item_buttons["recall"].pressed.emit()
	var previous: int = setup.appearance_seed
	front.random_button.pressed.emit()
	for i in range(4): await process_frame
	game = current_scene
	if game.phase!="setup" or game.selected_weapon!="charger" or setup.selected_item!="recall" or game.round_time!=float(durations[1]) or previous==setup.appearance_seed:
		fail("random appearance lost preparation or did not change seed");return
	var hair: MeshInstance3D = game.get_node("World/Walker/Body/Kid/HairCap")
	if hair.material_override.albedo_color!=preload("res://team_palette.gd").color(0):
		fail("random palette differs from character material");return
	game._begin_intro()
	game._change_duration(0)
	if game.round_time!=float(durations[1]) or game.frontend.visible:
		fail("intro changed preparation settings");return
	game._start_round()
	game.weapon_buttons["blaster"].pressed.emit()
	if game.selected_weapon!="charger":
		fail("live player equipment should remain selected");return
	print("PASS: exported/injected durations, random appearance rebuild retains weapon/item/map/duration, material palette and live guard")
	quit()
func fail(message: String) -> void:
	printerr("FAIL: ",message);quit(1)
