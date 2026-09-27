extends Node3D

# Source-configured weapon cores, bomb and two specials for the 1v1 demo.
# Projectiles hit map collision and the visible bot; detailed effects are simplified.
const PROJECTILE_COLORS := [Color("ff8a14"), Color("2f5bff")]

var game: Node3D
var walker: CharacterBody3D
var weapon_data: Dictionary = {}
var weapons: Dictionary = {}
var selected_id := "shooter"
var ink_amount := 100.0
var refill_wait := 0.0
var cooldown := 0.0
var charge_time := 0.0
var charge_fraction := 0.0
var charging := false
var flick_time := -1.0
var rolling := false
var last_fire := false
var last_sub := false
var aiming_sub := false
var last_roll_position := Vector3.ZERO
var projectiles: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var bombs: Array[Dictionary] = []
var storm_bombs: Array[Dictionary] = []
var clouds: Array[Dictionary] = []
var special_points := 0.0
var special_active := ""
var special_time := 0.0


func special_cost() -> float:
	return float(weapons[selected_id]["specialCost"])


func special_ready() -> bool:
	return special_points >= special_cost() and special_active.is_empty()


func special_fraction() -> float:
	return clampf(special_points / special_cost(), 0.0, 1.0)


func _add_turf(area: float) -> void:
	if area > 0.0 and special_active.is_empty():
		special_points = minf(special_cost(), special_points + area)


func _paint_player(at: Vector3, radius: float, seed: float) -> float:
	var area := float(game.call("paint_at_world", at, 0, radius, seed))
	_add_turf(area)
	return area


func setup(owner: Node3D, avatar: CharacterBody3D) -> void:
	game = owner
	walker = avatar
	weapon_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons.json"))
	weapons = weapon_data["weapons"]
	ink_amount = float(weapon_data["player"]["inkMax"])
	last_roll_position = walker.global_position


func select_weapon(weapon_id: String) -> bool:
	if not weapons.has(weapon_id):
		return false
	selected_id = weapon_id
	walker.get_node("Body").call("set_weapon", weapon_id)
	charging = false
	charge_time = 0.0
	charge_fraction = 0.0
	flick_time = -1.0
	rolling = false
	cooldown = 0.0
	aiming_sub = false
	last_sub = false
	return true


func on_death() -> void:
	special_points *= 0.5
	special_active = ""
	special_time = 0.0
	walker.call("cancel_slam")
	charging = false
	charge_time = 0.0
	charge_fraction = 0.0
	flick_time = -1.0
	rolling = false
	last_fire = false
	last_sub = false
	aiming_sub = false
	walker.set("firing_speed_limit", INF)


func advance_effects(delta: float) -> void:
	_update_projectiles(delta)
	_update_beams(delta)
	_update_bombs(delta)
	_update_storm_bombs(delta)
	_update_clouds(delta)
	_update_special(delta)


func try_special() -> bool:
	if game.get("phase") != "playing" or float(game.get("player_respawn")) > 0.0 or not special_ready():
		return false
	# Godot must have room for the kid collision volume before launching.
	if bool(walker.call("update_form", false)):
		return false
	var weapon: Dictionary = weapons[selected_id]
	var id := String(weapon["special"])
	special_points = 0.0
	special_active = id
	special_time = 0.0
	if id == "slam":
		walker.call("begin_slam", weapon_data["specials"]["slam"])
	else:
		_throw_storm(weapon_data["specials"]["storm"])
	return true


func _update_special(delta: float) -> void:
	if special_active == "storm":
		special_time += delta
		if special_time > 0.35:
			special_active = ""
	elif special_active == "slam" and bool(walker.get("slam_impact_pending")):
		walker.set("slam_impact_pending", false)
		_slam_impact(weapon_data["specials"]["slam"])
		special_active = ""
		game.set("player_invuln", maxf(float(game.get("player_invuln")), 0.3))


