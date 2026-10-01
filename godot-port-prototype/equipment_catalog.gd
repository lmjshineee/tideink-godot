extends RefCounted
# Local extensions use the existing projectile families and source equipment meshes.
const EXTRA := ["dualie","heavy","rapid"]
const BASE := {"dualie":"shooter","heavy":"shooter","rapid":"blaster"}
const LABELS := {"dualie":"双持喷枪","heavy":"长管喷枪","rapid":"轻爆枪"}
static func base(id:String) -> String:
	return String(BASE.get(id,id))
static func extend(data:Dictionary) -> void:
	for id in EXTRA:
		var w:Dictionary=data.weapons[BASE[id]].duplicate(true)
		w.id=id;w.model=BASE[id]
		match id:
			"dualie":
				w.merge({"damage":16.5,"shots":2,"fireInterval":.16,"inkPerShot":1.4,"range":10.5,"moveSpeedFiring":5.3,"impactRadius":.65,"specialCost":150},true)
				w.stats={"range":.4,"damage":.33,"rate":.9,"mobility":.9,"paint":.7}
			"heavy":
				w.merge({"damage":43,"fireInterval":.22,"inkPerShot":1.9,"range":17,"projSpeed":40,"straightTime":.18,"moveSpeedFiring":3.4,"impactRadius":.95,"spreadBaseGround":3.3,"spreadBaseAir":7,"special":"storm","specialCost":165},true)
				w.stats={"range":.7,"damage":.43,"rate":.55,"mobility":.45,"paint":.75}
			"rapid":
				w.merge({"directDamage":52,"splashDamageMax":35,"splashDamageMin":18,"fireInterval":.42,"inkPerShot":6.5,"range":9,"splashRadius":2,"burstRadius":1.5,"moveSpeedFiring":4.8,"specialCost":145},true)
				w.stats={"range":.35,"damage":.52,"rate":.6,"mobility":.8,"paint":.6}
		data.weapons[id]=w
		data.text.weapons[id]=LABELS[id]
		if not data.weaponOrder.has(id):data.weaponOrder.append(id)
