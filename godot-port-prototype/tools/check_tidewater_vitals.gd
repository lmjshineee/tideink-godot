extends SceneTree


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.call("_start_round")
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	for i in range(12):
		await physics_frame
	if not bool(walker.get("grounded")):
		_fail("player did not settle on the spawn deck")
		return
	scene.call("paint_at_world", walker.global_position + Vector3.UP * 0.06, 1, 0.9, 0.5)
	await physics_frame
	if int(walker.get("ink_owner")) != 1:
		_fail("enemy ink did not reach the player's floor sample")
		return
	scene.set_physics_process(false)
	walker.set("active", false)
	if float(scene.get("player_health")) != 100.0 or float(scene.get("player_invuln")) != 0.0:
		_fail("initial lineup should start healthy without respawn protection")
		return
	scene.call("damage_player", 10.0)
	if float(scene.get("player_health")) != 90.0:
		_fail("initial lineup incorrectly blocked normal damage")
		return
	scene.set("player_health", 100.0)
	scene.set("player_last_damage", 99.0)
	for i in range(5):
		scene.call("_update_player_vitals", 0.5)
	if absf(float(scene.get("player_health")) - 60.0) > 0.01 or absf(float(scene.get("player_ink_damage")) - 40.0) > 0.01:
		_fail("enemy ink did not stop at the source damage cap")
		return
	scene.call("_update_player_vitals", 1.0)
	if absf(float(scene.get("player_health")) - 60.0) > 0.01:
		_fail("standing on enemy ink caused extra damage or regeneration")
		return
	walker.set("ink_owner", -1)
	scene.call("_update_player_vitals", 0.5)
	if absf(float(scene.get("player_health")) - 60.0) > 0.01 or float(scene.get("player_ink_damage")) >= 40.0:
		_fail("leaving enemy ink did not decay its damage counter")
		return
	scene.call("_update_player_vitals", 0.5)
	if absf(float(scene.get("player_health")) - 71.0) > 0.01:
		_fail("normal regeneration did not wait for the source delay")
		return
	walker.set("ink_owner", 0)
	walker.call("update_form", true)
	scene.call("_update_player_vitals", 0.2)
	if absf(float(scene.get("player_health")) - 83.0) > 0.01:
		_fail("own ink swim regeneration is not using the source rate")
		return
	walker.set("ink_owner", 1)
	scene.set("player_health", 5.0)
	scene.set("player_ink_damage", 0.0)
	scene.call("_update_player_vitals", 1.0)
	if absf(float(scene.get("player_health")) - 1.0) > 0.01 or float(scene.get("player_respawn")) > 0.0:
		_fail("enemy ink should stop at one HP without causing a splat")
		return
	scene.call("damage_player", 1.0)
	if float(scene.get("player_respawn")) <= 0.0:
		_fail("direct damage did not splat the one-HP player")
		return
	scene.call("_update_player_respawn", 5.6)
	if float(scene.get("player_invuln")) <= 0.0 or float(scene.get("player_health")) != 100.0:
		_fail("respawn protection was not initialized")
		return
	scene.call("damage_player", 50.0)
	if float(scene.get("player_health")) != 100.0:
		_fail("respawn protection did not block damage")
		return
	print("PASS: enemy ink cap/floor, delayed health regeneration, swim healing and respawn-only protection")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
