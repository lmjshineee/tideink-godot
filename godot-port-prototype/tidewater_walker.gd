extends CharacterBody3D

# CharacterBody3D traversal for the exported Tidewater map.
# Horizontal handling follows actor.js; kid/squid collision volumes share source dimensions.
const LOOK_SENSITIVITY := 0.0021
const CAMERA_DISTANCE := 4.5
const CAMERA_HEIGHT := 1.85
# Foot-probe constants from the source. physics.js:11 defines WALKABLE = 0.68, the
# minimum ground normal.y a character may stand on (about 47.2 deg, vs Godot's 45
# default). The 8-sample ring at footRadius is how the source steps onto curbs and
# keeps the feet planted on a ledge until the whole footprint has left it.
const RING: Array[Vector2] = [
	Vector2(1.0, 0.0), Vector2(0.70710678, 0.70710678), Vector2(0.0, 1.0), Vector2(-0.70710678, 0.70710678),
	Vector2(-1.0, 0.0), Vector2(-0.70710678, -0.70710678), Vector2(0.0, -1.0), Vector2(0.70710678, -0.70710678),
]
const WALKABLE := 0.68
# A ring sample must sit this far above the centre sample to count as a step
# (physics.js groundProbe stepMin): slopes stay exact, curbs get stepped onto.
const STEP_MIN := 0.12
var jump_requested := false
var jump_buffer := 0.0
var coyote := 0.0
# Intent state (actor.js:226-241, 253-263, 317-324). Owned here rather than in the
# match controller so the squid/fire rule is testable without a scene.
var weapon_fire := false
var intent_driven := false
var fire_buffer := 0.0
var kid_time := 99.0
var intent_time := 0.0
var _fire_press := -1.0
var _squid_press := -1.0
var _previous_fire := false
var _previous_squid := false
var ink: RefCounted
var ink_owner := -1
var active := true
var auto_respawn := true
var firing_speed_limit := INF
var climbing := false
var wall_normal := Vector3.ZERO
var climb_velocity := 0.0
var climb_exit := 0.0
var player_config: Dictionary = {}
var squid_form := false
var camera_yaw := 0.0
var camera_pitch := -0.1
var look_enabled := false
var slam_phase := ""
var slam_time := 0.0
var slam_config: Dictionary = {}
var slam_impact_pending := false
# Ground state owned by the foot probe (see _resolve_ground). The engine's
# is_on_floor() stays in use for collision and for the other modules, but the walk
# rules use this footprint-based state, because a 0.24 m footprint and a 0.38 m
# capsule disagree at ledge edges.
var grounded := false
var ground_normal := Vector3.UP
# Hard-landing recovery (actor.js:241, 388, 508-512). A landing faster than
# hardLandSpeed sets a weight in 0..1; while it is above zero the kid's ground target
# speed is scaled down, and the weight drains to zero over hardLandTime.
var hard_land := 0.0
var land_speed := 0.0
# Facing angular spring (actor.js:781-815). The body yaw is a damped spring towards a
# target, capped in both rate and acceleration, with the target's own angular velocity
# fed forward so a smoothly moving target is tracked without steady-state lag.
var body_yaw := 0.0
var yaw_velocity := 0.0
var aim_yaw := 0.0
var firing_pose := false
var sub_intent := false
var weapon_busy_state := false
var _face_target := 0.0
var _has_face_target := false
var step_height := 0.35
var step_down := 0.45
var foot_radius := 0.24
var _kid_shape: Shape3D
var _squid_shape: Shape3D


func _ready() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons.json"))
	player_config = config["player"]
	_kid_shape = $CollisionShape3D.shape
	_squid_shape = _make_squid_shape()
	step_height = float(player_config["stepUp"])
	step_down = float(player_config["stepDown"])
	foot_radius = float(player_config["footRadius"])
	# Stand on the same slope range as the source, and let the engine cover the same
	# step-down range the foot probe searches.
	floor_max_angle = acos(WALKABLE)
	floor_snap_length = step_down
	body_yaw = $Body.rotation.y
	aim_yaw = camera_yaw
	_update_camera()


func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		jump_requested = true
	if active and look_enabled and event is InputEventMouseMotion:
		apply_look_delta(event.relative)


