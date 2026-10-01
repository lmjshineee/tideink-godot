extends SceneTree
func _initialize() -> void: call_deferred("_check")
func _check() -> void:
	var setup := preload("res://match_setup.gd")
	setup.screen = "home"
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var front: Control = scene.get("frontend")
	if scene.phase!="home" or not front.home.visible or front.preparation.visible or scene.menu_panel.visible or scene.score_panel.visible:
		fail("app must open main menu with no battle/setup HUD");return
	if front.model.get("ornament_seed")!=scene.get_node("World/Walker/Body").get("ornament_seed"):
		fail("full body preview must use the actual actor appearance");return
	front.play_button.pressed.emit()
	if scene.phase!="setup" or not front.preparation.visible or front.home.visible:
		fail("PLAY enters preparation");return
	if scene.weapon_cards.size()!=7 or front.item_buttons.size()!=7:
		fail("seven weapons and seven pre-match items");return
	for id in scene.weapon_order:
		if scene.weapon_cards[id].get_child(0).texture==null:
			fail("missing source weapon icon");return
	scene.weapon_buttons["charger"].pressed.emit()
	front.item_buttons["shield"].pressed.emit()
	if scene.selected_weapon!="charger" or scene.items.state(scene.get_node("World/Walker"))["kind"]!="shield":
		fail("GUI weapon/item loadout is not equipped");return
	scene._begin_intro()
	if front.visible or scene.menu_panel.visible:
		fail("preparation covers intro");return
	scene._start_round()
	scene.damage_player(200)
	scene._update_hud()
	if front.visible or scene.menu_panel.visible:
		fail("death must not reopen preparation menus");return
	print("PASS: main -> preparation -> battle, full body matches actor, source weapon icons, chosen item and no death menu")
	quit()
func fail(message: String) -> void:
	printerr("FAIL: ",message);quit(1)
