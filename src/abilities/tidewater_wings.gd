extends Node3D
const COST := 40.0
const LIFE := 4.0
const DRAIN := 8.0
var game: Node3D
var flights: Dictionary = {}
var casts_total := 0
func setup(owner_game: Node3D) -> void: game = owner_game
func busy(actor: Node3D) -> bool: return flights.has(actor.get_instance_id())
func begin(actor: Node3D) -> bool:
	var local := actor == game.get_node("World/Walker"); var tank: Node = game.get_node("Combat") if local else actor
	if busy(actor) or tank.ink_amount < COST: return false
	var from := actor.global_position
	var checked: Dictionary = game.deployment.landing(Vector2(from.x,from.z),false,from.y,game.actor_team(actor),actor)
	if checked.is_empty() or absf(checked.point.y-from.y) > .25: return false
	if local:
		actor.update_form(false)
		if actor.squid_form or actor.climbing: return false
		actor.floor_snap_length = 0; actor.jump_requested = false
	else: actor.team_mover.floor_snap_length = 0; actor.set_meta("enemy_swimming",false); actor.get_node("Body").set_form(false)
	var visual := Node3D.new(); add_child(visual)
	var mesh := preload("res://src/combat/ink_equipment_mesh.gd"); var color: Color = preload("res://src/core/team_palette.gd").color(game.actor_team(actor))
	for sign in [-1,1]:
		var points := PackedVector3Array([Vector3(sign*.16,1.05,-.12),Vector3(sign*.95,1.0,-.23),Vector3(sign*.78,.6,-.45),Vector3(sign*.18,.55,-.18)])
		var fabric := SurfaceTool.new(); fabric.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in [0,1,2,0,2,3]: fabric.add_vertex(points[i])
		fabric.generate_normals()
		var mat := mesh.material(color.lightened(.15),.15); mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.part(visual,fabric.commit(),mat)
		for i in 4: mesh.rod(visual,points[i],points[(i+1)%4],.022,mesh.material(Color("dce9ed"),.65))
		mesh.rod(visual,points[0],points[2],.018,mesh.material(color.darkened(.2)))
	visual.global_position = from; visual.rotation.y = actor.get_node("Body").rotation.y
	flights[actor.get_instance_id()] = {"actor":actor,"time":LIFE,"age":0.0,"base":from.y,"visual":visual}
	tank.ink_amount -= COST; tank.last_fire_time = 0; casts_total += 1; actor.set_meta("wing_casts",int(actor.get_meta("wing_casts",0))+1)
	return true
func vertical(actor: Node3D, delta: float = 1.0/30) -> float:
	var s: Dictionary = flights.get(actor.get_instance_id(),{})
	if s.is_empty(): return 0.0
	var local := actor == game.get_node("World/Walker")
	var rise := Input.is_physical_key_pressed(KEY_SPACE) if local else actor.global_position.y < float(s.base)+2.5
	var fall := Input.is_physical_key_pressed(KEY_SHIFT) if local else false
	var speed := 3.2 if rise else -3.2 if fall else 0.0
	if s.age < .35: speed = 3.2
	if speed > 0: speed = minf(speed,maxf(0,(float(s.base)+4.5-actor.global_position.y)/maxf(.001,delta)))
	return speed
func move_player(actor: CharacterBody3D, delta: float) -> void:
	var axis := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): axis.x -= 1
	if Input.is_physical_key_pressed(KEY_D): axis.x += 1
	if Input.is_physical_key_pressed(KEY_W): axis.y += 1
	if Input.is_physical_key_pressed(KEY_S): axis.y -= 1
	axis = actor._camera_relative_axis(axis.normalized())
	var speed := minf(7.0,actor.firing_speed_limit)
	actor.velocity = Vector3(axis.x*speed,vertical(actor,delta),axis.y*speed)
	var old: float = actor.global_position.y
	actor.move_and_slide(); actor._resolve_ground(false,old,false,maxf(0,-actor.velocity.y))
	actor._apply_spawn_barrier(); actor._face(delta,false,axis,false); actor._update_camera()
func tick(delta: float) -> void:
	for id in flights.keys():
		var s: Dictionary = flights[id]; var actor: Node3D = s.actor
		var tank: Node = game.get_node("Combat") if actor == game.get_node("World/Walker") else actor
		s.time -= delta; s.age += delta; tank.ink_amount = maxf(0,tank.ink_amount-DRAIN*delta); tank.last_fire_time = 0
		if s.time <= 0 or tank.ink_amount <= 0 or not game.actor_alive(actor): cancel(actor); continue
		s.visual.global_position = actor.global_position
		s.visual.rotation.y = actor.get_node("Body").rotation.y
		s.visual.rotation.z = .06*sin(s.age*15)
func cancel(actor: Node3D) -> void:
	var id := actor.get_instance_id()
	if not flights.has(id): return
	flights[id].visual.queue_free(); flights.erase(id)
	if actor == game.get_node("World/Walker"):
		actor.floor_snap_length = actor.step_down; actor.jump_requested = false; actor.jump_buffer = 0
		actor.velocity.y = minf(0,actor.velocity.y)
	else:
		actor.team_mover.floor_snap_length = .45; actor.team_mover.velocity.y = minf(0,actor.team_mover.velocity.y)
func clear_all() -> void:
	for s in flights.values(): cancel(s.actor)
