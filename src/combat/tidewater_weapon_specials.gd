extends Node3D
# Three weapon-exclusive specials. Actor state owns buffs and pending launches;
# launched shells retain their source. Painting uses the CPU ledger, without charge.
const Palette := preload("res://src/core/team_palette.gd")
const KINDS := ["overdrive","ink_vortex","siege_shell"]
const DURATION := 6.0
const VORTEX_RADIUS := 3.8
const VORTEX_DPS := 32.0
const SHELL_CAP := 150.0
var game: Node3D
var combat: Node3D
var states: Dictionary = {}
var shells: Array[Dictionary] = []
var launched := 0
func setup(owner_game: Node3D, owner_combat: Node3D) -> void:
	game=owner_game;combat=owner_combat
func active(actor: Node3D) -> bool:return states.has(actor.get_instance_id())
func locks_primary(actor: Node3D) -> bool:return active(actor) and states[actor.get_instance_id()].kind == "siege_shell"
func modify_weapon(actor: Node3D, weapon: Dictionary) -> Dictionary:
	if actor == null or not active(actor) or states[actor.get_instance_id()].kind != "overdrive":return weapon
	var boosted := weapon.duplicate()
	boosted.fireInterval = float(weapon.fireInterval)*.60
	boosted.inkPerShot = float(weapon.inkPerShot)*.50
	return boosted
func begin(actor: Node3D, kind: String, direction: Vector3) -> bool:
	if kind not in KINDS or not game.actor_alive(actor) or active(actor) or direction.length_squared()<.01:return false
	var visual:=Node3D.new();add_child(visual)
	var ring:=MeshInstance3D.new();var mesh:=TorusMesh.new()
	mesh.inner_radius=VORTEX_RADIUS-.12 if kind=="ink_vortex" else .65
	mesh.outer_radius=VORTEX_RADIUS if kind=="ink_vortex" else .85
	mesh.rings=48;mesh.ring_segments=8;ring.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Palette.color(game.actor_team(actor)).lightened(.25);mat.emission_enabled=true;mat.emission=mat.albedo_color*.35
	ring.material_override=mat;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;visual.add_child(ring)
	# Three orbiting beads distinguish moving buffs from an armour bubble.
	for i in range(3):
		var bead:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.12;sphere.height=.24;bead.mesh=sphere;bead.material_override=mat
		bead.position=Vector3(cos(i*TAU/3)*.85,.65,sin(i*TAU/3)*.85);visual.add_child(bead)
	visual.global_position=actor.global_position+Vector3.UP*.12
	states[actor.get_instance_id()]={"actor":actor,"kind":kind,"time":DURATION if kind!="siege_shell" else 1.35,"paint":0.0,"visual":visual,"direction":direction.normalized(),"next":.25,"count":0,"budget":{}}
	return true
func cancel(actor: Node3D) -> void:
	var id:=actor.get_instance_id()
	if states.has(id):states[id].visual.queue_free();states.erase(id)
func clear() -> void:
	for s in states.values():s.visual.queue_free()
	states.clear()
	for shell in shells:shell.visual.queue_free()
	shells.clear()
