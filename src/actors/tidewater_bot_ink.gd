extends RefCounted

# Low-ink decisions read CPU ownership and the existing navigation graph.
# They never paint, refill a tank, move an actor or inspect hidden opponents.
const LOW := .2
const READY := .6
const SEARCH_RADIUS := 8.0
const MAX_PATH := 16.0
var active := false
var retry := 0.0
var goal := Vector3.INF
var path := PackedVector3Array()

func reset() -> void:
	active = false
	retry = 0
	goal = Vector3.INF
	path.clear()

func plan(actor: Node3D, delta: float) -> Dictionary:
	var game: Node3D = actor.game
	var cap: float = game.actor_ink_max(actor)
	if active and actor.ink_amount >= cap * READY:
		reset()
	# Airborne movement/affordable shooting stays with the normal actor path.
	# A floor is required before starting or servicing a refill decision.
	if actor.team_mover == null or not actor.team_mover.is_on_floor():return {}
	if not active and actor.ink_amount <= cap * LOW:
		active = true
	if not active or game.phase != "playing" or game.paused or not game.actor_alive(actor):
		return {}
	if game.wings.busy(actor) or game.mobility.busy(actor) or game.bot_deployment.busy(actor) or game.bot_specials.busy(actor) or game.get_node("Combat").canopy.holding(actor):
		return {}
	if actor.team_mover.is_on_floor() and actor.floor_ink_owner() == actor.team:
		return {"stop":true,"swim":true}
	retry -= delta
	# Enemy repaint or an invalid support cancels the destination immediately.
	if goal != Vector3.INF and actor.ink_owner_at(goal) != actor.team:
		goal = Vector3.INF
		path.clear()
		retry = 0
	if retry <= 0:
		retry = .9 + float(actor.slot) * .04
		path = _friendly_route(actor)
		goal = path[-1] if not path.is_empty() else Vector3.INF
	# No suitable local route: stop spending ink and use normal delayed refill.
	return {"stop":path.is_empty(),"swim":false,"route":path}

func _friendly_route(actor: Node3D) -> PackedVector3Array:
	var nav: RefCounted = actor.game.navigation
	var graph: AStar3D = nav.graphs[actor.team]
	var nearby: Array[Dictionary] = []
	for node in nav.nodes:
		var id := int(node.id)
		if not graph.has_point(id) or graph.is_point_disabled(id):continue
		var point := graph.get_point_position(id)
		var distance := point.distance_to(actor.global_position)
		if distance <= SEARCH_RADIUS:
			nearby.append({"point":point,"distance":distance})
	nearby.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return a.distance < b.distance)
	var routes_tried := 0
	# Bound dynamic physics/AStar work. The fallback above still restores ink
	# when no candidate in this local sample can be reached.
	for candidate in nearby.slice(0,64):
		var point: Vector3 = candidate.point
		if actor.ink_owner_at(point) != actor.team:continue
		var found: PackedVector3Array = nav.route(actor.global_position,point,actor.team)
		routes_tried += 1
		if not found.is_empty() and found[0].distance_to(actor.global_position) <= 3 and found[-1].distance_to(point) < .3:
			var length := actor.global_position.distance_to(found[0])
			for i in range(1,found.size()):length += found[i-1].distance_to(found[i])
			if length <= MAX_PATH:return found
		if routes_tried >= 4:break
	return PackedVector3Array()
