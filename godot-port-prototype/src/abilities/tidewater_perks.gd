extends RefCounted

# One persistent choice per actor per match. Equipment rerolls never call select.
const ORDER := ["balanced","adrenaline","leech","enemy_swim","vault_runner","last_ink","dry_focus","turf_engine"]
const LABELS := {"vault_runner":"翻墙加速","last_ink":"残墨引爆","dry_focus":"极限省墨","turf_engine":"涂地充能","enemy_swim":"敌墨潜游","balanced":"均衡","vitality":"强健体魄","runner":"游击步伐","saver":"节墨专家","reserve":"扩容墨囊","adrenaline":"逆境反击","recovery":"快速恢复","bulwark":"爆破防护","subtech":"道具技师","leech":"命中回复","focus":"稳枪专注","recycler":"循环墨泵"}
const DESCRIPTIONS := {
	"vault_runner":"成功攀上己方墨墙后，人形跑速 +35% 持续 .9 秒；窗口内受敌袭伤害 +15%。触发间隔 6 秒，机器人越过实际高障碍同样触发；普通平地跳跃不触发",
	"last_ink":"被击倒后原地预告 .65 秒，再引爆残墨，半径 2.6m、伤害 32→16，涂墨半径 1.3m；墙与楼板遮挡、无友伤、不充能。代价是复活额外 .75 秒；敌人能在预告期间离开",
	"dry_focus":"墨水不超过 20 时，主武器消耗减少 35%、伤害减少 20%；墨量回到 20 以上恢复常态。道具、大招、墨翼耗墨与护伞耗墨保持原值；伤害按发射时低墨状态保存",
	"turf_engine":"每次实际新增涂地的大招充能 +25%，攻击伤害 -10%；重涂己方墨和大招自身涂地仍不充能。可与逆风支援同时生效",
	"enemy_swim":"敌墨地面可潜泳（8 m/s）；敌墨每秒伤害 6、累计最多失血 20，敌人攻击伤害 +10%；敌墨中不回墨、不回血，保留可见扰动",
	"balanced":"标准 120 生命 / 100 墨水，无额外加成",
	"vitality":"最大生命 +25%（150），墨水与伤害不变",
	"runner":"奔跑与潜泳速度 +10%",
	"saver":"主武器墨水消耗 -20%",
	"reserve":"最大墨水 +25%（125）",
	"adrenaline":"生命 ≤50% 时伤害 +15%、回墨速度 +50%",
	"recovery":"脱战恢复提前 0.5 秒，回血速度 +25%",
	"bulwark":"受到爆破、手雷与大招伤害 -20%",
	"subtech":"道具冷却 -20%；死亡和换装仍保留剩余冷却",
	"leech":"主武器有效扣血的 15% 回复自身，单次最多 6 HP",
	"focus":"站立主武器散布 -35%；不增加伤害或空中精度",
	"recycler":"所有自然回墨速度 +25%；容量与伤害不变"}
var game: Node3D
var choices: Dictionary = {}
var locked := false
var death_bursts: Array[Dictionary] = []
var bursts_total := 0

func setup(owner: Node3D) -> void:
	game = owner
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for actor in game.call("all_actors"):
		choices[actor.get_instance_id()] = preload("res://src/core/match_setup.gd").selected_perk if actor==game.get_node("World/Walker") else ORDER[rng.randi_range(0,ORDER.size()-1)]
	var selected: String = preload("res://src/core/match_setup.gd").selected_perk
	if not ORDER.has(selected):
		choices[game.get_node("World/Walker").get_instance_id()] = "balanced"
		preload("res://src/core/match_setup.gd").selected_perk = "balanced"
	apply_movement()

func kind(actor: Node3D) -> String:
	return String(choices.get(actor.get_instance_id(),"balanced"))

func select_player(id: String) -> bool:
	if locked or game.get("phase") not in ["home","setup"] or not LABELS.has(id):
		return false
	var actor := game.get_node("World/Walker") as Node3D
	choices[actor.get_instance_id()] = id
	preload("res://src/core/match_setup.gd").selected_perk = id
	game.set("player_health",max_health(actor))
	game.get_node("Combat").set("ink_amount",max_ink(actor))
	apply_movement()
	return true

func max_health(actor: Node3D) -> float:
	var base := float(game.get_node("Combat").get("weapon_data")["player"]["hp"])
	return base*1.25 if kind(actor)=="vitality" else base

func max_ink(actor: Node3D) -> float:
	var base := float(game.get_node("Combat").get("weapon_data")["player"]["inkMax"])
	return base*1.25 if kind(actor)=="reserve" else base

