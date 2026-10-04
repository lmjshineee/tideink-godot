extends SceneTree


func _initialize() -> void:
	preload("res://src/core/match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	# This fixture checks pursuit. A charger should now hold range at eight metres.
	scene.set("selected_bot_weapon","shooter")
	scene.call("_start_round")
	var bot: Node3D = scene.get_node("Bot")
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	bot.global_position = Vector3(8.0, 0.05, 8.0)
	walker.global_position = Vector3(8.0, 0.05, 0.0)
	bot.set("waypoint_index", 4)
	if not bool(bot.call("_can_see_player")):
		_fail("test lane has no line of sight")
		return
	var before := bot.global_position.distance_to(walker.global_position)
	bot.call("tick", 0.1)
	if not bool(bot.get("chasing")) or bot.global_position.distance_to(walker.global_position) >= before:
		_fail("visible nearby player did not draw the bot closer")
		return
	var clearance := SphereShape3D.new()
	clearance.radius = 0.34
	var body_query := PhysicsShapeQueryParameters3D.new()
	body_query.shape = clearance
	body_query.collision_mask = 1
	body_query.transform = Transform3D(Basis(), bot.global_position + Vector3.UP * 0.75)
	if not scene.get_world_3d().direct_space_state.intersect_shape(body_query, 1).is_empty():
		_fail("chase step intersects the map")
		return
	if bool(bot.call("_safe_chase_step", Vector3(100.0, bot.global_position.y, 8.0))):
		_fail("bot accepted a chase step over missing ground")
		return
	scene.set("player_respawn", 1.0)
	bot.call("tick", 0.1)
	if bool(bot.get("chasing")) or bot.target_actor != null or bot.team_mover == null:
		_fail("splatted target was not released back to physical navigation patrol")
		return
	print("PASS: visible-player pursuit, safe body position and physical navigation patrol fallback")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
