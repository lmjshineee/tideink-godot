extends SceneTree

const STEP := 1.0 / 30.0


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var walker: CharacterBody3D = scene.get_node("Walker")
	walker.set("active", false)
	var config: Dictionary = walker.get("player_config")
	for key in ["jumpBuffer", "coyoteTime", "fallGravityMul", "apexGravityMul", "apexBand", "maxFall"]:
		if not config.has(key):
			_fail("missing source jump parameter " + key)
			return

	walker.set("jump_requested", true)
	walker.call("_advance_jump_input", STEP)
	if not bool(walker.call("_vertical_step", STEP, false, true)) or walker.velocity.y < 7.0:
		_fail("ground jump did not launch")
		return
	if bool(walker.call("_vertical_step", STEP, false, false)):
		_fail("ground jump retriggered in air")
		return

	walker.call("reset_movement_state")
	walker.set("ink_owner", 0)
	walker.set("jump_requested", true)
	walker.call("_advance_jump_input", STEP)
	# submerged = squid on own ink *and grounded* (actor.js:267-268).
	if not bool(walker.call("_vertical_step", STEP, true, true, true, false)) or walker.velocity.y < 8.5:
		_fail("own ink swim jump is not stronger")
		return
	walker.call("reset_movement_state")
	walker.set("ink_owner", 1)
	walker.set("jump_requested", true)
	walker.call("_advance_jump_input", STEP)
	if not bool(walker.call("_vertical_step", STEP, false, true, false, true)) \
		or walker.velocity.y < 5.0 or walker.velocity.y > 6.0:
		_fail("enemy ink jump penalty differs from source")
		return
	# On enemy ink but airborne inside the coyote window: the web only applies the
	# 0.72 penalty while grounded (actor.js:267-268, 281-282). A grounded frame first,
	# then a jump after walking off, must clear the plain 7.0 threshold a penalised
	# jump (about 5.4) cannot reach. The old test passed on_enemy without grounding.
	walker.call("reset_movement_state")
	walker.set("ink_owner", 1)
	walker.call("_vertical_step", STEP, false, true, false, true)
	walker.set("jump_requested", true)
	walker.call("_advance_jump_input", STEP)
	if not bool(walker.call("_vertical_step", STEP, false, false, false, false)) or walker.velocity.y < 7.0:
		_fail("airborne enemy-ink jump wrongly took the grounded penalty: " + str(walker.velocity.y))
		return

	walker.call("reset_movement_state")
	walker.set("ink_owner", -1)
	walker.call("_vertical_step", STEP, false, true)
	for i in range(2):
		walker.call("_advance_jump_input", STEP)
		walker.call("_vertical_step", STEP, false, false)
	walker.set("jump_requested", true)
	walker.call("_advance_jump_input", STEP)
	if not bool(walker.call("_vertical_step", STEP, false, false)):
		_fail("coyote jump was lost just after leaving ground")
		return
	walker.call("reset_movement_state")
	walker.call("_vertical_step", STEP, false, true)
	for i in range(5):
		walker.call("_advance_jump_input", STEP)
		walker.call("_vertical_step", STEP, false, false)
	walker.set("jump_requested", true)
	walker.call("_advance_jump_input", STEP)
	if bool(walker.call("_vertical_step", STEP, false, false)):
		_fail("coyote window did not expire")
		return

	walker.call("reset_movement_state")
	walker.set("jump_requested", true)
	walker.call("_advance_jump_input", STEP)
	if bool(walker.call("_vertical_step", STEP, false, false)):
		_fail("airborne jump should remain buffered")
		return
	for i in range(2):
		walker.call("_advance_jump_input", STEP)
		walker.call("_vertical_step", STEP, false, false)
	if not bool(walker.call("_vertical_step", STEP, false, true)):
		_fail("buffered jump did not fire on landing")
		return
	walker.call("reset_movement_state")
	walker.set("jump_requested", true)
	walker.call("_advance_jump_input", STEP)
	for i in range(5):
		walker.call("_vertical_step", STEP, false, false)
		walker.call("_advance_jump_input", STEP)
	if bool(walker.call("_vertical_step", STEP, false, true)):
		_fail("jump buffer did not expire")
		return

	walker.call("reset_movement_state")
	walker.velocity.y = 0.0
	walker.call("_vertical_step", STEP, false, false)
	var apex_drop := absf(walker.velocity.y)
	walker.velocity.y = -10.0
	walker.call("_vertical_step", STEP, false, false)
	var falling_drop := absf(walker.velocity.y + 10.0)
	if apex_drop >= falling_drop or falling_drop < 0.95:
		_fail("apex hang or faster fall gravity is missing")
		return
	walker.velocity.y = -39.9
	walker.call("_vertical_step", STEP, false, false)
	if walker.velocity.y < -40.01:
		_fail("fall speed was not capped")
		return
	walker.call("reset_movement_state")
	walker.set("active", true)
	walker.global_position = Vector3(0.0, 2.25, -39.2)
	for i in range(12):
		await physics_frame
	if not bool(walker.get("grounded")):
		_fail("integration walker did not land before jumping")
		return
	var floor_y := walker.global_position.y
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	for i in range(4):
		await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	if walker.global_position.y < floor_y + 0.1:
		_fail("space key did not launch the actual CharacterBody")
		return
	print("PASS: source jump windows/gravity and CharacterBody space-key launch")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
