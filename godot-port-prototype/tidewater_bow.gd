extends Node3D

var game: Node3D
var combat: Node3D
var arrows: Array[Dictionary] = []
var planted: Array[Dictionary] = []

func setup(owner_game: Node3D, owner_combat: Node3D) -> void:
	game = owner_game
	combat = owner_combat

func fire(actor: Node3D, target: Vector3, charge: float) -> bool:
	if game.phase != "playing" or game.paused or not game.actor_alive(actor): return false
	var weapon: Dictionary = game.perks.weapon(actor, combat.weapons.bow).duplicate(true)
	var tank: Node = combat if actor == combat.walker else actor
	charge = clampf(charge,0,1)
	var cost := lerpf(float(weapon.inkMin),float(weapon.inkFull),charge)
	if float(tank.ink_amount) < cost: return false
	var start := actor.global_position + Vector3.UP*1.05
	var direction := (target-start).normalized()
	if direction.length_squared() < .1: return false
	combat.report_attack(actor, game.actor_team(actor))
	tank.ink_amount -= cost
	tank.last_fire_time = 0.0
	var speed := lerpf(float(weapon.arrowSpeedMin),float(weapon.arrowSpeedFull),charge)
	var reach := lerpf(float(weapon.rangeMin),float(weapon.rangeMax),charge)
	direction = combat._ballistic_direction(start,direction,target,speed,.16,18,.15,reach)
	var airborne: bool = not bool(combat.walker.grounded) if actor==combat.walker else not actor.team_mover.is_on_floor()
	var basis: Array = combat._perpendicular_basis(direction)
	var fan: Vector3 = basis[1] if airborne else basis[0]
	var budget := {"hits":{},"blasts":{},"final_hits":{},"max":110.0}
	# Half draw spreads explosive traps; full draw actually converges all three
	# arrows within a body-width target at the advertised range.
	var spread:=lerpf(.105,.07,charge*2) if charge<.5 else lerpf(.07,.008,(charge-.5)*2)
	for side in [-1.0,0.0,1.0]:
		var forward: Vector3 = (direction+fan*tan(spread)*side).normalized()
		var model := preload("res://ink_equipment_mesh.gd").bolt(game.actor_team(actor))
		add_child(model)
		model.global_position = start
		model.basis = Basis.looking_at(forward,Vector3.UP if absf(forward.y)<.99 else Vector3.RIGHT,true)
		arrows.append({"owner":actor,"team":game.actor_team(actor),"weapon":weapon,"visual":model,
			"velocity":forward*speed,"age":0.0,"origin":start,"distance":0.0,"range":reach,
			"charge":charge,"damage":lerpf(float(weapon.arrowDamageMin),float(weapon.arrowDamageMax),charge),"budget":budget})
	actor.get_node("Body").set_action("shoot")
	game.play_sound("shoot_charger",start)
	return true

func bot_charge(actor:Node3D,target:Vector3) -> float:
	var weapon:Dictionary=game.perks.weapon(actor,combat.weapons.bow)
	if actor.global_position.distance_to(target)<5:return 0.0
	if actor.ink_amount<float(weapon.inkFull):
		return .5 if actor.ink_amount>=lerpf(float(weapon.inkMin),float(weapon.inkFull),.5) else 0.0
	return 1.0

