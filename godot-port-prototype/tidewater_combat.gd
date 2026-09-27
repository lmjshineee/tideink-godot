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
var last_fire_time := 99.0
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
var bloom := 0.0
var roll_time := 0.0
var flick_recover := 0.0
var firing_time := 0.0
var roll_hits: Dictionary = {}
var elapsed := 0.0
var special_points := 0.0
var special_active := ""
var special_time := 0.0


# weapons.js:42 — a weapon mid-charge or mid-flick keeps the actor a kid.
func is_busy() -> bool:
	return charging or flick_time >= 0.0


func special_cost() -> float:
	return float(weapons[selected_id]["specialCost"])


func special_ready() -> bool:
	return special_points >= special_cost() and special_active.is_empty()


func special_fraction() -> float:
	return clampf(special_points / special_cost(), 0.0, 1.0)


func _add_turf(area: float) -> void:
	if area > 0.0 and special_active.is_empty():
		special_points = minf(special_cost(), special_points + area)


func _paint_player(at: Vector3, radius: float, seed: float,
		stretch: Vector3 = Vector3.ZERO, stretch_amount: float = 0.0) -> float:
	return _paint_team(at, 0, radius, seed, stretch, stretch_amount)


func _paint_team(at: Vector3, team: int, radius: float, seed: float,
		stretch: Vector3 = Vector3.ZERO, stretch_amount: float = 0.0) -> float:
	var area := float(game.call("paint_at_world", at, team, radius, seed, stretch, stretch_amount))
	if team == 0:
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
	bloom = 0.0
	roll_time = 0.0
	flick_recover = 0.0
	firing_time = 0.0
	roll_hits.clear()
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
	roll_time = 0.0
	flick_recover = 0.0
	firing_time = 0.0
	roll_hits.clear()
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
	# Spread bloom recovers only once the trigger is released (weapons.js:72).
	if not fire:
		bloom = maxf(0.0, bloom - delta / float(weapons[selected_id]["bloomRecover"]))
	elapsed += delta
	firing_time = maxf(0.0, firing_time - delta)
	flick_recover = maxf(0.0, flick_recover - delta)
	advance_effects(delta)
	if not special_active.is_empty():
		walker.set("firing_speed_limit", INF)
		return
	var player_config: Dictionary = weapon_data["player"]
	last_fire_time += delta
	# Ink refill, mirroring actor.js:311-314. The delay is measured from the last shot
	# that actually left the barrel, not from the button state: the port used to reset
	# the delay every frame the trigger was held, so an empty tank pressed against the
	# trigger never refilled and the player was stuck dry until they let go.
	var submerged := squid and walker.is_on_floor() and int(walker.get("ink_owner")) == 0
	if submerged or bool(walker.get("climbing")):
		ink_amount = minf(float(player_config["inkMax"]), ink_amount + float(player_config["inkRefillSwim"]) * delta)
	elif not squid and last_fire_time > float(player_config["inkRefillDelay"]) and not is_busy():
		ink_amount = minf(float(player_config["inkMax"]), ink_amount + float(player_config["inkRefillKid"]) * delta)
	elif squid:
		# A squid on dry ground still trickles at half the kid rate (actor.js:314).
		ink_amount = minf(float(player_config["inkMax"]), ink_amount + float(player_config["inkRefillKid"]) * 0.5 * delta)
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
			last_fire_time = 0.0
			_throw_bomb(bomb)
	var weapon: Dictionary = weapons[selected_id]
	var speed_limit := INF
	if not squid:
		match selected_id:
			"shooter", "blaster":
				if fire and cooldown <= 0.0 and ink_amount >= float(weapon["inkPerShot"]):
					_spawn_shot(weapon)
					ink_amount -= float(weapon["inkPerShot"])
					# Accumulate like the web's while-loop so a slow weapon is not
					# quantised by the 30 Hz tick (blaster 0.78 s used to become 0.80 s).
					cooldown += float(weapon["fireInterval"])
					last_fire_time = 0.0
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
				speed_limit = _roller_speed_limit(weapon)
	else:
		charging = false
		charge_time = 0.0
		charge_fraction = 0.0
		rolling = false
		flick_time = -1.0
	walker.set("firing_speed_limit", speed_limit)


