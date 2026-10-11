extends RefCounted

# Godot balance overrides the frozen imported base in assets/weapons.json.
# The current Godot data and rules are authoritative; no web config is read.
static func apply(data: Dictionary) -> void:
	data["player"].merge({"hp":120,"regenDelay":1.8,"regenRate":24,"regenRateSwim":65,
		"respawnTime":4.0,"climbSpeed":9.5,"climbAccel":58,"enemyInkDps":2.0,"enemyInkDamageCap":24.0,"enemyInkSpeed":3.8,"inkRefillDelay":.7},true)
	# Local balance; percentage ink references are documented in COMBAT_BALANCE.md.
	data["weapons"]["shooter"].merge({"specialCost":120,"damage":34,"inkPerShot":.92,"spreadBaseGround":4.8,"spreadBaseAir":11.6,"special":"overdrive"},true)
	data["weapons"]["roller"].merge({"rollDamage":95,"flickDamageNear":105,"flickDamageFar":22,"finalDamageCap":130.0},true)
	data["weapons"]["charger"].merge({"damageMin":28,"damageMax":115,"inkMin":2.5,"inkFull":18.0,"chargeTime":1.15,"releaseRecovery":.4,"rangeMax":24.0,"hitRadius":.04,"finalDamageCap":118.0},true)
	data["weapons"]["blaster"].merge({"directDamage":95,"splashDamageMax":45,"splashDamageMin":20,"inkPerShot":9.0,"spreadBaseGround":1.0,"spreadBaseAir":6.0,"special":"siege_shell","finalDamageCap":130.0},true)
	data["sub"]["bomb"].merge({"damageMax":100,"damageMin":30},true)
	data["weapons"]["roller"]["specialCost"] = 120
	data["weapons"]["charger"]["specialCost"] = 130
	data["weapons"]["blaster"]["specialCost"] = 140
	data["specials"]["slam"].merge({"radius":6.0,"killRadius":3.2,"damageMin":70},true)
	data["specials"]["storm"].merge({"duration":9.0,"radius":4.8,"dps":48,"throwSpeed":21.0},true)
	preload("res://src/core/equipment_catalog.gd").extend(data)

static func shooter_damage(base: float, distance: float, reach: float) -> float:
	# The last quarter of range rewards closing distance.
	return base * lerpf(1.0,0.78,clampf((distance/reach-0.75)/0.25,0.0,1.0))
