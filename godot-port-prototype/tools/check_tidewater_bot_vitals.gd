extends SceneTree


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	scene.call("_start_round")
	scene.set_physics_process(false)
	var bot: Node3D = scene.get_node("Bot")
	var config: Dictionary = scene.get_node("Combat").get("weapon_data")["player"]
	if float(scene.get("bot_invuln")) != 0.0 or float(scene.get("bot_health")) != float(config["hp"]):
		_fail("initial bot lineup state")
		return
	# Stop bot movement so each step samples the same actual map surface.
	scene.call("paint_at_world", bot.global_position + Vector3.UP * 0.12, 0, 1.5, 0.5)
	if int(bot.call("floor_ink_owner")) != 0:
		_fail("bot did not sample enemy ink from the shared surface grid")
		return
	for i in range(5):
		scene.call("_update_bot_vitals", 0.5)
	if not _near(float(scene.get("bot_health")), 60.0) \
			or not _near(float(scene.get("bot_ink_damage")), float(config["enemyInkDamageCap"])):
		_fail("enemy ink damage or cap")
		return
	scene.call("_update_bot_vitals", 1.0)
	if not _near(float(scene.get("bot_health")), 60.0):
		_fail("enemy ink should stop at cap without regenerating")
		return
	scene.call("paint_at_world", bot.global_position + Vector3.UP * 0.12, 1, 1.5, 0.5)
	if int(bot.call("floor_ink_owner")) != 1:
		_fail("bot did not sample friendly ink")
		return
	scene.call("_update_bot_vitals", 0.5)
	scene.call("_update_bot_vitals", 0.5)
	if not _near(float(scene.get("bot_health")), 71.0) \
			or not _near(float(scene.get("bot_ink_damage")), 10.0):
		_fail("delayed normal regeneration or ink damage decay")
		return
	scene.call("damage_bot", 10.0)
	scene.call("_update_bot_vitals", 1.0)
	if not _near(float(scene.get("bot_health")), 61.0):
		_fail("direct hit should restart regeneration delay")
		return
	scene.call("_update_bot_vitals", 0.31)
	if float(scene.get("bot_health")) <= 61.0:
		_fail("direct hit regeneration did not resume")
		return
	scene.call("damage_bot", float(scene.get("bot_health")))
	if not _near(float(scene.get("bot_respawn")), float(config["respawnTime"])) or bot.visible:
		_fail("bot death should use player respawn duration")
		return
	scene.call("_update_bot", float(config["respawnTime"]) + 0.1)
	if not bot.visible or not _near(float(scene.get("bot_health")), float(config["hp"])) \
			or not _near(float(scene.get("bot_invuln")), float(config["spawnInvuln"])) \
			or not _near(float(scene.get("bot_ink_damage")), 0.0):
		_fail("bot respawn state")
		return
	scene.call("damage_bot", 50.0)
	if not _near(float(scene.get("bot_health")), float(config["hp"])):
		_fail("respawn protection should block direct hits")
		return
	scene.call("paint_at_world", bot.global_position + Vector3.UP * 0.12, 0, 1.5, 0.5)
	scene.call("_update_bot_vitals", 0.5)
	if not _near(float(scene.get("bot_health")), float(config["hp"])):
		_fail("respawn protection should block enemy ink")
		return
	scene.call("_update_bot_vitals", float(config["spawnInvuln"]) - 0.7)
	if not _near(float(scene.get("bot_health")), float(config["hp"])):
		_fail("enemy ink should stay blocked until protection expires")
		return
	scene.call("_update_bot_vitals", 0.25)
	if not _near(float(scene.get("bot_health")), float(config["hp"]) - float(config["enemyInkDps"]) * 0.25):
		_fail("enemy ink should resume after protection expires")
		return
	print("PASS: bot enemy ink damage/cap, delayed regeneration, death, respawn and protection")
	quit()


func _near(actual: float, expected: float) -> bool:
	return absf(actual - expected) < 0.02


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