# Current shot cone half-angle in degrees, mirroring weapons.js:57-64. Only the
# shooter's cone widens with bloom; the blaster's is constant.
func _spread_degrees(weapon: Dictionary) -> float:
	var base := float(weapon["spreadBaseGround"]) if walker.is_on_floor() else float(weapon["spreadBaseAir"])
	if String(weapon["kind"]) == "shooter":
		return base * lerpf(float(weapon["spreadFirst"]), 1.0, bloom)
	return base


func _spawn_shot(weapon: Dictionary) -> void:
	var muzzle := walker.global_position + Vector3.UP * 1.05
	var target := _aim_target(muzzle, float(weapon["range"]))
	var direction := (target - muzzle).normalized()
	if String(weapon["kind"]) == "shooter":
		direction = _ballistic_direction(muzzle, direction, target,
			float(weapon["projSpeed"]), float(weapon["straightTime"]),
			28.0, 0.8, float(weapon["range"]))
	# Per-shot spread with bloom (weapons.js:57-64, 119). Without it the shooter is a
	# laser: 5.5 deg on the ground, 11 deg in the air, opening from spreadFirst to the
	# full cone over a burst and recovering once the trigger is released.
	var angle := deg_to_rad(_spread_degrees(weapon))
	if angle > 0.0:
		direction = _spread_direction(direction, angle)
	bloom = minf(1.0, bloom + float(weapon["bloomPerShot"]))
	muzzle += direction * 0.55
	_spawn_projectile(String(weapon["kind"]), muzzle, direction * float(weapon["projSpeed"]), weapon)


# The bot fires the same shooter projectile as the player, including launch
# compensation, spread, flight, direct damage and trail paint.
func spawn_bot_shot(from: Vector3, target: Vector3) -> void:
	var weapon: Dictionary = weapons["shooter"]
	var direction := (target - from).normalized()
	if direction.length_squared() < 0.01:
		return
	direction = _ballistic_direction(from, direction, target,
		float(weapon["projSpeed"]), float(weapon["straightTime"]),
		28.0, 0.8, float(weapon["range"]))
	direction = _spread_direction(direction, deg_to_rad(float(weapon["spreadBaseGround"])))
	_spawn_projectile("shooter", from + direction * 0.55,
		direction * float(weapon["projSpeed"]), weapon, 1)


# weapons.js:_spread samples a disk in angular space, with 55% vertical spread.
# The radius and azimuth share one sample; independent positive offsets would
# bias every shot to the same quadrant and can exceed the intended cone.
func _spread_direction(direction: Vector3, angle: float) -> Vector3:
	if angle <= 0.0:
		return direction
	var basis := _perpendicular_basis(direction)
	var radius := angle * sqrt(randf())
	var azimuth := randf() * TAU
	return (direction + basis[0] * cos(azimuth) * tan(radius)
			+ basis[1] * sin(azimuth) * tan(radius) * 0.55).normalized()


# Horizontal and vertical unit vectors perpendicular to `direction`.
func _perpendicular_basis(direction: Vector3) -> Array:
	var helper := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var first := direction.cross(helper).normalized()
	return [first, direction.cross(first).normalized()]


