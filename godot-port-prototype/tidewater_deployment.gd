extends Node3D
# Base launcher and one-action teammate/beacon jumps. All destinations are rechecked.
const Palette:=preload("res://team_palette.gd")
var game:Node3D
var camera:Camera3D
var marker:MeshInstance3D
var selector:Control
var target:=Vector3.ZERO
var aim_offset:=Vector2(0,6)
var active:=false
var flying:=false
var queued:=false
var live_jump:=false
var selector_open:=false
var selected_key:="base"
var flight_time:=0.0
var charge_time:=0.0
var flight_duration:=0.72
var arc_height:=4.0
var origin:=Vector3.ZERO
var return_position:=Vector3.ZERO
var landing_protection:=1.6
var cooldown:=0.0
var beacons:Array[Dictionary]=[]
var beacon_serial:=0
var beacon_refresh:=0.0

func setup(owner_game:Node3D) -> void:
	game=owner_game;camera=Camera3D.new();camera.fov=58;add_child(camera)
	marker=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.6;ring.outer_radius=.8;marker.mesh=ring
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Palette.color(0).lightened(.3);marker.material_override=material;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(marker);marker.visible=false

func setup_ui() -> void:
	selector=preload("res://tidewater_jump_selector.gd").new();game.hud_root.add_child(selector);selector.setup(game,self)

func base_position() -> Vector3:return game.get_node("World/Map").spawn_pads[0]+Vector3.UP*.05
func initial_position() -> Vector3:return base_position()

func clear() -> void:
	active=false;flying=false;queued=false;live_jump=false;selector_open=false;selected_key="base";marker.visible=false;camera.current=false
	if selector!=null:selector.visible=false

func begin() -> void:
	active=true;flying=false;live_jump=false;selected_key="base";aim_offset=Vector2(0,6);_resolve_target();origin=base_position()+Vector3.UP*2
	var walker:Node3D=game.get_node("World/Walker");walker.global_position=origin;walker.visible=true;walker.get_node("Body").set_form(true);walker.look_enabled=false
	camera.global_position=base_position()+Vector3(0,12,-12);camera.look_at(base_position()+Vector3(0,0,8));camera.current=true;marker.visible=true
	# Countdown and destination selection start together; outside the panel still launches base.
	selector_open=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if queued and game.respawn_ready:launch()

func aim(relative:Vector2) -> void:
	if not active or flying or selected_key!="base":return
	aim_offset+=Vector2(-relative.x*.022,-relative.y*.025);aim_offset.x=clampf(aim_offset.x,-7,7);aim_offset.y=clampf(aim_offset.y,2,13);_resolve_target()

func _resolve_target() -> void:
	var pad:=base_position();var candidate:=landing(Vector2(pad.x+aim_offset.x,pad.z+aim_offset.y),false)
	if not candidate.is_empty():target=candidate.point
	elif not active or target==Vector3.ZERO:target=pad
	marker.global_position=target+Vector3.UP*.07

func _actor_destination(actor:Node3D) -> Dictionary:
	if actor==game.get_node("World/Walker") or game.actor_team(actor)!=0 or not game.actor_alive(actor) or game.actor_health(actor)<=0:return {}
	var mover:CharacterBody3D=actor.get("team_mover")
	if mover!=null and absf(mover.velocity.y)>1.2:return {}
	for offset in [Vector2(1.3,0),Vector2(-1.3,0),Vector2(0,1.3),Vector2(0,-1.3),Vector2(.95,.95),Vector2(-.95,-.95)]:
		var point:Vector3=actor.global_position;var checked:=landing(Vector2(point.x,point.z)+offset,false,point.y)
		if not checked.is_empty():return checked
	return {}

func _destination(key:String) -> Dictionary:
	if key=="base":return landing(Vector2(target.x,target.z),false) if active and not live_jump else {"point":base_position()}
	if key.begins_with("actor:"):
		for actor in game.all_actors():
			if game.actor_id(actor)==int(key.get_slice(":",1)):return _actor_destination(actor)
	else:
		for beacon in beacons:
			if key=="beacon:%d" % beacon.id and beacon.team==0 and beacon.uses>0:
				return landing(Vector2(beacon.point.x,beacon.point.z),true,beacon.point.y,0)
	return {}

func destinations() -> Array:
	var result:Array=[{"key":"base","label":"基地 / 快速出场","valid":true,"point":base_position()}]
	for actor in game.all_actors():
		if actor==game.get_node("World/Walker") or game.actor_team(actor)!=0:continue
		var checked:=_actor_destination(actor)
		result.append({"key":"actor:%d" % game.actor_id(actor),"label":"%s · %s" % [game._actor_name(actor),"可跳跃" if not checked.is_empty() else "暂不可用"],"valid":not checked.is_empty(),"point":checked.get("point",actor.global_position)})
	for beacon in beacons:
		if beacon.team!=0:continue
		var checked:=_destination("beacon:%d" % beacon.id)
		result.append({"key":"beacon:%d" % beacon.id,"label":"信标 #%02d · %d 次 / %.0fs" % [game.actor_id(beacon.owner),beacon.uses,beacon.time],"valid":not checked.is_empty(),"point":beacon.point})
	return result

