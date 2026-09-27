extends Node3D

# Tidewater 1v1 opponent. Patrol the clear right lane, pursue a visible nearby
# player only when a body-width path stays on walkable ground, and paint the
# same authoritative surface grid used by the player and judge.
const WAYPOINTS := [
	Vector2(0.0, 31.0), Vector2(12.0, 31.0),
	Vector2(12.0, 13.0), Vector2(8.0, 8.0), Vector2(8.0, -10.0),
	Vector2(8.0, 8.0), Vector2(12.0, 13.0), Vector2(12.0, 31.0),
]
const PAINT_INTERVAL := 0.22
const ATTACK_INTERVAL := 1.2
const ATTACK_RANGE := 5.0
const CHASE_RANGE := 13.0
const CHASE_STOP := 3.8
const BODY_RADIUS := 0.34

var game: Node3D
var walker: CharacterBody3D
var map: Node3D
var waypoint_index := 0
var paint_cooldown := 0.0
var attack_cooldown := 0.0
var chasing := false
var returning := false
var chase_trail: Array[Vector3] = []
var _body_shape: SphereShape3D
var health_bar: Node3D
var health_fill: MeshInstance3D
var attack_tracer: MeshInstance3D
var attack_tracer_mesh: BoxMesh
var attack_visual_time := 0.0


func setup(owner: Node3D, player: CharacterBody3D, level: Node3D) -> void:
	game = owner
	walker = player
	map = level
	_body_shape = SphereShape3D.new()
	_body_shape.radius = BODY_RADIUS
	_build_feedback()
	reset()


func reset() -> void:
	var pads: Array = map.get("spawn_pads")
	global_position = pads[1] as Vector3
	waypoint_index = 0
	paint_cooldown = 0.0
	attack_cooldown = 0.0
	chasing = false
	returning = false
	chase_trail.clear()
	visible = true
	clear_attack_visual()
	_update_health_visual()


func clear_attack_visual() -> void:
	attack_visual_time = 0.0
	if attack_tracer != null:
		attack_tracer.visible = false


func tick(delta: float) -> void:
	attack_visual_time = maxf(0.0, attack_visual_time - delta)
	attack_tracer.visible = attack_visual_time > 0.0
	_update_health_visual()
	var old_position := global_position
	var current := Vector2(global_position.x, global_position.z)
	var player := Vector2(walker.global_position.x, walker.global_position.z)
	var speed := float(game.get_node("Combat").get("weapon_data")["player"]["runSpeed"])
	var can_chase := float(game.get("player_respawn")) <= 0.0 and current.distance_to(player) <= CHASE_RANGE \
		and _can_see_player()
	chasing = false
	if can_chase and current.distance_to(player) > CHASE_STOP:
		var step := current.move_toward(player, speed * delta)
		var candidate := Vector3(step.x, global_position.y, step.y)
		if _safe_chase_step(candidate):
			if chase_trail.is_empty() or global_position.distance_to(chase_trail.back()) >= 0.5:
				chase_trail.append(global_position)
			candidate.y = float(_ground_at(candidate)["position"].y) + 0.05
			global_position = candidate
			chasing = true
	elif can_chase:
		chasing = true
	if not chasing:
		if not chase_trail.is_empty():
			returning = true
			_return_step(speed * delta)
		else:
			returning = false
			var target: Vector2 = WAYPOINTS[waypoint_index]
			var movement := target - current
			if movement.length() <= speed * delta:
				current = target
				waypoint_index = (waypoint_index + 1) % WAYPOINTS.size()
			else:
				current += movement.normalized() * speed * delta
			var next := Vector3(current.x, global_position.y, current.y)
			var patrol_floor := _ground_at(next)
			if not patrol_floor.is_empty():
				next.y = float(patrol_floor["position"].y) + 0.05
			global_position = next
	else:
		returning = false
	var facing := global_position - old_position
	if facing.length_squared() > 0.0001:
		$Body.rotation.y = atan2(facing.x, facing.z)
	var floor_hit := _ground_at(global_position)
	paint_cooldown = maxf(0.0, paint_cooldown - delta)
	if paint_cooldown <= 0.0 and not floor_hit.is_empty():
		paint_cooldown = PAINT_INTERVAL
		game.call("paint_at_world", global_position + Vector3.UP * 0.12, 1, 0.9, randf())
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if float(game.get("player_respawn")) <= 0.0 and attack_cooldown <= 0.0 \
		and global_position.distance_to(walker.global_position) < ATTACK_RANGE and _can_see_player():
		attack_cooldown = ATTACK_INTERVAL
		_show_attack()
		game.call("damage_player", 18.0)
		game.call("paint_at_world", walker.global_position + Vector3.UP * 0.2, 1, 0.8, randf())