# Solve launch pitch against the same discrete gravity/drag step used by
# _update_projectiles. Keep the original aim if the target is too near, beyond
# range, or would require an implausible pitch correction (weapons.js:_ballistic).
func _ballistic_direction(from: Vector3, direction: Vector3, target: Vector3,
		speed: float, straight: float, gravity: float, drag: float, max_range: float) -> Vector3:
	var horizontal := Vector2(target.x - from.x, target.z - from.z).length()
	var horizontal_aim := Vector2(direction.x, direction.z).length()
	if horizontal < 1.5 or horizontal > max_range or gravity <= 0.0 or horizontal_aim < 0.0001:
		return direction
	if Vector2(target.x - from.x, target.z - from.z).dot(Vector2(direction.x, direction.z)) <= 0.0:
		return direction
	var desired_height := target.y - from.y
	var initial_pitch := atan2(direction.y, horizontal_aim)
	var pitch0 := initial_pitch
	var error0 := _ballistic_height_at(pitch0, horizontal, speed, straight, gravity, drag) - desired_height
	if absf(error0) < 0.01:
		return direction
	var pitch1 := pitch0 - atan2(error0, horizontal)
	var error1 := _ballistic_height_at(pitch1, horizontal, speed, straight, gravity, drag) - desired_height
	for iteration in range(4):
		if absf(error1) <= 0.005 or absf(error1 - error0) < 0.000001:
			break
		var pitch2 := pitch1 - error1 * (pitch1 - pitch0) / (error1 - error0)
		pitch0 = pitch1
		error0 = error1
		pitch1 = clampf(pitch2, -1.2, 1.2)
		error1 = _ballistic_height_at(pitch1, horizontal, speed, straight, gravity, drag) - desired_height
	if absf(error1) > 0.25 or absf(pitch1 - initial_pitch) > 0.35:
		return direction
	var cosine := cos(pitch1) / horizontal_aim
	return Vector3(direction.x * cosine, sin(pitch1), direction.z * cosine)


func _ballistic_height_at(pitch: float, horizontal: float, speed: float,
		straight: float, gravity: float, drag: float) -> float:
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var horizontal_speed := cos(pitch) * speed
	var vertical_speed := sin(pitch) * speed
	var travelled := 0.0
	var height := 0.0
	var age := 0.0
	for iteration in range(90):
		age += step
		var previous_x := travelled
		var previous_y := height
		if age > straight:
			vertical_speed -= gravity * step
			var factor := 1.0 - drag * step
			horizontal_speed *= factor
			vertical_speed *= factor
		travelled += horizontal_speed * step
		height += vertical_speed * step
		if travelled >= horizontal:
			return lerpf(previous_y, height,
				(horizontal - previous_x) / maxf(0.000001, travelled - previous_x))
		if horizontal_speed < 0.5:
			break
	return -1000.0


# Mirrors the web game's projectile record (weapons.js:357/377/401), including the
# per-type radius, lifetime, gravity after the straight segment, air drag and the
# trail-drip cadence. These used to be re-derived at impact time from the weapon
# table, which silently dropped the roller's randomised drop radius and every
# trail drip.
func _spawn_projectile(kind: String, at: Vector3, velocity: Vector3,
		weapon: Dictionary, team: int = 0) -> void:
	var radius := 0.15
	var life := 1.4
	var straight := 0.0
	var gravity := 26.0
	var drag := 0.0
	var trail_every := 0.0
	var trail_radius := 0.0
	var trail := 0.0
	match kind:
		"shooter":
			radius = float(weapon["impactRadius"])
			life = 1.2
			straight = float(weapon.get("straightTime", 0.13))
			gravity = 28.0
			drag = 0.8
			trail_every = float(weapon["trailEvery"])
			trail_radius = float(weapon["trailRadius"])
			trail = -(2.5 - trail_every)
		"blaster":
			radius = float(weapon["impactRadius"])
			life = float(weapon["range"]) / float(weapon["projSpeed"])
			straight = 99.0
			gravity = 0.0
			trail_every = 2.2
			trail_radius = 0.45
			trail = -1.5
		"drop":
			radius = 0.85 + randf() * 0.3
			life = 1.4
			straight = 0.0
			gravity = 26.0
			drag = 0.4
			trail_every = 1.8
			trail_radius = 0.45
			trail = 0.0
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.25 if kind == "blaster" else 0.15
	mesh.height = mesh.radius * 2.0
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = PROJECTILE_COLORS[team]
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	add_child(visual)
	visual.global_position = at
	projectiles.append({
		"kind": kind, "team": team, "visual": visual, "velocity": velocity, "origin": at,
		"age": 0.0, "distance": 0.0, "weapon": weapon,
		"radius": radius, "life": life, "straight": straight, "gravity": gravity,
		"drag": drag, "trail_every": trail_every, "trail_radius": trail_radius, "trail": trail,
	})


