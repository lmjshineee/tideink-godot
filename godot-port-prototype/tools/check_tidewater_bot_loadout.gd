extends SceneTree

const TeamPalette := preload("res://team_palette.gd")


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	var bot: Node3D = scene.get_node("Bot")
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	walker.set_physics_process(false)
	var combat: Node3D = scene.get_node("Combat")
	var weapons: Dictionary = combat.get("weapons")
	# Fixed combat fixture; random kits and respawn reroll are covered separately.
	preload("res://match_setup.gd").reroll_bots = false
	scene.set("selected_bot_weapon","blaster")
	bot.call("select_weapon","blaster")
	for actor in scene.all_actors(): scene.perks.choices[actor.get_instance_id()]="balanced"
	scene.call("_start_round")
	walker.global_position = bot.global_position + Vector3(0.0, 0.05, -3.2)
	bot.call("tick", 0.1)
	var shots: Array = combat.get("projectiles")
	if shots.size() != 1 or String((shots[0] as Dictionary)["kind"]) != "blaster" \
			or int((shots[0] as Dictionary)["team"]) != 1:
		_fail("blue blaster did not fire a team 1 projectile")
		return
	combat.call("advance_effects", 0.15)
	if float(scene.get("player_respawn")) > 0.0 or float(scene.get("player_health"))>=120.0:
		_fail("blue blaster must damage while leaving full-health counterplay")
		return
	var bursts: Array = combat.get("bursts")
	if bursts.is_empty() or not _near(float(((bursts[0] as Dictionary)["visual"] as MeshInstance3D).mesh.radius),
			float(weapons["blaster"]["burstRadius"])):
		_fail("blaster burst did not use the source visual radius")
		return
	scene.call("damage_bot", float(scene.get("bot_health")))
	scene.call("_update_bot", float(combat.get("weapon_data")["player"]["respawnTime"]) + 0.1)
	if bot.get("weapon_id") != "blaster" or not bot.get_node("Body/Kid/Weapon_blaster").visible:
		_fail("bot loadout was lost on respawn")
		return
	var splash_scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(splash_scene)
	await physics_frame
	splash_scene.set_physics_process(false)
	for actor in splash_scene.all_actors():splash_scene.perks.choices[actor.get_instance_id()]="balanced"
	splash_scene.call("_start_round")
	var splash_combat: Node3D = splash_scene.get_node("Combat")
	var splash_walker: CharacterBody3D = splash_scene.get_node("World/Walker")
	splash_walker.set_physics_process(false)
	splash_walker.global_position = Vector3(0.0, 2.25, 36.0)
	var blue_before := float(splash_scene.get("ink").call("coverage", 1))
	splash_combat.call("_burst_blaster", splash_walker.global_position + Vector3(1.0, 0.8, 0.0),
		weapons["blaster"], false, 1)
	if float(splash_scene.get("player_health")) >= 120.0 \
			or float(splash_scene.get("ink").call("coverage", 1)) <= blue_before:
		_fail("blue blaster splash did not damage and paint for team 1")
		return
	var splash_bot: Node3D = splash_scene.get_node("Bot")
	splash_combat.call("_burst_blaster", splash_bot.global_position + Vector3(1.0, 0.8, 0.0),
		weapons["blaster"], false, 0)
	if float(splash_scene.get("bot_health")) >= 120.0:
		_fail("orange blaster splash regressed after team sharing")
		return
	var charger_scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(charger_scene)
	await physics_frame
	charger_scene.set_physics_process(false)
	for actor in charger_scene.all_actors(): charger_scene.perks.choices[actor.get_instance_id()]="balanced"
	charger_scene.call("_start_round")
	var charger_bot: Node3D = charger_scene.get_node("Bot")
	var charger_walker: CharacterBody3D = charger_scene.get_node("World/Walker")
	charger_walker.set_physics_process(false)
	charger_bot.call("select_weapon", "charger")
	charger_walker.global_position = charger_bot.global_position + Vector3(0.0, 0.05, -3.0)
	charger_bot.call("tick", 0.5)
	if float(charger_scene.get("player_health")) < 120.0:
		_fail("charger fired before completing its charge")
		return
	charger_bot.call("tick", 0.51)
	var charger_combat: Node3D = charger_scene.get_node("Combat")
	if float(charger_scene.get("player_respawn")) > 0.0 or float(charger_scene.get("player_health")) >= 120.0 \
			or (charger_combat.get("beams") as Array).size() != 1 \
			or float(charger_bot.get("ink_amount")) > 100.0 - float(weapons["charger"]["inkFull"]):
		_fail("blue charger charge, beam, ink cost or hit")
		return
	var beam: MeshInstance3D = (charger_combat.get("beams") as Array)[0]["visual"]
	if (beam.material_override as StandardMaterial3D).albedo_color != TeamPalette.color(1).lightened(0.35):
		_fail("blue charger beam used the wrong team colour")
		return
	var roller_scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(roller_scene)
	await physics_frame
	roller_scene.set_physics_process(false)
	for actor in roller_scene.all_actors():roller_scene.perks.choices[actor.get_instance_id()]="balanced"
	roller_scene.call("_start_round")
	var roller_bot: Node3D = roller_scene.get_node("Bot")
	var roller_walker: CharacterBody3D = roller_scene.get_node("World/Walker")
	roller_walker.set_physics_process(false)
	roller_bot.call("select_weapon", "roller")
	roller_bot.global_position = Vector3(0.0, 0.05, 25.0)
	roller_walker.global_position = Vector3(0.0, 0.05, 22.0)
	roller_bot.call("tick", 0.1)
	var roller_combat: Node3D = roller_scene.get_node("Combat")
	var drops: Array = roller_combat.get("projectiles")
	if drops.size() != int(weapons["roller"]["flickDrops"]) \
			or int((drops[0] as Dictionary)["team"]) != 1 \
			or float(roller_scene.get("ink").call("coverage", 1)) <= 0.0:
		_fail("blue roller did not flick and lay a scoring stripe")
		return
	roller_walker.global_position = roller_bot.global_position + Vector3(0.0, 0.0, -1.0)
	roller_bot.call("tick", 0.1)
	if float(roller_scene.get("player_respawn")) > 0.0 or float(roller_scene.get("player_health"))>=120.0:
		_fail("blue roller contact must damage while leaving full-health counterplay")
		return
	print("PASS: setup bot loadout, blue blaster direct/splash, charger, roller and respawn persistence")
	quit()


func _near(actual: float, expected: float) -> bool:
	return absf(actual - expected) < 0.02


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
