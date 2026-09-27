extends SceneTree

const STEP := 1.0 / 30.0


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var walker: CharacterBody3D = scene.get_node("Walker")
	walker.set("active", false)
	if not _has_source_parameters(walker):
		_fail("exported player config lacks source handling parameters")
		return
	var forward := Vector2(0.0, 1.0)
	walker.call("_horizontal_step", STEP, forward, false, false, true)
	var first := _speed(walker)
	if first <= 0.0 or first >= 6.0:
		_fail("run acceleration snapped to full speed")
		return
	for i in range(15):
		walker.call("_horizontal_step", STEP, forward, false, false, true)
	if absf(_speed(walker) - 6.0) > 0.05:
		_fail("run never reached the source speed")
		return
	walker.call("_horizontal_step", STEP, Vector2.ZERO, false, false, true)
	if _speed(walker) <= 0.0 or _speed(walker) >= 6.0:
		_fail("release did not brake gradually")
		return
	walker.velocity = Vector3(0.0, 0.0, 6.0)
	walker.call("_horizontal_step", STEP, -forward, false, false, true)
	if walker.velocity.z <= 0.0:
		_fail("reverse changed direction instantly")
		return
	for i in range(4):
		walker.call("_horizontal_step", STEP, -forward, false, false, true)
	if walker.velocity.z >= 0.0:
		_fail("reverse never crossed zero")
		return
	walker.velocity = Vector3(0.0, 0.0, 6.0)
	walker.call("_horizontal_step", STEP, Vector2.RIGHT, false, false, true)
	if walker.velocity.x <= 0.0 or walker.velocity.z <= 0.0:
		_fail("turn did not carve through the previous heading")
		return
	walker.velocity = Vector3.ZERO
	walker.set("ink_owner", 0)
	for i in range(30):
		walker.call("_horizontal_step", STEP, forward, true, false, true)
	if _speed(walker) < 11.5 or _speed(walker) > 11.81:
		_fail("own ink swim speed differs from source")
		return
	walker.velocity = Vector3.ZERO
	walker.set("ink_owner", 1)
	for i in range(30):
		walker.call("_horizontal_step", STEP, forward, true, true, true)
	if _speed(walker) > 1.91 or _speed(walker) < 1.6:
		_fail("enemy ink squid speed is not limited")
		return
	walker.velocity = Vector3(6.0, 0.0, 0.0)
	walker.call("_horizontal_step", STEP, Vector2.ZERO, false, false, false)
	if walker.velocity.x < 5.8:
		_fail("airborne momentum disappeared too quickly")
		return
	walker.velocity = Vector3.ZERO
	walker.set("firing_speed_limit", 1.8)
	for i in range(15):
		walker.call("_horizontal_step", STEP, forward, false, false, true)
	if _speed(walker) > 1.81 or _speed(walker) < 1.6:
		_fail("firing speed cap is not applied")
		return
	print("PASS: source handling accelerates, brakes, reverses, carves, swims, bogs, preserves air momentum and limits firing speed")
	quit()


func _has_source_parameters(walker: CharacterBody3D) -> bool:
	var config: Dictionary = walker.get("player_config")
	for key in ["runAccel", "runDecel", "reverseDecel", "turnRate", "swimAccel", "enemyInkAccel", "airDecel"]:
		if not config.has(key):
			return false
	return true


func _speed(walker: CharacterBody3D) -> float:
	return Vector2(walker.velocity.x, walker.velocity.z).length()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
