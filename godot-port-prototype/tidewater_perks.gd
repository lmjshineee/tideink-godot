extends RefCounted

# One persistent choice per actor per match. Equipment rerolls never call select.
const ORDER := ["balanced","vitality","runner","saver","reserve","adrenaline","recovery","bulwark","subtech","leech","focus","recycler"]
const LABELS := {"balanced":"均衡","vitality":"强健体魄","runner":"游击步伐","saver":"节墨专家","reserve":"扩容墨囊","adrenaline":"逆境反击","recovery":"快速恢复","bulwark":"爆破防护","subtech":"道具技师","leech":"命中回复","focus":"稳枪专注","recycler":"循环墨泵"}
const DESCRIPTIONS := {
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

func setup(owner: Node3D) -> void:
	game = owner
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for actor in game.call("all_actors"):
		choices[actor.get_instance_id()] = preload("res://match_setup.gd").selected_perk if actor==game.get_node("World/Walker") else ORDER[rng.randi_range(0,ORDER.size()-1)]
	apply_movement()

func kind(actor: Node3D) -> String:
	return String(choices.get(actor.get_instance_id(),"balanced"))

func select_player(id: String) -> bool:
	if locked or game.get("phase") not in ["home","setup"] or not ORDER.has(id):
		return false
	var actor := game.get_node("World/Walker") as Node3D
	choices[actor.get_instance_id()] = id
	preload("res://match_setup.gd").selected_perk = id
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

func active(actor: Node3D) -> bool:
	var health := float(game.call("actor_health",actor))
	return health>0 and health<=max_health(actor)*0.5

func outgoing(actor: Node3D) -> float:
	return 1.15 if is_instance_valid(actor) and kind(actor)=="adrenaline" and active(actor) else 1.0

func incoming(actor: Node3D, source: String) -> float:
	return 0.8 if kind(actor)=="bulwark" and source in ["blaster","rapid","bomb","cluster","slam","storm"] else 1.0

func refill(actor: Node3D) -> float:
	if kind(actor)=="recycler":return 1.25
	return 1.5 if kind(actor)=="adrenaline" and active(actor) else 1.0

func item_cooldown(actor:Node3D,base:float) -> float:
	return base*.8 if kind(actor)=="subtech" else base

func on_hit(actor:Node3D,damage:float,source:String) -> void:
	if is_instance_valid(actor) and game.actor_alive(actor) and kind(actor)=="leech" and game.weapon_order.has(source):
		game.heal_actor(actor,minf(6,damage*.15))

func regen_delay(actor: Node3D, base: float) -> float:
	return base-0.5 if kind(actor)=="recovery" else base

func regen_rate(actor: Node3D, base: float) -> float:
	return base*1.25 if kind(actor)=="recovery" else base

func weapon(actor: Node3D, original: Dictionary) -> Dictionary:
	if kind(actor) not in ["saver","focus"]: return original
	var result := original.duplicate()
	if kind(actor)=="focus":
		result["spreadBaseGround"]=float(result.get("spreadBaseGround",0))*.65
		return result
	for field in ["inkPerShot","inkFull","flickInk","rollInkPerMeter"]:
		if result.has(field): result[field] = float(result[field])*0.8
	return result

func hud_text() -> String:
	var actor := game.get_node("World/Walker") as Node3D
	var id := kind(actor)
	return "天赋 %s%s" % [LABELS[id]," · 已触发" if id=="adrenaline" and active(actor) else " · 整局锁定"]
