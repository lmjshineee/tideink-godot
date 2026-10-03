extends Node3D

var game: Node3D
var combat: Node3D
var flights: Array[Dictionary] = []
var windups: Dictionary = {}

func setup(owner_game: Node3D, owner_combat: Node3D) -> void:
	game = owner_game
	combat = owner_combat

func primary_in_flight(actor: Node3D) -> bool:
	for disc in flights:
		if disc.owner == actor and not disc.special:
			return true
	return false

func throw_primary(actor: Node3D, target: Vector3) -> bool:
	if game.phase != "playing" or game.paused or not game.actor_alive(actor) or primary_in_flight(actor):
		return false
	var weapon: Dictionary = game.perks.weapon(actor, combat.weapons.disc)
	var ink_node: Node = combat if actor == combat.walker else actor
	if float(ink_node.ink_amount) < float(weapon.inkPerShot):
		return false
	var at := actor.global_position + Vector3.UP * 1.05
	var direction := (target - at).normalized()
	if direction.length_squared() < 0.1:
		return false
	ink_node.ink_amount -= float(weapon.inkPerShot)
	ink_node.last_fire_time = 0.0
	_spawn(actor, at + direction * 0.4, direction, false, weapon)
	actor.get_node("Body").set_action("flick")
	game.play_sound("shoot_roller", actor.global_position)
	return true

func begin_twins(actor: Node3D, direction: Vector3) -> void:
	var preview := Node3D.new()
	add_child(preview)
	for side in [-1.0, 1.0]:
		var model := preload("res://ink_disc_mesh.gd").make(game.actor_team(actor), 0.75)
		preview.add_child(model)
		model.position = Vector3(side * 0.95, 1.1, 0)
	windups[actor.get_instance_id()] = {"owner": actor, "direction": direction.normalized(), "time": 0.4, "visual": preview}
	combat._ability_ring(actor.global_position, 2.0, 0.4, game.actor_team(actor))
	actor.get_node("Body").set_action("flick")

func winding_up(actor: Node3D) -> bool:
	return windups.has(actor.get_instance_id())

func _spawn(actor: Node3D, at: Vector3, direction: Vector3, special: bool, weapon: Dictionary) -> void:
	combat.report_attack(actor, game.actor_team(actor))
	var radius := 1.05 if special else 0.46
	var model := preload("res://ink_disc_mesh.gd").make(game.actor_team(actor), radius)
	add_child(model)
	model.global_position = at
	flights.append({"owner": actor, "team": game.actor_team(actor), "special": special,
		"visual": model, "direction": direction, "speed": 24.0 if special else 28.0,
		"reach": 20.0 if special else float(weapon.range), "radius": radius,
		"age": 0.0, "distance": 0.0, "paint": 0.0, "returning": false,
		"hits": {}, "weapon": weapon.duplicate(true), "origin": at})

func tick(delta: float) -> void:
	for key in windups.keys():
		var w: Dictionary = windups[key]
		w.time -= delta
		w.visual.global_position = w.owner.global_position
		w.visual.rotation.y += delta * 8
		if not game.actor_alive(w.owner) or game.phase != "playing":
			w.visual.queue_free()
			windups.erase(key)
		elif w.time <= 0:
			var direction: Vector3 = w.direction
			var right := direction.cross(Vector3.UP).normalized()
			for side in [-1.0, 1.0]:
				_spawn(w.owner, w.owner.global_position + Vector3.UP * 1.05 + right * side * 0.72, direction, true, combat.weapons.disc)
			game.play_sound("special_slam", w.owner.global_position)
			w.visual.queue_free()
			windups.erase(key)
	for index in range(flights.size() - 1, -1, -1):
		var disc: Dictionary = flights[index]
		if game.phase != "playing":
			_remove(index)
			continue
		disc.age += delta
		var start: Vector3 = disc.visual.global_position
		if disc.returning:
			var home: Vector3 = disc.owner.global_position + Vector3.UP * 1.05
			if start.distance_to(home) <= disc.speed * delta + 0.3:
				_remove(index)
				continue
			disc.direction = (home - start).normalized()
		var step: Vector3 = disc.direction * disc.speed * delta
		if not disc.returning:
			step = step.limit_length(maxf(0, float(disc.reach) - float(disc.distance)))
		var finish := start + step
		var hit := _wall_hit(start, finish, disc.radius, disc.team)
		if not hit.is_empty():
			finish = start.lerp(finish, hit.fraction)
			combat.damage_cover_hit(hit, 85.0 if disc.special else float(disc.weapon.damage), disc.team)
		_hits(disc, start, finish)
		var travelled := start.distance_to(finish)
		disc.distance += travelled
		disc.paint += travelled
		if disc.paint >= 0.8:
			disc.paint = 0.0
			var down := PhysicsRayQueryParameters3D.create(finish, finish - Vector3.UP * 3.5, 1)
			var ground := get_world_3d().direct_space_state.intersect_ray(down)
			if not ground.is_empty():
				combat._paint_team(ground.position + ground.normal * 0.1, disc.team, 1.05 if disc.special else 0.65, randf(), Vector3.ZERO, 0.0, disc.owner)
		disc.visual.global_position = finish
		disc.visual.rotation.y += delta * 24
		var expired: bool = disc.age >= (1.3 if disc.special else 2.5)
		if disc.special:
			if expired or not hit.is_empty() or disc.distance >= float(disc.reach) - 0.001:
				_remove(index)
		elif expired or (disc.returning and not hit.is_empty()):
			_remove(index)
		elif not disc.returning and (not hit.is_empty() or disc.distance >= float(disc.reach) - 0.001):
			disc.returning = true
			disc.hits.clear()
			disc.visual.global_position -= disc.direction * 0.04

func _hits(disc: Dictionary, start: Vector3, finish: Vector3) -> void:
	for victim in game.enemies(disc.team):
		var key: int = victim.get_instance_id()
		if disc.hits.has(key):
			continue
		var height: float = combat.weapon_data.player.height
		if (victim == combat.walker and combat.walker.squid_form) or bool(victim.get_meta("enemy_swimming", false)):
			height = combat.weapon_data.player.squidHeight
		var hit: Dictionary = combat._segment_actor_hit(start, finish, disc.radius, victim.global_position, height)
		if hit.is_empty():
			continue
		disc.hits[key] = true
		var amount := 85.0 if disc.special else (float(disc.weapon.returnDamage) if disc.returning else float(disc.weapon.damage))
		game.damage_actor(victim, amount, disc.team, disc.owner, "twin_discs" if disc.special else "disc", "潜墨" if height < 1.0 else "躯干", (disc.origin as Vector3).distance_to(hit.point))

func _wall_hit(start: Vector3, finish: Vector3, radius: float, team: int) -> Dictionary:
	var nearest := {}
	var right := (finish - start).cross(Vector3.UP).normalized() * radius
	# Sweep both edges and vertical thickness as well as the centre. Wide discs
	# cannot pass a wall just because their centre ray missed its edge.
	for offset in [Vector3.ZERO, right, -right, Vector3.UP * 0.08, -Vector3.UP * 0.08]:
		var query := PhysicsRayQueryParameters3D.create(start + offset, finish + offset, combat.world_mask(team))
		query.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var fraction: float = (start + offset).distance_to(hit.position) / maxf(0.0001, start.distance_to(finish))
		if nearest.is_empty() or fraction < float(nearest.fraction):
			hit.fraction = fraction
			nearest = hit
	return nearest

func _remove(index: int) -> void:
	flights[index].visual.queue_free()
	flights.remove_at(index)
