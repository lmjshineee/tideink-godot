extends Node3D

const Palette := preload("res://team_palette.gd")
const KINDS := ["bomb","intel_mist","beacon","recall","sonar","mine","echo_decoy","supply_box","ink_wings"]
const COOLDOWNS := {"ink_wings":18.0,"echo_decoy":12.0,"supply_box":20.0,"mine":10.0,"intel_mist":15.0,"sonar":18.0,"recall":14.0,"bomb":6.0,"refill":12.0,"shield":16.0,"beacon":18.0,"cluster":10.0,"mist":15.0,"healing":18.0}
const LABELS := {"ink_wings":"墨翼背包","echo_decoy":"回声诱饵","supply_box":"接力补给盒","mine":"感应墨雷","intel_mist":"信息墨雾","sonar":"脉冲声呐","recall":"回溯锚","bomb":"墨水手雷","refill":"补充剂","shield":"护盾","beacon":"跳跃信标","cluster":"爆墨瓶","mist":"减速墨雾","healing":"医疗领域"}
const BLURBS:={"ink_wings":"升降悬停 / 空中主射","echo_decoy":"假身诱敌 / 声呐识破","supply_box":"停留领取 / 敌方可抢","mine":"埋伏 / 可拆 / 位置标记","intel_mist":"遮断视野 / 声呐反制","sonar":"扩散探测 / 队伍标记","recall":"标记 / 瞬间返回","bomb":"范围伤害","refill":"回血 / 回墨","shield":"60 点护盾","beacon":"队伍跳跃点","cluster":"短引信爆破","mist":"区域减速","healing":"队伍恢复"}
var fields:Array[Dictionary]=[]
var field_step:=0.0
var recall: Node3D
var mist: Node3D
var sonar: Node3D
var mines: Node3D
var decoys: Node3D
var supply: Node3D
var game: Node3D
var states: Dictionary = {}

func setup(owner_game: Node3D) -> void:
	game = owner_game
	recall = preload("res://tidewater_recall.gd").new()
	add_child(recall)
	recall.setup(game)
	sonar = preload("res://tidewater_sonar.gd").new()
	add_child(sonar)
	sonar.setup(game)
	mist = preload("res://tidewater_mist.gd").new()
	add_child(mist)
	mist.setup(game)
	mines = preload("res://tidewater_mines.gd").new()
	add_child(mines)
	mines.setup(game)
	decoys = preload("res://tidewater_decoys.gd").new(); add_child(decoys); decoys.setup(game)
	supply = preload("res://tidewater_supply.gd").new(); add_child(supply); supply.setup(game)
	if not KINDS.has(preload("res://match_setup.gd").selected_item): preload("res://match_setup.gd").selected_item = "bomb"
	for actor in game.call("all_actors"):
		var cooldowns:={};for id in COOLDOWNS:cooldowns[id]=0.0
		states[actor.get_instance_id()] = {"kind":"bomb","cooldowns":cooldowns,"armor":0.0,"time":0.0,"move_factor":1.0}
	equip(game.get_node("World/Walker"),preload("res://match_setup.gd").selected_item)

func state(actor: Node3D) -> Dictionary:
	return states[actor.get_instance_id()]

func equip(actor: Node3D, kind: String) -> void:
	if COOLDOWNS.has(kind):
		state(actor)["kind"] = kind
	# Cooldowns are per kind and survive rerolls/respawns; reroll cannot bypass CD.

func use(actor: Node3D, requested: String = "") -> bool:
	if game.get("phase")!="playing" or game.paused or not bool(game.call("actor_alive",actor)) or game.mobility.busy(actor) or game.wings.busy(actor):
		return false
	var s := state(actor)
	var kind: String = s["kind"]
	if (not requested.is_empty() and requested!=kind) or float(s["cooldowns"][kind])>0.0:
		return false
	var local: bool = actor==game.get_node("World/Walker")
	if local and (game.deployment.active or game.get_node("Combat").special_active != "" or game.get_node("Combat").action_lock > 0): return false
	if not local and game.bot_specials.busy(actor): return false
	if kind == "recall": return recall.use(actor)
	var ink_node: Node = game.get_node("Combat") if local else actor
	if kind == "ink_wings":
		if not game.wings.begin(actor): return false
	elif kind == "echo_decoy":
		if not decoys.place(actor): return false
	elif kind == "supply_box":
		if not supply.place(actor): return false
	elif kind == "mine":
		if not mines.place(actor): return false
	elif kind == "intel_mist":
		if not mist.use(actor): return false
	elif kind == "sonar":
		if not sonar.place(actor): return false
	elif kind=="bomb":
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
		game.get("presentation").call("notify_ability",{"ink_wings":"墨翼展开 · 4 秒 · 空格上升 / Shift 下降 · 可主射", "echo_decoy":"诱饵部署 · 8 秒 · 声呐可以识破", "supply_box":"补给部署 · 两份墨水 · 停留 0.6 秒领取 / 敌方可抢", "mine":"墨雷部署 · 0.8s 布防 / 30s · 敌弹可拆", "intel_mist":"信息墨雾 · 遮断敌方视野 6 秒 · 声呐可标记", "sonar":"声呐部署 · 12m 脉冲 / 8 秒 · 墙与楼板遮挡", "refill":"补充剂：恢复墨水与生命","shield":"护盾：吸收 60 伤害 · 6 秒","beacon":"已设置信标 · J 跳跃 · 2 次 / 45 秒","cluster":"爆墨瓶投出","mist":"减速墨雾 · 6 秒","healing":"医疗领域 · 5 秒"}[kind])
	return true