func movement(actor: Node3D) -> float:
	return 1.1 if kind(actor)=="runner" else 1.0

func apply_movement() -> void:
	var actor := game.get_node("World/Walker")
	var config: Dictionary = game.get_node("Combat").get("weapon_data")["player"].duplicate(true)
	for field in ["runSpeed","swimSpeed","squidDrySpeed"]:
		config[field] = float(config[field])*movement(actor)
	actor.set("player_config",config)
	actor.enemy_swim_enabled = kind(actor) == "enemy_swim"
	actor.perk_rules = self

func active(actor: Node3D) -> bool:
	var health := float(game.call("actor_health",actor))
	return health>0 and health<=max_health(actor)*0.5

func outgoing(actor: Node3D) -> float:
	if is_instance_valid(actor) and kind(actor) == "turf_engine": return .9
	return 1.15 if is_instance_valid(actor) and kind(actor)=="adrenaline" and active(actor) else 1.0

func incoming(actor: Node3D, source: String) -> float:
	if kind(actor) == "vault_runner" and float(actor.get_meta("vault_boost",0)) > 0 and source != "enemy_ink": return 1.15
	if kind(actor) == "enemy_swim" and source != "enemy_ink": return 1.1
	return 0.8 if kind(actor)=="bulwark" and source in ["blaster","rapid","bomb","cluster","slam","storm"] else 1.0

func refill(actor: Node3D) -> float:
	var base := 1.25 if kind(actor)=="recycler" else 1.5 if kind(actor)=="adrenaline" and active(actor) else 1.0
	return base * game.comeback.refill(actor)

func charge(actor: Node3D) -> float:
	return game.comeback.charge(actor) * (1.25 if kind(actor) == "turf_engine" else 1.0)

func item_cooldown(actor:Node3D,base:float) -> float:
	return base*.8 if kind(actor)=="subtech" else base

func on_hit(actor:Node3D,damage:float,source:String) -> void:
	if is_instance_valid(actor) and game.actor_alive(actor) and kind(actor)=="leech" and game.get_node("Combat").weapons.has(source):
		game.heal_actor(actor,minf(6,damage*.15))

func regen_delay(actor: Node3D, base: float) -> float:
	return base-0.5 if kind(actor)=="recovery" else base

func regen_rate(actor: Node3D, base: float) -> float:
	return base*1.25 if kind(actor)=="recovery" else base

func weapon(actor: Node3D, original: Dictionary) -> Dictionary:
	var low := dry_active(actor)
	if kind(actor) not in ["saver","focus"] and not low: return original
	if low:
		var reduced := original.duplicate()
		for field in ["inkPerShot","inkFull","flickInk","rollInkPerMeter","inkMin"]:
			if reduced.has(field): reduced[field] = float(reduced[field])*.65
		for field in ["damage","returnDamage","damageMin","damageMax","directDamage","splashDamageMax","splashDamageMin","flickDamageNear","flickDamageFar","rollDamage","arrowDamageMin","arrowDamageMax","blastDamage"]:
			if reduced.has(field): reduced[field] = float(reduced[field])*.8
		return reduced
	var result := original.duplicate()
	if kind(actor)=="focus":
		result["spreadBaseGround"]=float(result.get("spreadBaseGround",0))*.65
		return result
	for field in ["inkPerShot","inkFull","flickInk","rollInkPerMeter","inkMin","launchInk","coverDrain"]:
		if result.has(field): result[field] = float(result[field])*0.8
	return result

func hud_text() -> String:
	var actor := game.get_node("World/Walker") as Node3D
	var id := kind(actor)
	var triggered := (id=="adrenaline" and active(actor)) or dry_active(actor) or vault_factor(actor)>1
	return "天赋 %s%s" % [LABELS[id]," · 已触发" if triggered else " · 整局锁定"]

func ink_hazard(actor: Node3D) -> float:
	return 0.3 if kind(actor) == "enemy_swim" else 1.0

func ink_hazard_cap(actor: Node3D, base: float) -> float:
	return base*0.5 if kind(actor) == "enemy_swim" else base

func bot_form(actor: Node3D, fighting: bool) -> void:
	var swimming: bool = not game.wings.busy(actor) and kind(actor) == "enemy_swim" and not fighting and not game.bot_specials.busy(actor) and actor.floor_ink_owner() == 1 - game.actor_team(actor)
	if actor.team_mover != null and not actor.team_mover.is_on_floor(): swimming = false
	actor.set_meta("enemy_swimming", swimming)
	actor.get_node("Body").set_form(swimming)
	if actor.team_mover != null:
		var shape: CollisionShape3D = actor.team_mover.get_child(0)
		var height := 0.54 if swimming else float(game.get_node("Combat").weapon_data.player.height)
		var radius := 0.24 if swimming else 0.34
		shape.shape.radius = radius
		if not is_equal_approx(shape.shape.height, height):
			shape.shape.height = height
			shape.position.y = height * 0.5

