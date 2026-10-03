extends Node

# Bots fill the same weapon-specific meter from newly claimed ink, then choose a
# visible opponent. Their specials share the player's impact/cloud damage code.
var game: Node3D
var states: Dictionary = {}
func setup(owner_game: Node3D) -> void:
	game = owner_game
	for actor in game.call("all_actors"):
		if actor!=game.get_node("World/Walker"):
			states[actor.get_instance_id()] = {"points":0.0,"windup":0.0,"active":false,"cooldown":0.0,"casts":0}
func state(actor: Node3D) -> Dictionary:
	return states.get(actor.get_instance_id(),{})
func charge(actor: Node3D, area: float) -> void:
	var s := state(actor)
	if s.is_empty() or bool(s["active"]) or not bool(game.call("actor_alive",actor)):
		return
	var weapon: Dictionary = game.get_node("Combat").get("weapons")[actor.get("weapon_id")]
	s["points"] = minf(float(weapon["specialCost"]),float(s["points"])+maxf(0,area)*game.perks.charge(actor))
func busy(actor: Node3D) -> bool:
	return bool(state(actor).get("active",false))
func on_death(actor: Node3D) -> void:
	var s := state(actor)
	if s.is_empty(): return
	game.get_node("Combat").counter.cancel(actor)
	game.get_node("Combat").rain_arrows.cancel(actor)
	s["points"] = float(s["points"])*0.5
	s["active"] = false
	s["windup"] = 0.0
	actor.get_node("Body").position.y = 0.0
func tick(delta: float) -> void:
	var combat := game.get_node("Combat")
	for actor in game.call("all_actors"):
		var s := state(actor)
		if s.is_empty(): continue
		s["cooldown"] = maxf(0,float(s["cooldown"])-delta)
		if not bool(game.call("actor_alive",actor)): continue
		if bool(s.active) and String(s.get("kind","")) == "rain_arrows":
			s.active = combat.rain_arrows.busy(actor)
			continue
		if bool(s["active"]) and String(s.get("kind", "")) == "absorb_counter":
			s.active = combat.counter.busy(actor)
			continue
		if bool(s["active"]) and String(s.get("kind", "")) == "twin_discs":
			s.active = combat.discs.winding_up(actor)
			continue
		if bool(s["active"]):
			s["windup"] = float(s["windup"])-delta
			actor.get_node("Body").position.y = sin(clampf(1.0-float(s["windup"])/0.85,0,1)*PI)*2.6
			if float(s["windup"])<=0:
				actor.get_node("Body").position.y = 0.0
				combat.call("slam_actor",actor)
				s["active"] = false
			continue
		var weapon: Dictionary = combat.get("weapons")[actor.get("weapon_id")]
		if float(s["points"])<float(weapon["specialCost"]) or float(s["cooldown"])>0 or game.mobility.busy(actor) or game.wings.busy(actor):
			continue
		var nearest: Node3D = null
		var range_limit := 5.0 if weapon["special"]=="slam" else (23.0 if weapon.special == "rain_arrows" else 18.0 if weapon.special == "twin_discs" else 14.0)
		for enemy in game.call("enemies",int(game.call("actor_team",actor))):
			var distance: float = enemy.global_position.distance_to(actor.global_position)
			if distance<range_limit and game.intel.can_see(actor,enemy):
				nearest = enemy
				range_limit = distance
		if nearest==null: continue
		if weapon.special == "rain_arrows" and not combat.rain_arrows.begin(actor,game.intel.point(nearest)): continue
		s["points"] = 0.0
		s["cooldown"] = 12.0
		s["casts"] = int(s["casts"])+1
		var stats: Dictionary = actor.get_meta("match_stats")
		stats["specials"] = int(stats.get("specials",0))+1
		actor.set("ink_amount",game.call("actor_ink_max",actor))
		game.call("play_sound","special_activate",actor.global_position)
		var team: int = game.call("actor_team",actor)
		s.kind = weapon.special
		if weapon.special == "rain_arrows":
			s.active = true
		elif weapon.special == "absorb_counter":
			s.active = true
			combat.counter.begin(actor,(game.intel.point(nearest)-(actor.global_position+Vector3.UP*1.05)).normalized())
		elif weapon.special == "twin_discs":
			s.active = true
			combat.discs.begin_twins(actor, (nearest.global_position - actor.global_position).normalized())
		elif weapon["special"]=="slam":
			s["active"] = true
			s["windup"] = 0.85
			combat.call("_ability_ring",actor.global_position,6.0,0.85,team)
			actor.get_node("Body").call("set_reaction","jump")
		else:
			var from: Vector3 = actor.global_position+Vector3.UP*1.45
			var direction: Vector3 = (nearest.global_position+Vector3.UP*0.8-from).normalized()
			combat.call("throw_actor_storm",actor,direction)
		game.get("presentation").call("notify_ability",String(game.call("_actor_name",actor))+" · "+{"rain_arrows":"雨箭齐射", "absorb_counter":"吸墨反击", "slam":"潮汐重击","storm":"墨水风暴","twin_discs":"双镖突进"}[weapon.special])
func escape(actor: Node3D) -> Vector3:
	var combat := game.get_node("Combat")
	var residual_escape: Vector3 = game.perks.escape_burst(actor)
	if residual_escape.length_squared() > .1: return residual_escape
	var mine_escape: Vector3 = game.items.mines.escape(actor)
	if mine_escape.length_squared() > .1: return mine_escape
	var arrow_escape: Vector3 = combat.rain_arrows.escape(actor)
	if arrow_escape.length_squared() > .1: return arrow_escape
	for cloud in combat.get("clouds"):
		if int(cloud.get("team",0))==int(game.call("actor_team",actor)): continue
		var at: Vector3 = cloud["visual"].global_position
		var offset := Vector3(actor.global_position.x-at.x,0,actor.global_position.z-at.z)
		if offset.length()>4.6 or actor.global_position.y>at.y: continue
		if not bool(combat.call("_unblocked",actor.global_position+Vector3.UP,Vector3(actor.global_position.x,at.y-0.6,actor.global_position.z))): continue
		if offset.length()<0.1:
			offset = Vector3(1,0,0) if int(game.call("actor_id",actor))%2==0 else Vector3(-1,0,0)
		return offset.normalized()*6.0
	return Vector3.ZERO
