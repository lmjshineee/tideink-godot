extends Node3D

var game: Node3D
var combat: Node3D
var states: Dictionary = {}
const COVER_SIZE:=Vector3(2.3,1.7,.28)
const FLOOR_MASK:=1|8
var cover_shape:=BoxShape3D.new()

func setup(owner_game: Node3D, owner_combat: Node3D) -> void:
	game = owner_game
	combat = owner_combat
	cover_shape.size=COVER_SIZE

func state(actor: Node3D) -> Dictionary:
	var key := actor.get_instance_id()
	if not states.has(key):
		states[key] = {"owner":actor,"cooldown":0.0,"hold":0.0,"fire":false,"shot_cd":0.0,"cover":null,"launched":false,"age":0.0,"hp":0.0,"direction":Vector3.FORWARD,"paint":0.0,"grounded":false,"fall_speed":0.0}
	return states[key]

func holding(actor: Node3D) -> bool:
	var s := state(actor)
	return s.cover != null and not s.launched

func cancel(actor: Node3D) -> void:
	var s := state(actor)
	s.fire = false
	s.hold = 0.0
	if holding(actor): _remove(s)

func update_input(actor: Node3D, delta: float, fire: bool, target: Vector3) -> void:
	if game.phase!="playing" or game.paused or not game.actor_alive(actor):
		cancel(actor)
		return
	var s := state(actor)
	var weapon: Dictionary = game.perks.weapon(actor,combat.weapons.canopy)
	var direction := (target-(actor.global_position+Vector3.UP*1.05)).normalized()
	if direction.length_squared()<.1: return
	s.direction = direction if not s.launched else s.direction
	if not fire:
		if holding(actor): _remove(s)
		s.hold = 0.0
	elif not s.fire:
		if not holding(actor) and s.shot_cd<=0: _shot(actor,direction,weapon)
		s.hold = 0.0
	if fire:
		# Once the cover leaves, the same held trigger becomes sustained fire.
		# The old edge-only shot left the player unable to support their own push.
		if not holding(actor) and s.shot_cd<=0:
			_shot(actor,direction,weapon)
		s.hold += delta
		if s.hold>=float(weapon.openTime) and s.cooldown<=0 and s.cover==null:
			_open(actor,direction,weapon)
		if holding(actor) and s.hold>=float(weapon.launchTime): _launch(s,weapon)
	s.fire = fire

func _shot(actor: Node3D, direction: Vector3, weapon: Dictionary) -> bool:
	var tank: Node = combat if actor==combat.walker else actor
	if float(tank.ink_amount)<float(weapon.inkPerShot): return false
	tank.ink_amount -= float(weapon.inkPerShot)
	tank.last_fire_time = 0.0
	state(actor).shot_cd = float(weapon.fireInterval)
	var at := actor.global_position+Vector3.UP*1.05
	var basis: Array = combat._perpendicular_basis(direction)
	for i in range(int(weapon.pellets)):
		var angle := i*TAU/float(weapon.pellets)
		var forward: Vector3 = (direction+basis[0]*cos(angle)*.055+basis[1]*sin(angle)*.055).normalized()
		combat._spawn_projectile("canopy",at,forward*float(weapon.projSpeed),weapon.duplicate(true),game.actor_team(actor),actor)
	actor.get_node("Body").set_action("shoot")
	game.play_sound("shoot_shooter",at)
	return true

func _open(actor: Node3D, direction: Vector3, weapon: Dictionary) -> bool:
	var tank: Node = combat if actor==combat.walker else actor
	# Do not trap a nearly empty held trigger in a drain-only guard. Reserve
	# enough for the short hold and launch; low-ink shots can still refill normally.
	var reserve:=float(weapon.launchInk)+float(weapon.coverDrain)*maxf(0,float(weapon.launchTime)-float(weapon.openTime))
	if float(tank.ink_amount)<reserve: return false
	var at := actor.global_position+Vector3.UP*1.05
	# A narrow wall cannot be used to place the cover on its far side.
	var query := PhysicsRayQueryParameters3D.create(at,at+direction*1.15,1)
	query.hit_from_inside = true
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	var s := state(actor)
	var body := StaticBody3D.new()
	body.collision_layer = 64 if game.actor_team(actor)==0 else 128
	body.collision_mask = 0
	body.set_meta("canopy_owner",actor.get_instance_id())
	var shape := CollisionShape3D.new()
	shape.shape = cover_shape
	shape.position.z = .12
	body.add_child(shape)
	body.add_child(preload("res://src/combat/ink_equipment_mesh.gd").canopy(game.actor_team(actor),true))
	add_child(body)
	s.cover = body
	s.hp = float(weapon.coverHealth)
	s.launched = false
	s.age = 0.0
	s.direction = direction
	var position:=_held_position(at,direction)
	_pose(s,position)
	if not _clear_motion(s,position,position):
		body.collision_layer=0;body.queue_free();s.cover=null
		return false
	game.play_sound("ink_hit_wall",at)
	return true