func tick(delta: float, fire: bool, squid: bool, sub: bool = false) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	advance_effects(delta)
	if not special_active.is_empty():
		walker.set("firing_speed_limit", INF)
		return
	var player_config: Dictionary = weapon_data["player"]
	if squid:
		if int(walker.get("ink_owner")) == 0 or bool(walker.get("climbing")):
			ink_amount = minf(float(player_config["inkMax"]), ink_amount + float(player_config["inkRefillSwim"]) * delta)
	elif fire:
		refill_wait = float(player_config["inkRefillDelay"])
	else:
		refill_wait = maxf(0.0, refill_wait - delta)
		if refill_wait <= 0.0:
			ink_amount = minf(float(player_config["inkMax"]), ink_amount + float(player_config["inkRefillKid"]) * delta)
	var pressed := fire and not last_fire
	last_fire = fire
	var sub_released := not sub and last_sub
	last_sub = sub
	if squid:
		aiming_sub = false
	elif sub:
		aiming_sub = true
	elif sub_released and aiming_sub:
		aiming_sub = false
		var bomb: Dictionary = weapon_data["sub"]["bomb"]
		if ink_amount >= float(bomb["inkCost"]):
			ink_amount -= float(bomb["inkCost"])
			refill_wait = float(player_config["inkRefillDelay"])
			_throw_bomb(bomb)
	var weapon: Dictionary = weapons[selected_id]
	var speed_limit := INF
	if not squid:
		match selected_id:
			"shooter", "blaster":
				if fire and cooldown <= 0.0 and ink_amount >= float(weapon["inkPerShot"]):
					_spawn_shot(weapon)
					ink_amount -= float(weapon["inkPerShot"])
					cooldown = float(weapon["fireInterval"])
				if fire:
					speed_limit = float(weapon["moveSpeedFiring"])
			"charger":
				if fire and cooldown <= 0.0 and ink_amount >= float(weapon["inkFull"]) * 0.2:
					charging = true
					charge_time = minf(float(weapon["chargeTime"]), charge_time + delta)
					var t := charge_time / float(weapon["chargeTime"])
					var curved := t * 1.25 if t < 0.2 else 0.25 + (t - 0.2) * 0.9375
					charge_fraction = minf(ink_amount / float(weapon["inkFull"]), curved)
					speed_limit = float(weapon["moveSpeedFiring"])
				elif charging:
					_fire_charger(weapon, maxf(0.12, charge_fraction))
					charging = false
					charge_time = 0.0
					charge_fraction = 0.0
					cooldown = 0.28
			"roller":
				_update_roller(delta, fire, pressed, weapon)
				if fire or flick_time >= 0.0:
					speed_limit = float(weapon["moveSpeedFiring"])
	else:
		charging = false
		charge_time = 0.0
		charge_fraction = 0.0
		rolling = false
		flick_time = -1.0
	walker.set("firing_speed_limit", speed_limit)


func _spawn_shot(weapon: Dictionary) -> void:
	var muzzle := walker.global_position + Vector3.UP * 1.05
	var direction := _aim_direction(muzzle, float(weapon["range"]))
	muzzle += direction * 0.55
	var kind := String(weapon["kind"])
	_spawn_projectile(kind, muzzle, direction * float(weapon["projSpeed"]), weapon)


func _spawn_projectile(kind: String, at: Vector3, velocity: Vector3, weapon: Dictionary) -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.25 if kind == "blaster" else 0.15
	mesh.height = mesh.radius * 2.0
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = PROJECTILE_COLORS[0]
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	add_child(visual)
	visual.global_position = at
	projectiles.append({
		"kind": kind, "visual": visual, "velocity": velocity, "origin": at,
		"age": 0.0, "distance": 0.0, "weapon": weapon,
	})