func apply_look_delta(relative: Vector2) -> void:
	camera_yaw -= relative.x * LOOK_SENSITIVITY
	aim_yaw = camera_yaw
	camera_pitch = clampf(camera_pitch - relative.y * LOOK_SENSITIVITY, -1.05, 1.15)
	_update_camera()


func _camera_relative_axis(local_axis: Vector2) -> Vector2:
	var sy := sin(camera_yaw)
	var cy := cos(camera_yaw)
	return Vector2(sy * local_axis.y - cy * local_axis.x, cy * local_axis.y + sy * local_axis.x)


func _update_camera() -> void:
	var cp := cos(camera_pitch)
	var forward := Vector3(sin(camera_yaw) * cp, sin(camera_pitch), cos(camera_yaw) * cp)
	var pivot := global_position + Vector3.UP * CAMERA_HEIGHT
	var desired := pivot - forward * CAMERA_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(pivot, desired, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var distance := minf(CAMERA_DISTANCE, pivot.distance_to(hit["position"]) - 0.2) if not hit.is_empty() else CAMERA_DISTANCE
	var camera: Camera3D = $Camera3D
	camera.global_position = pivot - forward * maxf(0.45, distance)
	camera.look_at(camera.global_position + forward, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not active:
		if slam_phase.is_empty():
			velocity = Vector3.ZERO
		jump_requested = false
		jump_buffer = 0.0
		coyote = 0.0
		return
	if not slam_phase.is_empty():
		_advance_slam(delta)
		return
	var axis := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): axis.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): axis.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): axis.y += 1.0
	if Input.is_physical_key_pressed(KEY_S): axis.y -= 1.0
	axis = axis.normalized()
	axis = _camera_relative_axis(axis)
	ink_owner = _floor_ink_owner() if ink != null else -1
	# The match controller owns the form decision through update_intent(); the bare
	# walk scene (no controller) keeps reading the key directly.
	var squid := squid_form
	if not intent_driven:
		squid = update_form(Input.is_key_pressed(KEY_SHIFT))
	_advance_jump_input(delta)
	hard_land = maxf(0.0, hard_land - delta / float(player_config["hardLandTime"]))
	# Ground state from the previous frame's foot probe, exactly as actor.js reads
	# this.grounded before _integrate. Both "submerged" and "on enemy ink" require
	# contact with the ground (actor.js:267-268), so a coyote-time jump off a ledge
	# uses the plain jump.
	var was_grounded := grounded
	var submerged := squid and was_grounded and ink_owner == 0
	var on_enemy := was_grounded and ink_owner == 1 and not submerged
	if _update_climb(delta, squid, axis):
		coyote = maxf(0.0, coyote - delta)
		move_and_slide()
		_face(delta, squid, axis, submerged)
		_update_camera()
		return
	_horizontal_step(delta, axis, squid, on_enemy, was_grounded)
	var jumped := _vertical_step(delta, squid, was_grounded, submerged, on_enemy)
	var stick := was_grounded and not jumped
	if stick:
		# Follow the ground plane: the vertical component keeps the feet on the
		# surface at the current horizontal speed (actor.js:443-446).
		var n := ground_normal
		velocity.y = -(velocity.x * n.x + velocity.z * n.z) / maxf(0.35, n.y)
	var previous_y := global_position.y
	# move_and_slide() clears the vertical velocity when the body lands, so the impact
	# speed has to be sampled before the move or _on_land() would always see zero.
	var fall_speed := maxf(0.0, -velocity.y)
	move_and_slide()
	_resolve_ground(squid, previous_y, stick, fall_speed)
	_try_step_up(axis, squid, stick)
	_face(delta, squid, axis, submerged)
	_update_camera()
	if auto_respawn and global_position.y < -5.0:
		global_position = Vector3(0.0, 2.25, -39.2)
		velocity = Vector3.ZERO
		grounded = false
		coyote = 0.0
		_update_camera()


func begin_slam(config: Dictionary) -> void:
	update_form(false)
	climbing = false
	slam_config = config
	slam_phase = "rise"
	slam_time = 0.0
	slam_impact_pending = false
	_set_climbing(false)
	grounded = false
	velocity = Vector3(velocity.x * 0.3, 11.5, velocity.z * 0.3)


