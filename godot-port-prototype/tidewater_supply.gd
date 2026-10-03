extends Node3D
const COST := 40.0
const LIFE := 14.0
const CHANNEL := .6
var game: Node3D
var boxes: Dictionary = {}
var channels: Dictionary = {}
var serial := 0
var casts_total := 0
var received_total := 0
var stolen_total := 0
func setup(owner_game: Node3D) -> void: game = owner_game

func place(actor: Node3D) -> bool:
	var tank: Node = game.get_node("Combat") if actor == game.get_node("World/Walker") else actor
	if tank.ink_amount < COST: return false
	var from := actor.global_position
	var checked: Dictionary = game.deployment.landing(Vector2(from.x,from.z),false,from.y,game.actor_team(actor),actor)
	if checked.is_empty() or absf(checked.point.y-from.y) > .25: return false
	for id in boxes.keys():
		if boxes[id].owner == actor: _remove(id)
	serial += 1
	var team: int = game.actor_team(actor)
	var body := StaticBody3D.new(); body.collision_mask = 0; body.collision_layer = 16384 if team == 0 else 32768; body.set_meta("supply_key",serial)
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(.7,.5,.5); shape.shape = box; shape.position.y = .25; body.add_child(shape)
	add_child(body); body.global_position = checked.point
	var mesh := preload("res://ink_equipment_mesh.gd"); var color: Color = preload("res://team_palette.gd").color(team)
	mesh.rod(body,Vector3(0,.06,0),Vector3(0,.14,0),.38,mesh.material(Color("283045")))
	var packs: Array[MeshInstance3D] = []
	for x in [-.18,.18]:
		var pack := MeshInstance3D.new(); var cylinder := CylinderMesh.new(); cylinder.top_radius = .115; cylinder.bottom_radius = .115; cylinder.height = .4
		pack.mesh = cylinder; pack.position = Vector3(x,.31,0); pack.material_override = mesh.material(color.lightened(.3)); body.add_child(pack); packs.append(pack)
		mesh.rod(body,Vector3(x,.5,0),Vector3(x,.56,0),.075,mesh.material(Color("e8eff4")))
	boxes[serial] = {"id":serial,"owner":actor,"team":team,"point":checked.point,"visual":body,"packs":packs,"health":60.0,"time":LIFE,"stock":2,"used":{}}
	tank.ink_amount -= COST; tank.last_fire_time = 0; casts_total += 1
	actor.set_meta("supply_casts",int(actor.get_meta("supply_casts",0))+1)
	return true

func available(actor: Node3D, b: Dictionary) -> bool:
	return b.stock > 0 and not b.used.has(actor.get_instance_id())
func destination(actor: Node3D) -> Dictionary:
	var found := {}; var best := 14.0
	for b in boxes.values():
		var gap: float = actor.global_position.distance_to(b.point)
		if available(actor,b) and gap < best and (b.team == game.actor_team(actor) or game.intel.visible_point(b.point+Vector3.UP*.25,game.actor_team(actor))):
			found = b; best = gap
	return found
func eligible(actor: Node3D) -> bool:
	if not game.actor_alive(actor) or game.mobility.busy(actor) or game.wings.busy(actor): return false
	var local := actor == game.get_node("World/Walker"); var tank: Node = game.get_node("Combat") if local else actor
	if tank.ink_amount > game.actor_ink_max(actor)-10 or tank.last_fire_time < CHANNEL: return false
	if local:
		if actor.squid_form or game.deployment.active or tank.special_active != "" or tank.is_busy() or tank.action_lock > 0 or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return false
	elif actor.get_meta("enemy_swimming",false) or actor.target_actor != null or int(actor.get_meta("decoy_target",0)) != 0 or game.bot_specials.busy(actor): return false
	var recent: float = game.player_last_damage if local else game.bot_last_damage if actor == game.get_node("Bot") else actor.last_damage
	if recent < CHANNEL: return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.15,actor.global_position-Vector3.UP*.2,1))
	return not hit.is_empty() and hit.normal.y >= .68

