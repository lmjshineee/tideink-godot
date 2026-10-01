extends Node3D

const Palette := preload("res://team_palette.gd")
const KINDS := ["bomb","refill","shield","beacon","cluster","mist","healing"]
const COOLDOWNS := {"bomb":6.0,"refill":12.0,"shield":16.0,"beacon":18.0,"cluster":10.0,"mist":15.0,"healing":18.0}
const LABELS := {"bomb":"墨水手雷","refill":"补充剂","shield":"护盾","beacon":"跳跃信标","cluster":"爆墨瓶","mist":"减速墨雾","healing":"医疗领域"}
const BLURBS:={"bomb":"范围伤害","refill":"回血 / 回墨","shield":"60 点护盾","beacon":"队伍跳跃点","cluster":"短引信爆破","mist":"区域减速","healing":"队伍恢复"}
var fields:Array[Dictionary]=[]
var field_step:=0.0
var game: Node3D
var states: Dictionary = {}

func setup(owner_game: Node3D) -> void:
	game = owner_game
	for actor in game.call("all_actors"):
		var cooldowns:={};for id in KINDS:cooldowns[id]=0.0
		states[actor.get_instance_id()] = {"kind":"bomb","cooldowns":cooldowns,"armor":0.0,"time":0.0,"move_factor":1.0}
	equip(game.get_node("World/Walker"),preload("res://match_setup.gd").selected_item)

func state(actor: Node3D) -> Dictionary:
	return states[actor.get_instance_id()]

func equip(actor: Node3D, kind: String) -> void:
	if KINDS.has(kind):
		state(actor)["kind"] = kind
	# Cooldowns are per kind and survive rerolls/respawns; reroll cannot bypass CD.

func use(actor: Node3D, requested: String = "") -> bool:
	if game.get("phase")!="playing" or not bool(game.call("actor_alive",actor)):
		return false
	var s := state(actor)
	var kind: String = s["kind"]
	if (not requested.is_empty() and requested!=kind) or float(s["cooldowns"][kind])>0.0:
		return false
	var local: bool = actor==game.get_node("World/Walker")
	var ink_node: Node = game.get_node("Combat") if local else actor
	if kind=="bomb":
		var combat := game.get_node("Combat")
		var config: Dictionary = combat.get("weapon_data")["sub"]["bomb"]
		if float(ink_node.get("ink_amount"))<float(config["inkCost"]):
			return false
		ink_node.set("ink_amount",float(ink_node.get("ink_amount"))-float(config["inkCost"]))
		if local:
			combat.set("last_fire_time",0.0)
		combat.call("throw_actor_bomb",actor)
	elif kind=="cluster":
		if float(ink_node.get("ink_amount"))<45:return false
		var config:Dictionary=game.get_node("Combat").weapon_data.sub.bomb.duplicate(true)
		config.merge({"id":"cluster","inkCost":45,"fuse":.3,"radius":2.2,"damageMax":70,"damageMin":20,"paintRadius":2.2},true)
		ink_node.ink_amount-=45;game.get_node("Combat").throw_actor_bomb(actor,config)
	elif kind in ["mist","healing"]:
		var cost:=45.0 if kind=="mist" else 35.0
		if float(ink_node.get("ink_amount"))<cost or not _place_field(actor,kind):return false
		ink_node.ink_amount-=cost
	elif kind=="refill":
		if float(game.call("actor_health",actor))>=float(game.call("actor_max_health",actor)) and float(ink_node.get("ink_amount"))>=float(game.call("actor_ink_max",actor))-0.1:
			return false
		ink_node.set("ink_amount",minf(float(game.call("actor_ink_max",actor)),float(ink_node.get("ink_amount"))+75))
		game.call("heal_actor",actor,35.0)
	elif kind=="beacon":
		if float(ink_node.get("ink_amount"))<35 or not game.deployment.place_beacon(actor):return false
		ink_node.set("ink_amount",float(ink_node.get("ink_amount"))-35)
	else:
		s["armor"] = 60.0
		s["time"] = 6.0
		if not s.has("visual"):
			var visual := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.92
			sphere.height = 1.84
			visual.mesh = sphere
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(Palette.color(int(game.call("actor_team",actor))).lightened(0.4),0.18)
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			visual.material_override = material
			add_child(visual)
			s["visual"] = visual
	s["cooldowns"][kind] = game.perks.item_cooldown(actor,COOLDOWNS[kind])
	if kind!="bomb":
		game.call("play_sound","special_activate",actor.global_position)
	if local and kind!="bomb":
		game.get("presentation").call("notify_ability",{"refill":"补充剂：恢复墨水与生命","shield":"护盾：吸收 60 伤害 · 6 秒","beacon":"已设置信标 · J 跳跃 · 2 次 / 45 秒","cluster":"爆墨瓶投出","mist":"减速墨雾 · 6 秒","healing":"医疗领域 · 5 秒"}[kind])
	return true

func absorb(actor: Node3D, amount: float) -> float:
	var s := state(actor)
	var blocked := minf(amount,float(s["armor"]))
	s["armor"] = maxf(0.0,float(s["armor"])-blocked)
	if blocked>0.0:
		game.get_node("Combat").get("feedback").call("emit","hit",actor.global_position+Vector3.UP,int(game.call("actor_team",actor)))
	return amount-blocked

func on_death(actor: Node3D) -> void:
	var s := state(actor)
	s["armor"] = 0.0
	s["time"] = 0.0


func on_respawn(actor: Node3D) -> void:
	on_death(actor)