func cancel_slam() -> void:
	slam_phase = ""
	slam_time = 0.0
	slam_impact_pending = false
	floor_snap_length = step_down


func _advance_slam(delta: float) -> void:
	slam_time += delta
	match slam_phase:
		"rise":
			velocity.y -= float(player_config["gravity"]) * 0.9 * delta
			if slam_time > float(slam_config["rise"]):
				slam_phase = "hang"
				slam_time = 0.0
				velocity = Vector3(0.0, 0.4, 0.0)
		"hang":
			velocity.y = 0.4
			if slam_time > float(slam_config["hang"]):
				slam_phase = "fall"
				slam_time = 0.0
				velocity = Vector3(0.0, -34.0, 0.0)
		"fall":
			velocity.y = -34.0
	var previous_y := global_position.y
	var fall_speed := maxf(0.0, -velocity.y)
	move_and_slide()
	_update_camera()
	# The slam lands on the foot probe's surface, not on engine floor contact: the
	# probe starts from the highest point this frame passed through, so a 34 m/s fall
	# cannot tunnel through the deck (actor.js:483-495).
	if slam_phase == "fall":
		_resolve_ground(false, previous_y, false, fall_speed)
	_face(delta, false, Vector2.ZERO, false)
	if slam_phase == "fall" and (grounded or slam_time > 1.2):
		cancel_slam()
		slam_impact_pending = true


func reset_movement_state() -> void:
	cancel_slam()
	climbing = false
	wall_normal = Vector3.ZERO
	climb_velocity = 0.0
	climb_exit = 0.0
	jump_requested = false
	jump_buffer = 0.0
	coyote = 0.0
	_apply_form(false)
	floor_snap_length = step_down
	grounded = false
	ground_normal = Vector3.UP
	yaw_velocity = 0.0
	_has_face_target = false
	hard_land = 0.0
	land_speed = 0.0
	velocity = Vector3.ZERO
	_update_camera()


# Applies one frame of player intent and decides, per actor.js:253-263 and
# 317-324, whether the actor is a squid this frame and whether the weapon may fire.
# "Most recent press wins" is what makes diving mid-spray and popping out of the ink
# to shoot both work; the pop-out shot is buffered for fireBuffer seconds instead of
# being dropped, and the weapon only leaves the barrel emergeDelay after surfacing.
# The match controller passes `firing` and `sub` for the facing branch
# (actor.js:789-791: the body turns to the crosshair while firing or holding a bomb).
# Defaults keep standalone movement tests and older callers compatible.
func update_intent(delta: float, fire: bool, squid_request: bool, weapon_busy: bool,
		firing: bool = false, sub: bool = false) -> void:
	intent_driven = true
	firing_pose = firing
	sub_intent = sub
	weapon_busy_state = weapon_busy
	intent_time += delta
	kid_time += delta
	var fire_pressed := fire and not _previous_fire
	if squid_request and not _previous_squid:
		_squid_press = intent_time
	if fire_pressed:
		_fire_press = intent_time
	_previous_fire = fire
	_previous_squid = squid_request

	fire_buffer = float(player_config["fireBuffer"]) if fire_pressed else maxf(0.0, fire_buffer - delta)
	var fire_wins := (fire or fire_buffer > 0.0) and _fire_press >= _squid_press
	var want_squid := squid_request and not fire_wins and not weapon_busy
	var was_squid := squid_form
	update_form(want_squid)
	if was_squid != squid_form and not squid_form:
		kid_time = 0.0

	if not squid_form and kid_time >= float(player_config["emergeDelay"]):
		weapon_fire = fire or fire_buffer > 0.0
		fire_buffer = 0.0
	else:
		weapon_fire = false


func update_form(requested_squid: bool) -> bool:
	if requested_squid == squid_form:
		return squid_form
	if not requested_squid and not _can_stand():
		return true
	_apply_form(requested_squid)
	return squid_form


func _apply_form(squid: bool) -> void:
	squid_form = squid
	$CollisionShape3D.shape = _squid_shape if squid else _kid_shape
	# The kid shape keeps the scene's source-sized capsule (0 .. 1.45); only the squid
	# uses the lifted centre from _squid_shape_center().
	$CollisionShape3D.position.y = _squid_shape_center() if squid else float(player_config["height"]) * 0.5
	$Body.call("set_form", squid)


