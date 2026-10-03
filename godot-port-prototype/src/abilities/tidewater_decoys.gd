extends Node3D
# Fake contacts stay outside the real roster, damage/score and special-charge paths.
const COST := 25.0
const LIFE := 8.0
var game: Node3D
var decoys: Dictionary = {}
var serial := 0
var casts_total := 0
var fooled_total := 0
var revealed_total := 0
func setup(owner_game: Node3D) -> void: game = owner_game

func target(actor: Node3D, desired: Vector3) -> Dictionary:
	var from := actor.global_position + Vector3.UP * .8
	if actor.global_position.distance_to(desired) > 8.5: return {}
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(desired+Vector3.UP*.15,desired-Vector3.UP*4,1))
	if hit.is_empty() or hit.normal.y < .68: return {}
	var at: Vector3 = hit.position
	if actor.global_position.distance_to(at) > 8 or not game.get_node("World/Map").map_bounds.has_point(Vector2(at.x,at.z)): return {}
	if not game.get_node("Combat")._unblocked(from,at+Vector3.UP*.15): return {}
	var shape := CapsuleShape3D.new(); shape.radius = .34; shape.height = 1.45
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.collision_mask = 1
	query.transform = Transform3D(Basis(),at+Vector3.UP*.76)
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return {}
	return {"point":at}

func place(actor: Node3D) -> bool:
	var combat := game.get_node("Combat")
	var local := actor == game.get_node("World/Walker")
	var tank: Node = combat if local else actor
	if tank.ink_amount < COST: return false
	var desired: Vector3
	if local: desired = combat._aim_target(actor.global_position+Vector3.UP,8)
	else:
		var info: Dictionary = game.intel.nearest_contact(actor)
		if info.is_empty(): return false
		desired = actor.global_position + (info.point-actor.global_position).limit_length(7.5)
	var checked := target(actor,desired)
	if checked.is_empty(): return false
	for id in decoys.keys():
		if decoys[id].owner == actor: _remove(id)
	serial += 1
	var team: int = game.actor_team(actor)
	var body := StaticBody3D.new(); body.collision_mask = 0; body.collision_layer = 4096 if team == 0 else 8192
	body.set_meta("decoy_key",serial)
	var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius = .34; capsule.height = 1.45
	shape.shape = capsule; shape.position.y = .725; body.add_child(shape)
	add_child(body); body.global_position = checked.point
	var visual: Node3D = preload("res://src/actors/tidewater_character_visual.gd").new()
	visual.team = team; visual.style_index = actor.get_node("Body").style_index; visual.ornament_seed = actor.get_node("Body").ornament_seed
	body.add_child(visual); visual.configure_animation(combat.weapon_data.player)
	visual.set_form(false); visual.set_weapon(combat.selected_id if local else actor.weapon_id); visual.set_aim(true)
	var offset: Vector3 = checked.point-actor.global_position
	visual.rotation.y = atan2(offset.x,offset.z)
	var label := Label3D.new(); label.text = "回声诱饵"; label.font = preload("res://src/ui/ui_fonts.gd").font(); label.font_size = 34
	label.position.y = 1.9; label.pixel_size = .006; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; body.add_child(label)
	decoys[serial] = {"id":serial,"owner":actor,"team":team,"point":checked.point,"visual":body,"body":visual,"label":label,"health":20.0,"time":LIFE,"pulse":0.0,"revealed":[false,false],"contacts":[{},{}]}
	tank.ink_amount -= COST; tank.last_fire_time = 0.0; casts_total += 1
	actor.set_meta("decoy_casts",int(actor.get_meta("decoy_casts",0))+1)
	_update_visual(decoys[serial])
	return true

func visible_to(actor: Node3D, d: Dictionary) -> bool:
	var from: Vector3 = game.intel.point(actor); var to: Vector3 = d.point+Vector3.UP*.85
	return from.distance_to(to) <= 30 and game.get_node("Combat")._unblocked(from,to) and not game.items.mist.obscures(from,to,game.actor_team(actor))

func target_for(actor: Node3D, limit: float) -> Dictionary:
	var found := {}; var best := limit; var team: int = game.actor_team(actor)
	for d in decoys.values():
		var gap := actor.global_position.distance_to(d.point)
		if d.team != team and not d.revealed[team] and gap < best and visible_to(actor,d): found = d; best = gap
	return found

func scan(origin: Vector3, before: float, radius: float, team: int) -> void:
	for d in decoys.values():
		var to: Vector3 = d.point+Vector3.UP*.85; var gap := origin.distance_to(to)
		if d.team != team and not d.revealed[team] and gap >= before-.5 and gap <= radius and game.get_node("Combat")._unblocked(origin,to):
			d.revealed[team] = true; revealed_total += 1; _update_visual(d)

func tick(delta: float) -> void:
	for id in decoys.keys():
		var d: Dictionary = decoys[id]; d.time -= delta; d.pulse -= delta
		if d.time <= 0: _remove(id); continue
		_update_visual(d)
		if d.pulse <= 0:
			d.pulse += .9; d.body.set_action("shoot"); game.play_sound("shoot_shooter",d.point+Vector3.UP)
		for team in [0,1]:
			var contact: Dictionary = d.contacts[team]
			if d.team == team or game.intel.visible_point(d.point+Vector3.UP*.85,team):
				d.contacts[team] = {"point":d.point,"yaw":d.body.rotation.y,"time":1.5,"status":"seen"}
			elif not contact.is_empty():
				contact.time -= delta; contact.status = "last"
				if contact.time <= 0: d.contacts[team] = {}

func marks_for(team: int) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	for d in decoys.values():
		var info: Dictionary = d.contacts[team]
		if info.is_empty(): continue
		marks.append({"point":info.point,"yaw":info.yaw,"team":d.team,"known":d.team==team or d.revealed[team],"status":info.status,"owner_id":game.actor_id(d.owner),"name":game.actor_name(d.owner)})
	return marks

func _update_visual(d: Dictionary) -> void:
	var known: bool = d.team == 0 or d.revealed[0]
	var seen: bool = d.team == 0 or visible_to(game.get_node("World/Walker"),d)
	d.body.visible = seen; d.label.visible = seen
	d.label.text = "回声诱饵" if known else "#%02d %s" % [game.actor_id(d.owner),game.actor_name(d.owner)]
	_transparency(d.body,.35 if known else 0.0)
func _transparency(node: Node, amount: float) -> void:
	if node is GeometryInstance3D: node.transparency = amount
	for child in node.get_children(): _transparency(child,amount)

func damage_hit(hit: Dictionary, amount: float, team: int) -> bool:
	if hit.is_empty() or not hit.collider.has_meta("decoy_key"): return false
	var id: int = hit.collider.get_meta("decoy_key")
	if not decoys.has(id) or decoys[id].team == team: return false
	decoys[id].health -= maxf(0,amount)
	game.get_node("Combat").feedback.emit("hit",decoys[id].point+Vector3.UP*.8,team)
	if decoys[id].health <= 0: _remove(id)
	return true
func damage_area(at: Vector3, radius: float, amount: float, team: int) -> void:
	for id in decoys.keys():
		var d: Dictionary = decoys[id]; var to: Vector3 = d.point+Vector3.UP*.8
		if d.team != team and at.distance_to(to) <= radius and game.get_node("Combat")._unblocked(at,to): damage_hit({"collider":d.visual},amount,team)
func _remove(id: int) -> void:
	if not decoys.has(id): return
	decoys[id].visual.collision_layer = 0; decoys[id].visual.queue_free(); decoys.erase(id)
func clear_all() -> void:
	for id in decoys.keys(): _remove(id)