func select_destination(key:String) -> void:
	if game.phase!="playing" or flying:return
	var checked:=_destination(key)
	if checked.is_empty():game.presentation.notify_ability("目标不可用，请重选");return
	selected_key=key;target=checked.point;queued=true;selector_open=false;marker.global_position=target+Vector3.UP*.07;marker.visible=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if game.player_respawn>0:
		if key=="base":aim_offset=Vector2(0,6);_resolve_target()
		if game.respawn_ready:launch()
	else:
		if cooldown>0:queued=false;game.presentation.notify_ability("快速跳跃冷却 %.1f 秒" % cooldown);return
		live_jump=true;active=true;charge_time=0;origin=game.get_node("World/Walker").global_position;return_position=origin
		var combat:Node3D=game.get_node("Combat")
		combat.charging=false;combat.charge_fraction=0;combat.flick_time=-1;combat.rolling=false;combat.firing_time=0
		var walker:Node3D=game.get_node("World/Walker");walker.active=false;walker.look_enabled=false;walker.get_node("Body").set_form(true)
		game._fire_pressed_pending=false;game._sub_pressed_pending=false;camera.global_position=origin+Vector3(0,8,-10);camera.look_at(origin+Vector3.UP);camera.current=true
		game.presentation.notify_ability("准备跳跃 · 1 秒 · Esc 取消")

func toggle_selector() -> void:
	if game.phase!="playing" or game.paused or flying:return
	if selector_open:cancel_selection();return
	if live_jump:cancel_selection()
	selector_open=true;queued=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;game.get_node("World/Walker").look_enabled=false
	if game.player_respawn<=0:game.get_node("World/Walker").active=false
	if selector!=null:selector.refresh_time=0

func cancel_selection() -> void:
	if flying:return
	selector_open=false;queued=false;selected_key="base";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if live_jump:
		var walker:Node3D=game.get_node("World/Walker");walker.global_position=return_position;walker.get_node("Body").set_form(false);walker.get_node("Camera3D").current=true;clear();game._set_pointer_lock(true)
	elif game.player_respawn>0:_resolve_target()
	else:game._set_pointer_lock(true)

func handle_input(event:InputEvent) -> bool:
	if game.phase!="playing" or game.paused:return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_J:toggle_selector();return true
		if event.keycode==KEY_ESCAPE and (selector_open or live_jump or (active and queued)):cancel_selection();return true
	if live_jump:return true
	if selector_open:
		if event is InputEventMouseButton:
			if selector!=null and selector.panel.get_global_rect().has_point(event.position/game.hud_root.scale.x):return true
			if game.player_respawn<=0:return true
		elif event is InputEventMouseMotion:return game.player_respawn<=0
		elif event is InputEventKey and game.player_respawn<=0:return true
	return false

func _fallback() -> void:
	selected_key="base";target=base_position();game.presentation.notify_ability("跳跃目标失效，返回基地")
	marker.global_position=target+Vector3.UP*.07

func launch() -> void:
	queued=true
	if not active or flying or (not live_jump and not game.respawn_ready):return
	var checked:=_destination(selected_key)
	if checked.is_empty():
		if live_jump:game.presentation.notify_ability("目标失效，跳跃取消");cancel_selection();return
		_fallback()
	else:target=checked.point
	var remote:=selected_key!="base" or live_jump
	flight_duration=1.15+minf(origin.distance_to(target)/90,.75) if remote else .72;arc_height=maxf(8,origin.distance_to(target)*.18) if remote else 4
	landing_protection=.35 if remote else float(game.get_node("Combat").weapon_data.player.spawnInvuln)
	flying=true;flight_time=0;selector_open=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;marker.visible=remote;game.play_sound("jump",origin)

func tick(delta:float) -> bool:
	if not active:return false
	if not flying and queued and game.respawn_ready:launch()
	if not flying:
		game.get_node("World/Walker/Body").set_form(true)
		var axis:=Vector2(float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A)),float(Input.is_key_pressed(KEY_W))-float(Input.is_key_pressed(KEY_S)))
		aim(Vector2(axis.x,-axis.y)*delta*170);return false
	flight_time+=delta;var t:=clampf(flight_time/flight_duration,0,1);var walker:Node3D=game.get_node("World/Walker")
	walker.global_position=origin.lerp(target,t)+Vector3.UP*sin(t*PI)*arc_height
	if flight_duration>.72:camera.global_position=walker.global_position+Vector3(0,7,-11);camera.look_at(walker.global_position+Vector3.UP)
	if t<1:return false
	# Recheck geometry/occupancy and remote target even during transit; never land in water/props.
	var valid_target:=_destination(selected_key)
	var checked:=landing(Vector2(target.x,target.z),selected_key.begins_with("beacon:"),target.y)
	if valid_target.is_empty() or checked.is_empty():_fallback()
	else:target=checked.point
	walker.global_position=target
	if selected_key.begins_with("beacon:"):
		for beacon in beacons:
			if beacon.id==int(selected_key.get_slice(":",1)):beacon.uses-=1
	walker.get_node("Body").set_form(false);walker.get_node("Camera3D").current=true;clear();return true

