extends Node3D

const COST := 40.0
const HEALTH := 60.0
const LIFETIME := 8.0
const RADIUS := 12.0
const SPEED := 16.0
var game: Node3D
var stations: Dictionary = {}

func setup(owner_game: Node3D) -> void: game = owner_game

func place(actor: Node3D) -> bool:
	var tank: Node = game.get_node("Combat") if actor == game.get_node("World/Walker") else actor
	if float(tank.ink_amount) < COST: return false
	var at := actor.global_position
	var checked: Dictionary = game.deployment.landing(Vector2(at.x, at.z), false, at.y, game.actor_team(actor), actor)
	if checked.is_empty() or absf(float(checked.point.y) - at.y) > .25: return false
	var key := actor.get_instance_id()
	_remove(key)
	var team: int = game.actor_team(actor)
	var body := StaticBody3D.new()
	body.collision_layer = 256 if team == 0 else 512
	body.collision_mask = 0
	body.set_meta("sonar_key", key)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = .3; cylinder.height = .95
	shape.shape = cylinder; shape.position.y = .475; body.add_child(shape)
	add_child(body); body.global_position = checked.point
	var mesh := preload("res://src/combat/ink_equipment_mesh.gd")
	var color: Color = preload("res://src/core/team_palette.gd").color(team)
	mesh.rod(body, Vector3(0, .12, 0), Vector3(0, .68, 0), .17, mesh.material(color.darkened(.4)))
	mesh.rod(body, Vector3(0, .68, 0), Vector3(0, .98, 0), .045, mesh.material(Color.WHITE))
	var dish := MeshInstance3D.new()
	var torus := TorusMesh.new(); torus.inner_radius = .16; torus.outer_radius = .31
	dish.mesh = torus; dish.position.y = .66
	dish.material_override = _material(color, false); body.add_child(dish)
	var wave := MeshInstance3D.new()
	var ring := TorusMesh.new(); ring.inner_radius = .96; ring.outer_radius = 1.04; ring.rings = 48
	wave.mesh = ring; wave.material_override = _material(color.lightened(.3), true)
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wave); wave.global_position = checked.point + Vector3.UP * .12; wave.visible = false
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new(); sphere.radius = 1; sphere.height = 2; sphere.radial_segments = 32; sphere.rings = 16
	shell.mesh = sphere; shell.material_override = _material(color, true)
	shell.material_override.albedo_color.a = .055
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell); shell.global_position = checked.point + Vector3.UP * .75; shell.visible = false
	stations[key] = {"owner": actor, "team": team, "point": checked.point, "visual": body,
		"wave": wave, "shell": shell, "dish": dish, "health": HEALTH, "time": LIFETIME, "next": .4, "radius": -1.0, "hits": {}}
	tank.ink_amount -= COST; tank.last_fire_time = 0.0
	return true

func _material(color: Color, translucent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if translucent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = .65
	return material

func tick(delta: float) -> void:
	for key in stations.keys():
		var station: Dictionary = stations[key]
		station.time -= delta; station.next -= delta
		station.dish.rotation.z += delta * 1.5
		if float(station.time) <= 0: _remove(key); continue
		if float(station.next) <= 0:
			station.next += 2.0; station.radius = 0.0; station.hits.clear()
		if float(station.radius) < 0: continue
		var before: float = station.radius
		station.radius = minf(RADIUS, before + SPEED * delta)
		station.shell.visible = true
		station.shell.scale = Vector3.ONE * maxf(.02, station.radius)
		station.wave.visible = true
		station.wave.scale = Vector3(maxf(.02, station.radius), .04, maxf(.02, station.radius))
		game.items.decoys.scan(station.point+Vector3.UP*.75,before,station.radius,station.team)
		for enemy in game.enemies(station.team):
			var target: Vector3 = game.intel.point(enemy)
			var origin: Vector3 = station.point + Vector3.UP * .75
			var distance := origin.distance_to(target)
			var id: int = enemy.get_instance_id()
			if distance <= float(station.radius) and distance >= before - .5 and not station.hits.has(id):
				station.hits[id] = true
				if game.get_node("Combat")._unblocked(origin, target): game.intel.tag(enemy, station.team)
		if float(station.radius) >= RADIUS: station.radius = -1.0; station.wave.visible = false; station.shell.visible = false

func damage_hit(hit: Dictionary, amount: float, team: int) -> bool:
	if hit.is_empty() or not hit.collider.has_meta("sonar_key"): return false
	var key: int = hit.collider.get_meta("sonar_key")
	if not stations.has(key) or int(stations[key].team) == team: return false
	stations[key].health -= maxf(0, amount)
	game.get_node("Combat").feedback.emit("hit", stations[key].point + Vector3.UP * .6, team)
	if float(stations[key].health) <= 0: _remove(key)
	return true

func damage_area(at: Vector3, radius: float, amount: float, team: int) -> void:
	for key in stations.keys():
		var station: Dictionary = stations[key]
		var target: Vector3 = station.point + Vector3.UP * .5
		if int(station.team) != team and at.distance_to(target) <= radius and game.get_node("Combat")._unblocked(at, target):
			damage_hit({"collider": station.visual}, amount, team)

func _remove(key: int) -> void:
	if stations.has(key):
		stations[key].visual.collision_layer = 0
		stations[key].visual.queue_free(); stations[key].wave.queue_free(); stations[key].shell.queue_free(); stations.erase(key)

func clear_all() -> void:
	for key in stations.keys(): _remove(key)