func _launch(s: Dictionary, weapon: Dictionary) -> bool:
	var actor: Node3D = s.owner
	var tank: Node = combat if actor==combat.walker else actor
	if float(tank.ink_amount)<float(weapon.launchInk): return false
	tank.ink_amount -= float(weapon.launchInk)
	tank.last_fire_time = 0.0
	s.launched = true
	s.age = 0.0
	s.paint = 0.0
	s.cooldown=float(weapon.coverCooldown)
	var position:Vector3=s.cover.global_position
	var ground:=_panel_ground(position,s.cover.basis.x,1.8,2.6)
	# Grounded covers follow the terrain; airborne covers retain pitched aiming.
	s.grounded=not ground.is_empty() and position.y-float(ground.position.y)<1.8
	s.fall_speed=0.0
	if s.grounded:
		var flat:=Vector3(s.direction.x,0,s.direction.z)
		if flat.length_squared()<.01:flat=Vector3(s.cover.basis.z.x,0,s.cover.basis.z.z)
		if flat.length_squared()<.01:flat=Vector3.FORWARD
		s.direction=flat.normalized()
		_pose(s,Vector3(position.x,float(ground.position.y)+1.02,position.z))
	if actor==combat.walker:game.presentation.notify_ability("推进伞 · 跟进射击",0)
	actor.get_node("Body").set_action("shoot")
	return true

func _ground(at:Vector3,up:float,down:float) -> Dictionary:
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*up,at-Vector3.UP*down,FLOOR_MASK))
	return hit if not hit.is_empty() and hit.normal.y>=.68 else {}

func _held_position(at:Vector3,direction:Vector3) -> Vector3:
	var position:=at+direction*1.15
	var basis:=Basis.looking_at(direction,Vector3.UP if absf(direction.y)<.99 else Vector3.RIGHT,true)
	var floor_hit:=_panel_ground(position,basis.x,.4,1.8)
	if not floor_hit.is_empty():
		var extent:=absf(basis.y.y)*.85+absf(basis.z.y)*.26
		position.y=maxf(position.y,float(floor_hit.position.y)+extent+.10)
	return position

func _panel_ground(at:Vector3,side:Vector3,up:float,down:float) -> Dictionary:
	var best:Dictionary={}
	for offset in [Vector3.ZERO,side*1.12,-side*1.12]:
		var hit:=_ground(at+offset,up,down)
		if not hit.is_empty() and (best.is_empty() or hit.position.y>best.position.y):best=hit
	return best

func _clear_motion(s:Dictionary,from:Vector3,to:Vector3) -> bool:
	# Sweep the whole panel, including corners. Five point rays missed narrow walls.
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=cover_shape;query.collision_mask=FLOOR_MASK;query.margin=.012
	query.transform=Transform3D(s.cover.basis,from+s.cover.basis.z*.12)
	var space:=get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty():return false
	query.motion=to-from
	var fractions:=space.cast_motion(query)
	if fractions.size()>0 and fractions[0]<.999:return false
	query.motion=Vector3.ZERO;query.transform.origin=to+s.cover.basis.z*.12
	return space.intersect_shape(query,1).is_empty()

func _pose(s: Dictionary, at: Vector3) -> void:
	s.cover.global_position = at
	var direction: Vector3 = s.direction
	s.cover.basis = Basis.looking_at(direction,Vector3.UP if absf(direction.y)<.99 else Vector3.RIGHT,true)

