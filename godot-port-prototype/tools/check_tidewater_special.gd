extends SceneTree


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	scene.call("_start_round")
	var combat: Node3D = scene.get_node("Combat")
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	var bot: Node3D = scene.get_node("Bot")
	var config: Dictionary = combat.get("weapon_data")
	if not config.has("specials") or absf(float(config["specials"]["slam"]["radius"]) - 5.2) > 0.001:
		_fail("source special parameters were not exported")
		return
	combat.call("_paint_player", Vector3(0.0, 2.4, 39.2), 2.2, 0.5)
	if float(combat.get("special_points")) <= 0.0:
		_fail("player turf did not charge the special")
		return
	combat.set("special_points", 190.0)
	var activate := InputEventKey.new()
	activate.keycode = KEY_F
	activate.pressed = true
	if not bool(combat.call("special_ready")):
		_fail("shooter slam did not activate at its source cost")
		return
	scene.call("_input", activate)
	if combat.get("special_active") != "slam" or walker.get("slam_phase") != "rise" or float(combat.get("special_points")) != 0.0:
		_fail("slam did not enter rise or consume the meter")
		return
	scene.call("damage_player", 40.0)
	if absf(float(scene.get("player_health")) - 90.0) > 0.01:
		_fail("slam armor should reduce direct damage to one quarter")
		return
	walker.global_position = bot.global_position + Vector3(1.0, 0.0, 0.0)
	walker.set("slam_impact_pending", true)
	combat.call("_update_special", 0.01)
	if float(scene.get("bot_respawn")) <= 0.0 or combat.get("special_active") != "" or float(combat.get("special_points")) != 0.0:
		_fail("slam impact did not damage opponent or recharged itself")
		return
	scene.call("_update_bot", float(config["player"]["respawnTime"]) + 0.1)
	scene.set("bot_invuln", 0.0)
	bot.global_position = Vector3(0.0, 2.2, 0.0)
	combat.call("select_weapon", "charger")
	combat.set("special_points", 180.0)
	activate.keycode = KEY_Q
	scene.call("_input", activate)
	if combat.get("special_active") != "storm":
		_fail("charger storm did not activate")
		return
	if (combat.get("storm_bombs") as Array).size() != 1:
		_fail("storm throw did not create a projectile")
		return
	var bomb: Dictionary = (combat.get("storm_bombs") as Array)[0]
	bomb["position"] = Vector3(0.0, 3.0, 0.0)
	bomb["velocity"] = Vector3(0.0, -10.0, 0.0)
	combat.call("_update_storm_bombs", 0.12)
	if (combat.get("clouds") as Array).size() != 1:
		_fail("storm projectile did not become a cloud after map impact")
		return
	combat.call("_update_special", 0.36)
	var old_health := float(scene.get("bot_health"))
	var old_coverage := float(scene.get("ink").call("coverage", 0))
	combat.call("_update_clouds", 0.1)
	if float(scene.get("bot_health")) >= old_health or (combat.get("clouds") as Array).size() != 1 \
		or float(scene.get("ink").call("coverage", 0)) <= old_coverage:
		_fail("storm cloud did not paint new turf and damage opponent")
		return
	var cloud: Dictionary = (combat.get("clouds") as Array)[0]
	cloud["time"] = float(config["specials"]["storm"]["duration"]) - 0.05
	combat.call("_update_clouds", 0.1)
	if (combat.get("clouds") as Array).size() != 0:
		_fail("storm cloud did not expire")
		return
	combat.set("special_points", 100.0)
	combat.call("on_death")
	if absf(float(combat.get("special_points")) - 50.0) > 0.001:
		_fail("death should halve retained special points")
		return
	var timeline := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(timeline)
	await physics_frame
	timeline.call("_start_round")
	var real_combat: Node3D = timeline.get_node("Combat")
	real_combat.set("special_points", 190.0)
	if not bool(real_combat.call("try_special")):
		_fail("live slam activation")
		return
	for i in range(65):
		await physics_frame
	if real_combat.get("special_active") != "" or timeline.get_node("World/Walker").get("slam_phase") != "":
		_fail("slam did not land during physics frames")
		return
	print("PASS: source special data, turf charge, slam flight/armor/impact, storm projectile/cloud/turf/damage/expiry and death meter")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
