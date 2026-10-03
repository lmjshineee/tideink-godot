extends SceneTree


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	scene.call("_start_round")
	var bot: Node3D = scene.get_node("Bot")
	var ink: RefCounted = scene.get("ink")
	var spawn_z := bot.global_position.z
	var clearance := SphereShape3D.new()
	clearance.radius = 0.34
	var body_query := PhysicsShapeQueryParameters3D.new()
	body_query.shape = clearance
	body_query.collision_mask = 1
	var furthest_z := spawn_z
	var distance := 0.0
	var previous: Vector3 = bot.global_position
	for step in 240:
		scene.call("_update_bot", 0.1)
		furthest_z = minf(furthest_z, bot.global_position.z)
		distance += bot.global_position.distance_to(previous)
		previous = bot.global_position
		body_query.transform = Transform3D(Basis(), bot.global_position + Vector3.UP * 0.75)
		var overlap: Array[Dictionary] = scene.get_world_3d().direct_space_state.intersect_shape(body_query, 1)
		if not overlap.is_empty():
			_fail("bot route intersects %s at step %d, position %s" % [overlap[0]["collider"].name, step, bot.global_position])
			return
	if bot.team_mover == null or distance < 12.0 or spawn_z - furthest_z < 7.0:
		_fail("bot did not leave spawn and advance along the map lane")
		return
	var support: Dictionary = bot._ground_at(bot.global_position)
	if support.is_empty() or absf(bot.global_position.y - float(support.position.y)) > 0.6:
		_fail("bot did not follow main-deck floor height")
		return
	if float(ink.call("coverage", 1)) <= 0.0:
		_fail("bot route did not claim scoring turf")
		return
	var stopped := bot.global_position
	var coverage := float(ink.call("coverage", 1))
	scene.call("_finish_round")
	scene.call("_physics_process", 0.5)
	if bot.global_position != stopped or float(ink.call("coverage", 1)) != coverage:
		_fail("bot continued moving or painting after finish")
		return
	print("PASS: opponent advances from spawn, paints real turf and freezes at finish")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
