extends Node3D

# Three announced volleys, launched from the real bow. Nothing spawns beyond
# a wall or roof; each ballistic segment collides before applying an impact.
const RANGE := 24.0
const GRAVITY := 24.0
const WINDUP := .6
const INTERVAL := .45
const RADIUS := 2.4
const WAVE_CAP := 45.0
var game: Node3D
var combat: Node3D
var casts: Dictionary = {}
var zones: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var casts_total := 0
var volleys_total := 0

func setup(owner_game: Node3D, owner_combat: Node3D) -> void:
	game = owner_game; combat = owner_combat

func target(actor: Node3D, desired: Vector3) -> Dictionary:
	var from := actor.global_position + Vector3.UP * 1.05
	if from.distance_to(desired) > RANGE + .1: return {}
	var ray := PhysicsRayQueryParameters3D.create(desired + Vector3.UP * .15, desired - Vector3.UP * 4, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < .68: return {}
	var at: Vector3 = hit.position
	if from.distance_to(at) > RANGE + .1 or not game.get_node("World/Map").map_bounds.has_point(Vector2(at.x,at.z)): return {}
	if not combat._unblocked(from, at + Vector3.UP * .15): return {}
	return {"point":at}

func begin(actor: Node3D, desired: Vector3) -> bool:
	if busy(actor) or not game.actor_alive(actor): return false
	var checked := target(actor, desired)
	if checked.is_empty(): return false
	var marker := MeshInstance3D.new()
	var mesh := TorusMesh.new(); mesh.inner_radius = RADIUS - .06; mesh.outer_radius = RADIUS + .06; mesh.rings = 48
	marker.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = preload("res://team_palette.gd").color(game.actor_team(actor)).lightened(.3)
	marker.material_override = mat; marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker); marker.global_position = checked.point + Vector3.UP * .06
	var zone := {"team":game.actor_team(actor),"point":checked.point,"visual":marker,"time":4.0}
	zones.append(zone)
	casts[actor.get_instance_id()] = {"owner":actor,"team":game.actor_team(actor),"point":checked.point,"next":WINDUP,"wave":0,"marker":marker,"zone":zone}
	casts_total += 1
	actor.set_meta("rain_casts",int(actor.get_meta("rain_casts",0))+1)
	actor.get_node("Body").set_action("shoot")
	return true

func busy(actor: Node3D) -> bool: return casts.has(actor.get_instance_id())

func tick(delta: float) -> void:
	for i in range(zones.size()-1,-1,-1):
		zones[i].time -= delta
		if zones[i].time <= 0: zones[i].visual.queue_free(); zones.remove_at(i)
	for key in casts.keys():
		var s: Dictionary = casts[key]
		if not game.actor_alive(s.owner): cancel(s.owner); continue
		s.next -= delta
		s.marker.scale = Vector3.ONE * (1.0 + .025 * sin(s.next * 24))
		if s.next <= 0:
			_fire(s); s.wave += 1; s.next += INTERVAL
			if s.wave >= 3: cancel(s.owner)
	for i in range(arrows.size()-1,-1,-1):
		var a: Dictionary = arrows[i]
		var start: Vector3 = a.visual.global_position
		# Exact integration of constant gravity avoids frame-rate-dependent landings.
		var end: Vector3 = start + a.velocity * delta - Vector3.UP * GRAVITY * delta * delta * .5
		a.velocity.y -= GRAVITY * delta; a.age += delta
		var ray := PhysicsRayQueryParameters3D.create(start,end,combat.world_mask(a.team)); ray.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		var body: Dictionary = combat._segment_team_hit(start,end,.07,a.team)
		var stop := end
		if not hit.is_empty(): stop = hit.position
		if not body.is_empty() and start.distance_to(body.point) < start.distance_to(stop): stop = body.point
		if combat.counter.consume(start,stop,a.team,28.0):
			a.visual.queue_free(); arrows.remove_at(i); continue
		var done := false
		if not body.is_empty() and (hit.is_empty() or body.distance < start.distance_to(hit.position)):
			_damage(a,body.actor,28,"躯干"); _impact(a,body.point,Vector3.UP,body.actor); done = true
		elif not hit.is_empty():
			combat.damage_cover_hit(hit,28,a.team)
			_impact(a,hit.position + hit.normal * .04,hit.normal); done = true
		elif a.age > 3 or end.y < float(combat.weapon_data.player.waterY) - 2: done = true
		if done:
			a.visual.queue_free(); arrows.remove_at(i)
		else:
			a.visual.global_position = end
			a.visual.basis = Basis.looking_at(a.velocity.normalized(),Vector3.RIGHT if absf(a.velocity.normalized().y) > .99 else Vector3.UP,true)