func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _kid_shape
	query.transform = Transform3D(global_transform.basis, global_position + global_transform.basis * Vector3.UP * float(player_config["height"]) * 0.5)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# physics.js:201 builds the body capsule as `bot = lift + radius,
# top = max(bot, height - radius)`. For the squid that is lift = squidBodyLift (0.16)
# and height = squidHeight (0.55), so `top == bot` and the body degenerates into a
# sphere of PLAYER.radius whose centre sits lift + radius above the feet: its solid
# extent is 0.16 .. 0.92. Everything below the lift belongs to the feet, which is what
# lets a squid slip over geometry shorter than squidBodyLift instead of being stopped
# by it. The port used a 0.38 m twelve-sided prism resting on the ground (0 .. 0.55),
# which was both fatter at the ankle and 0.37 m shorter at the top.
func _make_squid_shape() -> Shape3D:
	var radius := float(player_config["radius"])
	var bottom := float(player_config["squidBodyLift"]) + radius
	var top := maxf(bottom, float(player_config["squidHeight"]) - radius)
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = (top - bottom) + 2.0 * radius
	return shape


# Centre of the squid body above the feet, from the same formula.
func _squid_shape_center() -> float:
	var radius := float(player_config["radius"])
	var bottom := float(player_config["squidBodyLift"]) + radius
	var top := maxf(bottom, float(player_config["squidHeight"]) - radius)
	return (bottom + top) * 0.5


func _advance_jump_input(delta: float) -> void:
	jump_buffer = float(player_config["jumpBuffer"]) if jump_requested else maxf(0.0, jump_buffer - delta)
	jump_requested = false


# Port of actor.js jump buffering, coyote time and variable gravity. The Godot
# CharacterBody still handles floor contact, so step/ledge behavior differs.
func _vertical_step(delta: float, squid: bool, grounded: bool, submerged: bool = false,
		on_enemy: bool = false) -> bool:
	coyote = float(player_config["coyoteTime"]) if grounded else maxf(0.0, coyote - delta)
	var jumped := jump_buffer > 0.0 and (grounded or coyote > 0.0)
	if jumped:
		var jump := float(player_config["swimJumpVel"]) if submerged else float(player_config["jumpVel"])
		velocity.y = jump * 0.72 if on_enemy else jump
		jump_buffer = 0.0
		coyote = 0.0
	elif grounded:
		velocity.y = 0.0
		return false
	var gravity := float(player_config["gravity"])
	if velocity.y < 0.0:
		gravity *= float(player_config["fallGravityMul"])
	if absf(velocity.y) < float(player_config["apexBand"]):
		gravity *= float(player_config["apexGravityMul"])
	velocity.y = maxf(-float(player_config["maxFall"]), velocity.y - gravity * delta)
	return jumped