func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var visual: MeshInstance3D = shot["visual"]
		var velocity: Vector3 = shot["velocity"]
		var age := float(shot["age"]) + delta
		var kind := String(shot["kind"])
		var team := int(shot["team"])
		var straight := float(shot["straight"])
		if age > straight:
			velocity.y -= float(shot["gravity"]) * delta
			var drag := float(shot["drag"])
			if drag > 0.0:
				velocity *= 1.0 - drag * delta
		var previous := visual.global_position
		var next := previous + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(previous, next, 1)
		if team == 1:
			query.exclude = [walker.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var body_size := 0.26 if kind == "blaster" else 0.15
		var victim_hit := _segment_bot_hit(previous, next, body_size) if team == 0 else \
			_segment_player_hit(previous, next, body_size)
		shot["velocity"] = velocity
		shot["age"] = age
		shot["distance"] = float(shot["distance"]) + previous.distance_to(next)
		var done := false
		if not victim_hit.is_empty() and (hit.is_empty() or float(victim_hit["distance"]) < previous.distance_to(hit["position"])):
			var weapon: Dictionary = shot["weapon"]
			var damage := float(weapon.get("damage", weapon.get("directDamage", weapon.get("flickDamageNear", 0.0))))
			if kind == "drop":
				# Falloff measured from the launch point, not the flight path.
				damage = lerpf(float(weapon["flickDamageNear"]), float(weapon["flickDamageFar"]),
					clampf((shot["origin"] as Vector3).distance_to(victim_hit["point"]) / 7.0, 0.0, 1.0))
			if team == 0:
				game.call("damage_bot", damage)
			else:
				game.call("damage_player", damage)
			if kind == "blaster":
				_burst_blaster(victim_hit["point"], weapon, true)
			done = true
		elif not hit.is_empty():
			_impact(hit, shot)
			if kind == "blaster":
				_burst_blaster(hit["position"], shot["weapon"])
			done = true
		elif age >= float(shot["life"]):
			if kind == "blaster":
				_burst_blaster(next, shot["weapon"])
			done = true
		elif next.y < float(weapon_data["player"]["waterY"]) - 1.8:
			done = true
		# Trail drips: every `trail_every` metres the shot drops ink straight down
		# (weapons.js:681-687). This is the shooter's main turf channel, and the port
		# had no ink along the flight path at all.
		if not done:
			var trail_every := float(shot["trail_every"])
			if trail_every > 0.0:
				shot["trail"] = float(shot["trail"]) + velocity.length() * delta
				if float(shot["trail"]) > trail_every:
					shot["trail"] = 0.0
					var down := PhysicsRayQueryParameters3D.create(next, next - Vector3.UP * 4.0, 1)
					var ground := get_world_3d().direct_space_state.intersect_ray(down)
					if not ground.is_empty():
						_paint_team(ground["position"] + ground["normal"] * 0.1, team,
							float(shot["trail_radius"]) * (0.8 + randf() * 0.4), randf())
		visual.global_position = next
		if done:
			visual.queue_free()
			projectiles.remove_at(index)


# Impact splat: randomised radius, offset off the surface, and the blob stretched
# along the shot direction (weapons.js:705-710).
func _impact(hit: Dictionary, shot: Dictionary) -> void:
	var position: Vector3 = hit["position"] + hit["normal"] * 0.14
	var radius := float(shot["radius"]) * (0.85 + randf() * 0.3)
	var direction := (shot["velocity"] as Vector3).normalized()
	_paint_team(position, int(shot["team"]), radius, randf(), direction, 0.7)


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
	last_fire_time = 0.0
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
				float(weapon["lineRadius"]) * (0.8 + charge * 0.4), randf(), direction, 1.2)
		distance += float(weapon["lineSplatEvery"])
	if not hit.is_empty() and bot_hit.is_empty():
		_paint_player(hit["position"] + hit["normal"] * 0.12,
			float(weapon["impactRadius"]) * (0.6 + 0.4 * charge), randf(), direction, 0.6)
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


