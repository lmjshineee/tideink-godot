extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	scene.call("_start_round")
	if float(scene.get("player_invuln")) != 0.0:
		_fail("initial lineup should not have respawn protection")
		return
	var bot: Node3D = scene.get_node("Bot")
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	var combat: Node3D = scene.get_node("Combat")
	var weapon_data: Dictionary = combat.get("weapon_data")
	var shooter: Dictionary = weapon_data["weapons"]["shooter"]
	combat.call("_spawn_projectile", "shooter", Vector3(0.0, 3.0, 37.2), Vector3(0.0, 0.0, 34.0), shooter)
	combat.call("_update_projectiles", 0.1)
	if absf(float(scene.get("bot_health")) - 64.0) > 0.01:
		_fail("shooter shot missed visible bot or damage differs from source")
		return
	scene.call("damage_bot", 64.0)
	if float(scene.get("bot_respawn")) <= 0.0 or bot.visible:
		_fail("bot death")
		return
	scene.call("_update_bot", 4.1)
	if float(scene.get("bot_health")) != 100.0 or not bot.visible:
		_fail("bot respawn")
		return
	walker.global_position = Vector3(0.0, 2.25, 31.2)
	var charger: Dictionary = weapon_data["weapons"]["charger"]
	combat.call("_fire_charger", charger, 1.0, Vector3(0.0, 0.0, 1.0))
	if float(scene.get("bot_respawn")) <= 0.0:
		_fail("full charger hit should splat bot")
		return
	scene.call("_update_bot", 4.1)
	var blaster: Dictionary = weapon_data["weapons"]["blaster"]
	combat.call("_spawn_projectile", "blaster", Vector3(0.0, 3.0, 37.2), Vector3(0.0, 0.0, 23.0), blaster)
	combat.call("_update_projectiles", 0.1)
	if float(scene.get("bot_respawn")) <= 0.0:
		_fail("blaster direct hit should splat bot")
		return
	scene.call("_update_bot", 4.1)
	var roller: Dictionary = weapon_data["weapons"]["roller"]
	combat.call("_paint_roll_at", Vector3(0.0, 2.2, 38.2), Vector3(0.0, 0.0, 0.5), roller)
	if float(scene.get("bot_respawn")) <= 0.0:
		_fail("roller contact should splat bot")
		return
	scene.call("_update_bot", 4.1)
	walker.global_position = Vector3(0.0, 2.25, 39.2)
	scene.call("_update_bot", 0.1)
	if absf(float(scene.get("player_health")) - 82.0) > 0.01:
		_fail("bot close-range attack")
		return
	combat.set("charging", true)
	scene.call("damage_player", 82.0)
	if float(scene.get("player_respawn")) <= 0.0 or walker.visible or bool(walker.get("active")) or bool(combat.get("charging")):
		_fail("player death and weapon cancellation")
		return
	var select := InputEventKey.new()
	select.keycode = KEY_4
	select.pressed = true
	scene.call("_input", select)
	if scene.get("selected_weapon") != "blaster" or combat.get("selected_id") != "blaster":
		_fail("weapon change during respawn")
		return
	scene.call("_update_player_respawn", 5.6)
	if float(scene.get("player_respawn")) != 0.0 or float(scene.get("player_health")) != 100.0 \
		or not walker.visible or not bool(walker.get("active")) or combat.get("selected_id") != "blaster" \
		or float(scene.get("player_invuln")) <= 0.0:
		_fail("player respawn state")
		return
	scene.call("damage_player", 50.0)
	if float(scene.get("player_health")) != 100.0:
		_fail("respawn protection did not block direct damage")
		return
	select.keycode = KEY_1
	scene.call("_input", select)
	if scene.get("selected_weapon") != "blaster":
		_fail("weapon changed while alive")
		return
	walker.global_position.y = -2.0
	scene.call("_update_player_respawn", 0.01)
	if float(scene.get("player_respawn")) <= 0.0:
		_fail("sea fall should start respawn")
		return
	print("PASS: four weapon damage paths, bot/player respawn, loadout switch and sea fall")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
