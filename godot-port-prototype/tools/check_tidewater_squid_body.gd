extends SceneTree

# T05 / squidBodyLift. physics.js:201 builds the body capsule as
#   bot = lift + radius, top = max(bot, height - radius)
# For the squid that is lift = squidBodyLift (0.16) and height = squidHeight (0.55), so
# top == bot and the body degenerates into a sphere of PLAYER.radius whose centre sits
# lift + radius above the feet: a solid extent of 0.16 .. 0.92. This check pins the two
# observable consequences that the old ground-resting prism (0 .. 0.55) could not have.
#
# Why the vitals and the ink refill now read walker.grounded instead of is_on_floor():
# the lifted body no longer rests on the ground, so engine contact is at best a
# frame-late side effect of a brief overlap and cannot be used as "am I standing". The
# probe, which is footprint accurate, is the authority. What this check pins is that the
# probe keeps the squid standing and level; it deliberately does not assert anything
# about is_on_floor(), because that is an engine detail and not a game rule.
const PLATE_LAYER := 4


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var walker: CharacterBody3D = scene.get_node("Walker")
	for i in range(12):
		await physics_frame
	if not walker.is_on_floor():
		_fail("walker was not standing on the spawn deck in kid form")
		return
	var config: Dictionary = walker.get("player_config")
	var collision: CollisionShape3D = walker.get_node("CollisionShape3D")
	var kid_shape: Shape3D = collision.shape

	# --- 1. a plate entirely below squidBodyLift is not touched by the squid body -----
	walker.set("active", false)
	walker.collision_mask |= PLATE_LAYER
	var feet := walker.global_position
	var plate_top := float(config["squidBodyLift"]) - 0.04
	var plate := StaticBody3D.new()
	plate.name = "SubLiftPlate"
	plate.collision_layer = PLATE_LAYER
	plate.collision_mask = 0
	plate.position = Vector3(feet.x, feet.y + plate_top * 0.5, feet.z)
	var plate_collision := CollisionShape3D.new()
	var plate_shape := BoxShape3D.new()
	plate_shape.size = Vector3(4.0, plate_top, 4.0)
	plate_collision.shape = plate_shape
	plate.add_child(plate_collision)
	root.add_child(plate)
	await physics_frame

	if not bool(walker.call("update_form", true)):
		_fail("squid request did not change collision shape")
		return
	if _overlaps(walker, collision.global_transform, collision.shape):
		_fail("squid body touches a plate below squidBodyLift (%.2f m)" % plate_top)
		return
	# Control: the kid body reaches the feet, so it must touch the same plate.
	walker.call("update_form", false)
	if not _overlaps(walker, Transform3D(walker.global_transform.basis,
			feet + Vector3.UP * float(config["height"]) * 0.5), kid_shape):
		_fail("kid body unexpectedly clears a plate it stands on")
		return
	plate.queue_free()
	await physics_frame

	# --- 2. the lifted body stays grounded through the walker's own probe -------------
	# The engine's own contact flag is not usable for a lifted body, so everything that
	# asks "is the squid standing" must read the probe.
	walker.set("active", true)
	walker.set_physics_process(true)
	_set_key(KEY_SHIFT, true)
	for i in range(6):
		await physics_frame
	if not bool(walker.get("squid_form")):
		_fail("holding squid did not enter squid form")
		return
	var squid_feet := walker.global_position.y
	for i in range(30):
		await physics_frame
	if not bool(walker.get("grounded")):
		_fail("probe grounded is false while the squid stands on the deck")
		return
	if absf(walker.global_position.y - squid_feet) > 0.05:
		_fail("lifted squid body did not hold its height: %.3f -> %.3f" % [squid_feet, walker.global_position.y])
		return
	_set_key(KEY_SHIFT, false)

	print("PASS: squid body lifted by squidBodyLift, ignores sub-lift geometry, grounded by the probe alone")
	quit()


func _overlaps(walker: CharacterBody3D, transform: Transform3D, shape: Shape3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	query.collision_mask = PLATE_LAYER
	query.exclude = [walker.get_rid()]
	return not walker.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _set_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
