extends Node3D

const Difficulty := preload("res://src/core/bot_difficulty.gd")
const TeamPalette := preload("res://src/core/team_palette.gd")

# Tidewater 1v1 opponent. Patrol the clear right lane, pursue a visible nearby
# player only when a body-width path stays on walkable ground, and paint the
# same authoritative surface grid used by the player and judge.
const WAYPOINTS := [
	Vector2(0.0, 31.0), Vector2(12.0, 31.0),
	Vector2(12.0, 13.0), Vector2(8.0, 8.0), Vector2(8.0, -10.0),
	Vector2(8.0, 8.0), Vector2(12.0, 13.0), Vector2(12.0, 31.0),
]
const PAINT_INTERVAL := 0.22
const ROLLER_FLICK_RANGE := 8.0
const CHASE_RANGE := 13.0
const BODY_RADIUS := 0.34

var team_mover: CharacterBody3D
var team := 1
var slot := 0
var health := 100.0
var respawn_time := 0.0
var invuln := 0.0
var last_damage := 99.0
var ink_damage := 0.0
var route := PackedVector3Array()
var route_index := 0
var repath_time := 0.0
var route_purpose := ""
var jump_time := 0.0
var jumps_started := 0
var reaction_target: Node3D
var reaction_time := 0.0
var strafe_sign := 1.0
var strafe_time := 0.0
var blocked_time := 0.0
var recovery_time := 0.0
var recovery_direction := Vector3.ZERO
var target_actor: Node3D
var game: Node3D
var walker: CharacterBody3D
var map: Node3D
var waypoint_index := 0
var paint_cooldown := 0.0
var attack_cooldown := 0.0
var roll_hit_cooldown := 0.0
var roll_distance := 0.0
var charge_time := 0.0
var weapon_id := "shooter"
var ink_amount := 100.0
var last_fire_time := 99.0
var ink_brain := preload("res://src/actors/tidewater_bot_ink.gd").new()
var chasing := false
var returning := false
var chase_trail: Array[Vector3] = []
var _body_shape: SphereShape3D
var health_bar: Node3D
var identity_label: Label3D
var health_fill: MeshInstance3D
var attack_tracer: MeshInstance3D
var attack_tracer_mesh: BoxMesh
var attack_visual_time := 0.0


func setup(owner: Node3D, player: CharacterBody3D, level: Node3D) -> void:
	game = owner
	walker = player
	map = level
	$Body.call("configure_animation", game.get_node("Combat").get("weapon_data")["player"])
	_body_shape = SphereShape3D.new()
	_body_shape.radius = BODY_RADIUS
	team_mover = CharacterBody3D.new()
	team_mover.name = "TeamMover"
	team_mover.collision_layer = 4
	team_mover.collision_mask = 9
	team_mover.floor_snap_length = 0.35
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = float(game.get_node("Combat").get("weapon_data")["player"]["height"])
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	team_mover.add_child(shape)
	add_child(team_mover)
	_build_feedback()
	reset()


func reset() -> void:
	var pads: Array = map.get("spawn_pads")
	global_position = pads[team] as Vector3
	if game.has_method("team_mode") and bool(game.call("team_mode")):
		global_position += Vector3([0.0,-0.8,0.8,-1.6,1.6][slot], 0.05, 0.0)
	if team_mover != null:
		team_mover.position = Vector3.ZERO
		team_mover.velocity = Vector3.ZERO
	reaction_target = null
	reaction_time = 0.0
	blocked_time = 0.0
	recovery_time = 0.0
	route.clear()
	route_purpose = ""
	repath_time = 0.0
	jump_time = 0.0
	waypoint_index = 0
	paint_cooldown = 0.0
	attack_cooldown = 0.0
	roll_hit_cooldown = 0.0
	roll_distance = 0.0
	charge_time = 0.0
	var player_config: Dictionary = game.get_node("Combat").get("weapon_data")["player"]
	ink_amount = float(game.call("actor_ink_max",self)) if game.has_method("actor_ink_max") else float(player_config["inkMax"])
	last_fire_time = 99.0
	ink_brain.reset()
	set_meta("friendly_swimming",false)
	set_meta("enemy_swimming",false)
	$Body.set_form(false)
	if team_mover != null:
		var shape:CollisionShape3D=team_mover.get_child(0)
		shape.shape.radius=BODY_RADIUS;shape.shape.height=float(player_config.height)
		shape.position.y=shape.shape.height*.5
	chasing = false
	returning = false
	chase_trail.clear()
	visible = true
	$Body.call("set_weapon", weapon_id)
	clear_attack_visual()
	_update_health_visual()


