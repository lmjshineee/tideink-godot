extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player: Node3D = scene.get_node("World/Walker/Body")
	var bot: Node3D = scene.get_node("Bot/Body")
	if not player.get_node("Kid").visible or player.get_node("Squid").visible \
		or not bot.get_node("Kid").visible or int(bot.get("team")) != 1:
		_fail("team character visuals did not initialize in kid form")
		return
	var hair: MeshInstance3D = bot.get_node("Kid/HairCap")
	if (hair.material_override as StandardMaterial3D).albedo_color != Color("2f5bff"):
		_fail("blue opponent has the wrong team hair colour")
		return
	var combat: Node3D = scene.get_node("Combat")
	combat.call("select_weapon", "roller")
	if not player.get_node("Kid/Weapon_roller").visible or player.get_node("Kid/Weapon_shooter").visible:
		_fail("selected roller is not shown on the player")
		return
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	walker.call("update_form", true)
	if player.get_node("Kid").visible or not player.get_node("Squid").visible:
		_fail("squid visual did not follow the collision form")
		return
	walker.call("update_form", false)
	if not player.get_node("Kid").visible or player.get_node("Squid").visible:
		_fail("kid visual did not return after standing")
		return
	scene.call("_start_round")
	scene.call("_update_bot", 0.1)
	if absf(absf(bot.rotation.y) - PI) > 0.01:
		_fail("opponent visual does not face its travel direction")
		return
	var opponent: Node3D = scene.get_node("Bot")
	walker.global_position = opponent.global_position + Vector3(2.0, 0.0, 0.0)
	scene.call("_update_bot", 0.1)
	var tracer: MeshInstance3D = scene.get_node("BotAttackTracer")
	var shots: Array = combat.get("projectiles")
	if shots.is_empty() or int((shots.back() as Dictionary)["team"]) != 1 or not tracer.visible:
		_fail("opponent projectile has no visible firing cue")
		return
	scene.call("damage_bot", 25.0)
	scene.call("_update_bot", 0.01)
	var fill: MeshInstance3D = opponent.get_node("HealthBar/Fill")
	if not is_equal_approx(fill.scale.x, 0.75):
		_fail("opponent health bar did not track damage")
		return
	scene.set("player_respawn", 1.0)
	scene.call("_update_bot", 0.2)
	if tracer.visible:
		_fail("opponent attack trace did not expire")
		return
	print("PASS: team silhouettes, weapon/form/facing and opponent combat feedback")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
