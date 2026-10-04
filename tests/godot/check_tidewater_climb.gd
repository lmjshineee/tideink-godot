extends SceneTree

# Wall-climb check for the real map.
#
# The walker reads a camera-relative input axis, so this test states the facing
# explicitly (camera_yaw = -PI/2 makes W walk toward -X, into the wall at x = 5)
# instead of assuming which physical key points at the wall. The previous version
# hard-coded strafe-left, which silently stopped pointing at the wall once the
# walker became camera-relative; the feature was fine, the test was stale.
const SurfaceInk = preload("res://src/world/surface_ink.gd")
const WALL_FACE := 5
const WALL_SPOT := Vector3(5.5, 0.1, 0.0)
const AIM_AT_WALL_YAW := -PI / 2.0

var scene: Node3D
var walker: CharacterBody3D
var ink: RefCounted


func _initialize() -> void:
	# Historical fixture timings are measured at 60 Hz; match runtime is 30 Hz.
	Engine.physics_ticks_per_second = 60
	call_deferred("_check")


func _check() -> void:
	scene = (load("res://scenes/world/tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	walker = scene.get_node("Walker")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater_surfaces.json"))
	ink = SurfaceInk.new(data)
	walker.set("ink", ink)

	# 1. Dry wall: walking into it must not attach.
	_reset()
	_hold(true)
	await _frames(12)
	if bool(walker.get("climbing")):
		_fail("dry wall should not attach")
		return

	# 2. Enemy ink wall must not attach either.
	ink.splat_face(WALL_FACE, 5.0, 1.4, 3.0, 1, 0.5)
	await _frames(12)
	if bool(walker.get("climbing")):
		_fail("enemy ink wall should not attach")
		return

	# 3. Own ink wall attaches and lifts the walker.
	ink.splat_face(WALL_FACE, 5.0, 1.4, 3.0, 0, 0.5)
	var start_y := walker.global_position.y
	await _frames(14)
	if not bool(walker.get("climbing")) or walker.global_position.y < start_y + 0.3:
		_fail("own ink wall should attach and lift the walker: " + str(walker.global_position))
		return

	# 4. Releasing squid detaches from the wall.
	_set_key(KEY_SHIFT, false)
	await _frames(4)
	if bool(walker.get("climbing")):
		_fail("releasing squid should detach")
		return

	# 5. Climbing to the top edge pops the walker over it.
	_reset()
	_hold(true)
	var peak := walker.global_position.y
	var popped := false
	for i in range(90):
		await physics_frame
		peak = maxf(peak, walker.global_position.y)
		popped = popped or (float(walker.get("climb_exit")) > 0.0 and peak > 2.0)
	_set_key(KEY_SHIFT, false)
	_set_key(KEY_W, false, true)
	if peak < 2.6 or not popped:
		_fail("own ink did not carry walker over the ledge: peak=" + str(peak) + " pos=" + str(walker.global_position))
		return
	# Sideways movement into a painted wall must use the same axis as attachment.
	# Forward-only can_dive rejected this even though _update_climb accepted it.
	_reset()
	walker.set("camera_yaw",0.0)
	_set_key(KEY_D,true,true)
	_set_key(KEY_SHIFT,true)
	var sideways_y := walker.global_position.y
	await _frames(14)
	_set_key(KEY_D,false,true)
	_set_key(KEY_SHIFT,false)
	if walker.global_position.y<sideways_y+0.3:
		_fail("Shift + sideways movement did not enter own-ink wall climb")
		return

	print("PASS: dry/enemy walls reject; own ink climbs; squid release detaches; ledge pops")
	quit()


# Places the walker in front of the wall, facing it, with no keys held.
func _reset() -> void:
	_set_key(KEY_SHIFT, false)
	_set_key(KEY_W, false, true)
	walker.call("reset_movement_state")
	walker.global_position = WALL_SPOT
	walker.set("camera_yaw", AIM_AT_WALL_YAW)
	walker.set("look_enabled", false)


# Squid form (Shift) plus forward (W) — the real input path for climbing.
func _hold(on: bool) -> void:
	_set_key(KEY_SHIFT, on)
	_set_key(KEY_W, on, true)


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _set_key(code: Key, pressed: bool, physical: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	if physical:
		event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