func _fire(s: Dictionary) -> void:
	var from: Vector3 = s.owner.global_position + Vector3.UP * 1.05
	var budget := {"hits":{}}
	# A rotated 3x3 footprint makes the second wave cover the first wave's gaps.
	var turn := Basis(Vector3.UP, .35 * int(s.wave))
	for x in [-1,0,1]:
		for z in [-1,0,1]:
			var destination: Vector3 = s.point + turn * Vector3(x * 1.55,.1,z * 1.55)
			var flight := clampf(from.distance_to(destination) / 17.0,1.0,1.7)
			var velocity := (destination-from)/flight + Vector3.UP * GRAVITY * flight * .5
			var visual := preload("res://ink_equipment_mesh.gd").bolt(s.team)
			visual.scale = Vector3.ONE * 1.3; add_child(visual); visual.global_position = from
			visual.basis = Basis.looking_at(velocity.normalized(),Vector3.UP,true)
			arrows.append({"owner":s.owner,"team":s.team,"visual":visual,"velocity":velocity,"age":0.0,"budget":budget})
	volleys_total += 1; combat.report_attack(s.owner,s.team)
	game.play_sound("shoot_charger",from)

func _damage(a: Dictionary, actor: Node3D, amount: float, region: String = "溅射") -> void:
	var id := actor.get_instance_id()
	var spent := float(a.budget.hits.get(id,0))
	var factor := float(game.perks.outgoing(a.owner))
	amount = minf(amount,maxf(0,WAVE_CAP-spent)/factor)
	a.budget.hits[id] = spent + amount * factor
	if amount > 0:
		# Death splats also paint through the game's general damage path.
		var charge: bool = game.charge_special
		game.charge_special = false
		game.damage_actor(actor,amount,a.team,a.owner,"rain_arrows",region)
		game.charge_special = charge

func _impact(a: Dictionary, at: Vector3, normal: Vector3, direct: Node3D = null) -> void:
	combat._add_burst(at,a.team,.65)
	var charge: bool = game.charge_special
	game.charge_special = false
	game.paint_at_world(at,a.team,.75,randf(),Vector3.ZERO,0,a.owner)
	game.charge_special = charge
	combat.damage_cover_area(at,1.15,28,a.team)
	for enemy in game.enemies(a.team):
		if enemy == direct: continue
		var to: Vector3 = enemy.global_position + Vector3.UP * .8
		var gap := at.distance_to(to)
		if gap <= 1.15 and combat._unblocked(at + normal * .02,to,a.team):
			_damage(a,enemy,lerpf(28,14,gap/1.15))

func cancel(actor: Node3D) -> void:
	var key := actor.get_instance_id()
	if not casts.has(key): return
	var s: Dictionary = casts[key]
	if s.wave == 0:
		s.marker.queue_free(); zones.erase(s.zone)
	else:
		s.zone.time = minf(s.zone.time,2.0)
	casts.erase(key)

func escape(actor: Node3D) -> Vector3:
	for s in zones:
		if s.team == game.actor_team(actor) or not game.intel.visible_point(s.point + Vector3.UP * .15,game.actor_team(actor)): continue
		var offset: Vector3 = actor.global_position - s.point
		if absf(offset.y) < 1.5 and Vector2(offset.x,offset.z).length() < RADIUS + 1:
			offset.y = 0
			return (offset.normalized() if offset.length() > .1 else Vector3.RIGHT) * 6
	return Vector3.ZERO

func clear_all() -> void:
	for s in zones: s.visual.queue_free()
	zones.clear()
	casts.clear()
	for a in arrows: a.visual.queue_free()
	arrows.clear()