func tick(delta: float) -> void:
	for id in boxes.keys():
		boxes[id].time -= delta
		if boxes[id].time <= 0: _remove(id)
	for actor in game.all_actors():
		var key: int = actor.get_instance_id()
		if not eligible(actor): channels.erase(key); continue
		var nearest := {}; var best := 1.6
		for b in boxes.values():
			var gap: float = actor.global_position.distance_to(b.point)
			if available(actor,b) and gap < best and game.get_node("Combat")._unblocked(actor.global_position+Vector3.UP*.3,b.point+Vector3.UP*.25): nearest = b; best = gap
		if nearest.is_empty(): channels.erase(key); continue
		var c: Dictionary = channels.get(key,{"box":nearest.id,"time":0.0,"point":actor.global_position,"anchor":actor.global_position})
		if c.box != nearest.id or (c.point as Vector3).distance_to(actor.global_position) > delta*.8+.015 or (c.anchor as Vector3).distance_to(actor.global_position) > .08:
			c = {"box":nearest.id,"time":0.0,"point":actor.global_position,"anchor":actor.global_position}
			channels[key] = c; continue
		c.time += delta; c.point = actor.global_position; channels[key] = c
		if c.time < CHANNEL: continue
		var tank: Node = game.get_node("Combat") if actor == game.get_node("World/Walker") else actor
		var gain := minf(35,game.actor_ink_max(actor)-float(tank.ink_amount))
		tank.ink_amount += gain; tank.last_fire_time = 0
		if actor == game.get_node("World/Walker"): tank.action_lock = maxf(tank.action_lock,.25)
		else: actor.set_meta("action_lock",maxf(float(actor.get_meta("action_lock",0)),.25))
		nearest.stock -= 1; nearest.used[key] = true; nearest.packs[nearest.stock].visible = false
		received_total += 1; channels.erase(key); actor.set_meta("supply_received",int(actor.get_meta("supply_received",0))+1)
		if nearest.team != game.actor_team(actor): stolen_total += 1
		game.play_sound("special_activate",nearest.point)
		if actor == game.get_node("World/Walker"): game.presentation.notify_ability("领取墨水 +%.0f · %s" % [gain,"敌方补给已夺取" if nearest.team != 0 else "接力补给"])
		if nearest.stock <= 0: _remove(nearest.id)

func channel_text(actor: Node3D) -> String:
	var c: Dictionary = channels.get(actor.get_instance_id(),{})
	return "领取补给 %.0f%% · 保持停留" % minf(100,c.time/CHANNEL*100) if not c.is_empty() else ""
func cancel(actor: Node3D) -> void: channels.erase(actor.get_instance_id())
func damage_hit(hit: Dictionary, amount: float, team: int) -> bool:
	if hit.is_empty() or not hit.collider.has_meta("supply_key"): return false
	var id: int = hit.collider.get_meta("supply_key")
	if not boxes.has(id) or boxes[id].team == team: return false
	boxes[id].health -= maxf(0,amount); game.get_node("Combat").feedback.emit("hit",boxes[id].point+Vector3.UP*.25,team)
	if boxes[id].health <= 0: _remove(id)
	return true
func damage_area(at: Vector3, radius: float, amount: float, team: int) -> void:
	for id in boxes.keys():
		var b: Dictionary = boxes[id]; var to: Vector3 = b.point+Vector3.UP*.25
		if b.team != team and at.distance_to(to) <= radius and game.get_node("Combat")._unblocked(at,to): damage_hit({"collider":b.visual},amount,team)
func _remove(id: int) -> void:
	if not boxes.has(id): return
	boxes[id].visual.collision_layer = 0; boxes[id].visual.queue_free(); boxes.erase(id)
	for key in channels.keys():
		if channels[key].box == id: channels.erase(key)
func clear_all() -> void:
	for id in boxes.keys(): _remove(id)
	channels.clear()
