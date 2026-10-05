extends Node3D

const COST:=45.0
const HEALTH:=45.0
const LIFE:=12.0
const DETECT:=8.0
const SPEED:=4.2
const GRAVITY:=18.0
const RADIUS:=.28
const HEIGHT:=.7
const DAMAGE:=18.0
const REACH:=1.2
const WINDUP:=.22
const RECOVERY:=.38
var game:Node3D
var buddies:Dictionary={}
var serial:=0
var casts_total:=0
var bites_total:=0
var destroyed_total:=0
var preview:MultiMeshInstance3D
var preview_mesh:MultiMesh
var landing_dot:MeshInstance3D

func setup(owner_game:Node3D) -> void:
	game=owner_game
	preview=MultiMeshInstance3D.new();preview_mesh=MultiMesh.new();preview_mesh.transform_format=MultiMesh.TRANSFORM_3D
	var segment:=CylinderMesh.new();segment.top_radius=1;segment.bottom_radius=1;segment.height=1;segment.radial_segments=6
	preview_mesh.mesh=segment;preview_mesh.instance_count=120;preview_mesh.visible_instance_count=0;preview.multimesh=preview_mesh
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("fff3b0")
	preview.material_override=mat;preview.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(preview)
	landing_dot=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.23;ring.outer_radius=.3;ring.rings=32
	landing_dot.mesh=ring;landing_dot.material_override=mat;landing_dot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(landing_dot)
	preview.visible=false;landing_dot.visible=false

func _shape() -> CapsuleShape3D:
	var capsule:=CapsuleShape3D.new();capsule.radius=RADIUS;capsule.height=HEIGHT;return capsule

func launch(actor:Node3D) -> Dictionary:
	var at:=actor.global_position+Vector3.UP*.9
	var target:Vector3
	if actor==game.get_node("World/Walker"):target=game.get_node("Combat")._aim_target(at,14)
	else:
		var info:Dictionary=game.intel.nearest_contact(actor)
		if info.is_empty():return {}
		target=info.point+Vector3.UP*.5
	var direction:Vector3=(target-at).normalized()
	if direction.length_squared()<.1:direction=Vector3.FORWARD
	direction.y=clampf(direction.y,-.25,.6);direction=direction.normalized()
	var start:Vector3=at+Vector3(direction.x,0,direction.z).normalized()*.65
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=_shape();query.collision_mask=9
	query.transform=Transform3D(Basis.IDENTITY,start+Vector3.UP*HEIGHT*.5)
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty() or not _clear(at,start):return {}
	return {"point":start,"velocity":direction*13+Vector3.UP*3}

func summon(actor:Node3D) -> bool:
	if owned(actor)!=0:return false
	var tank:Node=game.get_node("Combat") if actor==game.get_node("World/Walker") else actor
	if float(tank.ink_amount)<COST:return false
	var shot:Dictionary=launch(actor)
	if shot.is_empty():return false
	serial+=1
	var team:int=game.actor_team(actor)
	var body:=CharacterBody3D.new();body.collision_layer=1024 if team==0 else 2048;body.collision_mask=9
	body.floor_snap_length=.25;body.floor_max_angle=deg_to_rad(50);body.set_meta("buddy_key",serial)
	var shape:=CollisionShape3D.new();shape.shape=_shape();shape.position.y=HEIGHT*.5;body.add_child(shape)
	add_child(body);body.global_position=shot.point;body.velocity=shot.velocity
	var visual:=preload("res://src/presentation/ink_buddy_visual.gd").new();body.add_child(visual);visual.configure(team)
	var label:=Label3D.new();label.font=load("res://assets/fonts/NotoSansSC.ttf");label.font_size=28;label.pixel_size=.006;label.outline_size=6
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position.y=1.15;label.no_depth_test=false;label.modulate=preload("res://src/core/team_palette.gd").color(team).lightened(.5);body.add_child(label)
	buddies[serial]={"id":serial,"owner":actor,"team":team,"body":body,"visual":visual,"label":label,"health":HEALTH,"time":LIFE,"mode":"flying","target":null,"point":shot.point,"last_seen":0.0,"scan":0.0,"attack":0.0,"windup":0.0,"flash":0.0}
	tank.ink_amount-=COST;tank.last_fire_time=0;casts_total+=1
	actor.get_node("Body").set_action("throw");game.play_sound("bomb_throw",actor.global_position)
	return true

func owned(actor:Node3D) -> int:
	for id in buddies:
		if buddies[id].owner==actor:return id
	return 0

func _clear(from:Vector3,to:Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,9)).is_empty()

