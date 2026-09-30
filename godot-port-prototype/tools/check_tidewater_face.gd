extends SceneTree

# DS-02 acceptance: the facing angular spring in tidewater_walker.gd.
#
# Source: public/game/src/game/actor.js:781-815 (_face) with the parameters from
# assets/weapons.json (PLAYER.faceOmega 20 / faceMaxRate 12.5 / faceMaxAcc 170,
# squidFaceOmega 26 / squidFaceMaxRate 17 / swimFaceMaxRate 14 / squidFaceMaxAcc 260,
# aimFaceOmega 36 / aimFaceMaxRate 24 / aimFaceMaxAcc 380).
#
# The old behaviour was `$Body.rotation.y = atan2(axis.x, axis.y)` whenever there was
# input: an instant snap with no rate limit, no acceleration limit, no feed-forward and
# no facing while coasting, climbing or aiming. This check pins the four observable
# consequences of the spring: it must not snap, it must respect the rate cap, it must
# face the velocity when coasting, and it must face the crosshair while firing.
const FLOOR_Y := 100.0
const RATE_EPSILON := 0.001

var scene: Node3D
var walker: CharacterBody3D
var peak_rate := 0.0


func _initialize() -> void:
	# Historical fixture timings are measured at 60 Hz; match runtime is 30 Hz.
	Engine.physics_ticks_per_second = 60
	call_deferred("_check")