func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var visual: MeshInstance3D = shot["visual"]
		var velocity: Vector3 = shot["velocity"]
		var age := float(shot["age"]) + delta
		var kind := String(shot["kind"])
		if kind != "blaster" and age > float(shot["weapon"].get("straightTime", 0.0)):
			velocity.y -= (26.0 if kind == "drop" else 28.0) * delta
		var previous := visual.global_position
		var next := previous + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(previous, next, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var body_size := 0.25 if kind == "blaster" else 0.15
		var bot_hit := _segment_bot_hit(previous, next, body_size)
		shot["velocity"] = velocity
		shot["age"] = age
		shot["distance"] = float(shot["distance"]) + previous.distance_to(next)
		var done := false
		if not bot_hit.is_empty() and (hit.is_empty() or float(bot_hit["distance"]) < previous.distance_to(hit["position"])):
			var weapon: Dictionary = shot["weapon"]
			var damage := float(weapon.get("damage", weapon.get("directDamage", weapon.get("flickDamageNear", 0.0))))
			if kind == "drop":
				damage = lerpf(float(weapon["flickDamageNear"]), float(weapon["flickDamageFar"]),
					clampf(float(shot["distance"]) / 7.0, 0.0, 1.0))
			game.call("damage_bot", damage)
			if kind == "blaster":
				_burst_blaster(bot_hit["point"], weapon, true)
			done = true
		elif not hit.is_empty():
			var radius := float(shot["weapon"].get("impactRadius", 0.9))
			_paint_player(hit["position"] + hit["normal"] * 0.1, radius, randf())
			if kind == "blaster":
				_burst_blaster(hit["position"], shot["weapon"])
			done = true
		elif kind == "blaster" and float(shot["distance"]) >= float(shot["weapon"]["range"]):
			_burst_blaster(next, shot["weapon"])
			done = true
		elif age >= 1.4 or next.y < -3.4:
			done = true
		visual.global_position = next
		if done:
			visual.queue_free()
			projectiles.remove_at(index)


func _burst_blaster(at: Vector3, weapon: Dictionary, direct_hit_bot: bool = false) -> void:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, at - Vector3.UP * 3.5, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_paint_player(hit["position"] + hit["normal"] * 0.1, float(weapon["impactRadius"]), randf())
	if not direct_hit_bot and float(game.get("bot_respawn")) <= 0.0:
		var bot: Node3D = game.get_node("Bot")
		var target := bot.global_position + Vector3.UP * 0.8
		var distance := at.distance_to(target)
		if distance <= float(weapon["splashRadius"]):
			var sight := PhysicsRayQueryParameters3D.create(at + (target - at).normalized() * 0.06, target, 1)
			if get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
				game.call("damage_bot", lerpf(float(weapon["splashDamageMax"]), float(weapon["splashDamageMin"]),
					distance / float(weapon["splashRadius"])))


func _fire_charger(weapon: Dictionary, charge: float, aim_override: Vector3 = Vector3.ZERO) -> void:
	ink_amount = maxf(0.0, ink_amount - float(weapon["inkFull"]) * charge)
	var muzzle := walker.global_position + Vector3.UP * 1.05
	var range_m := lerpf(float(weapon["rangeMin"]), float(weapon["rangeMax"]), charge)
	var direction := aim_override.normalized() if aim_override.length_squared() > 0.01 else _aim_direction(muzzle, range_m)
	var query := PhysicsRayQueryParameters3D.create(muzzle, muzzle + direction * range_m, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var length := muzzle.distance_to(hit["position"]) if not hit.is_empty() else range_m
	var bot_hit := _segment_bot_hit(muzzle, muzzle + direction * length, 0.14)
	if not bot_hit.is_empty():
		length = float(bot_hit["distance"])
		var damage := float(weapon["damageMax"]) if charge >= 0.999 else lerpf(float(weapon["damageMin"]), float(weapon["damageMax"]) * 0.62, charge)
		game.call("damage_bot", damage)
	var distance := 1.2
	while distance < length - 0.3:
		var sample := muzzle + direction * distance
		var down := PhysicsRayQueryParameters3D.create(sample, sample - Vector3.UP * 3.5, 1)
		var ground := get_world_3d().direct_space_state.intersect_ray(down)
		if not ground.is_empty():
			_paint_player(ground["position"] + ground["normal"] * 0.1,
				float(weapon["lineRadius"]) * (0.8 + charge * 0.4), randf())
		distance += float(weapon["lineSplatEvery"])
	if not hit.is_empty() and bot_hit.is_empty():
		_paint_player(hit["position"] + hit["normal"] * 0.1,
			float(weapon["impactRadius"]) * (0.6 + 0.4 * charge), randf())
	_add_beam(muzzle, direction, length, charge)


func _add_beam(origin: Vector3, direction: Vector3, length: float, charge: float) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07 + charge * 0.07, 0.07 + charge * 0.07, maxf(length, 0.01))
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = PROJECTILE_COLORS[0].lightened(0.35)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	add_child(visual)
	visual.global_position = origin + direction * (length * 0.5)
	visual.look_at(visual.global_position + direction, Vector3.UP)
	beams.append({"visual": visual, "life": 0.22})


func _update_beams(delta: float) -> void:
	for index in range(beams.size() - 1, -1, -1):
		var beam: Dictionary = beams[index]
		beam["life"] = float(beam["life"]) - delta
		if float(beam["life"]) <= 0.0:
			(beam["visual"] as MeshInstance3D).queue_free()
			beams.remove_at(index)


func _throw_bomb(config: Dictionary) -> void:
	var at := walker.global_position + Vector3.UP * 1.35
	var direction := _aim_direction(at, 18.0)
	var velocity := (direction + Vector3.UP * 0.28).normalized() * float(config["throwSpeed"])
	velocity += walker.velocity * 0.4 + Vector3.UP * 1.5
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = PROJECTILE_COLORS[0]
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	add_child(visual)
	visual.global_position = at
	bombs.append({"visual": visual, "position": at, "velocity": velocity, "fuse": -1.0, "age": 0.0})


func _update_bombs(delta: float) -> void:
	var config: Dictionary = weapon_data["sub"]["bomb"]
	for index in range(bombs.size() - 1, -1, -1):
		var bomb: Dictionary = bombs[index]
		var position: Vector3 = bomb["position"]
		var velocity: Vector3 = bomb["velocity"]
		velocity.y -= 24.0 * delta
		var next := position + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(position, next, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			next = hit["position"] + hit["normal"] * 0.21
			var normal: Vector3 = hit["normal"]
			velocity = (velocity - normal * velocity.dot(normal) * 1.35) * (0.45 if normal.y > 0.6 else 0.6)
			if normal.y > 0.6 and float(bomb["fuse"]) < 0.0:
				bomb["fuse"] = float(config["fuse"])
		bomb["position"] = next
		bomb["velocity"] = velocity
		bomb["age"] = float(bomb["age"]) + delta
		var visual: MeshInstance3D = bomb["visual"]
		visual.global_position = next
		if float(bomb["fuse"]) >= 0.0:
			bomb["fuse"] = float(bomb["fuse"]) - delta
			if float(bomb["fuse"]) <= 0.0:
				_explode_bomb(next, config)
				visual.queue_free()
				bombs.remove_at(index)
				continue
		if next.y < float(weapon_data["player"]["fallDeathY"]) - 1.8 or float(bomb["age"]) > 5.0:
			visual.queue_free()
			bombs.remove_at(index)


func _explode_bomb(at: Vector3, config: Dictionary) -> void:
	_paint_player(at + Vector3.UP * 0.2, float(config["paintRadius"]), randf())
	for i in 5:
		var angle := randf() * TAU
		var radius := float(config["paintRadius"]) * randf_range(0.6, 1.0)
		var splat := at + Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
		_paint_player(splat, randf_range(0.7, 1.2), randf())
	if float(game.get("bot_respawn")) > 0.0:
		return
	var bot: Node3D = game.get_node("Bot")
	var target := bot.global_position + Vector3.UP * 0.7
	var distance := at.distance_to(target)
	if distance > float(config["radius"]):
		return
	var sight := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, target, 1)
	if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
		return
	var closeness := 1.0 - clampf((distance - 0.8) / (float(config["radius"]) - 0.8), 0.0, 1.0)
	game.call("damage_bot", lerpf(float(config["damageMin"]), float(config["damageMax"]), closeness * closeness))


func _slam_impact(config: Dictionary) -> void:
	var at := walker.global_position
	# Like actor.js addTurfNoSpecial: the shockwave paints turf but does not refill itself.
	game.call("paint_at_world", at + Vector3.UP * 0.3, 0, float(config["radius"]) * 0.72, randf())
	for i in range(9):
		var angle := float(i) / 9.0 * TAU + randf() * 0.3
		var radius := float(config["radius"]) * randf_range(0.55, 0.85)
		var splat := at + Vector3(cos(angle) * radius, 0.6, sin(angle) * radius)
		game.call("paint_at_world", splat, 0, randf_range(1.1, 1.7), randf())
	if float(game.get("bot_respawn")) > 0.0:
		return
	var bot: Node3D = game.get_node("Bot")
	var target := bot.global_position + Vector3.UP * 0.8
	var distance := bot.global_position.distance_to(at)
	if distance > float(config["radius"]):
		return
	var sight := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, target, 1)
	if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
		return
	var damage := float(config["damageMax"]) if distance < float(config["killRadius"]) else \
		float(config["damageMin"]) + (float(config["damageMax"]) - float(config["damageMin"])) * 0.3 * \
		(1.0 - (distance - float(config["killRadius"])) / (float(config["radius"]) - float(config["killRadius"])))
	game.call("damage_bot", damage)