# Port of actor.js _horizontal. This changes horizontal velocity only; collision
# and grounding continue to be resolved by CharacterBody3D.
func _horizontal_step(delta: float, axis: Vector2, squid: bool, on_enemy: bool, grounded: bool) -> void:
	var p := player_config
	var horizontal := Vector2(velocity.x, velocity.z)
	var speed := horizontal.length()
	var input_length := axis.length()
	var magnitude := minf(1.0, input_length)
	if not grounded:
		var target := maxf(float(p["squidDrySpeed"]), speed) if squid else maxf(minf(float(p["runSpeed"]), firing_speed_limit), float(p["airMinSpeed"]))
		var acceleration := float(p["squidAirAccel"]) if squid else float(p["airAccel"])
		var deceleration := float(p["squidAirDecel"]) if squid else float(p["airDecel"])
		var desired := axis.normalized() * target * magnitude if input_length > 0.01 else Vector2.ZERO
		horizontal = horizontal.move_toward(desired, (acceleration if input_length > 0.01 else deceleration) * delta)
		_set_horizontal(horizontal)
		return

	var target_speed: float
	var acceleration: float
	var acceleration_in: float
	var in_knee: float
	var out_knee: float
	var deceleration: float
	var deceleration_min: float
	var deceleration_knee: float
	var turn_rate: float
	if squid and ink_owner == 0:
		target_speed = float(p["swimSpeed"])
		acceleration = float(p["swimAccel"])
		acceleration_in = float(p["swimAccelIn"])
		in_knee = 3.0
		out_knee = float(p["swimOutKnee"])
		deceleration = float(p["swimDecel"])
		deceleration_min = 0.5
		deceleration_knee = 4.0
		turn_rate = float(p["swimTurn"])
	elif squid:
		target_speed = float(p["squidDrySpeed"])
		acceleration = float(p["squidAccel"])
		acceleration_in = 0.6
		in_knee = 1.0
		out_knee = 0.3
		deceleration = float(p["squidDecel"])
		deceleration_min = 0.5
		deceleration_knee = 2.0
		turn_rate = float(p["squidTurn"])
	else:
		target_speed = minf(float(p["runSpeed"]), firing_speed_limit)
		# Recovery weight after a hard landing; squid branches above are untouched
		# because the source applies this only to the kid ground branch.
		if hard_land > 0.0:
			target_speed *= 1.0 - (1.0 - float(p["hardLandSlow"])) * hard_land
		acceleration = float(p["runAccel"])
		acceleration_in = float(p["runAccelIn"])
		in_knee = float(p["runInKnee"])
		out_knee = float(p["runOutKnee"])
		deceleration = float(p["runDecel"])
		deceleration_min = float(p["runDecelMin"])
		deceleration_knee = float(p["runDecelKnee"])
		turn_rate = float(p["turnRate"])
	if on_enemy:
		target_speed = minf(target_speed, float(p["enemyInkSpeed"]))
		acceleration = minf(acceleration, float(p["enemyInkAccel"]))
		deceleration = maxf(float(p["enemyInkDecel"]), 0.0)
	if input_length < 0.01:
		if speed < 0.0001:
			_set_horizontal(Vector2.ZERO)
			return
		var brake := deceleration * (deceleration_min + (1.0 - deceleration_min) * smoothstep(0.0, deceleration_knee, speed)) * delta
		_set_horizontal(horizontal.move_toward(Vector2.ZERO, brake))
		return

	var direction := axis / input_length
	var desired_speed := target_speed * magnitude
	var heading := horizontal / speed if speed > 0.05 else direction
	var angle := absf(heading.angle_to(direction))
	if speed > 0.5 and angle > float(p["reverseAngle"]):
		var reverse_rate := maxf(float(p["reverseDecel"]), deceleration) * delta * (0.5 if on_enemy else 1.0)
		_set_horizontal(horizontal.move_toward(direction * desired_speed, reverse_rate))
		return
	var max_turn := turn_rate * (1.0 + float(p["turnRateSlow"]) * (1.0 - smoothstep(0.0, target_speed, speed))) * delta
	heading = heading.rotated(clampf(heading.angle_to(direction), -max_turn, max_turn))
	var next_speed: float
	if speed < desired_speed:
		var gain := acceleration * (acceleration_in + (1.0 - acceleration_in) * smoothstep(0.0, in_knee, speed))
		gain *= clampf((desired_speed - speed) / (out_knee * target_speed), float(p["runOutMin"]), 1.0)
		next_speed = minf(desired_speed, speed + gain * delta)
	else:
		var brake := deceleration * (deceleration_min + (1.0 - deceleration_min) * smoothstep(0.0, deceleration_knee, speed - desired_speed)) * delta
		next_speed = maxf(desired_speed, speed - brake)
	_set_horizontal(heading * next_speed)


func _set_horizontal(value: Vector2) -> void:
	velocity.x = value.x
	velocity.z = value.y