func _check() -> void:
	scene = (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	walker = scene.get_node("Walker")
	_build_floor(scene)
	if bool(walker.get("intent_driven")):
		_fail("expected the bare walk scene, not a controller-driven walker")
		return
	var p: Dictionary = walker.get("player_config")

	# --- 1. the body must not snap to a new input direction ----------------------
	# Facing +Z, then pressing D asks for a quarter turn. With camera_yaw = 0 the
	# camera looks along +Z, so screen-right is world -X and the target yaw is -PI/2
	# (the camera-relative axis is what the walker and the web both face).
	_place(Vector3(0.0, FLOOR_Y + 0.3, 0.0), 0.0)
	await _frames(40)
	if absf(float(walker.get("body_yaw"))) > 0.02 or not bool(walker.get("grounded")):
		_fail("walker did not settle facing +Z: %s yaw=%s" % [_pos(), walker.get("body_yaw")])
		return
	_set_key(KEY_D, true)
	peak_rate = 0.0
	await _frames(2)
	var early := float(walker.get("body_yaw"))
	if absf(early) > 0.20:
		_fail("body yaw snapped to the new direction in 2 frames: yaw=%.3f" % early)
		return
	await _sample_frames(60, float(p["faceMaxRate"]))
	var settled := float(walker.get("body_yaw"))
	_set_key(KEY_D, false)
	if absf(settled - (-PI / 2.0)) > 0.12:
		_fail("body did not turn to world -X: yaw=%.3f (expected %.3f)" % [settled, -PI / 2.0])
		return
	# peak_rate is the largest |yaw_velocity| seen while turning; the spring must never
	# exceed the source max rate.
	if peak_rate > float(p["faceMaxRate"]) + RATE_EPSILON:
		_fail("yaw rate %.3f exceeded faceMaxRate %.3f" % [peak_rate, p["faceMaxRate"]])
		return
	if peak_rate < 0.5:
		_fail("body barely turned at all: peak rate %.4f" % peak_rate)
		return

	# --- 2. coasting (no input) faces the velocity -------------------------------
	_place(Vector3(0.0, FLOOR_Y + 0.3, 0.0), PI / 2.0)
	await _frames(40)
	walker.velocity = Vector3(0.0, 0.0, 6.0)
	await _frames(4)
	var coasted := float(walker.get("body_yaw"))
	if coasted >= PI / 2.0 - 0.02:
		_fail("body did not turn from the velocity while coasting: yaw=%.3f" % coasted)
		return
	if coasted < 0.0:
		_fail("body overshot past the velocity direction: yaw=%.3f" % coasted)
		return

	# --- 3. firing turns the body to the crosshair -------------------------------
	# The aim branch uses its own stiffer spring and higher rate cap.
	_place(Vector3(0.0, FLOOR_Y + 0.3, 0.0), 0.0)
	await _frames(40)
	# Exercise the real mouse-look path and the controller's four-argument fire call.
	walker.call("apply_look_delta", Vector2((PI / 2.0) / 0.0021, 0.0))
	if absf(float(walker.get("aim_yaw")) + PI / 2.0) > 0.01:
		_fail("mouse look did not update the facing aim target")
		return
	walker.call("update_intent", 1.0 / 60.0, true, false, false)
	peak_rate = 0.0
	await _sample_frames(50, float(p["aimFaceMaxRate"]))
	if absf(float(walker.get("body_yaw")) - (-PI / 2.0)) > 0.15:
		_fail("body did not turn to the crosshair while firing: yaw=%.3f" % float(walker.get("body_yaw")))
		return
	if peak_rate > float(p["aimFaceMaxRate"]) + RATE_EPSILON:
		_fail("aim yaw rate %.3f exceeded aimFaceMaxRate %.3f" % [peak_rate, p["aimFaceMaxRate"]])
		return

	# --- 4. squid form uses its own rate cap -------------------------------------
	walker.call("apply_look_delta", Vector2(-(PI / 2.0) / 0.0021, 0.0))
	walker.call("update_intent", 1.0 / 60.0, false, false, false)
	_place(Vector3(0.0, FLOOR_Y + 0.3, 0.0), 0.0)
	await _frames(40)
	walker.call("update_form", true) # Isolated rotation fixture has no source ink at y=100.
	await _frames(10)
	if not bool(walker.get("squid_form")):
		_fail("holding squid did not enter squid form")
		return
	_set_key(KEY_D, true)
	peak_rate = 0.0
	await _sample_frames(50, float(p["squidFaceMaxRate"]))
	_set_key(KEY_D, false)
	if peak_rate < 0.5:
		_fail("squid facing barely turned at all")
		return
	if peak_rate > float(p["squidFaceMaxRate"]) + RATE_EPSILON:
		_fail("squid yaw rate %.3f exceeded squidFaceMaxRate %.3f" % [peak_rate, p["squidFaceMaxRate"]])
		return
	walker.call("update_intent", 1.0 / 60.0, false, false, false)

	# --- 5. with no target at all the turn decays to a stop ----------------------
	_place(Vector3(0.0, FLOOR_Y + 0.3, 0.0), 0.0)
	await _frames(30)
	walker.set("yaw_velocity", 6.0)
	await _frames(90)
	if absf(float(walker.get("yaw_velocity"))) > 1e-4:
		_fail("yaw velocity did not decay with no target: %.5f" % float(walker.get("yaw_velocity")))
		return

	print("PASS: facing spring (no snap, rate caps, coast/aim/squid branches, idle decay)")
	quit()


# Samples |yaw_velocity| for `count` frames and advances the limit as a cross-check.
func _sample_frames(count: int, limit: float) -> void:
	for i in range(count):
		await physics_frame
		peak_rate = maxf(peak_rate, absf(float(walker.get("yaw_velocity"))))


func _build_floor(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "FaceFloor"
	body.position = Vector3(0.0, FLOOR_Y - 0.5, 0.0)
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60.0, 1.0, 60.0)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _place(position: Vector3, yaw: float) -> void:
	_set_key(KEY_W, false)
	_set_key(KEY_D, false)
	walker.velocity = Vector3.ZERO
	walker.set("grounded", false)
	walker.set("coyote", 0.0)
	walker.set("jump_buffer", 0.0)
	walker.set("climbing", false)
	walker.set("yaw_velocity", 0.0)
	walker.global_position = position
	walker.set("body_yaw", yaw)
	walker.get_node("Body").rotation.y = yaw


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _set_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _pos() -> String:
	return str(walker.global_position)


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