func tick(delta: float) -> void:
	game.deployment.advance_beacons(delta)
	_advance_fields(delta)
	for actor in game.call("all_actors"):
		var s := state(actor)
		for kind in KINDS:
			s["cooldowns"][kind] = maxf(0,float(s["cooldowns"][kind])-delta)
		s["time"] = maxf(0,float(s["time"])-delta)
		if float(s["time"])<=0:
			s["armor"] = 0.0
		if s.has("visual"):
			var visual: MeshInstance3D = s["visual"]
			visual.visible = float(s["armor"])>0 and bool(game.call("actor_alive",actor))
			visual.global_position = actor.global_position+Vector3.UP*0.75
		if actor==game.get_node("World/Walker") or not bool(game.call("actor_alive",actor)):
			continue
		var kind: String = s["kind"]
		if kind=="refill" and (float(game.call("actor_health",actor))<=80 or float(actor.get("ink_amount"))<20):
			use(actor)
		elif kind=="healing" and float(game.call("actor_health",actor))<float(game.call("actor_max_health",actor))*.75:
			use(actor)
		elif kind=="shield" and float(game.call("actor_health",actor))<100:
			use(actor)
		elif kind=="beacon":
			s["beacon_try"]=float(s.get("beacon_try",0))-delta
			if float(s["beacon_try"])<=0:
				s["beacon_try"]=2.0
				use(actor)
		elif kind in ["bomb","cluster","mist"]:
			for enemy in game.call("enemies",int(game.call("actor_team",actor))):
				if enemy.global_position.distance_to(actor.global_position)<12.0:
					use(actor)
					break

func hud_text() -> String:
	var s := state(game.get_node("World/Walker"))
	var kind: String = s["kind"]
	var cd := float(s["cooldowns"][kind])
	return game.get("perks").call("hud_text")+"  |  "+"右键 / E  %s  ·  %s%s" % [LABELS[kind],"%.1f 秒" % cd if cd>0 else "就绪","  ·  护盾 %.0f / %.1fs" % [s["armor"],s["time"]] if float(s["armor"])>0 else ""]


func move_factor(actor:Node3D) -> float:
	return float(state(actor).get("move_factor",1.0))

func _place_field(actor:Node3D,kind:String) -> bool:
	var at:Vector3=actor.global_position
	var combat:Node3D=game.get_node("Combat")
	if kind=="mist":
		var desired:Vector3=combat._aim_target(at+Vector3.UP,8) if actor==game.get_node("World/Walker") else at
		if actor!=game.get_node("World/Walker"):
			var best:=INF
			for enemy in game.enemies(game.actor_team(actor)):
				var gap:float=at.distance_to(enemy.global_position)
				if gap<best:best=gap;desired=enemy.global_position
		var offset:Vector3=(desired-at).limit_length(8);at+=offset
	var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*2,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or float(hit.normal.y)<.68:return false
	at=hit.position
	var map:Node3D=game.get_node("World/Map")
	if not map.map_bounds.has_point(Vector2(at.x,at.z)):return false
	if not combat._unblocked(actor.global_position+Vector3.UP*.8,at+Vector3.UP*.8):return false
	for i in range(fields.size()-1,-1,-1):
		if fields[i].owner==actor and fields[i].kind==kind:fields[i].visual.queue_free();fields.remove_at(i)
	var visual:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=4;mesh.bottom_radius=4;mesh.height=.12;mesh.radial_segments=48;visual.mesh=mesh
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(Palette.color(game.actor_team(actor)),.22);visual.material_override=material;add_child(visual);visual.global_position=at+Vector3.UP*.12
	var duration:=6.0 if kind=="mist" else 5.0
	fields.append({"kind":kind,"owner":actor,"team":game.actor_team(actor),"point":at,"time":duration,"total":duration,"radius":4.0,"paint":0.0,"visual":visual})
	return true

func _advance_fields(delta:float) -> void:
	field_step+=delta
	for i in range(fields.size()-1,-1,-1):
		var field:=fields[i];field.time-=delta
		if field.time<=0:field.visual.queue_free();fields.remove_at(i);continue
		field.visual.get_active_material(0).albedo_color.a=.22*minf(1,field.time)
	if field_step<.2:return
	var step:=field_step;field_step=0
	var combat:Node3D=game.get_node("Combat")
	for actor in game.all_actors():
		state(actor).move_factor=1.0
		if not game.actor_alive(actor):continue
		for field in fields:
			if absf(actor.global_position.y-field.point.y)>1.5 or Vector2(actor.global_position.x-field.point.x,actor.global_position.z-field.point.z).length()>field.radius:continue
			if not combat._unblocked(field.point+Vector3.UP*.8,actor.global_position+Vector3.UP*.8):continue
			if field.kind=="mist" and game.actor_team(actor)!=field.team:state(actor).move_factor=.65
			elif field.kind=="healing" and game.actor_team(actor)==field.team:game.heal_actor(actor,12*step)
	game.get_node("World/Walker").external_speed_factor=move_factor(game.get_node("World/Walker"))
	for field in fields:
		field.paint+=step
		if field.kind=="mist" and field.paint>=.4:
			field.paint=0
			var previous:Node3D=game.painting_actor;var previous_bot:bool=game.bot_painting
			game.painting_actor=field.owner;game.bot_painting=field.owner!=game.get_node("World/Walker")
			game.paint_at_world(field.point+Vector3.UP*.1,field.team,field.radius,randf())
			game.painting_actor=previous;game.bot_painting=previous_bot