func _update_climb(delta: float, squid: bool, axis: Vector2) -> bool:
	climb_exit = maxf(0.0, climb_exit - delta)
	if not squid or ink == null or climb_exit > 0.0:
		if climbing:
			_set_climbing(false)
		return false
	var movement := Vector3(axis.x, 0.0, axis.y)
	var direction := -wall_normal if climbing else movement
	if direction.length_squared() < 0.04:
		return false
	direction = direction.normalized()
	var radius := float(player_config["radius"])
	var hit := _wall_ray(global_position + Vector3.UP * 0.3, direction, radius + 0.35)
	if hit.is_empty():
		if climbing:
			_ledge_pop(direction)
			return true
		return false
	var normal: Vector3 = hit["normal"]
	var own_wall := _is_own_wall_hit(hit)
	var into := -movement.dot(normal) / movement.length() if movement.length() > 0.01 else 0.0
	if not climbing:
		if not own_wall or into <= float(player_config["climbAttachDot"]):
			return false
		wall_normal = normal
		climb_velocity = maxf(0.0, velocity.y)
		_set_climbing(true)
	if not own_wall:
		_set_climbing(false)
		velocity.y = minf(velocity.y, 1.5)
		velocity.x += normal.x * 1.2
		velocity.z += normal.z * 1.2
		climb_exit = 0.2
		return true
	if into < float(player_config["climbDetachDot"]):
		_set_climbing(false)
		velocity = normal * 3.2 + Vector3.UP * 3.2
		climb_exit = 0.3
		return true
	wall_normal = normal
	var upper_hit := _wall_ray(global_position + Vector3.UP * 0.85, direction, radius + 0.45)
	var capped := not upper_hit.is_empty() and absf(float(upper_hit["normal"].y)) < 0.5 and not _is_own_wall_hit(upper_hit)
	var want := 0.0 if capped else float(player_config["climbSpeed"]) * clampf(into, 0.0, 1.0) * minf(1.0, movement.length())
	if upper_hit.is_empty() and want > 0.0:
		want = minf(want, sqrt(2.0 * float(player_config["gravity"]) * float(player_config["apexGravityMul"]) * (float(player_config["ledgePopClear"]) + 0.3)))
	var accel := float(player_config["climbAccel"]) * delta * (1.0 if want > climb_velocity else 1.6)
	climb_velocity = move_toward(climb_velocity, want, accel)
	velocity.y = climb_velocity
	var side := movement - normal * movement.dot(normal)
	velocity.x = side.x * float(player_config["climbSideSpeed"]) - normal.x * 1.2
	velocity.z = side.z * float(player_config["climbSideSpeed"]) - normal.z * 1.2
	return true


func _wall_ray(from: Vector3, direction: Vector3, length: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * length, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _is_own_wall_hit(hit: Dictionary) -> bool:
	if hit.is_empty() or absf(float(hit["normal"].y)) >= 0.5:
		return false
	var collider: Object = hit["collider"]
	var block_id := int(collider.get_meta("source_id", -1))
	if block_id < 0:
		return false
	var map := get_parent().get_node("Map")
	var face: Dictionary = map.call("find_surface", hit["position"], hit["normal"], block_id)
	if face.is_empty() or not bool(face["wall"]):
		return false
	var relative: Vector3 = hit["position"] - _vector(face["origin"])
	return int(ink.call("owner_at", int(face["id"]), relative.dot(_vector(face["u"])), relative.dot(_vector(face["v"])))) == 0


func _set_climbing(on: bool) -> void:
	climbing = on
	floor_snap_length = 0.0 if on else step_down
	if on:
		# A climbing character is not standing on the ground (actor.js:436-438).
		grounded = false
	else:
		climb_velocity = 0.0


# physics.js:164-188 groundProbe. A vertical centre sample wins when it is walkable
# and inside the search range, so slopes are exact; a ring sample at footRadius only
# wins when it sits at least STEP_MIN above the centre — that is what steps a curb up
# as soon as the foot reaches it — or when the centre is over a gap, which keeps the
# feet planted until the whole footprint has left the ledge.
func _ground_probe(up: float, down: float) -> Dictionary:
	var length := up + down
	var center_y := -INF
	var have_center := false
	var best: Dictionary = {}
	var center := _probe_ray(global_position, up, length)
	if not center.is_empty() and float(center["normal"].y) >= WALKABLE:
		have_center = true
		center_y = float(center["position"].y)
		best = center
	var threshold := center_y + STEP_MIN if have_center else -INF
	for direction in RING:
		var base := global_position + Vector3(direction.x * foot_radius, 0.0, direction.y * foot_radius)
		var sample := _probe_ray(base, up, length)
		if sample.is_empty() or float(sample["normal"].y) < WALKABLE:
			continue
		if float(sample["position"].y) > threshold:
			threshold = float(sample["position"].y)
			best = sample
	if best.is_empty():
		return {}
	return {"y": float(best["position"].y), "normal": best["normal"]}


# The source lifts the character's body capsule by stepUp, which is why a curb never
# blocks it and the foot ring can pull the feet up. Godot's capsule must keep touching
# the ground here (is_on_floor() still drives the play controller and the weapons), so
# the same outcome is produced by probing just ahead of the body: a walkable surface
# within stepUp of the feet raises them before the next move, and the capsule then
# passes over the curb instead of being stopped by it.
#
# Known difference from the source: the lift fires at body radius + 5 cm from the face
# instead of at the 0.24 m footprint, so the character rises slightly earlier than the
# web build. Lifting the collision shape instead would match exactly but would break
# is_on_floor() for the modules that still read it.
func _try_step_up(axis: Vector2, squid: bool, stick: bool) -> void:
	if not stick or climbing or axis.length_squared() < 0.01:
		return
	var limit := float(player_config["squidStepUp"]) if squid else step_height
	var direction := Vector3(axis.x, 0.0, axis.y).normalized()
	var from := global_position + direction * (float(player_config["radius"]) + 0.05) + Vector3.UP * (limit + 0.02)
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * (limit + 0.04), collision_mask))
	if hit.is_empty() or float(hit["normal"].y) < WALKABLE:
		return
	var rise := float(hit["position"].y) - global_position.y
	# groundProbe only lets a footprint sample win when it sits more than STEP_MIN
	# above the centre, so a lip shorter than that is walked over, not stepped onto.
	# The squid body is lifted like the source's, so that threshold applies directly;
	# the kid body is not lifted here (see _try_step_up's header), so it keeps a looser
	# threshold to stand in for the missing lift.
	var minimum := STEP_MIN if squid else 0.02
	if rise <= minimum or rise > limit + 0.01:
		return
	global_position.y = float(hit["position"].y)
	ground_normal = hit["normal"]
	grounded = true
	velocity.y = 0.0