func select_weapon(id: String) -> bool:
	if not game.get_node("Combat").get("weapons").has(id):
		return false
	var combat: Node3D = game.get_node("Combat")
	if game.bot_specials != null:
		var meter: Dictionary = game.bot_specials.state(self)
		if not meter.is_empty():
			var fraction := float(meter.points) / float(combat.weapons[weapon_id].specialCost)
			game.bot_specials.on_death(self)
			meter.points = clampf(fraction,0,1) * float(combat.weapons[id].specialCost)
	weapon_id = id
	attack_cooldown = 0.0
	charge_time = 0.0
	roll_distance = 0.0
	$Body.call("set_weapon", id)
	return true


func clear_attack_visual() -> void:
	attack_visual_time = 0.0
	if attack_tracer != null:
		attack_tracer.visible = false


func _weapon_reach(weapon: Dictionary) -> float:
	if String(weapon["kind"]) == "roller":
		return ROLLER_FLICK_RANGE
	return float(weapon.get("rangeMax", weapon.get("range", 5.5)))


func _engagement_distance(weapon: Dictionary) -> float:
	if String(weapon["kind"]) == "roller":
		return 0.75 if team_mover != null else 0.9
	# Leave room inside the effective range for aim height and moving targets.
	return _weapon_reach(weapon) * (0.65 if String(weapon["kind"]) in ["charger", "bow"] else 0.55)


