extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var menu: Panel = scene.get("menu_panel")
	var cards: Dictionary = scene.get("weapon_cards")
	var size := scene.get_viewport().get_visible_rect().size
	if not menu.visible or cards.size() != 4 or (menu.position + menu.size * 0.5).distance_to(size * 0.5) > 2.0:
		_fail("setup loadout panel is absent or not centered")
		return
	for card in cards.values():
		var icon := card.get_child(0) as TextureRect
		if icon.texture == null:
			_fail("loadout card lacks its source weapon icon")
			return
		if icon.size.x > 70.0 or icon.size.y > 70.0 or icon.position.y + icon.size.y > card.size.y - 25.0:
			_fail("loadout icon overflows its card: %s at %s" % [icon.size, icon.position])
			return
	var select := InputEventKey.new()
	select.keycode = KEY_3
	select.pressed = true
	scene.call("_input", select)
	if scene.get("selected_weapon") != "charger" or scene.get_node("Combat").get("selected_id") != "charger":
		_fail("menu keyboard selection did not update the equipped weapon")
		return
	var selected_style := (cards["charger"] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	if selected_style.border_color != Color("ff8a14"):
		_fail("selected weapon card lacks the orange highlight")
		return
	scene.call("_begin_intro")
	if menu.visible:
		_fail("loadout panel remained over the intro")
		return
	scene.call("_start_round")
	scene.call("damage_player", 100.0)
	scene.call("_update_hud")
	if not menu.visible or not String(scene.get("menu_hint").text).contains("重生"):
		_fail("loadout panel did not return during respawn")
		return
	print("PASS: centered setup menu, four imported icons, selection highlight and respawn loadout")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
