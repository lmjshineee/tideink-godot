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
	_respawn_bot(scene)
	if float(scene.get("bot_health")) != 100.0 or not bot.visible:
		_fail("bot respawn")
		return
	walker.global_position = Vector3(0.0, 2.25, 31.2)
	var charger: Dictionary = weapon_data["weapons"]["charger"]
	combat.call("_fire_charger", charger, 1.0, Vector3(0.0, 0.0, 1.0))
	if float(scene.get("bot_respawn")) <= 0.0:
		_fail("full charger hit should splat bot")
		return
	_respawn_bot(scene)
	var blaster: Dictionary = weapon_data["weapons"]["blaster"]
	combat.call("_spawn_projectile", "blaster", Vector3(0.0, 3.0, 37.2), Vector3(0.0, 0.0, 23.0), blaster)
	combat.call("_update_projectiles", 0.1)
	if float(scene.get("bot_respawn")) <= 0.0:
		_fail("blaster direct hit should splat bot")
		return
	_respawn_bot(scene)
	# Roller crushing damage (weapons.js:200-207): the drum must be moving, the victim
	# must be in front of the body's facing, and each victim can be hit at most once
	# every 0.5 s. The old assertion called _paint_roll_at once and expected a kill,
	# which hid the fact that damage was re-applied every 0.28 m of travel.
	var roller: Dictionary = weapon_data["weapons"]["roller"]
	walker.global_position = Vector3(0.0, 2.25, 38.2)
	walker.get_node("Body").rotation.y = 0.0
	walker.velocity = Vector3(0.0, 0.0, 4.4)
	combat.call("_roll_damage", roller)
	if float(scene.get("bot_respawn")) <= 0.0:
		_fail("roller contact should crush the bot")
		return
	_respawn_bot(scene)
	# A standing drum deals nothing.
	walker.velocity = Vector3.ZERO
	combat.call("_roll_damage", roller)
	if float(scene.get("bot_respawn")) > 0.0 or float(scene.get("bot_health")) != 100.0:
		_fail("standing roller should not damage")
		return
	# Second pass inside the cooldown window: still nothing.
	walker.velocity = Vector3(0.0, 0.0, 4.4)
	combat.call("_roll_damage", roller)
	if float(scene.get("bot_respawn")) > 0.0:
		_fail("roller cooldown did not limit the second hit")
		return
	# Past the cooldown the drum bites again.
	combat.set("elapsed", float(combat.get("elapsed")) + 0.6)
	combat.call("_roll_damage", roller)
	if float(scene.get("bot_respawn")) <= 0.0:
		_fail("roller cooldown never expired")
		return
	_respawn_bot(scene)
	walker.global_position = Vector3(0.0, 2.25, 36.0)
	var bot_ink_before := float(bot.get("ink_amount"))
	scene.call("_update_bot", 0.1)
	var bot_shots: Array = combat.get("projectiles")
	if bot_shots.is_empty() or int((bot_shots.back() as Dictionary)["team"]) != 1 \
			or absf(float(bot.get("ink_amount")) - bot_ink_before + float(shooter["inkPerShot"])) > 0.01:
		_fail("bot did not fire a source-configured shooter projectile")
		return
	combat.call("advance_effects", 0.1)
	if absf(float(scene.get("player_health")) - (100.0 - float(shooter["damage"]))) > 0.01:
		_fail("bot projectile did not reach the player with source damage")
		return
	var blue_before := float(scene.get("ink").call("coverage", 1))
	combat.call("_spawn_projectile", "shooter", Vector3(4.0, 4.0, -39.2),
		Vector3(0.0, -34.0, 0.0), shooter, 1)
	combat.call("advance_effects", 0.1)
	if float(scene.get("ink").call("coverage", 1)) <= blue_before:
		_fail("bot shooter impact did not paint blue turf")
		return
	var head_start: Vector3 = walker.global_position + Vector3(-1.0, 1.2, 0.0)
	var head_end: Vector3 = walker.global_position + Vector3(1.0, 1.2, 0.0)
	if (combat.call("_segment_player_hit", head_start, head_end, 0.15) as Dictionary).is_empty():
		_fail("standing player capsule missed a head-height shot")
		return
	walker.set("squid_form", true)
	if not (combat.call("_segment_player_hit", head_start, head_end, 0.15) as Dictionary).is_empty():
		_fail("squid was hit by a shot above its low body")
		return
	walker.set("squid_form", false)
	combat.set("charging", true)
	scene.call("damage_player", float(scene.get("player_health")))
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


func _respawn_bot(scene: Node3D) -> void:
	var player_config: Dictionary = scene.get_node("Combat").get("weapon_data")["player"]
	scene.call("_update_bot", float(player_config["respawnTime"]) + 0.1)
	# Isolate independent weapon hits from the respawn protection window.
	# The dedicated vitals test covers protection itself.
	scene.set("bot_invuln", 0.0)