func sees(b:Dictionary,enemy:Node3D) -> bool:
	if not is_instance_valid(enemy) or not game.actor_alive(enemy) or game.actor_team(enemy)==b.team:return false
	var from:Vector3=b.body.global_position+Vector3.UP*.4
	var to:Vector3=game.intel.point(enemy)
	var gap:float=from.distance_to(to)
	if gap>DETECT:return false
	var key:int=enemy.get_instance_id()
	var tagged:bool=float(game.intel.tags[b.team].get(key,0))>game.intel.clock
	var flashed:bool=float(game.intel.shot_until.get(key,0))>game.intel.clock
	if game.intel.concealed(enemy) and gap>2.5 and not tagged and not flashed:return false
	return _clear(from,to) and (tagged or not game.items.mist.obscures(from,to,b.team))

func tick(delta:float) -> void:
	if game.phase!="playing" or game.paused:
		preview.visible=false;landing_dot.visible=false;return
	_update_preview()
	for id in buddies.keys():
		if not buddies.has(id):continue
		var b:Dictionary=buddies[id]
		b.time-=delta;b.attack=maxf(0,b.attack-delta);b.flash=maxf(0,b.flash-delta)
		if b.time<=0 or not game.actor_alive(b.owner) or b.body.global_position.y<float(game.get_node("Combat").weapon_data.player.waterY)-1 or b.body.global_position.distance_to(b.owner.global_position)>28:
			_remove(id);continue
		var body:CharacterBody3D=b.body
		var old:Vector3=body.global_position
		var movement:=Vector3.ZERO
		if b.mode=="flying":
			body.velocity.y-=GRAVITY*delta;body.move_and_slide()
			game.get_node("Combat").feedback.trail(old+Vector3.UP*.35,body.global_position+Vector3.UP*.35,b.team,.065)
			if body.get_slide_collision_count()>0:
				b.mode="search";body.velocity=Vector3.ZERO;game.play_sound("jump",body.global_position)
		else:
			b.scan-=delta
			if b.scan<=0 and b.mode!="windup":
				b.scan=.12
				var chosen:Node3D=null;var best:=DETECT
				for enemy in game.enemies(b.team):
					var gap:float=body.global_position.distance_to(enemy.global_position)
					if gap<best and sees(b,enemy):chosen=enemy;best=gap
				b.target=chosen
				if chosen!=null:b.point=chosen.global_position;b.last_seen=.6
				else:b.last_seen=maxf(0,b.last_seen-.12)
			var target:Node3D=b.target
			var visible_enemy:bool=target!=null and sees(b,target)
			if visible_enemy:b.point=target.global_position
			if b.mode=="windup":
				b.windup-=delta
				if b.windup<=0:
					if visible_enemy and (body.global_position+Vector3.UP*.4).distance_to(game.intel.point(target))<=REACH:
						game.damage_actor(target,DAMAGE,b.team,b.owner,"ink_buddy","扑击")
						game.get_node("Combat").feedback.trail(body.global_position+Vector3.UP*.4,game.intel.point(target),b.team,.1)
						game.get_node("Combat").feedback.emit("hit",game.intel.point(target),b.team)
						game.paint_at_world(body.global_position+Vector3.UP*.06,b.team,.6,float(id)*.173,Vector3.ZERO,0,b.owner)
						bites_total+=1;b.flash=.16
					b.mode="search";b.attack=RECOVERY
			elif visible_enemy and body.is_on_floor() and (body.global_position+Vector3.UP*.4).distance_to(game.intel.point(target))<=REACH and b.attack<=0:
				b.mode="windup";b.windup=WINDUP
				game.get_node("Combat")._ability_ring(body.global_position,REACH,WINDUP,b.team)
				game.play_sound("special_ready",body.global_position)
			else:
				var goal:Vector3=b.point if visible_enemy or b.last_seen>0 else b.owner.global_position
				var offset:=goal-body.global_position;offset.y=0
				if offset.length()>(.7 if visible_enemy else 1.6) and _clear(body.global_position+Vector3.UP*.4,goal+Vector3.UP*.4):
					movement=offset.normalized()*SPEED
				b.mode="chase" if visible_enemy else "follow" if movement.length()>0 else "search"
			body.velocity.x=movement.x;body.velocity.z=movement.z
			body.velocity.y=-1 if body.is_on_floor() else body.velocity.y-GRAVITY*delta
			body.move_and_slide()
		var facing:Vector3=(b.point-body.global_position) if b.target!=null else body.velocity
		facing.y=0
		if facing.length_squared()>.01:b.visual.rotation.y=lerp_angle(b.visual.rotation.y,atan2(facing.x,facing.z),minf(1,delta*12))
		b.visual.animate(delta,"bite" if b.flash>0 else b.mode,Vector2(body.velocity.x,body.velocity.z).length(),b.windup)
		b.label.text="墨仔 · %.0f HP" % b.health
		var walker:Node3D=game.get_node("World/Walker")
		var shown:bool=b.team==0 or (_clear(game.intel.point(walker),body.global_position+Vector3.UP*.4) and not game.items.mist.obscures(game.intel.point(walker),body.global_position+Vector3.UP*.4,0))
		b.visual.visible=shown;b.label.visible=shown