func tick_live(delta:float) -> void:
	cooldown=maxf(0,cooldown-delta)
	if not live_jump:return
	if not flying:
		charge_time+=delta
		if _destination(selected_key).is_empty():game.presentation.notify_ability("目标失效，跳跃取消");cancel_selection();return
		if charge_time<1:return
		launch()
	if tick(delta):
		var walker:Node3D=game.get_node("World/Walker");walker.reset_movement_state();cooldown=4;game._set_pointer_lock(true);game.play_sound("land",walker.global_position)

func selected_label() -> String:
	if selected_key=="base":return "基地"
	for choice in destinations():
		if choice.key==selected_key:return choice.label
	return "基地"

func place_beacon(actor:Node3D) -> bool:
	var team:int=game.actor_team(actor);var at:Vector3=actor.global_position
	var checked:=landing(Vector2(at.x+1.3,at.z),true,at.y,team)
	if checked.is_empty():checked=landing(Vector2(at.x-1.3,at.z),true,at.y,team)
	if checked.is_empty():return false
	for i in range(beacons.size()-1,-1,-1):
		if beacons[i].owner==actor:beacons[i].visual.queue_free();beacons.remove_at(i)
	beacon_serial+=1;var visual:=Node3D.new();add_child(visual);visual.global_position=checked.point
	var material:=StandardMaterial3D.new();material.albedo_color=Palette.color(team);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring:=MeshInstance3D.new();var shape:=TorusMesh.new();shape.inner_radius=.32;shape.outer_radius=.48;ring.mesh=shape;ring.material_override=material;visual.add_child(ring)
	var signal_light:=MeshInstance3D.new();var column:=CylinderMesh.new();column.top_radius=.06;column.bottom_radius=.06;column.height=1.1;signal_light.mesh=column;signal_light.position.y=.55;signal_light.material_override=material;visual.add_child(signal_light)
	beacons.append({"id":beacon_serial,"owner":actor,"team":team,"point":checked.point,"visual":visual,"time":45.0,"uses":2,"available":true});game.play_sound("special_activate",at);return true

func advance_beacons(delta:float) -> void:
	beacon_refresh-=delta;var refresh:bool=beacon_refresh<=0
	if refresh:beacon_refresh=.15
	for i in range(beacons.size()-1,-1,-1):
		var beacon:=beacons[i];beacon.time-=delta
		if beacon.time<=0 or beacon.uses<=0:beacon.visual.queue_free();beacons.remove_at(i);continue
		if refresh:beacon.available=not landing(Vector2(beacon.point.x,beacon.point.z),true,beacon.point.y,beacon.team).is_empty()
		beacon.visual.scale=Vector3.ONE if beacon.available else Vector3.ONE*.35

func landing(xz: Vector2, own_ink: bool, preferred_height:float=INF, team:int=0) -> Dictionary:
	var map: Node3D = game.get_node("World/Map")
	if not (map.get("map_bounds") as Rect2).has_point(xz):
		return {}
	var top:float=18 if is_inf(preferred_height) else preferred_height+0.7
	var bottom:float=-1.4 if is_inf(preferred_height) else preferred_height-0.8
	var hit := game.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(xz.x,top,xz.y),Vector3(xz.x,bottom,xz.y),1))
	if hit.is_empty() or float(hit["normal"].y)<0.68:
		return {}
	var at: Vector3 = hit["position"]
	var pads: Array = map.get("spawn_pads")
	if Vector2(at.x-pads[1].x,at.z-pads[1].z).length()<6.5:
		return {}
	var face: Dictionary = map.call("find_surface",at,hit["normal"],int(hit["collider"].get_meta("source_id",-1)))
	if face.is_empty() or not bool(face["turf"]):
		return {}
	if own_ink:
		for offset in [Vector3.ZERO,Vector3(0.32,0,0),Vector3(-0.32,0,0),Vector3(0,0,0.32),Vector3(0,0,-0.32)]:
			var relative: Vector3 = at+offset-_v(face["origin"])
			var u := relative.dot(_v(face["u"]))
			var v := relative.dot(_v(face["v"]))
			if u<0 or v<0 or u>float(face["su"]) or v>float(face["sv"]):
				return {}
			if int(game.get("ink").call("owner_at",int(face["id"]),u,v))!=team:
				return {}
	# Full standing capsule must fit. This rejects ceilings, props and narrow ledges.
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.45
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*0.81)
	query.collision_mask = 7
	query.exclude = [game.get_node("World/Walker").get_rid()]
	if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		return {}
	return {"point":at+Vector3.UP*0.05,"face":face}

func _v(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])