func _build_feedback() -> void:
	health_bar = Node3D.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector3(0.0, 1.75, 0.0)
	add_child(health_bar)
	var backing := MeshInstance3D.new()
	backing.name = "Backing"
	var backing_mesh := BoxMesh.new()
	backing_mesh.size = Vector3(0.78, 0.12, 0.025)
	backing.mesh = backing_mesh
	backing.material_override = _flat_material(Color("17203a"))
	health_bar.add_child(backing)
	health_fill = MeshInstance3D.new()
	health_fill.name = "Fill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.70, 0.065, 0.035)
	health_fill.mesh = fill_mesh
	health_fill.position.z = 0.018
	health_fill.material_override = _flat_material(Color("6ca8ff"))
	health_bar.add_child(health_fill)
	attack_tracer = MeshInstance3D.new()
	attack_tracer.name = "BotAttackTracer"
	attack_tracer_mesh = BoxMesh.new()
	attack_tracer.mesh = attack_tracer_mesh
	attack_tracer.material_override = _flat_material(Color("79b9ff"))
	attack_tracer.visible = false
	game.add_child(attack_tracer)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _update_health_visual() -> void:
	var max_health := float(game.get_node("Combat").get("weapon_data")["player"]["hp"])
	var fraction := clampf(float(game.get("bot_health")) / max_health, 0.0, 1.0)
	health_fill.scale.x = maxf(0.001, fraction)
	health_fill.position.x = (fraction - 1.0) * 0.35
	var camera: Camera3D = walker.get_node("Camera3D")
	health_bar.look_at(camera.global_position, Vector3.UP)


func _show_attack() -> void:
	var from := global_position + Vector3.UP * 1.1
	var to := walker.global_position + Vector3.UP * 1.0
	var length := from.distance_to(to)
	if length < 0.01:
		return
	attack_tracer_mesh.size = Vector3(0.055, 0.055, length)
	attack_tracer.global_position = (from + to) * 0.5
	attack_tracer.look_at(to, Vector3.UP)
	attack_tracer.visible = true
	attack_visual_time = 0.14


func _return_step(distance: float) -> void:
	var previous: Vector3 = chase_trail.back()
	var current := Vector2(global_position.x, global_position.z)
	var target := Vector2(previous.x, previous.z)
	var step := current.move_toward(target, distance)
	var candidate := Vector3(step.x, global_position.y, step.y)
	if not _safe_chase_step(candidate):
		return
	candidate.y = float(_ground_at(candidate)["position"].y) + 0.05
	global_position = candidate
	if step.distance_to(target) < 0.05:
		chase_trail.pop_back()


func _safe_chase_step(candidate: Vector3) -> bool:
	var floor_hit := _ground_at(candidate)
	if floor_hit.is_empty() or float(floor_hit["normal"].y) < 0.7:
		return false
	var next_y := float(floor_hit["position"].y) + 0.05
	if absf(next_y - global_position.y) > 0.65:
		return false
	candidate.y = next_y
	var halfway := global_position.lerp(candidate, 0.5)
	var middle_floor := _ground_at(halfway)
	if middle_floor.is_empty() or float(middle_floor["normal"].y) < 0.7 \
		or absf(float(middle_floor["position"].y) + 0.05 - halfway.y) > 0.65:
		return false
	var horizontal := Vector3(candidate.x - global_position.x, 0.0, candidate.z - global_position.z)
	if horizontal.length_squared() < 0.0001:
		return true
	var lateral := Vector3(-horizontal.z, 0.0, horizontal.x).normalized() * BODY_RADIUS
	for offset in [Vector3.ZERO, lateral, -lateral]:
		var start: Vector3 = global_position + Vector3.UP * 0.75 + offset
		var finish: Vector3 = candidate + Vector3.UP * 0.75 + offset
		if not get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(start, finish, 1)).is_empty():
			return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _body_shape
	query.collision_mask = 1
	query.transform = Transform3D(Basis(), candidate + Vector3.UP * 0.75)
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	return true


func _ground_at(at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 5.0, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _can_see_player() -> bool:
	var from := global_position + Vector3.UP
	var to := walker.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
