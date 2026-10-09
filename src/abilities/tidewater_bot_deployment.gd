extends Node3D

# Only a completed bot respawn arms this choice. Failed/unsafe choices leave
# normal navigation in charge. This never selects a destination for the player.
const WINDUP := 1.0
const COOLDOWN := 4.0
const CHOICE_WINDOW := 3.0
const BASE_RADIUS := 6.0
const MIN_TRAVEL := 12.0
const Palette := preload("res://src/core/team_palette.gd")
var game: Node3D
var states: Dictionary = {}
var completed := 0
var fallbacks := 0
var started := 0

func setup(owner_game: Node3D) -> void:
	game = owner_game
	for actor in game.all_actors():
		if actor != game.get_node("World/Walker"):
			states[actor.get_instance_id()] = {"actor":actor,"pending":false,"window":0.0,
				"active":false,"flying":false,"time":0.0,"cooldown":0.0,"marker":null}

func state(actor: Node3D) -> Dictionary:
	return states.get(actor.get_instance_id(),{})

func busy(actor: Node3D) -> bool:
	return bool(state(actor).get("active",false))

func base_position(actor: Node3D) -> Vector3:
	return game.get_node("World/Map").spawn_pads[game.actor_team(actor)]+Vector3.UP*.05

func on_respawn(actor: Node3D) -> void:
	cancel(actor)
	var s := state(actor)
	if s.is_empty(): return
	s.pending = true
	s.window = CHOICE_WINDOW

func cancel(actor: Node3D) -> void:
	var s := state(actor)
	if s.is_empty(): return
	if s.active:
		s.cooldown = COOLDOWN
		actor.get_node("Body").set_form(false)
		actor.team_mover.velocity = Vector3.ZERO
		actor.repath_time = 0.0
	if is_instance_valid(s.marker): s.marker.queue_free()
	s.marker = null
	s.active = false
	s.flying = false
	s.pending = false

func clear_all() -> void:
	for s in states.values(): cancel(s.actor)

func tick(delta: float) -> void:
	if game.phase!="playing" or game.paused: return
	for s in states.values(): s.cooldown=maxf(0,float(s.cooldown)-delta)

func _eligible(actor: Node3D) -> bool:
	if game.phase != "playing" or game.paused or not game.actor_alive(actor): return false
	if busy(actor) or float(state(actor).get("cooldown",0)) > 0: return false
	if actor.global_position.distance_to(base_position(actor)) > BASE_RADIUS: return false
	if game.actor_health(actor) < game.actor_max_health(actor)*.6 or actor.ink_amount < 20: return false
	if game.mobility.busy(actor) or game.wings.busy(actor) or game.bot_specials.busy(actor): return false
	if absf(actor.team_mover.velocity.y)>1.2: return false
	var ground: Dictionary = game.deployment.landing(Vector2(actor.global_position.x,actor.global_position.z),false,actor.global_position.y,game.actor_team(actor),actor)
	if ground.is_empty() or absf(ground.point.y-actor.global_position.y)>.3: return false
	var contact: Dictionary = game.intel.nearest_contact(actor)
	return contact.is_empty() or actor.global_position.distance_to(contact.point)>12

func _safe(point: Vector3, team: int) -> bool:
	# Frozen/sonar/visible team contacts only; no hidden opponent coordinates.
	for enemy in game.enemies(team):
		var info: Dictionary = game.intel.marker(enemy,team)
		if not info.is_empty() and point.distance_to(info.point)<8: return false
	return true

func choose(actor: Node3D) -> String:
	if state(actor).is_empty() or not _eligible(actor): return ""
	var keys: Array[String] = []
	for ally in game.all_actors():
		if ally!=actor and game.actor_team(ally)==game.actor_team(actor): keys.append("actor:%d" % game.actor_id(ally))
	for beacon in game.deployment.beacons:
		if beacon.team==game.actor_team(actor): keys.append("beacon:%d" % beacon.id)
	var base := base_position(actor)
	var pads: Array = game.get_node("World/Map").spawn_pads
	var forward: Vector3 = (pads[1-game.actor_team(actor)]-base).normalized()
	var selected := ""
	var best := 6.0
	for key in keys:
		var checked: Dictionary = game.deployment.destination_for(actor,key)
		if checked.is_empty() or actor.global_position.distance_to(checked.point)<MIN_TRAVEL: continue
		if not _safe(checked.point,game.actor_team(actor)): continue
		var progress: float = (checked.point-base).dot(forward)
		if progress>best: best=progress;selected=key
	return selected