func tick(delta: float) -> void:
	if team_mover != null:
		_tick_team(delta)
		return
	var combat: Node3D = game.get_node("Combat")
	var player_config: Dictionary = combat.get("weapon_data")["player"]
	var weapon: Dictionary = game.perks.weapon(self,combat.get("weapons")[weapon_id])
	game.perks.bot_form(self, _can_see_player() and global_position.distance_to(walker.global_position) < _weapon_reach(weapon))
	game.mobility.consider_bot_roll(self, walker if game.player_respawn <= 0 and _can_see_player() else null)
	last_fire_time += delta
	$Body.call("set_expression_state",ink_amount/float(game.call("actor_ink_max",self)),float(game.call("actor_health",self))/float(game.call("actor_max_health",self)),charge_time/maxf(0.01,float(weapon.get("chargeTime",1.0))),false)
	if not bool(get_meta("enemy_swimming", false)) and charge_time <= 0.0 and last_fire_time > float(player_config["inkRefillDelay"]):
		ink_amount = minf(float(game.call("actor_ink_max",self)), ink_amount + float(player_config["inkRefillKid"]) * game.perks.refill(self) * delta)
	roll_hit_cooldown = maxf(0.0, roll_hit_cooldown - delta)
	attack_visual_time = maxf(0.0, attack_visual_time - delta)
	attack_tracer.visible = attack_visual_time > 0.0
	_update_health_visual()
	var old_position := global_position
	var current := Vector2(global_position.x, global_position.z)
	var player := Vector2(walker.global_position.x, walker.global_position.z)
	var speed := float(weapon["rollSpeed"]) if weapon_id == "roller" and ink_amount > 0.5 else float(player_config["runSpeed"])
	speed = minf(game.perks.travel_speed(self, speed) * game.perks.movement(self)*game.perks.vault_factor(self)*game.items.move_factor(self), combat.counter.move_limit(self))
	var chase_stop := _engagement_distance(weapon)
	var can_chase := float(game.get("player_respawn")) <= 0.0 and current.distance_to(player) <= maxf(CHASE_RANGE, _weapon_reach(weapon)) \
		and _can_see_player()
	chasing = false
	if game.mobility.rolling(self):
		var next: Vector3 = global_position + game.mobility.velocity_for(self) * delta
		if _safe_chase_step(next):
			next.y = float(_ground_at(next).position.y) + 0.05
			global_position = next
		chasing = true
	elif game.mobility.recovering(self):
		chasing = true
	elif can_chase and current.distance_to(player) > chase_stop:
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
				# Keep the whole body above a deck edge until its trailing radius clears.
				# Slower random roller kits can step across the edge by < BODY_RADIUS.
				var trailing := next-Vector3(movement.x,0,movement.y).normalized()*BODY_RADIUS
				trailing.y = old_position.y
				var back := _ground_at(trailing)
				if not back.is_empty():
					next.y = maxf(next.y,float(back["position"].y)+0.05)
			global_position = next
	else:
		returning = false
	var facing := global_position - old_position
	if facing.length_squared() > 0.0001:
		$Body.rotation.y = atan2(facing.x, facing.z)
	var floor_hit := _ground_at(global_position)
	paint_cooldown = maxf(0.0, paint_cooldown - delta)
	if weapon_id == "roller":
		_update_roll(delta, old_position, weapon, combat)
	elif not bool(get_meta("enemy_swimming", false)) and paint_cooldown <= 0.0 and not floor_hit.is_empty():
		paint_cooldown = PAINT_INTERVAL
		game.call("paint_at_world", global_position + Vector3.UP * 0.12, 1, 0.9, randf())
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var distance := global_position.distance_to(walker.global_position)
	var attack_range := _weapon_reach(weapon)
	var can_attack: bool = not game.mobility.busy(self) and not game.bot_specials.busy(self) and float(game.get("player_respawn")) <= 0.0 and distance < attack_range and _can_see_player()
	var target_height := 0.3 if bool(walker.get("squid_form")) else 1.0
	var target := walker.global_position + Vector3.UP * target_height
	var aim_vector := target - (global_position + Vector3.UP * 1.05)
	$Body.set_aim(can_attack)
	$Body.set_weapon_pose(atan2(aim_vector.y, Vector2(aim_vector.x, aim_vector.z).length()) if can_attack else 0.0, weapon_id == "roller" and chasing)
	match String(weapon["kind"]):
		"disc":
			if can_attack and attack_cooldown <= 0 and combat.discs.throw_primary(self, target): attack_cooldown = float(weapon.fireInterval)
		"shooter", "blaster":
			if can_attack and attack_cooldown <= 0.0 and ink_amount >= float(weapon["inkPerShot"]):
				attack_cooldown = float(weapon["fireInterval"])
				ink_amount -= float(weapon["inkPerShot"])
				last_fire_time = 0.0
				_show_attack()
				combat.call("spawn_bot_shot", global_position + Vector3.UP * 1.05, target, weapon_id,team,self)
		"charger":
			if can_attack and attack_cooldown <= 0.0 and ink_amount >= float(weapon["inkFull"]):
				charge_time += delta
				if charge_time >= float(weapon["chargeTime"]):
					charge_time = 0.0
					attack_cooldown = 0.28
					ink_amount -= float(weapon["inkFull"])
					last_fire_time = 0.0
					_show_attack()
					combat.call("fire_bot_charger", global_position + Vector3.UP * 1.05, target,1.0,team,self)
			else:
				charge_time = 0.0
		"roller":
			if can_attack and distance > 1.5 and attack_cooldown <= 0.0 \
					and ink_amount >= float(weapon["flickInk"]):
				attack_cooldown = float(weapon["flickInterval"])
				ink_amount -= float(weapon["flickInk"])
				last_fire_time = 0.0
				_show_attack()
				combat.call("spawn_bot_flick", global_position + Vector3.UP * 1.3, target,team,self)


