extends RefCounted

# Local ability tuning, not a reproduction of Nintendo's numerical formula.
const PIECES := ["head", "clothes", "shoes"]
const PIECE_LABELS := {"head":"头饰", "clothes":"衣服", "shoes":"鞋子"}
const ABILITIES := ["run_speed", "swim_speed", "main_saver", "ink_recovery", "special_charge", "sub_cooldown"]
const LABELS := {"none":"空槽", "run_speed":"奔跑加速", "swim_speed":"潜泳加速", "main_saver":"主武器省墨", "ink_recovery":"回墨加速", "special_charge":"大招充能", "sub_cooldown":"副武器冷却"}
const CAPS := {"run_speed":.12, "swim_speed":.12, "main_saver":.18, "ink_recovery":.20, "special_charge":.15, "sub_cooldown":.15}
const DESCRIPTIONS := {
	"none":"不提供额外加成；随时在开战前换成能力。",
	"run_speed":"提高人形奔跑和干地墨形速度，最多 +12%；射击、爬墙与特殊动作的速度上限保留。",
	"swim_speed":"提高己方墨地潜泳速度，最多 +12%；敌墨潜游保持天赋原速。",
	"main_saver":"主射、蓄力、甩墨和滚刷耗墨最多 -18%；不改变伤害、滑步、护伞维持或推出的耗墨。",
	"ink_recovery":"自然回墨速度最多 +20%；不增加容量，不缩短回墨等待，也不改变补给领取量。",
	"special_charge":"有效新增涂地的大招充能最多 +15%；己方重涂、墨墙和大招自身涂地仍不给充能。",
	"sub_cooldown":"副武器新施放的冷却最多 -15%；已有剩余冷却不被换装、死亡或 ROLL 缩短。"}
const MAIN_POINTS := 10
const SUB_POINTS := 3
const MAX_POINTS := 57

static func empty() -> Dictionary:
	var result := {}
	for piece in PIECES: result[piece] = ["none", "none", "none", "none"]
	return result

static func normalize(value: Variant) -> Dictionary:
	var result := empty()
	if not value is Dictionary: return result
	for piece in PIECES:
		var slots: Variant = value.get(piece, [])
		if not slots is Array: continue
		for index in mini(4, slots.size()):
			if slots[index] is String and LABELS.has(slots[index]): result[piece][index] = slots[index]
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3: return false
	for piece in PIECES:
		if not value.has(piece) or not value[piece] is Array or value[piece].size() != 4: return false
		for ability in value[piece]:
			if not ability is String or not LABELS.has(ability): return false
	return true

static func points(loadout: Dictionary) -> Dictionary:
	var result := {}
	for ability in ABILITIES: result[ability] = 0
	for piece in PIECES:
		for index in 4:
			var ability: String = loadout[piece][index]
			if ability != "none": result[ability] += MAIN_POINTS if index == 0 else SUB_POINTS
	return result

static func bonus(ability: String, amount: int) -> float:
	# Positive, diminishing marginal gain; normalized to the reachable 57-point cap.
	var p := float(clampi(amount, 0, MAX_POINTS))
	return float(CAPS.get(ability, 0)) * (p / (p + 20.0)) / (57.0 / 77.0)

static func roll(rng: RandomNumberGenerator, previous: Dictionary) -> Dictionary:
	var result := empty()
	for piece in PIECES:
		for index in 4: result[piece][index] = ABILITIES[rng.randi_range(0, ABILITIES.size() - 1)]
	if result == previous:
		result.head[0] = ABILITIES[(ABILITIES.find(result.head[0]) + 1) % ABILITIES.size()]
	return result
