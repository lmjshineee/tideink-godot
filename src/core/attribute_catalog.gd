extends RefCounted

# Local pre-match allocation. One point buys one rank; appearance is independent.
const ABILITIES := ["health", "ink_capacity", "run_speed", "swim_speed", "main_saver", "ink_recovery", "special_charge", "sub_cooldown"]
const BUDGET := 20
const MAX_RANK := 8
const LABELS := {"health":"生命上限", "ink_capacity":"墨水容量", "run_speed":"奔跑速度", "swim_speed":"潜泳速度", "main_saver":"主武器省墨", "ink_recovery":"回墨速度", "special_charge":"大招充能", "sub_cooldown":"副武器冷却"}
const CAPS := {"health":.18, "ink_capacity":.25, "run_speed":.12, "swim_speed":.12, "main_saver":.18, "ink_recovery":.20, "special_charge":.15, "sub_cooldown":.15}
const DESCRIPTIONS := {
	"health":"增加最大生命，最多 +18%。加点不立即回血，开战与复活使用新上限。",
	"ink_capacity":"增加最大墨量，最多 +25%。加点不立即补墨，主副武器仍实际扣墨。",
	"run_speed":"提高人形奔跑和干地墨形速度，最多 +12%；射击、爬墙与特殊动作的速度上限保留。",
	"swim_speed":"提高己方墨地潜泳速度，最多 +12%；敌墨潜游保持天赋原速。",
	"main_saver":"主射、蓄力、甩墨和滚刷耗墨最多 -18%；不改变伤害、滑步、护伞维持或推出耗墨。",
	"ink_recovery":"自然回墨速度最多 +20%；不缩短等待，也不改变补给领取量。",
	"special_charge":"有效新增涂地的大招充能最多 +15%；己方重涂、墨墙和大招自身涂地仍不给充能。",
	"sub_cooldown":"新施放的副武器冷却最多 -15%；已有剩余冷却跨死亡与配装重摇保留。"}

static func empty() -> Dictionary:
	var result := {}
	for ability in ABILITIES: result[ability] = 0
	return result

static func spent(value: Dictionary) -> int:
	var count := 0
	for ability in ABILITIES: count += int(value.get(ability, 0))
	return count

static func normalize(value: Variant) -> Dictionary:
	var result := empty()
	if not value is Dictionary: return result
	var left := BUDGET
	for ability in ABILITIES:
		var rank: Variant = value.get(ability, 0)
		if rank is int:
			result[ability] = clampi(rank, 0, mini(MAX_RANK, left))
			left -= result[ability]
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != ABILITIES.size(): return false
	for ability in ABILITIES:
		if not value.has(ability) or not value[ability] is int or value[ability] < 0 or value[ability] > MAX_RANK: return false
	return spent(value) <= BUDGET

static func points(value: Dictionary) -> Dictionary:
	return value.duplicate()

static func bonus(ability: String, amount: int) -> float:
	var rank := float(clampi(amount, 0, MAX_RANK))
	return float(CAPS.get(ability, 0)) * (rank / (rank + 4.0)) / (8.0 / 12.0)

static func roll(rng: RandomNumberGenerator, previous: Dictionary, budget: int = BUDGET) -> Dictionary:
	var result := empty()
	for point in clampi(budget, 0, BUDGET):
		var available: Array[String] = []
		for ability in ABILITIES:
			if result[ability] < MAX_RANK: available.append(ability)
		result[available[rng.randi_range(0, available.size() - 1)]] += 1
	if result == previous and spent(result) > 0:
		for source in ABILITIES:
			if result[source] == 0: continue
			for target in ABILITIES:
				if target != source and result[target] < MAX_RANK:
					result[source] -= 1; result[target] += 1
					return result
	return result
