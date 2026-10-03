extends RefCounted
# Local extensions use the existing projectile families and source equipment meshes.
const EXTRA := ["dualie","heavy","rapid"]
const BASE := {"dualie":"shooter","heavy":"shooter","rapid":"blaster","disc":"roller","bow":"charger","canopy":"shooter"}
const ACTIVE := ["shooter","roller","charger","blaster","dualie","disc","bow","canopy"]
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

	var disc: Dictionary = data.weapons.shooter.duplicate(true)
	disc.merge({"id":"disc", "kind":"disc", "model":"roller", "damage":48.0, "returnDamage":34.0,
		"range":13.0, "fireInterval":0.3, "inkPerShot":8.0, "moveSpeedFiring":5.0,
		"special":"twin_discs", "specialCost":180.0}, true)
	disc.stats = {"range":0.55, "damage":0.48, "rate":0.35, "mobility":0.8, "paint":0.7}
	data.weapons.disc = disc
	data.text.weapons.disc = "回旋飞镖"
	var bow: Dictionary = data.weapons.charger.duplicate(true)
	bow.merge({"id":"bow", "kind":"bow", "model":"charger", "chargeTime":0.8,
		"rangeMin":12.0, "rangeMax":26.0, "damageMin":51.0, "damageMax":108.0,
		"arrowDamageMin":17.0, "arrowDamageMax":36.0, "inkMin":3.0, "inkFull":7.0,
		"moveSpeedFiring":4.6, "special":"rain_arrows", "specialCost":170.0,
		"blastDamage":40.0, "blastRadius":1.9, "blastDelay":0.5,
		"plantCharge":0.5, "releaseMin":0.22, "releaseFull":0.20,
		"arrowSpeedMin":34.0, "arrowSpeedFull":58.0, "arrowRadius":0.09}, true)
	bow.stats = {"range":0.9, "damage":1.0, "rate":0.4, "mobility":0.7, "paint":0.85}
	data.weapons.bow = bow
	data.text.weapons.bow = "三弦墨弓"
	var canopy: Dictionary = data.weapons.shooter.duplicate(true)
	canopy.merge({"id":"canopy", "kind":"canopy", "model":"shooter", "damage":15.0,
		"pellets":6, "range":11.0, "projSpeed":38.0, "fireInterval":0.48, "inkPerShot":5.0,
		"moveSpeedFiring":4.8, "impactRadius":0.55, "special":"absorb_counter", "specialCost":150.0,
		"coverHealth":220.0, "openTime":0.20, "launchTime":0.85, "launchInk":8.0,
		"coverDrain":1.4, "coverCooldown":4.5, "coverSpeed":6.5, "coverLife":3.4}, true)
	canopy.stats = {"range":0.4, "damage":0.84, "rate":0.35, "mobility":0.6, "paint":0.7}
	data.weapons.canopy = canopy
	data.text.weapons.canopy = "推进挡墨伞"
	data.weaponOrder = ACTIVE.duplicate()