func _throw_storm(config: Dictionary) -> void:
	var at := walker.global_position + Vector3.UP * 1.45
	var direction := _aim_direction(at, 18.0)
	var velocity := (direction + Vector3.UP * 0.28).normalized() * float(config["throwSpeed"])
	velocity += walker.velocity * 0.4 + Vector3.UP * 1.5
	var visual := _colored_sphere(0.25)
	visual.global_position = at
	storm_bombs.append({"visual": visual, "position": at, "velocity": velocity, "age": 0.0,
		"direction": Vector3(velocity.x, 0.0, velocity.z).normalized()})


func _update_storm_bombs(delta: float) -> void:
	for index in range(storm_bombs.size() - 1, -1, -1):
		var bomb: Dictionary = storm_bombs[index]
		var position: Vector3 = bomb["position"]
		var velocity: Vector3 = bomb["velocity"]
		velocity.y -= 24.0 * delta
		var next := position + velocity * delta
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position, next, 1))
		bomb["age"] = float(bomb["age"]) + delta
		if not hit.is_empty() or float(bomb["age"]) >= 1.1:
			_spawn_cloud(hit["position"] if not hit.is_empty() else next, bomb["direction"])
			(bomb["visual"] as MeshInstance3D).queue_free()
			storm_bombs.remove_at(index)
		else:
			bomb["position"] = next
			bomb["velocity"] = velocity
			(bomb["visual"] as MeshInstance3D).global_position = next