func _update_roll(delta: float, old_position: Vector3, weapon: Dictionary,
		combat: Node3D) -> void:
	var movement := global_position - old_position
	movement.y = 0.0
	var distance := movement.length()
	if distance <= 0.001 or ink_amount <= 0.5:
		return
	var forward := movement.normalized()
	ink_amount = maxf(0.0, ink_amount - float(weapon["rollInkPerMeter"]) * distance)
	last_fire_time = 0.0
	roll_distance += distance
	if roll_distance >= 0.28:
		roll_distance = fmod(roll_distance, 0.28)
		combat.call("paint_bot_roll", global_position, forward, team)
	if roll_hit_cooldown > 0.0 or distance / maxf(delta, 0.0001) <= 1.0:
		return
	for victim in game.enemies(team):
		var offset: Vector3 = victim.global_position - global_position
		var ahead: float = offset.x * forward.x + offset.z * forward.z
		var lateral := absf(offset.x * forward.z - offset.z * forward.x)
		if ahead > -0.2 and ahead < 1.35 and lateral < float(weapon.rollWidth) * 0.5 + 0.35 and absf(offset.y) < 1.2 and combat._unblocked(global_position + Vector3.UP * 0.5, victim.global_position + Vector3.UP * 0.5):
			roll_hit_cooldown = 0.5
			game.damage_actor(victim, float(weapon.rollDamage), team, self, "roller")


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
	health_fill.material_override = _flat_material(TeamPalette.color(team).lightened(0.25))
	health_bar.add_child(health_fill)
	backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	health_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	identity_label = Label3D.new()
	identity_label.name = "ActorIdentity"
	identity_label.font = load("res://assets/fonts/TitanOne-latin.woff2") as Font
	identity_label.position = Vector3(0, 0.18, 0.035)
	identity_label.font_size = 32
	identity_label.pixel_size = 0.005
	identity_label.outline_size = 8
	identity_label.modulate = TeamPalette.color(team).lightened(0.65)
	health_bar.add_child(identity_label)
	attack_tracer = MeshInstance3D.new()
	attack_tracer.name = "BotAttackTracer" if name == "Bot" else "%sAttackTracer" % name
	attack_tracer_mesh = BoxMesh.new()
	attack_tracer.mesh = attack_tracer_mesh
	attack_tracer.material_override = _flat_material(TeamPalette.color(team).lightened(0.3))
	attack_tracer.visible = false
	game.add_child(attack_tracer)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _update_health_visual() -> void:
	var max_health := float(game.call("actor_max_health",self)) if game.has_method("actor_max_health") else float(game.get_node("Combat").get("weapon_data")["player"]["hp"])
	var fraction := clampf((float(game.call("actor_health", self)) if game.has_method("actor_health") else float(game.get("bot_health"))) / max_health, 0.0, 1.0)
	health_fill.scale.x = maxf(0.001, fraction)
	health_fill.position.x = (fraction - 1.0) * 0.35
	var id := int(game.call("actor_id", self)) if game.has_method("actor_id") else team * 5 + slot + 1
	var actor_label := String(game.call("actor_name",self)) if game.has_method("actor_name") else String(get_meta("actor_name","Ink"))
	identity_label.text = "#%02d %s" % [id,actor_label]
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		camera = walker.get_node("Camera3D")
	# The fill sits on +Z, so +Z must face the camera. Default look_at uses -Z.
	var toward := camera.global_position - health_bar.global_position
	if toward.length_squared() > 0.001:
		health_bar.look_at(camera.global_position, Vector3.RIGHT if absf(toward.normalized().y) > 0.99 else Vector3.UP, true)


