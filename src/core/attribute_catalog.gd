extends RefCounted

# Local pre-match allocation. One point buys one rank; appearance is independent.
const ABILITIES := ["health", "ink_capacity", "run_speed", "swim_speed", "main_saver", "ink_recovery", "special_charge", "sub_cooldown"]
const BUDGET := 20
const MAX_RANK := 8
const LABELS := {"health":"生命上限", "ink_capacity":"墨水容量", "run_speed":"奔跑速度", "swim_speed":"潜泳速度", "main_saver":"主武器省墨", "ink_recovery":"回墨速度", "special_charge":"大招充能", "sub_cooldown":"副武器冷却"}
const CAPS := {"health":.18, "ink_capacity":.25, "run_speed":.12, "swim_speed":.12, "main_saver":.18, "ink_recovery":.20, "special_charge":.15, "sub_cooldown":.15}
const SHORT_LABELS := ["生命", "墨量", "跑速", "潜泳", "省墨", "回墨", "充能", "副CD"]
# Weighted tickets for bot allocation only, ordered like ABILITIES. Every stat
# remains reachable; players keep the uniform ROLL and the same rank/budget caps.
const BOT_WEIGHTS := {
	"shooter":[3,2,3,2,2,2,2,1], "roller":[3,2,2,3,3,2,1,1],
	"charger":[1,4,2,1,5,4,2,1], "bow":[2,3,2,1,4,4,2,1],
	"blaster":[3,3,3,1,4,3,1,1], "dualie":[3,2,4,3,2,2,1,1],
	"disc":[2,2,3,1,3,3,2,1], "canopy":[4,4,2,1,3,3,1,1]}
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

static func bot_weights(weapon: String, perk: String) -> Dictionary:
	var base: Array = BOT_WEIGHTS.get(weapon, [2,2,2,1,2,2,1,1])
	var result := {}
	for i in ABILITIES.size():result[ABILITIES[i]]=int(base[i])
	match perk:
		"adrenaline":result.health+=2;result.ink_recovery+=1
		"leech":result.health+=2;result.main_saver+=1
		"enemy_swim":result.health+=2;result.run_speed+=2
		"vault_runner":result.run_speed+=3;result.health+=1
		"last_ink":result.health+=2;result.sub_cooldown+=2
		"dry_focus":result.main_saver+=3;result.ink_recovery+=2;result.ink_capacity=1
		"turf_engine":result.special_charge+=4;result.main_saver+=1;result.ink_recovery+=1
	return result

static func roll_bot(rng: RandomNumberGenerator, budget: int, weapon: String, perk: String) -> Dictionary:
	var result := empty()
	var weights := bot_weights(weapon, perk)
	for point in clampi(budget,0,BUDGET):
		var tickets := 0
		for ability in ABILITIES:
			if result[ability]<MAX_RANK:tickets+=int(weights[ability])
		var pick := rng.randi_range(1,tickets)
		for ability in ABILITIES:
			if result[ability]>=MAX_RANK:continue
			pick-=int(weights[ability])
			if pick<=0:
				result[ability]+=1
				break
	return result

static func brief(value: Dictionary) -> String:
	var order: Array[int]=[]
	for i in ABILITIES.size():
		var rank: int = int(value.get(ABILITIES[i],0))
		if rank<=0:continue
		var at: int = order.size()
		for j in order.size():
			if rank>int(value[ABILITIES[order[j]]]):at=j;break
		order.insert(at,i)
	var parts: Array[String]=[]
	for i in mini(3,order.size()):
		var index:int=order[i];parts.append("%s%d"%[SHORT_LABELS[index],int(value[ABILITIES[index]])])
	return "%d 点 · %s"%[spent(value),"未分配" if parts.is_empty() else " / ".join(parts)]