func _spawn_cloud(at: Vector3, direction: Vector3) -> void:
	var ground := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 12.0, 1))
	var height := float(ground["position"].y) if not ground.is_empty() else at.y
	var visual := _colored_sphere(1.9)
	visual.scale.y = 0.5
	visual.global_position = Vector3(at.x, height + 4.6, at.z)
	clouds.append({"visual": visual, "direction": direction, "time": 0.0, "rain_time": 0.0})


func _update_clouds(delta: float) -> void:
	var config: Dictionary = weapon_data["specials"]["storm"]
	for index in range(clouds.size() - 1, -1, -1):
		var cloud: Dictionary = clouds[index]
		cloud["time"] = float(cloud["time"]) + delta
		var visual: MeshInstance3D = cloud["visual"]
		visual.global_position += (cloud["direction"] as Vector3) * float(config["driftSpeed"]) * delta
		if float(cloud["time"]) < float(config["duration"]) - 0.3:
			cloud["rain_time"] = float(cloud["rain_time"]) - delta
			while float(cloud["rain_time"]) <= 0.0:
				cloud["rain_time"] = float(cloud["rain_time"]) + 0.045
				var angle := randf() * TAU
				var radius := sqrt(randf()) * float(config["radius"])
				var start := visual.global_position + Vector3(cos(angle) * radius, -0.8, sin(angle) * radius)
				var ground := get_world_3d().direct_space_state.intersect_ray(
					PhysicsRayQueryParameters3D.create(start, start - Vector3.UP * 12.0, 1))
				if not ground.is_empty():
					_paint_player(ground["position"] + ground["normal"] * 0.1, randf_range(0.45, 0.8), randf())
			if float(game.get("bot_respawn")) <= 0.0:
				var bot: Node3D = game.get_node("Bot")
				var target := bot.global_position + Vector3.UP * 1.2
				var horizontal := Vector2(target.x - visual.global_position.x, target.z - visual.global_position.z)
				if horizontal.length() <= float(config["radius"]) and target.y <= visual.global_position.y:
					var sight := PhysicsRayQueryParameters3D.create(target, Vector3(target.x, visual.global_position.y - 0.6, target.z), 1)
					if get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
						game.call("damage_bot", float(config["dps"]) * delta)
		if float(cloud["time"]) >= float(config["duration"]):
			visual.queue_free()
			clouds.remove_at(index)


