extends Node3D

const COST := 35.0
const LIFE := 6.0
const RADIUS := 3.0
const HEIGHT := 4.0
const RANGE := 8.0
var game: Node3D
var volumes: Array[Dictionary] = []
var casts_total := 0

func setup(owner_game: Node3D) -> void:
	game = owner_game

func use(actor: Node3D) -> bool:
	var combat: Node3D = game.get_node("Combat")
	var tank: Node = combat if actor == combat.walker else actor
	if float(tank.ink_amount) < COST: return false
	var from := actor.global_position + Vector3.UP * .85
	var desired: Vector3
	if actor == combat.walker:
		desired = combat._aim_target(from, RANGE)
	else:
		var info: Dictionary = game.intel.nearest_contact(actor)
		if info.is_empty(): return false
		# Contacts can be frozen last positions; deployment never tracks the actor.
		desired = info.point + Vector3.UP * .85
	desired = from + (desired-from).limit_length(RANGE)
	var query := PhysicsRayQueryParameters3D.create(desired+Vector3.UP*.2, desired-Vector3.UP*4, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or float(hit.normal.y) < .68: return false
	var point: Vector3 = hit.position
	var map: Node3D = game.get_node("World/Map")
	if not map.map_bounds.has_point(Vector2(point.x,point.z)) or from.distance_to(point+Vector3.UP*.85) > RANGE+.01: return false
	if not combat._unblocked(from, point+Vector3.UP*.15): return false
	var ceiling := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.12, point+Vector3.UP*HEIGHT, 1))
	var height := HEIGHT if ceiling.is_empty() else minf(HEIGHT, float(ceiling.position.y)-point.y-.05)
	if height < .6: return false
	create_volume(actor,point,height)
	tank.ink_amount -= COST
	tank.last_fire_time = 0
	casts_total += 1
	return true

func create_volume(actor: Node3D, point: Vector3, height: float = HEIGHT) -> void:
	for i in range(volumes.size()-1,-1,-1):
		if volumes[i].owner == actor: _remove(i)
	var team: int = game.actor_team(actor)
	var center := point + Vector3.UP*height*.5
	var size := Vector3(RADIUS,height*.5,RADIUS)
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1; sphere.height = 2; sphere.radial_segments = 32; sphere.rings = 16
	visual.mesh = sphere
	var material := ShaderMaterial.new()
	material.shader = preload("res://ink_mist.gdshader")
	material.set_shader_parameter("fog_center",center)
	material.set_shader_parameter("fog_size",size)
	material.set_shader_parameter("ink_color",preload("res://team_palette.gd").color(team).lightened(.3))
	material.set_shader_parameter("density",.12 if team == 0 else 1.25)
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual); visual.global_position = center; visual.scale = size
	volumes.append({"owner":actor,"team":team,"point":point,"center":center,"size":size,"time":LIFE,"visual":visual})

func obscures(start: Vector3, end: Vector3, team: int) -> bool:
	for s in volumes:
		if s.team == team: continue
		var relative: Vector3 = (start-s.center)/s.size
		var step: Vector3 = (end-start)/s.size
		var a := step.dot(step)
		if a < .000001: continue
		var b := relative.dot(step)
		var d := b*b-a*(relative.dot(relative)-1)
		if d < 0: continue
		var enter := maxf(0,(-b-sqrt(d))/a)
		var leave := minf(1,(-b+sqrt(d))/a)
		if leave <= enter or start.distance_to(end)*(leave-enter) < .65: continue
		var middle := start.lerp(end,(enter+leave)*.5)
		# An adjoining floor/room cannot inherit a volume through solid geometry.
		if game.get_node("Combat")._unblocked(s.point+Vector3.UP*.2,middle): return true
	return false

func tick(delta: float) -> void:
	for i in range(volumes.size()-1,-1,-1):
		var s := volumes[i]
		s.time -= delta
		if s.time <= 0: _remove(i); continue
		s.visual.material_override.set_shader_parameter("fade",minf(1,s.time))

func _remove(index: int) -> void:
	volumes[index].visual.queue_free(); volumes.remove_at(index)

func clear_all() -> void:
	for i in range(volumes.size()-1,-1,-1): _remove(i)