func absorb(actor: Node3D, amount: float) -> float:
	var s := state(actor)
	var blocked := minf(amount,float(s["armor"]))
	s["armor"] = maxf(0.0,float(s["armor"])-blocked)
	if blocked>0.0:
		game.get_node("Combat").get("feedback").call("emit","hit",actor.global_position+Vector3.UP,int(game.call("actor_team",actor)))
	return amount-blocked

func on_death(actor: Node3D) -> void:
	game.intel.forget(actor)
	supply.cancel(actor)
	game.wings.cancel(actor)
	game.perks.on_death(actor)
	recall.clear_actor(actor)
	game.mobility.cancel(actor)
	var s := state(actor)
	s["armor"] = 0.0
	s["time"] = 0.0


func on_respawn(actor: Node3D) -> void:
	game.intel.forget(actor)
	recall.clear_actor(actor)
	game.mobility.cancel(actor)
	supply.cancel(actor)
	game.wings.cancel(actor)
	state(actor).armor = 0
	state(actor).time = 0

func tick(delta: float) -> void:
	recall.tick(delta)
	sonar.tick(delta)
	mist.tick(delta)
	mines.tick(delta)
	decoys.tick(delta)
	supply.tick(delta)
	game.deployment.advance_beacons(delta)
	_advance_fields(delta)
	for actor in game.call("all_actors"):
		var s := state(actor)
		for kind in COOLDOWNS:
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
		if kind == "recall":
			s["recall_try"] = float(s.get("recall_try", 0)) - delta
			if float(s["recall_try"]) <= 0:
				s["recall_try"] = 1.5
				if recall.anchors.has(actor.get_instance_id()):
					if game.actor_health(actor) <= 60 and actor.global_position.distance_to(recall.anchors[actor.get_instance_id()].point) > 2: use(actor)
				elif game.actor_health(actor) > 80: use(actor)
		elif kind == "ink_wings":
			if actor.target_actor != null and (absf(actor.target_actor.global_position.y-actor.global_position.y) > 1 or game.actor_health(actor) <= 90): use(actor)
		elif kind == "echo_decoy":
			var info: Dictionary = game.intel.nearest_contact(actor)
			if not info.is_empty() and actor.global_position.distance_to(info.point) <= 10 and game.actor_health(actor) <= 100: use(actor)
		elif kind == "supply_box":
			if actor.ink_amount >= 40 and actor.ink_amount <= 65 and actor.target_actor == null: use(actor)
		elif kind == "mine":
			var info: Dictionary = game.intel.nearest_contact(actor)
			if not info.is_empty() and actor.global_position.distance_to(info.point) <= 10 and game.actor_health(actor) <= 100: use(actor)
		elif kind == "intel_mist":
			var info: Dictionary = game.intel.nearest_contact(actor)
			if not info.is_empty() and actor.global_position.distance_to(info.point) <= 8 and game.actor_health(actor) <= 90: use(actor)
		elif kind == "sonar":
			var info: Dictionary = game.intel.nearest_contact(actor)
			if actor.target_actor != null or (not info.is_empty() and actor.global_position.distance_to(info.point) <= 12): use(actor)
		elif kind=="refill" and (float(game.call("actor_health",actor))<=80 or float(actor.get("ink_amount"))<20):
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
	var key := game.get_node("World/Walker").get_instance_id()
	if game.wings.busy(game.get_node("World/Walker")):
		return game.perks.hud_text()+"  |  墨翼 %.1fs · 空格 ↑ / Shift ↓ · 持续耗墨" % game.wings.flights[key].time
	var progress: String = supply.channel_text(game.get_node("World/Walker"))
	if not progress.is_empty(): return game.perks.hud_text()+"  |  "+progress
	if kind == "echo_decoy":
		for d in decoys.decoys.values():
			if d.owner.get_instance_id() == key: return game.perks.hud_text()+"  |  诱饵 %.1fs · %.0f HP · CD %.1fs" % [d.time,d.health,cd]
	if kind == "supply_box":
		for b in supply.boxes.values():
			if b.owner.get_instance_id() == key: return game.perks.hud_text()+"  |  补给 %d / 2 · %.1fs · %.0f HP · CD %.1fs" % [b.stock,b.time,b.health,cd]
	if kind == "mine":
		var count := 0; var life := 0.0; var warning := false
		for m in mines.mines.values():
			if m.owner.get_instance_id() == key: count += 1; life = maxf(life,m.time); warning = warning or m.fuse >= 0
		if count > 0: return game.perks.hud_text()+"  |  墨雷 %d / 2 · %.0fs · %s · CD %.1fs" % [count,life,"起爆警告" if warning else "布防",cd]
	if kind == "intel_mist":
		for volume in mist.volumes:
			if volume.owner.get_instance_id() == key: return game.perks.hud_text()+"  |  信息墨雾 %.1fs · CD %.1fs · 声呐可反制" % [volume.time,cd]
	if kind == "sonar" and sonar.stations.has(key):
		var station: Dictionary = sonar.stations[key]
		return game.perks.hud_text() + "  |  声呐 %.1fs · %.0f HP · 下一脉冲 %.1fs · CD %.1fs" % [station.time, station.health, station.next, cd]
	if kind == "recall" and recall.anchors.has(key):
		var a: Dictionary = recall.anchors[key]
		return game.perks.hud_text() + "  |  E / 右键 回溯 · %.1fs · %.1f / 18m · 锚 %.0f HP" % [a.time, game.get_node("World/Walker").global_position.distance_to(a.point), a.health]
	return game.get("perks").call("hud_text")+"  |  "+"右键 / E  %s  ·  %s%s" % [LABELS[kind],"%.1f 秒" % cd if cd>0 else "就绪","  ·  护盾 %.0f / %.1fs" % [s["armor"],s["time"]] if float(s["armor"])>0 else ""]