func tick(delta: float) -> void:
	# Existing embedded arrows run first, so newly embedded arrows retain the full fuse.
	for i in range(planted.size()-1,-1,-1):
		var arrow: Dictionary = planted[i]
		arrow.fuse -= delta
		arrow.visual.scale = Vector3.ONE*(1.0+.12*sin(arrow.fuse*35))
		if arrow.fuse <= 0:
			_explode(arrow)
			arrow.visual.queue_free()
			planted.remove_at(i)
	for i in range(arrows.size()-1,-1,-1):
		var arrow: Dictionary = arrows[i]
		arrow.age += delta
		var velocity: Vector3 = arrow.velocity
		if arrow.age > .16:
			velocity.y -= 18*delta
			velocity *= 1-.15*delta
		arrow.velocity = velocity
		var start: Vector3 = arrow.visual.global_position
		var end := start + velocity*delta
		var query := PhysicsRayQueryParameters3D.create(start,end,combat.world_mask(arrow.team))
		query.hit_from_inside = true
		var world_hit := get_world_3d().direct_space_state.intersect_ray(query)
		var body_hit: Dictionary = combat._segment_team_hit(start,end,float(arrow.weapon.arrowRadius),arrow.team)
		var remove := false
		var stop := end
		if not world_hit.is_empty(): stop = world_hit.position
		if not body_hit.is_empty() and start.distance_to(body_hit.point) < start.distance_to(stop): stop = body_hit.point
		if combat.counter.consume(start,stop,arrow.team,float(arrow.damage)):
			arrow.visual.queue_free(); arrows.remove_at(i); continue
		if not body_hit.is_empty() and (world_hit.is_empty() or body_hit.distance < start.distance_to(world_hit.position)):
			_damage(arrow,body_hit.actor,float(arrow.damage),false,body_hit.point)
			remove = true
		elif not world_hit.is_empty():
			combat.damage_cover_hit(world_hit,float(arrow.damage),arrow.team)
			var at: Vector3 = world_hit.position+world_hit.normal*.04
			combat._paint_team(at,arrow.team,lerpf(.8,1.0,float(arrow.charge)),randf(),Vector3.ZERO,0,arrow.owner)
			if arrow.charge >= float(arrow.weapon.plantCharge) and (int(world_hit.collider.collision_layer) & 1) != 0:
				arrow.visual.global_position = at
				arrow.at = at
				arrow.fuse = float(arrow.weapon.blastDelay)
				planted.append(arrow)
				arrows.remove_at(i)
				continue
			remove = true
		arrow.distance += start.distance_to(end)
		if arrow.age > 1.5 or arrow.distance > arrow.range: remove = true
		if remove:
			arrow.visual.queue_free()
			arrows.remove_at(i)
		else:
			arrow.visual.global_position = end
			arrow.visual.basis = Basis.looking_at(velocity.normalized(),Vector3.UP if absf(velocity.normalized().y)<.99 else Vector3.RIGHT,true)

func _damage(arrow: Dictionary, victim: Node3D, amount: float, blast: bool, at: Vector3) -> void:
	var key: int = victim.get_instance_id()
	var budget: Dictionary = arrow.budget
	if blast:
		var spent := float(budget.blasts.get(key,0))
		amount = minf(amount,maxf(0,float(arrow.weapon.blastDamage)-spent))
		budget.blasts[key] = spent+amount
	var spent := float(budget.hits.get(key,0))
	amount = minf(amount,maxf(0,float(budget.max)-spent))
	# One volley shares a final cap too: defender vulnerability and boosts that
	# become active during flight must not bypass it through three separate hits.
	if not budget.has("final_hits"):budget.final_hits={}
	var final_spent:=float(budget.final_hits.get(key,0))
	var multiplier:float=game.perks.outgoing(arrow.owner)*game.perks.incoming(victim,"bow")
	amount=minf(amount,maxf(0,115.0-final_spent)/maxf(.001,multiplier))
	budget.final_hits[key]=final_spent+float(game._modified_damage(amount,victim,arrow.owner,"bow"))
	budget.hits[key] = spent+amount
	if amount>0:
		game.damage_actor(victim,amount,arrow.team,arrow.owner,"bow","溅射" if blast else "躯干",(arrow.origin as Vector3).distance_to(at))

func _explode(arrow: Dictionary) -> void:
	var at: Vector3 = arrow.at
	var radius := float(arrow.weapon.blastRadius)
	combat._add_burst(at,arrow.team,radius)
	combat._sound("blaster_boom",at)
	combat._paint_team(at,arrow.team,1.3,randf(),Vector3.ZERO,0,arrow.owner)
	combat.damage_cover_area(at,radius,float(arrow.weapon.blastDamage),arrow.team)
	for actor in game.enemies(arrow.team):
		var target: Vector3 = actor.global_position+Vector3.UP*.8
		var distance := at.distance_to(target)
		if distance<radius and combat._unblocked(at,target,arrow.team):
			_damage(arrow,actor,float(arrow.weapon.blastDamage)*(1-.5*distance/radius),true,target)

func clear_all() -> void:
	for arrow in arrows: arrow.visual.queue_free()
	for arrow in planted: arrow.visual.queue_free()
	arrows.clear()
	planted.clear()