# Roller ground speed, mirroring weapons.js:45-52. The drum has weight: rolling
# speed builds from half to full over ~0.45 s, the flick wind-up plants the player,
# and the recovery after a flick eases back to a run. This used to read
# moveSpeedFiring, which only looked right because rollSpeed happens to equal it.
func _roller_speed_limit(weapon: Dictionary) -> float:
	var run_speed := float(weapon_data["player"]["runSpeed"])
	if rolling:
		return lerpf(float(weapon["rollSpeed"]) * 0.5, float(weapon["rollSpeed"]),
			smoothstep(0.0, 0.45, roll_time))
	if flick_time >= 0.0:
		return lerpf(float(weapon["moveSpeedFiring"]), float(weapon["moveSpeedFiring"]) * 0.45,
			clampf(flick_time / float(weapon["flickWindup"]), 0.0, 1.0))
	if flick_recover > 0.0:
		return lerpf(run_speed, float(weapon["moveSpeedFiring"]) * 0.6, flick_recover / 0.18)
	if firing_time > 0.0:
		return float(weapon["moveSpeedFiring"])
	return run_speed


func _update_roller(delta: float, fire: bool, pressed: bool, weapon: Dictionary) -> void:
	if flick_time >= 0.0:
		flick_time += delta
		if flick_time >= float(weapon["flickWindup"]):
			_spawn_flick(weapon)
			flick_time = -1.0
			cooldown = float(weapon["flickInterval"]) - float(weapon["flickWindup"])
			last_fire_time = 0.0
			firing_time = 0.25
			flick_recover = 0.18
		return
	if pressed and cooldown <= 0.0 and ink_amount >= float(weapon["flickInk"]):
		ink_amount -= float(weapon["flickInk"])
		flick_time = 0.0
		return
	var can_roll := fire and walker.is_on_floor() and ink_amount > 0.5 and cooldown <= 0.25
	roll_time = roll_time + delta if can_roll else 0.0
	rolling = can_roll
	if not rolling:
		last_roll_position = walker.global_position
		return
	var movement := walker.global_position - last_roll_position
	movement.y = 0.0
	# Damage is checked every frame while rolling, not per painted stripe, and is
	# rate-limited per victim below.
	_roll_damage(weapon)
	if movement.length() < 0.28:
		return
	last_roll_position = walker.global_position
	_paint_roll_at(walker.global_position, movement, weapon)


# Crushing damage in front of the drum (weapons.js:200-207): needs a moving roller
# (> 1 m/s) and hits each victim at most once every 0.5 s. Without that cooldown the
# port re-applied rollDamage every 0.28 m of travel — roughly 2100 dps against the
# web's 280 — so one touch killed instantly.
func _roll_damage(weapon: Dictionary) -> void:
	if game.get("phase") != "playing" or float(game.get("bot_respawn")) > 0.0:
		return
	if Vector2(walker.velocity.x, walker.velocity.z).length() <= 1.0:
		return
	var yaw := float(walker.get_node("Body").rotation.y)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var bot: Node3D = game.get_node("Bot")
	var offset := bot.global_position - walker.global_position
	var ahead := offset.x * forward.x + offset.z * forward.z
	if ahead <= -0.2 or ahead >= 1.35:
		return
	var lateral := absf(offset.x * forward.z - offset.z * forward.x)
	if lateral >= float(weapon["rollWidth"]) * 0.5 + 0.35 or absf(offset.y) >= 1.2:
		return
	var key := bot.get_instance_id()
	if elapsed - float(roll_hits.get(key, -9.0)) <= 0.5:
		return
	roll_hits[key] = elapsed
	game.call("damage_bot", float(weapon["rollDamage"]))