func tick(delta: float) -> void:
	for id in states.keys():
		var s:Dictionary=states[id];var actor:Node3D=s.actor
		if not is_instance_valid(actor) or not game.actor_alive(actor):cancel(actor);continue
		s.time-=delta;s.paint-=delta;s.visual.global_position=actor.global_position+Vector3.UP*.12;s.visual.rotation.y+=delta*2.5
		if s.kind=="siege_shell":
			s.next-=delta
			if s.next<=0 and s.count<3:
				# Each launch reads current visible aim, allowing the player to steer the volley.
				s.next+=.40;s.count+=1;_launch(s)
		elif s.kind=="ink_vortex":
			var from:Vector3=actor.global_position+Vector3.UP*.7
			for victim in game.enemies(game.actor_team(actor)):
				var target:Vector3=victim.global_position+Vector3.UP*.7
				if from.distance_to(target)<=VORTEX_RADIUS and combat._unblocked(from,target,game.actor_team(actor)):
					_damage(victim,VORTEX_DPS*delta,game.actor_team(actor),actor,"ink_vortex")
			if s.paint<=0:
				s.paint=.25;_paint(actor.global_position+Vector3.UP*.08,game.actor_team(actor),VORTEX_RADIUS,actor)
		if s.time<=0:cancel(actor)
	for i in range(shells.size()-1,-1,-1):
		var shell:=shells[i];shell.time-=delta
		var from:Vector3=shell.visual.global_position;var to:Vector3=from+shell.direction*30*delta
		var ray:=PhysicsRayQueryParameters3D.create(from,to,combat.world_mask(shell.team));ray.hit_from_inside=true
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		var body:Dictionary=combat._segment_team_hit(from,to,.26,shell.team)
		var at:Vector3=hit.position if not hit.is_empty() else to
		var direct:Node3D=null
		if not body.is_empty() and (hit.is_empty() or float(body.distance)<from.distance_to(at)):at=body.point;direct=body.actor
		combat.feedback.trail(from,at,shell.team,.12)
		if direct!=null or not hit.is_empty() or shell.time<=0:
			_explode(shell,at,direct,hit.normal if direct==null and not hit.is_empty() else Vector3.ZERO);shell.visual.queue_free();shells.remove_at(i)
		else:shell.visual.global_position=to
func _launch(s:Dictionary) -> void:
	if s.actor==combat.walker:
		s.direction=combat._aim_direction(s.actor.global_position+Vector3.UP*1.05,24)
	elif s.actor.target_actor!=null and game.intel.can_see(s.actor,s.actor.target_actor):
		s.direction=(game.intel.point(s.actor.target_actor)-(s.actor.global_position+Vector3.UP*1.05)).normalized()
	var visual:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.32;sphere.height=.64;visual.mesh=sphere
	var mat:=StandardMaterial3D.new();var team:int=game.actor_team(s.actor);mat.albedo_color=Palette.color(team);mat.emission_enabled=true;mat.emission=mat.albedo_color*.4;visual.material_override=mat;add_child(visual)
	# Start inside the body so the swept ray also sees a wall directly at the muzzle.
	visual.global_position=s.actor.global_position+Vector3.UP*1.05
	shells.append({"actor":s.actor,"team":team,"direction":s.direction,"visual":visual,"time":.8,"budget":s.budget})
	launched+=1;combat.report_attack(s.actor,team);game.play_sound("shoot_blaster",visual.global_position)
func _explode(shell:Dictionary, at:Vector3, direct:Node3D, normal:Vector3=Vector3.ZERO) -> void:
	combat.damage_cover_area(at,2.6,48,shell.team)
	combat._add_burst(at,shell.team,2.6);_paint(at,shell.team,2.6,shell.actor)
	for victim in game.enemies(shell.team):
		var target:Vector3=victim.global_position+Vector3.UP*.7;var distance:=at.distance_to(target)
		if victim!=direct and (distance>2.6 or not combat._unblocked(at+(normal if normal!=Vector3.ZERO else (target-at).normalized())*.06,target,shell.team)):continue
		var amount:=70.0 if victim==direct else lerpf(48,24,distance/2.6)
		var id:int=victim.get_instance_id();var remaining:=maxf(0,SHELL_CAP-float(shell.budget.get(id,0)))
		var factor:float=game._modified_damage(1.0,victim,shell.actor,"siege_shell")
		amount=minf(amount,remaining/maxf(factor,.001));shell.budget[id]=float(shell.budget.get(id,0))+amount*factor
		_damage(victim,amount,shell.team,shell.actor,"siege_shell")
func _paint(at:Vector3, team:int, radius:float, actor:Node3D) -> void:
	var previous:bool=game.charge_special;game.charge_special=false
	combat._paint_team(at,team,radius,.31,Vector3.ZERO,0,actor)
	game.charge_special=previous

func _damage(victim:Node3D, amount:float, team:int, actor:Node3D, kind:String) -> void:
	var previous:bool=game.charge_special;game.charge_special=false
	game.damage_actor(victim,amount,team,actor,kind)
	game.charge_special=previous
