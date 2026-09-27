extends CharacterBody3D

# CharacterBody3D traversal for the exported Tidewater map.
# Horizontal handling follows actor.js; kid/squid collision volumes share source dimensions.
const SQUID_SIDES := 12
const LOOK_SENSITIVITY := 0.0021
const CAMERA_DISTANCE := 4.5
const CAMERA_HEIGHT := 1.85
var jump_requested := false
var jump_buffer := 0.0
var coyote := 0.0
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
var _kid_shape: Shape3D
var _squid_shape: Shape3D


func _ready() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons.json"))
	player_config = config["player"]
	_kid_shape = $CollisionShape3D.shape
	_squid_shape = _make_squid_shape()
	floor_snap_length = 0.25
	_update_camera()


func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		jump_requested = true
	if active and look_enabled and event is InputEventMouseMotion:
		apply_look_delta(event.relative)


func apply_look_delta(relative: Vector2) -> void:
	camera_yaw -= relative.x * LOOK_SENSITIVITY
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
	var wants_squid := Input.is_key_pressed(KEY_SHIFT)
	var squid := update_form(wants_squid)
	_advance_jump_input(delta)
	if _update_climb(delta, wants_squid, axis):
		coyote = maxf(0.0, coyote - delta)
		move_and_slide()
		_update_camera()
		return
	_horizontal_step(delta, axis, squid, ink_owner == 1, is_on_floor())
	_vertical_step(delta, squid, is_on_floor())
	move_and_slide()
	_update_camera()
	if axis.length_squared() > 0.0:
		$Body.rotation.y = atan2(axis.x, axis.y)
	if auto_respawn and global_position.y < -5.0:
		global_position = Vector3(0.0, 2.25, -39.2)
		velocity = Vector3.ZERO
		_update_camera()


func begin_slam(config: Dictionary) -> void:
	update_form(false)
	climbing = false
	slam_config = config
	slam_phase = "rise"
	slam_time = 0.0
	slam_impact_pending = false
	floor_snap_length = 0.0
	velocity = Vector3(velocity.x * 0.3, 11.5, velocity.z * 0.3)


func cancel_slam() -> void:
	slam_phase = ""
	slam_time = 0.0
	slam_impact_pending = false
	floor_snap_length = 0.25


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
	move_and_slide()
	_update_camera()
	if slam_phase == "fall" and (is_on_floor() or slam_time > 1.2):
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
	floor_snap_length = 0.25
	velocity = Vector3.ZERO
	_update_camera()


func update_form(requested_squid: bool) -> bool:
	if requested_squid == squid_form:
		return squid_form
	if not requested_squid and not _can_stand():
		return true
	_apply_form(requested_squid)
	return squid_form


func _apply_form(squid: bool) -> void:
	squid_form = squid
	var height := float(player_config["squidHeight"]) if squid else float(player_config["height"])
	$CollisionShape3D.shape = _squid_shape if squid else _kid_shape
	$CollisionShape3D.position.y = height * 0.5
	$Body.call("set_form", squid)


func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _kid_shape
	query.transform = Transform3D(global_transform.basis, global_position + global_transform.basis * Vector3.UP * float(player_config["height"]) * 0.5)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _make_squid_shape() -> ConvexPolygonShape3D:
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	var radius := float(player_config["radius"]) / cos(PI / float(SQUID_SIDES))
	var half_height := float(player_config["squidHeight"]) * 0.5
	for i in range(SQUID_SIDES):
		var angle := TAU * float(i) / float(SQUID_SIDES)
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		points.append(Vector3(x, -half_height, z))
		points.append(Vector3(x, half_height, z))
	shape.points = points
	return shape


func _advance_jump_input(delta: float) -> void:
	jump_buffer = float(player_config["jumpBuffer"]) if jump_requested else maxf(0.0, jump_buffer - delta)
	jump_requested = false


# Port of actor.js jump buffering, coyote time and variable gravity. The Godot
# CharacterBody still handles floor contact, so step/ledge behavior differs.
func _vertical_step(delta: float, squid: bool, grounded: bool) -> bool:
	coyote = float(player_config["coyoteTime"]) if grounded else maxf(0.0, coyote - delta)
	var jumped := jump_buffer > 0.0 and (grounded or coyote > 0.0)
	if jumped:
		var jump := float(player_config["swimJumpVel"]) if squid and ink_owner == 0 else float(player_config["jumpVel"])
		velocity.y = jump * 0.72 if ink_owner == 1 else jump
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
	floor_snap_length = 0.0 if on else 0.25
	if not on:
		climb_velocity = 0.0


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
