extends RefCounted
const Perks:=preload("res://src/abilities/tidewater_perks.gd")
const Profile:=preload("res://src/core/weapon_profile.gd")

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
		"bow":
			text="按住左键蓄力，松开射出三支墨箭。\n"+attribute(w,"range","%.0f → %.0f m" % [w.rangeMin,w.rangeMax])+"\n"+attribute(w,"damage","每箭 %.0f → %.0f；三箭满蓄 %.0f" % [w.arrowDamageMin,w.arrowDamageMax,w.damageMax])+"\n"+attribute(w,"rate","满蓄 %.1f 秒；释放间隔 %.2f → %.2f 秒" % [w.chargeTime,w.releaseMin,w.releaseFull])+"\n"+attribute(w,"mobility","蓄力 %.1f m/s" % w.moveSpeedFiring)+"\n"+attribute(w,"paint","轻点涂地；半蓄布置爆裂箭")+"\n地面横向散射；跳起后纵向散射。满蓄三箭收束，适合精准远射。\n耗墨 %.0f → %.0f；蓄到一半（%.1f秒）可在地形留下爆裂箭。\n准星半环提示爆裂就绪，满环提示精准三箭并响提示音。\n落点 %.1f 秒后爆裂，半径 %.1f m；同轮溅射共享 %.0f 伤害预算。\n同轮直击＋爆裂基础总伤害最多110；增伤与易伤结算后仍最多115。箭与爆裂受楼板／墙遮挡。" % [w.inkMin,w.inkFull,w.chargeTime*w.plantCharge,w.blastDelay,w.blastRadius,w.blastDamage]
		"canopy":
			text="点按六颗散弹；按住开伞，推出后持续射击。\n"+attribute(w,"range","11 m")+"\n"+attribute(w,"damage","每弹 15；六弹躯干 90")+"\n"+attribute(w,"rate","0.48 秒 / 轮")+"\n"+attribute(w,"mobility","射击 / 持伞 4.8 m/s")+"\n"+attribute(w,"paint","推进留下可潜泳的宽墨路")+"\n每轮耗墨 5；按住 0.20 秒开伞，持伞每秒耗墨 1.4。\n伞面耐久 220，挡敌弹，友方射击可穿过；持伞时暂停射击。\n按住至 0.85 秒，额外耗墨 8 推出：6.5 m/s、最多 3.4 秒。\n地面推出沿平地／坡道走，离地推出保留高低瞄准；墙和窄障碍实际阻挡。\n推出即开始 4.5 秒冷却，跟进时持续按住可连射；松开后可以潜墨回墨。\n提前收伞／持伞被破也冷却 4.5 秒，死亡／重摇不能清除。\n敌人可以绕侧、绕后或从上方攻击。"
		"disc":
			text=attribute(w,"range","13 m")+"\n"+attribute(w,"damage","去程 / 回程")+"\n"+attribute(w,"rate","接回后再投")+"\n"+attribute(w,"mobility","投后移动改变回程")+"\n"+attribute(w,"paint","沿轨迹涂墨")+"\n点按投出一枚回旋飞镖，去程直飞，回程追向你的位置。\n射程 13 m · 去程 48 / 回程 34 伤害\n每次消耗 8 墨水，场上同时 1 枚。\n同一目标每段最多命中一次；墙壁挡住飞镖。\n投出后横移，改变回程路线；接回后再次投掷。"
		"roller":
			text="点按甩墨，按住持续滚刷。\n"+attribute(w,"range","近距接触 / 扇形甩墨")+"\n"+attribute(w,"damage","接触 %.0f；甩墨 %.0f → %.0f" % [w.rollDamage,w.flickDamageNear,w.flickDamageFar])+"\n"+attribute(w,"rate","%.2f 秒 / 轮；前摇 %.2f 秒" % [w.flickInterval,w.flickWindup])+"\n"+attribute(w,"mobility","滚动速度上限 %.1f m/s" % w.rollSpeed)+"\n"+attribute(w,"paint","滚刷宽 %.1f m" % w.rollWidth)
			text+="\n甩墨每轮 %.1f 墨水；滚动每米 %.2f 墨水。\n同轮墨滴共享目标伤害预算；接触间隔 0.5 秒。" % [w.flickInk,w.rollInkPerMeter]
		"charger":
			text="按住蓄力，松开释放长射线。\n"+attribute(w,"range","%.0f → %.0f m，随蓄力提升" % [w.rangeMin,w.rangeMax])+"\n"+attribute(w,"damage","伤害 %.0f → %.0f" % [w.damageMin,w.damageMax])+"\n"+attribute(w,"rate","满蓄 %.1f 秒" % w.chargeTime)+"\n"+attribute(w,"mobility","蓄力移速 %.1f m/s" % w.moveSpeedFiring)+"\n"+attribute(w,"paint","射线涂墨半径 %.2f m" % w.lineRadius)
			text+="\n满蓄消耗 %.1f 墨水；提前松开降低射程和伤害。\n满蓄躯干命中，基础满血目标剩余 20 HP。" % w.inkFull
		"blaster":
			text="慢速爆破，适合逼出掩体与范围压制。\n"+attribute(w,"range","%.1f m" % w.range)+"\n"+attribute(w,"damage","直击 %.0f；溅射 %.0f → %.0f" % [w.directDamage,w.splashDamageMax,w.splashDamageMin])+"\n"+attribute(w,"rate","%.2f 秒 / 发" % w.fireInterval)+"\n"+attribute(w,"mobility","射击移速 %.1f m/s" % w.moveSpeedFiring)+"\n"+attribute(w,"paint","爆开涂墨半径 %.1f m" % w.burstRadius)
			text+="\n每发 %.1f 墨水；溅射半径 %.1f m。\n直击不叠加同次溅射；溅射受距离和遮挡影响。" % [w.inkPerShot,w.splashRadius]
	if id=="dualie":text+="\n双持每轮两弹，每弹 16.5；命中分别计算。\n按住左键 + 方向 + 空格滑步，最多连续两次。\n每次耗墨 12，滑步 0.18s，结束停顿 0.16s。\n滑后 0.7s 内散布缩小 65%；滑步被地形阻挡。"
	if id=="heavy":text+="\n长管提高射程与单弹伤害，连射较慢。"
	if id=="rapid":text+="\n轻量爆破提高频率，单发直击与溅射降低。"
	if game.perks.kind(game.get_node("World/Walker"))=="focus":text+="\n地面散布已计入稳枪专注。"
	text+="\n大招：%s · %.0f 涂地点数" % [{"rain_arrows":"雨箭齐射 · 0.6s 前摇 / 三轮抛射", "absorb_counter":"吸墨反击 · 正面吸墨 3s / 反击前摇 0.4s", "slam":"重击","storm":"墨雨","twin_discs":"双镖突进 · 前摇 0.4s / 射程 20m / 每枚 85"}[w.special],w.specialCost]
	if w.special == "rain_arrows": text+="\n锁定准星 24m 内可见地面，提前显示 2.4m 落点圈。\n0.6 秒后发出三轮，每轮九箭、间隔 0.45 秒；轨迹受墙壁与屋顶阻挡。\n每箭直击 28，落点 1.15m 溅射 28 → 14；直击不叠加自身溅射。\n每轮同一目标伤害最多 45（基础出手值，强化不增加上限），不叠加头部倍率。\n发射期间不能主射／潜墨／使用道具；可移动，落点不会跟踪敌人。\n死亡取消尚未发出的箭，已飞出的箭继续；大招涂地不充能。"
	if w.special == "absorb_counter": text+="\n吸收正前方 6m 锥形区域内的喷枪弹、伞弹、爆破弹和墨箭。\n蓄能最多 100，满后或 3 秒后收口；蓄势 0.4 秒后发射反击弹。\n反击直击 40 → 100；溅射为一半，不叠加直击或头部倍率。\n射程 20m，墙与楼板挡住吸墨和反击；移动上限 2.5m/s。\n期间不能射击、使用道具或潜墨；侧后方、狙击、飞镖、滚筒和手雷仍可攻击。"
	text+="\n%s按体积命中，不叠加头部倍率。" % ("箭矢" if w.kind=="bow" else "飞镖") if w.kind in ["disc","bow"] else "\n主武器直接命中：头部 ×1.08 / 躯干 ×1 / 腿部 ×0.85"
	text+="\n星级用于相对比较；伤害为基础躯干值。"
	if game.perks.kind(game.get_node("World/Walker"))=="saver":text+="\n墨水消耗已计入节墨天赋。"
	return {"title":game._weapon_text(id)+" · 主武器","body":text}