func _paint_roll_at(position: Vector3, movement: Vector3, weapon: Dictionary) -> void:
	ink_amount = maxf(0.0, ink_amount - float(weapon["rollInkPerMeter"]) * movement.length())
	last_fire_time = 0.0
	# The stripe is laid out along the actor's facing, not the instantaneous travel
	# direction (weapons.js:213-219), so brushing past sideways paints a different
	# band than the web does.
	var yaw := float(walker.get_node("Body").rotation.y)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	for offset in [-1.0, 0.0, 1.0]:
		var at := position + forward * 0.75 + right * float(offset) * float(weapon["rollWidth"]) * 0.33 + Vector3.UP * 0.35
		_paint_player(at, 0.62, randf())


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
	var result := (_aim_target(muzzle, max_range) - muzzle).normalized()
	return result if result.length_squared() > 0.01 else Vector3.FORWARD


func _aim_target(muzzle: Vector3, max_range: float) -> Vector3:
	var camera: Camera3D = walker.get_node("Camera3D")
	var pointer := get_viewport().get_visible_rect().size * 0.5 if bool(game.get("pointer_locked")) else get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(pointer)
	var ray := camera.project_ray_normal(pointer)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + ray * max_range * 2.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else origin + ray * max_range


# Closest approach of a projectile segment to the victim's body capsule, mirroring
# weapons.js:657-661 + physics.js:305-334: a vertical capsule of PLAYER.radius and
# PLAYER.height whose axis runs base+radius .. base+height-radius, hit when the
# distance is under radius*0.95 + the projectile's own size. The port used a single
# 0.72 m sphere at +0.8 m, i.e. a 1.74 m wide hitbox that ignored body height, so
# remote shots connected far more often than in the web game.
func _segment_bot_hit(start: Vector3, finish: Vector3, projectile_radius: float) -> Dictionary:
	if game.get("phase") != "playing" or float(game.get("bot_respawn")) > 0.0:
		return {}
	return _segment_actor_hit(start, finish, projectile_radius, game.get_node("Bot").global_position)


func _segment_player_hit(start: Vector3, finish: Vector3, projectile_radius: float) -> Dictionary:
	if game.get("phase") != "playing" or float(game.get("player_respawn")) > 0.0:
		return {}
	var height := float(weapon_data["player"]["squidHeight"]) if bool(walker.get("squid_form")) else \
		float(weapon_data["player"]["height"])
	return _segment_actor_hit(start, finish, projectile_radius, walker.global_position, height)


func _segment_actor_hit(start: Vector3, finish: Vector3, projectile_radius: float,
		base: Vector3, actor_height: float = -1.0) -> Dictionary:
	var step := finish - start
	if step.length_squared() < 0.000001:
		return {}
	var player_config: Dictionary = weapon_data["player"]
	var height := actor_height if actor_height > 0.0 else float(player_config["height"])
	var radius := minf(float(player_config["radius"]), height * 0.5)
	var reach := radius * 0.95 + projectile_radius
	# The point-to-capsule distance is convex along the segment, so a ternary search
	# converges on the true closest approach.
	var low := 0.0
	var high := 1.0
	for iteration in range(40):
		var lower := low + (high - low) / 3.0
		var upper := high - (high - low) / 3.0
		if _point_capsule_distance(start + step * lower, base, radius, height) \
				< _point_capsule_distance(start + step * upper, base, radius, height):
			high = upper
		else:
			low = lower
	var closest := start + step * ((low + high) * 0.5)
	if _point_capsule_distance(closest, base, radius, height) > reach:
		return {}
	return {"point": closest, "distance": start.distance_to(closest)}


static func _point_capsule_distance(point: Vector3, base: Vector3, radius: float, height: float) -> float:
	var clamped_y := clampf(point.y, base.y + radius, base.y + maxf(radius, height - radius))
	return Vector3(point.x - base.x, point.y - clamped_y, point.z - base.z).length()