func _begin(actor: Node3D, key: String) -> void:
	var s := state(actor)
	var checked: Dictionary = game.deployment.destination_for(actor,key)
	if checked.is_empty(): return
	s.active = true
	s.pending = false
	s.flying = false
	s.time = 0.0
	s.key = key
	s.origin = actor.global_position
	s.target = checked.point
	started += 1
	actor.team_mover.velocity = Vector3.ZERO
	actor.charge_time = 0.0
	actor.clear_attack_visual()
	game.perks.bot_form(actor,true)
	actor.get_node("Body").set_form(true)
	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .6; ring.outer_radius = .8; marker.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Palette.color(game.actor_team(actor)).lightened(.3)
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.global_position = s.target+Vector3.UP*.07
	s.marker = marker

func update(actor: Node3D, delta: float) -> bool:
	var s := state(actor)
	if s.is_empty(): return false
	if game.phase != "playing" or game.paused: return busy(actor)
	if not game.actor_alive(actor) or game.actor_health(actor)<=0:
		cancel(actor);return false
	if not s.active:
		if not s.pending: return false
		s.window -= delta
		if s.window<=0 or actor.global_position.distance_to(base_position(actor))>BASE_RADIUS:
			s.pending=false;return false
		var key := choose(actor)
		if key.is_empty(): return false
		_begin(actor,key)
		return busy(actor)
	s.time += delta
	if not s.flying:
		var checked: Dictionary = game.deployment.destination_for(actor,s.key)
		if checked.is_empty() or not _safe(checked.point,game.actor_team(actor)):
			cancel(actor);return true
		s.target = checked.point
		s.marker.global_position = s.target+Vector3.UP*.07
		if s.time<WINDUP: return true
		s.flying=true;s.time=0.0
		s.duration=1.15+minf(actor.global_position.distance_to(s.target)/90,.75)
		s.arc=maxf(8,actor.global_position.distance_to(s.target)*.18)
		game.play_sound("jump",actor.global_position)
	var t := clampf(float(s.time)/float(s.duration),0,1)
	actor.global_position = (s.origin as Vector3).lerp(s.target,t)+Vector3.UP*sin(t*PI)*float(s.arc)
	actor.team_mover.position = Vector3.ZERO
	if t<1: return true
	var valid: Dictionary = game.deployment.destination_for(actor,s.key)
	var landing: Dictionary = game.deployment.landing(Vector2(s.target.x,s.target.z),String(s.key).begins_with("beacon:"),s.target.y,game.actor_team(actor),actor)
	if valid.is_empty() or landing.is_empty():
		# Normal spawn placement is the same guaranteed safe fallback as reset().
		actor.global_position = base_position(actor)+Vector3([0.0,-.8,.8,-1.6,1.6][actor.slot],0,0)
		fallbacks += 1
	else:
		actor.global_position = landing.point
		if String(s.key).begins_with("beacon:"):
			for beacon in game.deployment.beacons:
				if beacon.id==int(String(s.key).get_slice(":",1)): beacon.uses-=1
		completed += 1
	actor.route.clear()
	actor.jump_time=0.0
	actor.remove_meta("vault_origin")
	game.play_sound("land",actor.global_position)
	cancel(actor)
	return true

func marks_for(team: int) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	for s in states.values():
		if not s.active: continue
		var side: int = game.actor_team(s.actor)
		if side==team or game.intel.visible_point(s.target+Vector3.UP*.5,team):
			marks.append({"point":s.target,"team":side})
	return marks