func travel_speed(actor: Node3D, normal: float) -> float:
	return 8.0 if bool(actor.get_meta("enemy_swimming", false)) else normal

func tick(delta: float) -> void:
	_tick_bursts(delta)
	for actor in game.all_actors():
		actor.set_meta("vault_boost",maxf(0,float(actor.get_meta("vault_boost",0))-delta))
		actor.set_meta("vault_cooldown",maxf(0,float(actor.get_meta("vault_cooldown",0))-delta))
		var swimming: bool = actor.squid_form and actor.ink_owner == 1 if actor == game.get_node("World/Walker") else bool(actor.get_meta("enemy_swimming", false))
		if kind(actor) != "enemy_swim" or not swimming: continue
		var time := float(actor.get_meta("enemy_swim_ripple", 0.0)) - delta
		if time <= 0:
			game.get_node("Combat").feedback.emit("dive", actor.global_position + Vector3.UP * 0.1, game.actor_team(actor))
			time = 0.4
		actor.set_meta("enemy_swim_ripple", time)

func dry_active(actor: Node3D) -> bool:
	if kind(actor) != "dry_focus": return false
	var tank: Node = game.get_node("Combat") if actor == game.get_node("World/Walker") else actor
	return float(tank.ink_amount) <= 20
func vault_factor(actor: Node3D) -> float:
	return 1.35 if kind(actor) == "vault_runner" and float(actor.get_meta("vault_boost",0)) > 0 else 1.0
func on_vault(actor: Node3D) -> void:
	if kind(actor) != "vault_runner" or not game.actor_alive(actor) or float(actor.get_meta("vault_cooldown",0)) > 0: return
	actor.set_meta("vault_boost",.9); actor.set_meta("vault_cooldown",6.0)
	actor.set_meta("vault_casts",int(actor.get_meta("vault_casts",0))+1)
	if actor == game.get_node("World/Walker"): game.presentation.notify_ability("翻墙加速 · 跑速 +35% / 受击 +15% · 0.9 秒")
func on_death(actor: Node3D) -> void:
	actor.set_meta("vault_boost",0)
	if actor.has_meta("vault_origin"): actor.remove_meta("vault_origin")
	if kind(actor) != "last_ink" or game.actor_alive(actor): return
	if actor == game.get_node("World/Walker"): game.player_respawn += .75
	elif actor == game.get_node("Bot"): game.bot_respawn += .75
	else: actor.respawn_time += .75
	var at := actor.global_position+Vector3.UP*.3
	game.get_node("Combat")._ability_ring(at,2.6,.65,game.actor_team(actor))
	death_bursts.append({"owner":actor,"team":game.actor_team(actor),"point":at,"time":.65})
func _tick_bursts(delta: float) -> void:
	for i in range(death_bursts.size()-1,-1,-1):
		var s := death_bursts[i]; s.time -= delta
		if s.time > 0: continue
		death_bursts.remove_at(i); bursts_total += 1
		var combat := game.get_node("Combat"); combat._add_burst(s.point,s.team,2.6); game.play_sound("bomb_explode",s.point)
		var charging: bool = game.charge_special; game.charge_special = false
		game.paint_at_world(s.point,s.team,1.3,randf(),Vector3.ZERO,0,s.owner)
		combat.damage_cover_area(s.point,2.6,32,s.team)
		for enemy in game.enemies(s.team):
			var to: Vector3 = game.intel.point(enemy); var gap: float = to.distance_to(s.point)
			if gap < 2.6 and combat._unblocked(s.point,to): game.damage_actor(enemy,lerpf(32,16,gap/2.6),s.team,s.owner,"last_ink","溅射")
		game.charge_special = charging
func escape_burst(actor: Node3D) -> Vector3:
	for s in death_bursts:
		if s.team == game.actor_team(actor) or not game.intel.visible_point(s.point,game.actor_team(actor)): continue
		var offset: Vector3 = actor.global_position-s.point
		if offset.length() < 3.1:
			offset.y = 0
			return (offset.normalized() if offset.length() > .1 else Vector3.RIGHT)*6
	return Vector3.ZERO
func clear_bursts() -> void: death_bursts.clear()
