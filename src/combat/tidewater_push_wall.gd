extends Node3D

# A team-filtered projectile barrier. It never pushes actors or owns ink/score.
const SIZE := Vector3(5.0,2.8,.32)
const HEALTH := 600.0
const SPEED := 3.8
const LIFE := 6.0
const LIFT := 1.55
const FLOOR_MASK := 1|8
const Palette := preload("res://src/core/team_palette.gd")
var game: Node3D
var combat: Node3D
var states: Dictionary = {}
var shape := BoxShape3D.new()

func setup(owner_game: Node3D, owner_combat: Node3D) -> void:
	game=owner_game; combat=owner_combat; shape.size=SIZE

func active(actor: Node3D) -> bool: return states.has(actor.get_instance_id())

func begin(actor: Node3D, direction: Vector3) -> bool:
	if active(actor) or not game.actor_alive(actor):return false
	direction=Vector3(direction.x,0,direction.z)
	if direction.length_squared()<.01:return false
	direction=direction.normalized()
	var basis:=Basis.looking_at(direction,Vector3.UP,true)
	var at:=actor.global_position+Vector3.UP*LIFT
	var placement:=Vector3.ZERO
	var fits:=false
	for distance in [1.7,1.3,.9]:
		var candidate:Vector3=at+direction*distance
		var floor_hit:=_ground(candidate,basis.x,2.0,3.0)
		if not floor_hit.is_empty():candidate.y=maxf(candidate.y,float(floor_hit.position.y)+LIFT)
		var ray:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,candidate,1)
		ray.hit_from_inside=true
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		if _clear(basis,candidate,candidate):placement=candidate;fits=true;break
	if not fits:return false
	var body:=StaticBody3D.new()
	body.collision_layer=64 if game.actor_team(actor)==0 else 128
	body.collision_mask=0
	body.set_meta("push_wall_owner",actor.get_instance_id())
	var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
	var panel:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=SIZE;panel.mesh=box
	var mat:=StandardMaterial3D.new();mat.albedo_color=Palette.color(game.actor_team(actor)).lightened(.12)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color.a=.72
	mat.roughness=.25;mat.emission_enabled=true;mat.emission=mat.albedo_color*.25
	panel.material_override=mat;body.add_child(panel)
	# Solid posts and a top bar make the moving shield readable from either side.
	var frame_mat:=StandardMaterial3D.new();frame_mat.albedo_color=Palette.color(game.actor_team(actor)).darkened(.25)
	for x in [-2.4,0.0,2.4]:
		var post:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(.09,2.8,.4)
		post.mesh=mesh;post.material_override=frame_mat;post.position.x=x;body.add_child(post)
	add_child(body);body.global_transform=Transform3D(basis,placement)
	states[actor.get_instance_id()]={"owner":actor,"cover":body,"hp":HEALTH,"time":LIFE,"direction":direction,"stopped":false,"fall_speed":0.0,"paint":0.0}
	return true

func _ground(at:Vector3,side:Vector3,up:float,down:float) -> Dictionary:
	var highest:Dictionary={}
	for offset in [Vector3.ZERO,side*2.35,-side*2.35]:
		var ray:=PhysicsRayQueryParameters3D.create(at+offset+Vector3.UP*up,at+offset-Vector3.UP*down,FLOOR_MASK)
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.normal.y>=.68 and (highest.is_empty() or hit.position.y>highest.position.y):highest=hit
	return highest

func _clear(basis:Basis,from:Vector3,to:Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=FLOOR_MASK;query.margin=.015
	query.transform=Transform3D(basis,from)
	var space:=get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty():return false
	query.motion=to-from
	var fractions:=space.cast_motion(query)
	if not fractions.is_empty() and fractions[0]<.999:return false
	query.motion=Vector3.ZERO;query.transform.origin=to
	return space.intersect_shape(query,1).is_empty()

func tick(delta:float) -> void:
	for id in states.keys():
		var s:Dictionary=states[id]
		if game.phase!="playing" or not game.actor_alive(s.owner):cancel(s.owner);continue
		s.time-=delta
		if s.time<=0:cancel(s.owner);continue
		if s.stopped:continue
		var start:Vector3=s.cover.global_position
		var end:Vector3=start+(s.direction as Vector3)*SPEED*delta
		var floor_hit:=_ground(end,s.cover.basis.x,.8,LIFT+.8)
		if not floor_hit.is_empty() and start.y-float(floor_hit.position.y)<LIFT+.65:
			var height:=float(floor_hit.position.y)+LIFT
			if height-start.y>SPEED*delta*.94+.35:s.stopped=true;continue
			end.y=height;s.fall_speed=0.0
		else:
			s.fall_speed+=18.0*delta;end.y-=float(s.fall_speed)*delta
		if not _clear(s.cover.basis,start,end):s.stopped=true;continue
		s.cover.global_position=end
		s.paint+=start.distance_to(end)
		if s.paint>=.4:
			s.paint=0.0
			# Each lane independently checks a real surface, avoiding paint across roofs.
			var previous:bool=game.charge_special;game.charge_special=false
			for x in [-1.65,0.0,1.65]:
				var at:Vector3=end+s.cover.basis.x*x
				var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*2.2,1))
				if not hit.is_empty() and hit.normal.y>=.68:combat._paint_team(hit.position+hit.normal*.05,game.actor_team(s.owner),1.05,.31,Vector3.ZERO,0,s.owner)
			game.charge_special=previous

func damage_hit(hit:Dictionary,amount:float,team:int) -> bool:
	if hit.is_empty() or not hit.collider.has_meta("push_wall_owner"):return false
	var id:int=hit.collider.get_meta("push_wall_owner")
	if not states.has(id):return false
	var s:Dictionary=states[id]
	if game.actor_team(s.owner)==team:return false
	s.hp-=maxf(0,amount)
	combat.feedback.emit("hit",hit.position,team,hit.get("normal",Vector3.UP))
	if s.hp<=0:cancel(s.owner)
	return true

func damage_area(at:Vector3,radius:float,amount:float,team:int) -> void:
	for id in states.keys():
		var s:Dictionary=states[id]
		if game.actor_team(s.owner)==team:continue
		var local:Vector3=s.cover.to_local(at)
		var closest:=local.clamp(-SIZE*.5,SIZE*.5)
		var point:Vector3=s.cover.to_global(closest)
		if point.distance_to(at)<=radius and combat._unblocked(at,point):
			s.hp-=maxf(0,amount)
			if s.hp<=0:cancel(s.owner)

func cancel(actor:Node3D) -> void:
	var id:=actor.get_instance_id()
	if not states.has(id):return
	states[id].cover.collision_layer=0;states[id].cover.queue_free();states.erase(id)

func clear() -> void:
	for s in states.values():s.cover.collision_layer=0;s.cover.queue_free()
	states.clear()