# actor.js:781-815 _face. The body yaw is a spring towards a target chosen by state:
# a slam faces its velocity, firing or holding a bomb faces the crosshair, a climb
# faces into the wall, and otherwise the movement input wins, falling back to the
# velocity while coasting. Squid form uses its own stiffness and rate limits. Angular
# acceleration is capped too, so a turn spins up over a few frames instead of snapping.
func _face(delta: float, squid: bool, axis: Vector2, submerged: bool) -> void:
	var p := player_config
	var move_length := axis.length()
	var speed := Vector2(velocity.x, velocity.z).length()
	var target := 0.0
	var target_valid := false
	var omega := float(p["faceOmega"])
	var max_rate := float(p["faceMaxRate"])
	var max_acc := float(p["faceMaxAcc"])
	if not slam_phase.is_empty():
		if speed > 0.6:
			target = atan2(velocity.x, velocity.z)
			target_valid = true
	elif firing_pose or sub_intent or weapon_busy_state or weapon_fire:
		target = aim_yaw
		omega = float(p["aimFaceOmega"])
		max_rate = float(p["aimFaceMaxRate"])
		max_acc = float(p["aimFaceMaxAcc"])
		target_valid = true
	elif climbing:
		target = atan2(-wall_normal.x, -wall_normal.z)
		omega = 26.0
		max_rate = 18.0
		target_valid = true
	else:
		if move_length > 0.2:
			target = atan2(axis.x, axis.y)
			target_valid = true
		elif speed > 0.6:
			target = atan2(velocity.x, velocity.z)
			target_valid = true
		if squid:
			omega = float(p["squidFaceOmega"])
			max_rate = float(p["swimFaceMaxRate"]) if submerged else float(p["squidFaceMaxRate"])
			max_acc = float(p["squidFaceMaxAcc"])

	# Feed the target's own angular velocity forward so a smoothly moving target is
	# tracked without lag; a discrete jump (new key direction) gets no kick.
	var target_rate := 0.0
	if target_valid and _has_face_target:
		var difference := _angle_difference(_face_target, target)
		if absf(difference) < 0.12:
			target_rate = clampf(difference / maxf(delta, 1e-4), -max_rate, max_rate)
	_face_target = target
	_has_face_target = target_valid

	var acceleration := 0.0
	if target_valid:
		acceleration = omega * omega * _angle_difference(body_yaw, target) + 2.0 * omega * (target_rate - yaw_velocity)
	else:
		acceleration = -2.0 * omega * yaw_velocity
	yaw_velocity = clampf(yaw_velocity + clampf(acceleration, -max_acc, max_acc) * delta, -max_rate, max_rate)
	if absf(yaw_velocity) < 1e-5:
		yaw_velocity = 0.0
	body_yaw = wrapf(body_yaw + yaw_velocity * delta, -PI, PI)
	$Body.rotation.y = body_yaw