func _show_attack(target: Vector3 = Vector3.INF, preaim:bool=false) -> void:
	var from := global_position + Vector3.UP * 1.1
	var to := target if target.is_finite() else walker.global_position + Vector3.UP * 1.0
	var ray:=PhysicsRayQueryParameters3D.create(from,to,game.get_node("Combat").world_mask(team))
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():to=hit.position
	if weapon_id!="charger" and not preaim:to=from+(to-from).limit_length(1.6)
	var length := from.distance_to(to)
	if length < 0.01:
		return
	attack_tracer_mesh.size = Vector3(.035 if preaim else .085,.035 if preaim else .085,length)
	attack_tracer.global_position = (from + to) * 0.5
	var up := Vector3.RIGHT if absf((to - from).normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
	attack_tracer.look_at(to, up)
	attack_tracer.visible = true
	attack_visual_time = .08 if preaim else .22


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


func floor_ink_owner() -> int:
	return ink_owner_at(global_position)


func ink_owner_at(at: Vector3) -> int:
	var config: Dictionary = game.get_node("Combat").weapon_data.player
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * (float(config.stepUp)+.02),at-Vector3.UP*float(config.stepDown),9))
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.6 \
			or not bool(hit.collider.get_meta("paintable",false)):
		return -1
	var block_id := int((hit["collider"] as Object).get_meta("source_id", -1))
	if block_id < 0:
		return -1
	var face: Dictionary = map.call("find_surface", hit["position"], hit["normal"], block_id)
	if face.is_empty():
		return -1
	var relative: Vector3 = hit["position"] - _vector(face["origin"])
	return int(game.get("ink").call("owner_at", int(face["id"]),
		relative.dot(_vector(face["u"])), relative.dot(_vector(face["v"]))))


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _can_see_player() -> bool:
	if game.intel != null: return game.intel.can_see(self, walker)
	var from := global_position + Vector3.UP
	var to := walker.global_position + Vector3.UP * (0.3 if bool(walker.get("squid_form")) else 1.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _tick_team(delta: float) -> void:
	var combat: Node3D = game.get_node("Combat")
	var config: Dictionary = combat.get("weapon_data")["player"]
	roll_hit_cooldown = maxf(0, roll_hit_cooldown - delta)
	var profile := Difficulty.profile(game.ai_level)
	var weapon: Dictionary = combat.weapon_specials.modify_weapon(self,game.perks.weapon(self,combat.get("weapons")[weapon_id]))
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	$Body.call("set_expression_state",ink_amount/float(game.call("actor_ink_max",self)),float(game.call("actor_health",self))/float(game.call("actor_max_health",self)),charge_time/maxf(0.01,float(weapon.get("chargeTime",1.0))),false)
	attack_visual_time = maxf(0.0, attack_visual_time - delta)
	attack_tracer.visible = attack_visual_time > 0.0
	last_fire_time += delta
	_update_health_visual()
	# Visibility and opponent selection belong to each bot, never to the local player alone.
	target_actor = null
	var best := maxf(CHASE_RANGE, _weapon_reach(weapon))
	for enemy in game.call("enemies", team):
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best and _visible_actor(enemy):
			best = distance
			target_actor = enemy
	if target_actor != reaction_target:
		reaction_target = target_actor
		reaction_time = float(profile.reaction)
	reaction_time = maxf(0,reaction_time-delta)
	var lure: Dictionary = game.items.decoys.target_for(self,best)
	if not lure.is_empty():
		target_actor = null; best = global_position.distance_to(lure.point)
		if int(get_meta("decoy_target",0)) != int(lure.id): game.items.decoys.fooled_total += 1
	set_meta("decoy_target",int(lure.id) if not lure.is_empty() else 0)
	var threat:Dictionary=game.items.buddies.threat_for(self,best)
	if not threat.is_empty():
		target_actor=null;lure=threat;best=global_position.distance_to(threat.point);set_meta("decoy_target",0)
	set_meta("buddy_target",int(threat.get("id",0)))
	var fighting := target_actor != null or not lure.is_empty()
	var resupply: Dictionary = game.items.supply.destination(self) if not fighting and ink_amount <= 45 else {}
	var escape: Vector3 = game.get("bot_specials").call("escape",self)
	var refill_plan: Dictionary = ink_brain.plan(self,delta) if escape == Vector3.ZERO else {}
	var refilling := not refill_plan.is_empty()
	if refilling:
		fighting = false
		resupply = {}
		charge_time = 0
	chasing = fighting
	returning = false
	game.perks.bot_form(self, fighting or not resupply.is_empty() or refilling,bool(refill_plan.get("swim",false)))
	if bool(get_meta("friendly_swimming",false)):
		ink_amount = minf(float(game.actor_ink_max(self)),ink_amount+float(config.inkRefillSwim)*game.perks.refill(self)*delta)
	elif charge_time <= 0 and not combat.canopy.holding(self) and not game.bot_specials.locks_primary(self) and not game.wings.busy(self) and not game.perks.bot_swimming(self) and last_fire_time > float(config.inkRefillDelay):
		ink_amount = minf(float(game.actor_ink_max(self)),ink_amount+float(config.inkRefillKid)*game.perks.refill(self)*delta)
	if not refilling:game.mobility.consider_bot_roll(self, target_actor)
	if escape!=Vector3.ZERO:
		target_actor = null; lure = {}; resupply = {}; fighting = false; set_meta("decoy_target",0)
	repath_time -= delta
	var contact: Dictionary = game.intel.nearest_contact(self)
	var purpose := "patrol"
	if escape != Vector3.ZERO: purpose = "escape"
	elif refilling: purpose = "ink"
	elif not lure.is_empty(): purpose = ("buddy:%d" if lure.get("buddy",false) else "decoy:%d") % int(lure.id)
	elif target_actor != null: purpose = "enemy:%d" % game.actor_id(target_actor)
	elif not resupply.is_empty(): purpose = "supply:%d" % int(resupply.id)
	elif not contact.is_empty(): purpose = "contact"
	var refill_path: PackedVector3Array = refill_plan.get("route",PackedVector3Array())
	if jump_time <= 0.0 and (repath_time <= 0.0 or route_index >= route.size() or purpose != route_purpose or (refilling and refill_path != route)):
		var nav: RefCounted = game.get("navigation")
		if escape != Vector3.ZERO: route = nav.route(global_position, global_position + escape, team)
		elif refilling: route = refill_plan.get("route",PackedVector3Array())
		elif not lure.is_empty(): route = nav.route(global_position,lure.point,team)
		elif target_actor != null: route = nav.route(global_position, target_actor.global_position, team)
		elif not resupply.is_empty(): route = nav.route(global_position,resupply.point,team)
		elif not contact.is_empty(): route = nav.route(global_position, contact.point, team)
		elif route_purpose == "patrol" and route_index < route.size():
			# Refresh the path to the same objective. A periodic path query must
			# not reroll the destination and turn around halfway up a ramp.
			route = nav.route(global_position, route[-1], team)
		else: route = nav.patrol(global_position, team, slot)
		route_purpose = purpose
		route_index = 1 if route.size() > 1 else 0
		repath_time = float(profile.repath) * randf_range(.9,1.2)
	var old := global_position
	var travel := Vector3.ZERO
	var jump_edge := false
	if not bool(refill_plan.get("stop",false)) and route_index < route.size() and (not fighting or best > _engagement_distance(weapon)) and (resupply.is_empty() or global_position.distance_to(resupply.point) > 1.2):
		var next := route[route_index]
		var offset := next - global_position
		var horizontal := Vector3(offset.x,0.0,offset.z)
		if horizontal.length() < 0.3 and absf(offset.y) < 0.4:
			route_index += 1
		else:
			var speed := float(weapon["rollSpeed"]) if weapon_id == "roller" and ink_amount > 1.0 else float(config["runSpeed"])
			speed = minf(game.perks.travel_speed(self, speed) * game.perks.movement(self)*game.perks.vault_factor(self)*game.items.move_factor(self), combat.counter.move_limit(self))
			travel = horizontal.normalized() * minf(speed, horizontal.length() / maxf(delta,0.001))
			if route_index > 0 and jump_time <= 0.0:
				var transition:=String(game.get("navigation").call("transition",route[route_index-1],next,team))
				# Source walk edges allow 0.5m rises, but the collision body cannot
				# step sideways through a ramp's vertical edge. Hop these small lips.
				jump_edge = transition in ["jump","walk"] and offset.y > 0.4 and horizontal.length() < 2.5
	# Visible in-range enemies still permit collision-safe lateral movement.
	# Chargers/bows slow while drawing; easier AI moves more slowly.
	strafe_time -= delta
	if strafe_time <= 0:
		strafe_time = 1.5
		strafe_sign = -strafe_sign
	if fighting and best <= _engagement_distance(weapon) and float(profile.strafe) > 0 and weapon_id != "roller":
		var focus: Vector3 = lure.point if not lure.is_empty() else target_actor.global_position
		var facing := Vector3(focus.x-global_position.x,0,focus.z-global_position.z).normalized()
		var side := facing.cross(Vector3.UP) * strafe_sign
		travel = _safe_combat_step(side, float(profile.strafe) * (.55 if charge_time > 0 else 1.0))
		if travel == Vector3.ZERO:
			strafe_sign = -strafe_sign
			travel = _safe_combat_step(-side,float(profile.strafe))
	if recovery_time > 0 and not bool(refill_plan.get("stop",false)):
		recovery_time -= delta
		travel = _safe_combat_step(recovery_direction,2.0)
	# A collision body owns support, walls and gravity; the source graph can include
	# drop edges without teleporting through geometry or refusing every ledge.
	if game.mobility.rolling(self):
		travel = game.mobility.velocity_for(self)
		jump_edge = false
	elif game.mobility.recovering(self):
		travel = Vector3.ZERO
		jump_edge = false
	if game.wings.busy(self): travel = travel.limit_length(7.0)
	var was_on_floor := team_mover.is_on_floor()
	team_mover.global_position = global_position
	team_mover.velocity.x = travel.x
	team_mover.velocity.z = travel.z
	jump_time = maxf(0.0,jump_time-delta)
	if game.wings.busy(self):
		team_mover.velocity.y = game.wings.vertical(self,delta)
	elif jump_edge and team_mover.is_on_floor():
		team_mover.velocity.y = float(config["jumpVel"])
		jump_time = 0.8
		set_meta("vault_origin",global_position.y)
		jumps_started += 1
		$Body.call("set_reaction","jump")
	elif team_mover.is_on_floor():
		team_mover.velocity.y = -0.5
	else:
		var gravity := float(config["gravity"])
		if team_mover.velocity.y < 0.0:
			gravity *= float(config["fallGravityMul"])
		if absf(team_mover.velocity.y) < float(config["apexBand"]):
			gravity *= float(config["apexGravityMul"])
		team_mover.velocity.y = maxf(-float(config["maxFall"]),team_mover.velocity.y-gravity*delta)
	team_mover.move_and_slide()
	global_position = team_mover.global_position
	if not was_on_floor and team_mover.is_on_floor() and has_meta("vault_origin"):
		if global_position.y > float(get_meta("vault_origin"))+.25: game.perks.on_vault(self)
		remove_meta("vault_origin")
	team_mover.position = Vector3.ZERO
	if jump_time <= 0.0 and travel.length_squared() > 0.01 and global_position.distance_to(old) < delta * 0.15:
		blocked_time += delta
		if blocked_time > 1.1:
			# Step aside, then retry the route; never teleport through a wall.
			recovery_direction = travel.normalized().cross(Vector3.UP) * strafe_sign
			recovery_time = .65
			repath_time = 0.0
			blocked_time = 0
	else:
		blocked_time = 0
	var movement := global_position - old
	var aim: Vector3 = lure.point-global_position if not lure.is_empty() else target_actor.global_position-global_position if target_actor != null else movement
	if aim.length_squared() > 0.001:
		$Body.rotation.y = lerp_angle($Body.rotation.y, atan2(aim.x, aim.z), minf(delta * 9.0, 1.0))
	$Body.call("set_aim", fighting)
	$Body.call("set_weapon_pose", atan2(aim.y, Vector2(aim.x, aim.z).length()) if fighting else 0.0, weapon_id == "roller" and travel.length_squared() > 0.1)
	$Body.set_weapon_charge(charge_time/maxf(.01,float(weapon.get("chargeTime",1))))
	paint_cooldown -= delta
	if weapon_id == "roller" and not refilling and not game.perks.bot_swimming(self): _update_roll(delta, old, weapon, combat)
	if weapon_id != "roller" and not refilling and not game.perks.bot_swimming(self) and movement.length() > 0.001 and ink_amount > 1.0 and paint_cooldown <= 0.0:
		paint_cooldown = PAINT_INTERVAL
		game.call("paint_at_world", global_position + Vector3.UP * 0.12, team, 0.8, randf())
		ink_amount = maxf(0.0, ink_amount - 0.6)
	if weapon_id=="canopy":
		var candidate: Node3D = null if refilling else lure.visual if not lure.is_empty() else target_actor
		combat.canopy.bot_input(self,delta,candidate if not game.mobility.busy(self) and not game.bot_specials.locks_primary(self) and reaction_time <= 0 else null)
		return
	if not fighting or game.mobility.busy(self) or game.bot_specials.locks_primary(self) or reaction_time > 0:
		charge_time = 0.0
		return
	var from := global_position + Vector3.UP * 1.05
	var target: Vector3 = (lure.point if not lure.is_empty() else target_actor.global_position)+Vector3.UP*(.35 if lure.get("buddy",false) else .8)
	target = Difficulty.aim(from,target,game.ai_level)
	var attack_range := _weapon_reach(weapon)
	if from.distance_to(target) > attack_range or attack_cooldown > 0.0:
		return
	match String(weapon["kind"]):
		"disc":
			if combat.discs.throw_primary(self, target): attack_cooldown = float(weapon.fireInterval) * float(profile.cadence)
		"shooter", "blaster":
			if ink_amount < float(weapon["inkPerShot"]):
				return
			ink_amount -= float(weapon["inkPerShot"])
			attack_cooldown = float(weapon["fireInterval"]) * float(profile.cadence)
			combat.call("spawn_bot_shot", from, target, weapon_id, team,self)
		"bow":
			if ink_amount<float(weapon.inkMin): return
			var draw:float=combat.bow.bot_charge(self,target)
			charge_time+=delta
			if charge_time<float(weapon.chargeTime)*draw: return
			charge_time=0
			if combat.bow.fire(self,target,draw): attack_cooldown=lerpf(float(weapon.releaseMin),float(weapon.releaseFull),draw)*float(profile.cadence)
		"charger":
			if ink_amount < float(weapon["inkFull"]):
				return
			charge_time += delta
			if charge_time < float(weapon["chargeTime"]):
				_show_attack(target,true)
				return
			charge_time = 0.0
			ink_amount -= float(weapon["inkFull"])
			attack_cooldown = 0.28 * float(profile.cadence)
			combat.call("fire_bot_charger", from, target, 1.0, team,self)
		"roller":
			if ink_amount < float(weapon["flickInk"]):
				return
			ink_amount -= float(weapon["flickInk"])
			attack_cooldown = float(weapon["flickInterval"]) * float(profile.cadence)
			combat.call("spawn_bot_flick", from, target, team,self)
	last_fire_time = 0.0
	$Body.call("set_action", "flick" if weapon_id == "roller" else "shoot")
	_show_attack(target)


func _visible_actor(actor: Node3D) -> bool:
	if game.intel != null: return game.intel.can_see(self, actor)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, actor.global_position + Vector3.UP * 0.8, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _safe_combat_step(direction: Vector3, speed: float) -> Vector3:
	var at := global_position + direction * .75
	var checked: Dictionary = game.deployment.landing(Vector2(at.x,at.z),false,global_position.y,team,self)
	if checked.is_empty(): return Vector3.ZERO
	return direction * minf(speed*game.perks.movement(self)*game.perks.vault_factor(self)*game.items.move_factor(self),combat_move_limit())

func combat_move_limit() -> float:
	return game.get_node("Combat").counter.move_limit(self)