func _colored_sphere(radius: float) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = PROJECTILE_COLORS[0].lightened(0.3)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	add_child(visual)
	return visual


func _update_roller(delta: float, fire: bool, pressed: bool, weapon: Dictionary) -> void:
	if flick_time >= 0.0:
		flick_time += delta
		if flick_time >= float(weapon["flickWindup"]):
			_spawn_flick(weapon)
			flick_time = -1.0
			cooldown = float(weapon["flickInterval"]) - float(weapon["flickWindup"])
		return
	if pressed and cooldown <= 0.0 and ink_amount >= float(weapon["flickInk"]):
		ink_amount -= float(weapon["flickInk"])
		flick_time = 0.0
		return
	rolling = fire and walker.is_on_floor() and ink_amount > 0.5 and cooldown <= 0.25
	if not rolling:
		last_roll_position = walker.global_position
		return
	var movement := walker.global_position - last_roll_position
	movement.y = 0.0
	if movement.length() < 0.28:
		return
	last_roll_position = walker.global_position
	_paint_roll_at(walker.global_position, movement, weapon)


func _paint_roll_at(position: Vector3, movement: Vector3, weapon: Dictionary) -> void:
	ink_amount = maxf(0.0, ink_amount - float(weapon["rollInkPerMeter"]) * movement.length())
	var forward := movement.normalized()
	var lateral := Vector3(-forward.z, 0.0, forward.x)
	for offset in [-1.0, 0.0, 1.0]:
		var at := position + forward * 0.75 + lateral * float(offset) * float(weapon["rollWidth"]) * 0.33 + Vector3.UP * 0.35
		_paint_player(at, 0.62, randf())
	if float(game.get("bot_respawn")) <= 0.0:
		var bot: Node3D = game.get_node("Bot")
		var offset := bot.global_position - position
		if offset.dot(forward) > -0.2 and offset.dot(forward) < 1.35 \
			and absf(offset.dot(lateral)) < float(weapon["rollWidth"]) * 0.5 + 0.35 \
			and absf(offset.y) < 1.2:
			game.call("damage_bot", float(weapon["rollDamage"]))


func _spawn_flick(weapon: Dictionary) -> void:
	var muzzle := walker.global_position + Vector3.UP * 1.3
	var forward := _aim_direction(muzzle, 10.0)
	forward.y = 0.0
	forward = forward.normalized()
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	var yaw := atan2(forward.x, forward.z)
	var drops := int(weapon["flickDrops"])
	for i in range(drops):
		var t := float(i) / float(drops - 1) * 2.0 - 1.0
		var angle := yaw + t * deg_to_rad(float(weapon["flickSpreadDeg"])) * 0.5
		var speed := float(weapon["flickSpeed"]) * (0.82 + 0.28 * (1.0 - absf(t)))
		var up := 0.32
		var velocity := Vector3(sin(angle) * cos(up), sin(up), cos(angle) * cos(up)) * speed
		_spawn_projectile("drop", muzzle + forward * 0.6, velocity, weapon)


func _aim_direction(muzzle: Vector3, max_range: float) -> Vector3:
	var camera: Camera3D = walker.get_node("Camera3D")
	var pointer := get_viewport().get_visible_rect().size * 0.5 if bool(game.get("pointer_locked")) else get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(pointer)
	var ray := camera.project_ray_normal(pointer)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + ray * max_range * 2.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit["position"] if not hit.is_empty() else origin + ray * max_range
	var result := (target - muzzle).normalized()
	return result if result.length_squared() > 0.01 else Vector3.FORWARD


func _segment_bot_hit(start: Vector3, finish: Vector3, projectile_radius: float) -> Dictionary:
	if game.get("phase") != "playing" or float(game.get("bot_respawn")) > 0.0:
		return {}
	var bot: Node3D = game.get_node("Bot")
	var center := bot.global_position + Vector3.UP * 0.8
	var step := finish - start
	if step.length_squared() < 0.000001:
		return {}
	var t := clampf((center - start).dot(step) / step.length_squared(), 0.0, 1.0)
	var closest := start + step * t
	if closest.distance_to(center) > 0.72 + projectile_radius:
		return {}
	return {"point": closest, "distance": start.distance_to(closest)}
