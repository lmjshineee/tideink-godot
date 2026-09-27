extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var walker: CharacterBody3D = scene.get_node("Walker")
	for i in range(12):
		await physics_frame
	if not walker.is_on_floor():
		_fail("walker was not standing on the spawn deck")
		return
	walker.set("active", false)
	walker.collision_mask |= 4
	var config: Dictionary = walker.get("player_config")
	var collision: CollisionShape3D = walker.get_node("CollisionShape3D")
	var kid_shape: Shape3D = collision.shape
	if not bool(walker.call("update_form", true)) or not collision.shape is ConvexPolygonShape3D:
		_fail("squid request did not change collision shape")
		return
	if absf(collision.position.y * 2.0 - float(config["squidHeight"])) > 0.001:
		_fail("squid collision does not use source height")
		return
	if bool(walker.call("update_form", false)) or collision.shape != kid_shape:
		_fail("walker could not stand in open space")
		return
	walker.call("update_form", true)
	var floor_y := walker.global_position.y
	var roof := StaticBody3D.new()
	roof.collision_layer = 4
	roof.collision_mask = 0
	roof.position = Vector3(walker.global_position.x, floor_y + 0.85, walker.global_position.z)
	var roof_collision := CollisionShape3D.new()
	var roof_shape := BoxShape3D.new()
	roof_shape.size = Vector3(2.0, 0.2, 2.0)
	roof_collision.shape = roof_shape
	roof.add_child(roof_collision)
	root.add_child(roof)
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = 4
	query.exclude = [walker.get_rid()]
	if not walker.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		_fail("squid collision intersects the low ceiling")
		return
	query.shape = kid_shape
	query.transform = Transform3D(walker.global_transform.basis, walker.global_position + Vector3.UP * float(config["height"]) * 0.5)
	if walker.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		_fail("standing shape unexpectedly fits under the low ceiling")
		return
	if not bool(walker.call("update_form", false)) or collision.shape == kid_shape:
		_fail("walker stood up inside a low ceiling")
		return
	roof.queue_free()
	await physics_frame
	if bool(walker.call("update_form", false)) or collision.shape != kid_shape:
		_fail("walker stayed squid after the ceiling cleared")
		return
	if absf(collision.position.y * 2.0 - float(config["height"])) > 0.001:
		_fail("kid collision did not restore source height")
		return
	print("PASS: source-sized squid collision, safe low-ceiling exit and standing restoration")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