func tick(delta: float) -> void:
	for s in states.values():
		s.cooldown = maxf(0,s.cooldown-delta)
		s.shot_cd = maxf(0,s.shot_cd-delta)
		if s.cover==null: continue
		if game.phase!="playing":
			_remove(s)
			continue
		var actor: Node3D = s.owner
		var weapon: Dictionary = game.perks.weapon(actor,combat.weapons.canopy)
		if not s.launched:
			if not game.actor_alive(actor) or (combat.selected_id if actor==combat.walker else actor.weapon_id)!="canopy":
				cancel(actor)
				continue
			var tank: Node = combat if actor==combat.walker else actor
			var drain := float(weapon.coverDrain)*delta
			if float(tank.ink_amount)<drain:
				cancel(actor)
				continue
			tank.ink_amount -= drain
			tank.last_fire_time = 0.0
			var at := actor.global_position+Vector3.UP*1.05
			var query := PhysicsRayQueryParameters3D.create(at,at+(s.direction as Vector3)*1.15,1)
			query.hit_from_inside = true
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				cancel(actor)
				continue
			var position:=_held_position(at,s.direction)
			_pose(s,position)
			if not _clear_motion(s,position,position):cancel(actor)
		else:
			s.age += delta
			var start: Vector3 = s.cover.global_position
			var distance:=float(weapon.coverSpeed)*delta
			var end := start+(s.direction as Vector3)*distance
			if s.grounded:
				var ground:=_panel_ground(end,s.cover.basis.x,.6,2.5)
				if not ground.is_empty():
					var height:=float(ground.position.y)+1.02
					# Walkable slopes and small curbs work; a roof or tall step is a wall.
					if height-start.y>distance*.94+.35:
						_remove(s);continue
					if start.y-height<=.6:end.y=height
					else:s.grounded=false
				else:s.grounded=false
			if not s.grounded and absf(s.direction.y)<.001:
				s.fall_speed+=18.0*delta
				end.y-=s.fall_speed*delta
				var landing:=_ground(end,0,1.02)
				if not landing.is_empty() and end.y-float(landing.position.y)<1.02:
					end.y=float(landing.position.y)+1.02;s.grounded=true;s.fall_speed=0.0
			if not _clear_motion(s,start,end) or s.age>=float(weapon.coverLife):
				_remove(s)
				continue
			_pose(s,end)
			s.paint += distance
			if s.paint>=.4:
				s.paint=0.0
				var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(end,end-Vector3.UP*3.5,1))
				if not hit.is_empty(): combat._paint_team(hit.position+hit.normal*.1,game.actor_team(actor),1.25,randf(),Vector3.ZERO,0,actor)

func damage_hit(hit: Dictionary, amount: float, team: int) -> bool:
	if hit.is_empty() or not hit.collider.has_meta("canopy_owner"): return false
	var key := int(hit.collider.get_meta("canopy_owner"))
	if not states.has(key): return false
	var s: Dictionary = states[key]
	if s.cover==null or game.actor_team(s.owner)==team: return false
	s.hp -= amount
	combat.feedback.emit("hit",hit.position,team,hit.get("normal",Vector3.UP))
	if s.hp<=0: _remove(s)
	return true

func damage_area(at: Vector3, radius: float, amount: float, team: int) -> void:
	for s in states.values():
		if s.cover==null or game.actor_team(s.owner)==team: continue
		var point: Vector3 = s.cover.global_position
		if point.distance_to(at)<=radius and combat._unblocked(at,point):
			s.hp -= amount
			if s.hp<=0: _remove(s)

func _remove(s: Dictionary) -> void:
	if s.cover==null: return
	# Remove the collision immediately; queue_free only runs after the physics step.
	s.cover.collision_layer = 0
	s.cover.queue_free()
	s.cover = null
	if not s.launched:s.cooldown = float(combat.weapons.canopy.coverCooldown)

func bot_input(actor: Node3D, delta: float, target: Node3D) -> void:
	var s := state(actor)
	var fire := false
	var at := actor.global_position+Vector3.UP*1.05
	var aim := at+(s.direction as Vector3)*9
	if target!=null:
		aim=target.global_position+Vector3.UP*.8
		# Briefly reset between volleys. Under fire, hold long enough to deploy cover.
		var recent:float=game.bot_last_damage if actor==game.get_node("Bot") else actor.last_damage
		fire=s.launched or holding(actor) or (recent<1.5 and s.cooldown<=0) or (s.shot_cd<=0 and not s.fire)
	update_input(actor,delta,fire,aim)

func clear_all() -> void:
	for s in states.values():
		if s.cover!=null:
			s.cover.collision_layer=0
			s.cover.queue_free()
	states.clear()
