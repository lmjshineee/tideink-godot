extends SceneTree

# DS-03 acceptance: hard-landing recovery in tidewater_walker.gd.
#
# Source: public/game/src/game/actor.js:241 (decay), :388 (kid ground target speed)
# and :506-511 (_onLand), with the parameters from assets/weapons.json
# (PLAYER.hardLandSpeed 11.5, hardLandSlow 0.72, hardLandTime 0.16).
#
# Acceptance points:
#   1. a normal landing does not set the recovery weight
#   2. a fast landing sets it with the source formula
#   3. it drains to zero within hardLandTime
#   4. the kid ground speed is scaled while it is set, and the squid branches are not
const FLOOR_Y := 100.0

var scene: Node3D
var walker: CharacterBody3D
var p: Dictionary
# Sampled while a landing resolves. The weight is set once on the landing frame and
# only decays afterwards, so the peak over the window is the value the source formula
# produced, independent of how many frames the coroutine needed to observe it.
var peak_weight := 0.0
var peak_land_speed := 0.0


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	scene = (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	walker = scene.get_node("Walker")
	_build_floor(scene)
	p = walker.get("player_config")
	if bool(walker.get("intent_driven")):
		_fail("expected the bare walk scene, not a controller-driven walker")
		return
	var threshold := float(p["hardLandSpeed"])

	# --- 1. a normal landing must not set the weight -----------------------------
	await _land_at(-6.0)
	if peak_land_speed < 6.0:
		_fail("landing speed was not captured: land_speed=%.3f" % peak_land_speed)
		return
	if peak_land_speed >= threshold:
		_fail("test setup: %.2f m/s should be under the %.2f threshold" % [peak_land_speed, threshold])
		return
	if peak_weight != 0.0:
		_fail("a %.2f m/s landing set the weight: %.4f" % [peak_land_speed, peak_weight])
		return

	# --- 2. a fast landing sets it with the source formula -----------------------
	await _land_at(-13.0)
	if peak_land_speed <= threshold:
		_fail("test setup: %.2f m/s should exceed the threshold" % peak_land_speed)
		return
	var expected := clampf((peak_land_speed - threshold) / 6.0 + 0.5, 0.0, 1.0)
	# At most one frame of decay can pass between the landing and the sample.
	var slack := 1.0 / (float(p["hardLandTime"]) * 60.0) + 0.002
	if peak_weight > expected + 0.001 or peak_weight < expected - slack:
		_fail("weight %.4f does not match the source formula %.4f for %.3f m/s" % [
			peak_weight, expected, peak_land_speed])
		return

	# The clamp at 1.0 must saturate rather than keep growing.
	await _land_at(-18.0)
	if peak_weight != 1.0:
		_fail("a very fast landing should saturate the weight at 1.0, got %.4f" % peak_weight)
		return

	# --- 3. it drains to zero within hardLandTime --------------------------------
	var decay := float(p["hardLandTime"])
	var frames_to_zero := 0
	var still_set := false
	for i in range(40):
		await physics_frame
		frames_to_zero += 1
		if float(walker.get("hard_land")) > 0.0:
			still_set = true
		else:
			break
	if not still_set or frames_to_zero < 4:
		_fail("weight decayed instantly instead of over %.2f s (%d frames)" % [decay, frames_to_zero])
		return
	if frames_to_zero > int(ceil(decay * 60.0)) + 4:
		_fail("weight took %d frames to reach zero, expected about %d" % [
			frames_to_zero, int(ceil(decay * 60.0))])
		return

	# --- 4. kid ground speed is scaled, squid branches are not -------------------
	_place(Vector3(0.0, FLOOR_Y + 0.3, 0.0))
	await _frames(30)
	var clean := await _ground_speed(false)
	if clean < float(p["runSpeed"]) - 0.1:
		_fail("baseline kid ground speed was %.3f, expected %.3f" % [clean, p["runSpeed"]])
		return
	var slowed := await _ground_speed(true)
	if slowed >= clean:
		_fail("hard landing did not slow the kid: %.3f vs %.3f" % [slowed, clean])
		return
	# The source scales the target by 1 - (1 - hardLandSlow) * weight, so at weight 1
	# the achieved speed must sit near 0.72 of the clean speed.
	var ratio := slowed / clean
	if ratio < 0.70 or ratio > 0.82:
		_fail("kid slowdown ratio %.3f is outside the source range: %.3f vs %.3f" % [ratio, slowed, clean])
		return
	_set_key(KEY_D, false)
	# Squid on dry ground uses squidDrySpeed and must ignore the weight entirely.
	_place(Vector3(0.0, FLOOR_Y + 0.3, 0.0))
	_set_key(KEY_SHIFT, true)
	await _frames(30)
	if not bool(walker.get("squid_form")):
		_fail("holding squid did not enter squid form")
		return
	walker.set("hard_land", 0.0)
	var squid_clean := await _ground_speed(false)
	walker.set("hard_land", 0.0)
	var squid_weighted := await _ground_speed(true)
	_set_key(KEY_SHIFT, false)
	if absf(squid_clean - float(p["squidDrySpeed"])) > 0.15:
		_fail("squid dry-ground speed was %.3f, expected %.3f" % [squid_clean, p["squidDrySpeed"]])
		return
	if absf(squid_weighted - squid_clean) > 0.05:
		_fail("squid speed was affected by the kid hard-landing weight: %.3f vs %.3f" % [squid_weighted, squid_clean])
		return

	print("PASS: hard-landing threshold, source weight, %.2f s recovery; kid slowed, squid unaffected" % decay)
	quit()


# Drops the walker from just above the floor with the given downward velocity and
# waits until the landing has been resolved.
func _land_at(down_speed: float) -> void:
	_place(Vector3(0.0, FLOOR_Y + 0.05, 0.0))
	walker.velocity = Vector3(0.0, down_speed, 0.0)
	peak_weight = 0.0
	peak_land_speed = 0.0
	for i in range(12):
		await physics_frame
		peak_weight = maxf(peak_weight, float(walker.get("hard_land")))
		peak_land_speed = maxf(peak_land_speed, float(walker.get("land_speed")))
		if bool(walker.get("grounded")):
			return
	_fail("walker did not land: " + _pos())


# Holds a horizontal key and returns the settled horizontal speed. The weight is topped
# up every frame because it otherwise drains within hardLandTime, and the walker's own
# frame decays it once before use, so the effective weight is slightly under 1; the
# assertion therefore uses a range. Horizontal velocity is zeroed first so leftover
# momentum from an earlier measurement cannot masquerade as a higher speed.
func _ground_speed(weighted: bool) -> float:
	walker.velocity.x = 0.0
	walker.velocity.z = 0.0
	_set_key(KEY_D, true)
	var speed := 0.0
	for i in range(70):
		if weighted:
			walker.set("hard_land", 1.0)
		await physics_frame
		speed = Vector2(walker.velocity.x, walker.velocity.z).length()
	_set_key(KEY_D, false)
	return speed


func _build_floor(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "LandFloor"
	body.position = Vector3(0.0, FLOOR_Y - 0.5, 0.0)
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 1.0, 80.0)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _place(position: Vector3) -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT]:
		_set_key(code, false)
	walker.velocity = Vector3.ZERO
	walker.set("grounded", false)
	walker.set("coyote", 0.0)
	walker.set("jump_buffer", 0.0)
	walker.set("climbing", false)
	walker.set("hard_land", 0.0)
	walker.set("land_speed", 0.0)
	walker.global_position = position


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