static func _angle_difference(from_angle: float, to_angle: float) -> float:
	return wrapf(to_angle - from_angle, -PI, PI)


func _probe_ray(base: Vector3, up: float, length: float) -> Dictionary:
	var from := base + Vector3.UP * up
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * length, collision_mask))


# actor.js:471-500 _resolve. `stick` means we were grounded and did not jump, so the
# feet are snapped to the probed surface anywhere between stepUp above and stepDown
# below; otherwise this is a landing, searched upwards from the highest point the
# frame passed through plus ledgeAssist, which is what lets a fall land on a ledge.
func _resolve_ground(squid: bool, previous_y: float, stick: bool, fall_speed: float = 0.0) -> void:
	var landed := false
	if stick:
		var probe := _ground_probe(float(player_config["squidStepUp"]) if squid else step_height, step_down)
		if not probe.is_empty():
			global_position.y = float(probe["y"])
			ground_normal = probe["normal"]
			landed = true
	elif velocity.y <= 0.5:
		var assist := float(player_config["squidStepUp"]) if squid else float(player_config["ledgeAssist"])
		var top := maxf(previous_y, global_position.y)
		var probe := _ground_probe((top - global_position.y) + assist, 0.02)
		if not probe.is_empty():
			var probe_y := float(probe["y"])
			if probe_y >= global_position.y - 0.02 and (velocity.y <= 0.0 or probe_y - global_position.y < 0.02):
				global_position.y = probe_y
				ground_normal = probe["normal"]
				landed = true
	var was_grounded := grounded
	grounded = landed
	if grounded:
		# The impact speed must be read before the vertical velocity is cleared, and
		# only on the airborne -> grounded transition (actor.js:492/503-511).
		if not was_grounded:
			_on_land(fall_speed)
		velocity.y = 0.0


# actor.js:506-511 _onLand. Only the hard-landing weight is reproduced here; the
# land event, camera dip and audio hook live outside this controller.
func _on_land(fall_speed: float) -> void:
	land_speed = fall_speed
	var threshold := float(player_config["hardLandSpeed"])
	if land_speed > threshold:
		hard_land = clampf((land_speed - threshold) / 6.0 + 0.5, 0.0, 1.0)


func _ledge_pop(direction: Vector3) -> void:
	var radius := float(player_config["radius"])
	var start := global_position + direction * (radius + 0.32) + Vector3.UP * 1.4
	var query := PhysicsRayQueryParameters3D.create(start, start - Vector3.UP * 2.0, 1)
	var top_hit := get_world_3d().direct_space_state.intersect_ray(query)
	var top := float(top_hit["position"].y) if not top_hit.is_empty() and float(top_hit["normal"].y) > 0.6 else global_position.y + 0.3
	var gravity := float(player_config["gravity"]) * float(player_config["apexGravityMul"])
	var rise := maxf(0.25, top + float(player_config["ledgePopClear"]) - global_position.y)
	var previous_climb_velocity := climb_velocity
	_set_climbing(false)
	velocity.y = maxf(sqrt(2.0 * gravity * rise), minf(previous_climb_velocity, 6.5))
	velocity.x = direction.x * float(player_config["ledgePopCarry"])
	velocity.z = direction.z * float(player_config["ledgePopCarry"])
	climb_exit = 0.3


func _floor_ink_owner() -> int:
	var from := global_position + Vector3.UP * 0.35
	var to := global_position - Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	var collider: Object = hit["collider"]
	var block_id := int(collider.get_meta("source_id", -1))
	if block_id < 0:
		return -1
	var map := get_parent().get_node("Map")
	var face: Dictionary = map.call("find_surface", hit["position"], hit["normal"], block_id)
	if face.is_empty():
		return -1
	var relative: Vector3 = hit["position"] - _vector(face["origin"])
	var u := relative.dot(_vector(face["u"]))
	var v := relative.dot(_vector(face["v"]))
	return int(ink.call("owner_at", int(face["id"]), u, v))


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