# A display-only snapshot: no placement probes, resource spending or timer changes.
func hud_status() -> Dictionary:
	var walker := game.get_node("World/Walker")
	var combat := game.get_node("Combat")
	var s := state(walker)
	var kind: String = s.kind
	var key := walker.get_instance_id()
	var cd: float = s.cooldowns[kind]
	var total: float = game.perks.item_cooldown(walker,COOLDOWNS[kind])
	var status := {"kind":kind,"title":LABELS[kind],"cooldown":cd,"progress":1.0-clampf(cd/total,0,1),"state":"cooldown" if cd>0 else "ready","detail":"冷却 %.1fs" % cd if cd>0 else "E / 右键 · 就绪"}
	if game.wings.busy(walker):
		status.state = "active"
		status.detail = "飞行 %.1fs · Space ↑ / Shift ↓" % game.wings.flights[key].time
	elif kind == "recall" and recall.anchors.has(key):
		var anchor: Dictionary = recall.anchors[key]
		var distance: float = walker.global_position.distance_to(anchor.point)
		status.state = "active"
		status.detail = "E 返回 · %.1fs · %.1f / 18m" % [anchor.time,distance]
		if distance > recall.RANGE:
			status.state = "blocked"; status.detail = "超出 18m · 当前距离 %.1fm" % distance
	else:
		var channel: String = supply.channel_text(walker)
		if not channel.is_empty():
			status.detail = channel; status.state = "active"
		elif kind in ["echo_decoy","supply_box","mine","intel_mist","sonar"]:
			var raw := hud_text().get_slice("  |  ",1)
			if not raw.begins_with("右键"):
				status.detail = raw; status.state = "active"
	if status.state == "ready":
		var costs := {"bomb":float(combat.weapon_data.sub.bomb.inkCost),"beacon":35.0,"recall":preload("res://tidewater_recall.gd").COST,"intel_mist":preload("res://tidewater_mist.gd").COST,"sonar":preload("res://tidewater_sonar.gd").COST,"mine":preload("res://tidewater_mines.gd").COST,"echo_decoy":preload("res://tidewater_decoys.gd").COST,"supply_box":preload("res://tidewater_supply.gd").COST,"ink_wings":preload("res://tidewater_wings.gd").COST}
		if combat.ink_amount < float(costs.get(kind,0)):
			status.state = "blocked"; status.detail = "墨水不足 · 需要 %.0f" % costs[kind]
		elif game.deployment.active or combat.special_active!="" or combat.action_lock>0 or game.mobility.busy(walker):
			status.state = "blocked"; status.detail = "当前动作结束后可用"
	return status


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
