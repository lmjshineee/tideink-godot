extends Node3D

const COST := 30.0
const HEALTH := 25.0
const LIFE := 30.0
const ARM := .8
const FUSE := .45
const TRIGGER := 2.2
const BLAST := 3.0
var game: Node3D
var mines: Dictionary = {}
var serial := 0
var casts_total := 0
var triggered_total := 0
var explosions_total := 0

func setup(owner_game: Node3D) -> void: game = owner_game

func place(actor: Node3D) -> bool:
	var tank: Node = game.get_node("Combat") if actor == game.get_node("World/Walker") else actor
	if float(tank.ink_amount) < COST: return false
	var from := actor.global_position
	var checked: Dictionary = game.deployment.landing(Vector2(from.x,from.z),false,from.y,game.actor_team(actor),actor)
	if checked.is_empty() or absf(checked.point.y - from.y) > .25: return false
	var owned := []
	for id in mines:
		if mines[id].owner == actor:
			if mines[id].point.distance_to(checked.point) < .8: return false
			owned.append(id)
	if owned.size() >= 2: _remove(owned[0])
	serial += 1
	var team: int = game.actor_team(actor)
	var body := StaticBody3D.new(); body.collision_mask = 0; body.collision_layer = 1024 if team == 0 else 2048
	body.set_meta("mine_key",serial)
	var shape := CollisionShape3D.new(); var cylinder := CylinderShape3D.new()
	cylinder.radius = .36; cylinder.height = .22; shape.shape = cylinder; shape.position.y = .11; body.add_child(shape)
	add_child(body); body.global_position = checked.point
	var mesh := preload("res://ink_equipment_mesh.gd")
	var color: Color = preload("res://team_palette.gd").color(team)
	mesh.rod(body,Vector3(0,.04,0),Vector3(0,.18,0),.34,mesh.material(Color("283045"),.5))
	var ring := MeshInstance3D.new(); var torus := TorusMesh.new(); torus.inner_radius = .25; torus.outer_radius = .32
	ring.mesh = torus; ring.position.y = .18; ring.material_override = mesh.material(color.lightened(.25)); body.add_child(ring)
	for angle in [0,TAU/3,TAU*2/3]:
		mesh.rod(body,Vector3.ZERO,Vector3(sin(angle)*.46,.025,cos(angle)*.46),.045,mesh.material(color))
	var warning := MeshInstance3D.new(); var circle := TorusMesh.new(); circle.inner_radius = TRIGGER-.025; circle.outer_radius = TRIGGER+.025; circle.rings = 48
	warning.mesh = circle; warning.material_override = mesh.material(color.lightened(.4)); warning.position.y = .035; body.add_child(warning)
	warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mines[serial] = {"owner":actor,"team":team,"point":checked.point,"visual":body,"ring":ring,"warning":warning,"health":HEALTH,"time":LIFE,"arm":ARM,"fuse":-1.0}
	tank.ink_amount -= COST; tank.last_fire_time = 0.0; casts_total += 1
	actor.set_meta("mine_casts",int(actor.get_meta("mine_casts",0))+1)
	return true

func tick(delta: float) -> void:
	var combat := game.get_node("Combat")
	for id in mines.keys():
		if not mines.has(id): continue
		var m: Dictionary = mines[id]
		m.time -= delta; m.arm -= delta
		if m.time <= 0: _remove(id); continue
		m.warning.visible = m.team == 0 or m.fuse >= 0
		m.ring.scale = Vector3.ONE * (1.0 + .07 * sin(m.time * (30 if m.fuse >= 0 else 4)))
		if m.fuse >= 0:
			m.fuse -= delta
			if m.fuse <= 0: _explode(m); _remove(id)
			continue
		if m.arm > 0: continue
		var origin: Vector3 = m.point + Vector3.UP * .2
		for enemy in game.enemies(m.team):
			var to: Vector3 = game.intel.point(enemy)
			if origin.distance_to(to) <= TRIGGER and combat._unblocked(origin,to):
				m.fuse = FUSE; m.warning.visible = true; triggered_total += 1
				combat._ability_ring(m.point,BLAST,FUSE,m.team)
				game.play_sound("special_activate",m.point)
				break

func _explode(m: Dictionary) -> void:
	var combat := game.get_node("Combat")
	var at: Vector3 = m.point + Vector3.UP * .22
	explosions_total += 1
	combat._add_burst(at,m.team,BLAST); game.play_sound("bomb_explode",at)
	combat._paint_team(m.point + Vector3.UP * .04,m.team,2.0,randf(),Vector3.ZERO,0,m.owner)
	# Mines do not chain through each other: damage to devices safely disarms them.
	combat.damage_cover_area(at,BLAST,50,m.team)
	for enemy in game.enemies(m.team):
		var to: Vector3 = game.intel.point(enemy)
		var gap := at.distance_to(to)
		if gap <= BLAST and combat._unblocked(at,to):
			game.intel.tag(enemy,m.team)
			game.damage_actor(enemy,lerpf(50,25,gap/BLAST),m.team,m.owner,"mine","溅射")

func damage_hit(hit: Dictionary, amount: float, team: int) -> bool:
	if hit.is_empty() or not hit.collider.has_meta("mine_key"): return false
	var id: int = hit.collider.get_meta("mine_key")
	if not mines.has(id) or mines[id].team == team: return false
	mines[id].health -= maxf(0,amount)
	game.get_node("Combat").feedback.emit("hit",mines[id].point + Vector3.UP * .15,team)
	if mines[id].health <= 0: _remove(id)
	return true

func damage_area(at: Vector3, radius: float, amount: float, team: int) -> void:
	for id in mines.keys():
		var m: Dictionary = mines[id]
		var to: Vector3 = m.point + Vector3.UP * .15
		if m.team != team and at.distance_to(to) <= radius and game.get_node("Combat")._unblocked(at,to): damage_hit({"collider":m.visual},amount,team)

func escape(actor: Node3D) -> Vector3:
	for m in mines.values():
		if m.team == game.actor_team(actor) or not game.intel.visible_point(m.point + Vector3.UP * .15,game.actor_team(actor)): continue
		var offset: Vector3 = actor.global_position - m.point
		if absf(offset.y) < 1.5 and Vector2(offset.x,offset.z).length() < BLAST + .5:
			offset.y = 0
			return (offset.normalized() if offset.length() > .1 else Vector3.RIGHT) * 6
	return Vector3.ZERO

func _remove(id: int) -> void:
	if not mines.has(id): return
	mines[id].visual.collision_layer = 0; mines[id].visual.queue_free(); mines.erase(id)

func clear_all() -> void:
	for id in mines.keys(): _remove(id)