func threat_for(actor:Node3D,limit:float) -> Dictionary:
	var result:Dictionary={};var best:=minf(6,limit)
	for b in buddies.values():
		var at:Vector3=b.body.global_position
		var gap:float=actor.global_position.distance_to(at)
		if b.team!=game.actor_team(actor) and gap<best and _clear(game.intel.point(actor),at+Vector3.UP*.35) and not game.items.mist.obscures(game.intel.point(actor),at+Vector3.UP*.35,game.actor_team(actor)):
			best=gap;result={"id":b.id,"point":at,"visual":b.body,"buddy":true}
	return result

func damage_hit(hit:Dictionary,amount:float,team:int) -> bool:
	if hit.is_empty() or not hit.collider.has_meta("buddy_key"):return false
	var id:int=hit.collider.get_meta("buddy_key")
	if not buddies.has(id) or buddies[id].team==team:return false
	buddies[id].health-=maxf(0,amount)
	game.get_node("Combat").feedback.emit("hit",buddies[id].body.global_position+Vector3.UP*.4,team)
	if buddies[id].health<=0:destroyed_total+=1;_remove(id)
	return true

func damage_area(at:Vector3,radius:float,amount:float,team:int) -> void:
	for id in buddies.keys():
		var b:Dictionary=buddies[id];var to:Vector3=b.body.global_position+Vector3.UP*.35
		if b.team!=team and at.distance_to(to)<=radius and _clear(at,to):damage_hit({"collider":b.body},amount,team)

func trajectory(actor:Node3D) -> PackedVector3Array:
	var shot:Dictionary=launch(actor);var points:=PackedVector3Array()
	if shot.is_empty():return points
	var p:Vector3=shot.point;var velocity:Vector3=shot.velocity;var step:=1.0/float(Engine.physics_ticks_per_second)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=_shape();query.collision_mask=9
	points.append(p+Vector3.UP*.35)
	for i in range(mini(120,ceili(2.4/step))):
		velocity.y-=GRAVITY*step;query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.35);query.motion=velocity*step
		var safe:PackedFloat32Array=get_world_3d().direct_space_state.cast_motion(query)
		p+=query.motion*safe[0];points.append(p+Vector3.UP*.35)
		if safe[0]<.999:break
	return points

func _update_preview() -> void:
	var walker:Node3D=game.get_node("World/Walker");var combat:Node3D=game.get_node("Combat")
	var visible:bool=combat.aiming_sub and game.items.state(walker).kind=="ink_buddy" and owned(walker)==0 and game.actor_alive(walker)
	preview.visible=visible;landing_dot.visible=false;preview_mesh.visible_instance_count=0
	if not visible:return
	preview.material_override.albedo_color=Color("fff3b0") if game.items.hud_status().state=="ready" else Color("ff5c72")
	var points:PackedVector3Array=trajectory(walker)
	if points.size()<2:return
	var count:=mini(120,points.size()-1)
	for i in range(count):
		var offset:Vector3=points[i+1]-points[i];var direction:=offset.normalized()
		var right:=direction.cross(Vector3.UP).normalized()
		if right.length_squared()<.01:right=Vector3.RIGHT
		var basis:=Basis(right,direction,right.cross(direction).normalized()).scaled_local(Vector3(.025,maxf(.001,offset.length()),.025))
		preview_mesh.set_instance_transform(i,Transform3D(basis,(points[i]+points[i+1])*.5))
	preview_mesh.visible_instance_count=count;landing_dot.position=points[-1];landing_dot.visible=true

func cancel(actor:Node3D) -> void:
	var id:=owned(actor)
	if id!=0:_remove(id)

func _remove(id:int) -> void:
	if not buddies.has(id):return
	buddies[id].body.collision_layer=0;buddies[id].body.queue_free();buddies.erase(id)

func clear_all() -> void:
	for id in buddies.keys():_remove(id)
	preview.visible=false;landing_dot.visible=false