static func item(game: Node3D,id: String) -> Dictionary:
	var text: String
	match id:
		"bomb":
			var w: Dictionary=game.get_node("Combat").weapon_data["sub"]["bomb"]
			text="按住右键瞄准，松开投掷；E 快投。\n伤害 %.0f → %.0f · 爆炸半径 %.1f m\n消耗 %.0f 墨水 · 引信 %.2f 秒\n距离与遮挡影响伤害，不造成友伤。" % [w.damageMax,w.damageMin,w.radius,w.inkCost,w.fuse]
		"ink_wings":text="站立时展开墨翼背包，消耗 40 墨水，最多 4 秒。\nWASD 空中移动，空格上升、Shift 下降，松开垂直悬停。\n相对起点最高 4.5m，墙与屋顶实际阻挡；水平上限 7m/s。\n空中可用主武器，射击移速限制继续生效；每秒额外耗墨 8。\n墨水耗尽、到时或死亡结束，之后正常下落。\n飞行时不能潜墨、自然回墨、使用其他道具或大招。\n没有额外护甲；冷却跨死亡／换装保留。"
		"echo_decoy":text="向准星 8m 内可见地面放置自己的回声假身。\n消耗 25 墨水，20 HP，持续 8 秒，每人最多一个。\n假身模拟射击声和动作，骗取敌方瞄准与真实弹药。\n没有伤害、涂墨或大招充能，不占队伍人数或战绩。\n己方可辨认；敌方声呐可识破，此后机器人不再被骗。\n墙、楼板和信息墨雾遮挡发现，大小地图使用相同情报。\n敌弹和爆破可拆除；部署者死亡后仍保留。"
		"supply_box":text="脚下布置两份墨水，消耗 40 墨水，60 HP，持续 14 秒。\n人形站在 1.6m 内停留 0.6 秒，每份恢复最多 35 墨水。\n每名角色对同一盒只可领取一次；自己、队友、敌人都能拿。\n移动、潜墨、开火、受伤或跳跃打断领取，墙和楼板挡领取。\n至少缺 10 墨水才领取，领取后 0.25 秒不能攻击。\n不回血、不涂地、不充能，敌弹／爆破可以拆除。\n每人最多一盒，部署者死亡后持续；耗尽／过期后消失。"
		"mine":text="脚下布置感应墨雷，消耗 30 墨水，25 HP。\n0.8 秒布防，持续 30 秒，每人最多两枚；第三枚替换最早一枚。\n敌人进入 2.2m 三维范围且无遮挡后，警告 0.45 秒再爆炸。\n爆炸半径 3m，伤害 50 → 25，并向全队标记命中敌人 2 秒。\n可触发潜墨敌人；墙和楼板挡触发、伤害与标记。\n敌弹／爆破可安全拆除，警告期间仍可拆；不造成友伤。\n部署者死亡后仍保留，队伍地图显示己方墨雷。"
		"intel_mist":text="向准星 8m 内的落点投放信息墨雾。\n消耗 35 墨水；半径 3m，高度最多 4m，持续 6 秒。\n遮断敌方视野、血条及地图情报，队友可透视己方墨雾。\n敌方最后接触保留 1.5 秒，随后消失；开火也不能透视墨雾。\n声呐标记可反制墨雾，墙与楼板仍挡住视线。\n墨雾不挡子弹、不减速、不伤害或涂地。\n每人最多一团，部署者死亡后仍持续。"
		"sonar":text="脚下部署可被破坏的脉冲声呐。\n消耗 40 墨水，60 HP，持续 8 秒。\n每 2 秒发出一圈 12 m 三维探测波。\n墙与楼板遮挡探测；命中敌人后向全队标记 2 秒。\n可发现潜墨目标、识破回声诱饵；不造成伤害或涂墨。\n部署者死亡后继续工作；每人最多一个。"
		"recall":text="首次 E / 右键标记脚下，再次按下瞬间返回。\n消耗 25 墨水，锚点存活 12 秒，最大距离 18 m。\n锚点 40 HP，敌人可以射击或爆破摧毁。\n保留当前生命与墨水，回溯后 0.35s 不能攻击。\n堵塞落点暂时不能返回；死亡清除锚点。\n返回、被毁或过期后开始冷却。"
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
