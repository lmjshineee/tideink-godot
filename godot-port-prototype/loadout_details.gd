extends RefCounted
const Perks:=preload("res://tidewater_perks.gd")
const Profile:=preload("res://weapon_profile.gd")

static func attribute(w:Dictionary,key:String,value:String) -> String:
	var n:=Profile.rating(w,key)
	for field in Profile.CATEGORIES:
		if field[0]==key:return field[1]+"  "+"★".repeat(n)+"☆".repeat(5-n)+"  · "+value
	return ""

static func weapon(game: Node3D,id: String) -> Dictionary:
	var w: Dictionary=game.perks.weapon(game.get_node("World/Walker"),game.get_node("Combat").weapons[id])
	var text: String
	match String(w.kind):
		"shooter":
			text="连续喷射，适合涂地和近距离压制。\n"+attribute(w,"range","%.1f m；末端衰减" % w.range)+"\n"+attribute(w,"damage","伤害 %.0f → %.1f" % [w.damage,w.damage*0.78])+"\n"+attribute(w,"rate","%.2f 秒 / 发（%.0f 发 / 秒）" % [w.fireInterval,1.0/w.fireInterval])+"\n"+attribute(w,"mobility","射击移速 %.1f m/s" % w.moveSpeedFiring)+"\n"+attribute(w,"paint","命中涂墨半径 %.2f m" % w.impactRadius)
			text+="\n每发 %.2f 墨水；基础 120 HP 近端约 %d 轮击倒。\n连射扩大散布，跳射更散；停火后恢复精度。" % [w.inkPerShot,ceili(120.0/(w.damage*float(w.get("shots",1))))]
		"roller":
			text="点按甩墨，按住持续滚刷。\n"+attribute(w,"range","近距接触 / 扇形甩墨")+"\n"+attribute(w,"damage","接触 %.0f；甩墨 %.0f → %.0f" % [w.rollDamage,w.flickDamageNear,w.flickDamageFar])+"\n"+attribute(w,"rate","%.2f 秒 / 轮；前摇 %.2f 秒" % [w.flickInterval,w.flickWindup])+"\n"+attribute(w,"mobility","滚动速度上限 %.1f m/s" % w.rollSpeed)+"\n"+attribute(w,"paint","滚刷宽 %.1f m" % w.rollWidth)
			text+="\n甩墨每轮 %.1f 墨水；滚动每米 %.2f 墨水。\n同轮墨滴共享目标伤害预算；接触间隔 0.5 秒。" % [w.flickInk,w.rollInkPerMeter]
		"charger":
			text="按住蓄力，松开释放长射线。\n"+attribute(w,"range","%.0f → %.0f m，随蓄力提升" % [w.rangeMin,w.rangeMax])+"\n"+attribute(w,"damage","伤害 %.0f → %.0f" % [w.damageMin,w.damageMax])+"\n"+attribute(w,"rate","满蓄 %.1f 秒" % w.chargeTime)+"\n"+attribute(w,"mobility","蓄力移速 %.1f m/s" % w.moveSpeedFiring)+"\n"+attribute(w,"paint","射线涂墨半径 %.2f m" % w.lineRadius)
			text+="\n满蓄消耗 %.1f 墨水；提前松开降低射程和伤害。\n满蓄躯干命中，基础满血目标剩余 20 HP。" % w.inkFull
		"blaster":
			text="慢速爆破，适合逼出掩体与范围压制。\n"+attribute(w,"range","%.1f m" % w.range)+"\n"+attribute(w,"damage","直击 %.0f；溅射 %.0f → %.0f" % [w.directDamage,w.splashDamageMax,w.splashDamageMin])+"\n"+attribute(w,"rate","%.2f 秒 / 发" % w.fireInterval)+"\n"+attribute(w,"mobility","射击移速 %.1f m/s" % w.moveSpeedFiring)+"\n"+attribute(w,"paint","爆开涂墨半径 %.1f m" % w.burstRadius)
			text+="\n每发 %.1f 墨水；溅射半径 %.1f m。\n直击不叠加同次溅射；溅射受距离和遮挡影响。" % [w.inkPerShot,w.splashRadius]
	if id=="dualie":text+="\n双持每轮两弹，每弹 16.5；命中分别计算。"
	if id=="heavy":text+="\n长管提高射程与单弹伤害，连射较慢。"
	if id=="rapid":text+="\n轻量爆破提高频率，单发直击与溅射降低。"
	if game.perks.kind(game.get_node("World/Walker"))=="focus":text+="\n地面散布已计入稳枪专注。"
	text+="\n大招：%s · %.0f 涂地点数\n直接命中：头部 ×1.08 / 躯干 ×1 / 腿部 ×0.85" % ["重击" if w.special=="slam" else "墨雨",w.specialCost]
	text+="\n星级用于相对比较；伤害为基础躯干值。"
	if game.perks.kind(game.get_node("World/Walker"))=="saver":text+="\n墨水消耗已计入节墨天赋。"
	return {"title":game._weapon_text(id)+" · 主武器","body":text}

static func item(game: Node3D,id: String) -> Dictionary:
	var text: String
	match id:
		"bomb":
			var w: Dictionary=game.get_node("Combat").weapon_data["sub"]["bomb"]
			text="按住右键瞄准，松开投掷；E 快投。\n伤害 %.0f → %.0f · 爆炸半径 %.1f m\n消耗 %.0f 墨水 · 引信 %.2f 秒\n距离与遮挡影响伤害，不造成友伤。" % [w.damageMax,w.damageMin,w.radius,w.inkCost,w.fuse]
		"refill":text="立即恢复 35 生命和 75 墨水。\n受自身最大生命／墨量限制。\n生命与墨水都满时不会消耗冷却。"
		"beacon":text="在附近己方墨面布置一个队伍跳跃点。\n消耗 35 墨水，持续 45 秒，可使用 2 次。\n每名角色最多保留 1 个，新信标替换旧信标。\nJ 打开跳跃选择，队友也能使用。\n被敌墨覆盖或落点堵塞时暂停使用。"
		"cluster":text="快速爆墨瓶，消耗 45 墨水。\n接地后 0.3 秒引爆，范围 2.2 m，伤害 70 → 20。\n独立冷却 10 秒，保存发射时阵营与道具。"
		"mist":text="在瞄准方向附近放置 4 m 减速墨雾。\n消耗 45 墨水，持续 6 秒，敌方移动速度 -35%。\n逐次涂墨，不直接扣血；地形隔开时不影响目标。"
		"healing":text="脚下放置 4 m 医疗领域，持续 5 秒。\n消耗 35 墨水，同层且无遮挡队友恢复 12 HP / 秒。\n不复活、不越过生命上限；施放者死亡后领域持续。"
		"shield":text="吸收 60 伤害，最多持续 6 秒。\n耗尽或到时消失，可阻挡武器与爆炸。\n先扣护盾，再扣生命。"
	text+="\n冷却 %.0f 秒 · 右键 / E 使用\n死亡或重新配装不会清除冷却。" % game.perks.item_cooldown(game.get_node("World/Walker"),game.items.COOLDOWNS[id])
	return {"title":game.items.LABELS[id]+" · 道具","body":text}

static func perk(id: String) -> Dictionary:
	return {"title":Perks.LABELS[id]+" · 天赋","body":Perks.DESCRIPTIONS[id]+"\n\n赛前选一个，进入入场动画即锁定。\n天赋整局固定，死亡、复活和装备重摇不改变。\n队友与对手独立随机，一局内同样固定。"}
