extends SceneTree

# DS-01 acceptance: stepUp / stepDown / footRadius in tidewater_walker.gd.
#
# Source: public/game/src/game/actor.js:443-500 (_integrate/_resolve) and
# public/game/src/game/physics.js:160-188 (groundProbe). Parameters come from
# assets/weapons.json (PLAYER.stepUp 0.35, stepDown 0.45, footRadius 0.24).
#
# The three observable scenarios are built on an isolated arena high above the map so
# the map's own geometry and the set-dressing prop colliders cannot influence the
# result:
#   1. walk into a 0.35 m curb and end up standing on top of it
#   2. keep walking off the far edge and step down onto the lower surface
#   3. on a 0.9 m ledge, stay grounded while part of the 0.24 m footprint is still on
#      it, and fall once the whole footprint has cleared - and never climb the 0.9 m
#      face from below, because stepUp is only 0.35
const FLOOR_Y := 100.0
const CURB_TOP := 0.35
const LEDGE_TOP := 0.9
const CURB_Z := Vector2(-8.0, 2.0)      # curb spans z -8..2, top at FLOOR_Y + 0.35
const LEDGE_Z := Vector2(6.0, 14.0)     # ledge spans z 6..14, top at FLOOR_Y + 0.9

var scene: Node3D
var walker: CharacterBody3D


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	scene = (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	walker = scene.get_node("Walker")
	_settle_input()
	_build_arena(scene)
	# The walk scene reads keys directly when no match controller drives it.
	if bool(walker.get("intent_driven")):
		_fail("expected the bare walk scene, not a controller-driven walker")
		return

	# --- 1. step up a 0.35 m curb ------------------------------------------------
	_place(Vector3(0.0, FLOOR_Y + 0.3, -14.0))
	await _frames(40)
	if walker.global_position.y > FLOOR_Y + 0.05 or not bool(walker.get("grounded")):
		_fail("walker did not settle on the arena floor: " + _pos())
		return
	_set_key(KEY_W, true)
	await _frames(100)
	_set_key(KEY_W, false)
	await _frames(20)
	if walker.global_position.z < CURB_Z.x:
		_fail("walker never reached the curb: " + _pos())
		return
	if walker.global_position.y < FLOOR_Y + CURB_TOP - 0.05:
		_fail("walker did not step up onto the %.2f m curb: %s (grounded=%s)" % [
			CURB_TOP, _pos(), str(walker.get("grounded"))])
		return

	# --- 2. step down off the far edge -------------------------------------------
	_set_key(KEY_W, true)
	await _frames(80)
	_set_key(KEY_W, false)
	await _frames(20)
	if walker.global_position.z <= CURB_Z.y:
		_fail("walker did not walk off the curb: " + _pos())
		return
	if walker.global_position.y > FLOOR_Y + 0.05:
		_fail("walker did not step down to the lower surface: %s (grounded=%s)" % [
			_pos(), str(walker.get("grounded"))])
		return
	if not bool(walker.get("grounded")):
		_fail("walker was left airborne after stepping down: " + _pos())
		return

	# --- 3a. never climb the 0.9 m ledge face from below -------------------------
	_place(Vector3(0.0, FLOOR_Y + 0.3, LEDGE_Z.x - 0.6))
	await _frames(40)
	var before_z := walker.global_position.z
	_set_key(KEY_W, true)
	await _frames(60)
	_set_key(KEY_W, false)
	await _frames(20)
	if walker.global_position.y > FLOOR_Y + 0.1:
		_fail("stepUp climbed a %.2f m face (stepUp is 0.35): %s" % [LEDGE_TOP, _pos()])
		return
	if walker.global_position.z < before_z:
		_fail("walker moved backwards at the ledge: " + _pos())
		return

	# --- 3b. feet stay planted while part of the footprint is on the ledge -------
	_place(Vector3(0.0, FLOOR_Y + LEDGE_TOP + 0.05, 10.0))
	await _frames(40)
	if absf(walker.global_position.y - (FLOOR_Y + LEDGE_TOP)) > 0.05 or not bool(walker.get("grounded")):
		_fail("walker did not settle on the ledge top: " + _pos())
		return
	# Centre just past the edge, back-facing ring samples still on the ledge.
	_place(Vector3(0.0, FLOOR_Y + LEDGE_TOP + 0.01, LEDGE_Z.y + 0.10))
	await _frames(3)
	if not bool(walker.get("grounded")) or absf(walker.global_position.y - (FLOOR_Y + LEDGE_TOP)) > 0.05:
		_fail("footprint support did not hold the walker on the ledge edge: %s (grounded=%s)" % [
			_pos(), str(walker.get("grounded"))])
		return
	# Whole footprint clear of the ledge: must fall, not hover.
	_place(Vector3(0.0, FLOOR_Y + LEDGE_TOP + 0.01, LEDGE_Z.y + 0.30))
	await _frames(3)
	if bool(walker.get("grounded")):
		_fail("walker stayed grounded with the whole footprint past the ledge: " + _pos())
		return
	if walker.global_position.y > FLOOR_Y + LEDGE_TOP - 0.01:
		_fail("walker did not start falling off the ledge: " + _pos())
		return

	print("PASS: stepUp 0.35 m curb, stepDown off the edge, ledge footprint support; %.2f m face not climbable" % LEDGE_TOP)
	quit()


# Isolated flat arena: floor slab, a 0.35 m curb and a 0.9 m ledge.
func _build_arena(parent: Node3D) -> void:
	_add_box(parent, "Floor", Vector3(0.0, FLOOR_Y - 0.5, 0.0), Vector3(60.0, 1.0, 60.0))
	_add_box(parent, "Curb", Vector3(0.0, FLOOR_Y + CURB_TOP * 0.5, (CURB_Z.x + CURB_Z.y) * 0.5),
		Vector3(10.0, CURB_TOP, CURB_Z.y - CURB_Z.x))
	_add_box(parent, "Ledge", Vector3(0.0, FLOOR_Y + LEDGE_TOP * 0.5, (LEDGE_Z.x + LEDGE_Z.y) * 0.5),
		Vector3(10.0, LEDGE_TOP, LEDGE_Z.y - LEDGE_Z.x))


func _add_box(parent: Node3D, name_text: String, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name_text
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


# Places the walker with no motion so the next frames resolve the ground from scratch.
func _place(position: Vector3) -> void:
	_set_key(KEY_W, false)
	walker.velocity = Vector3.ZERO
	walker.set("grounded", false)
	walker.set("coyote", 0.0)
	walker.set("jump_buffer", 0.0)
	walker.set("climbing", false)
	walker.global_position = position


func _settle_input() -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_SPACE]:
		_set_key(code, false)


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
