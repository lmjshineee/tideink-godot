extends RefCounted

# Godot balance overrides the frozen imported base in assets/weapons.json.
# The current Godot data and rules are authoritative; no web config is read.
static func apply(data: Dictionary) -> void:
	data["player"].merge({"hp":120,"regenDelay":1.8,"regenRate":24,"regenRateSwim":65,
		"respawnTime":4.0,"climbSpeed":9.5,"climbAccel":58,"enemyInkDps":2.0,"enemyInkDamageCap":24.0,"enemyInkSpeed":3.8,"inkRefillDelay":.7},true)
	# 120 HP: reliable three-hit shooter; slow precision/contact attacks earn a splat.
	data["weapons"]["shooter"].merge({"specialCost":120,"damage":42,"inkPerShot":.85,"special":"overdrive"},true)
	data["weapons"]["roller"].merge({"rollDamage":125,"flickDamageNear":140,"flickDamageFar":22,"finalDamageCap":160.0},true)
	data["weapons"]["charger"].merge({"damageMin":32,"damageMax":150,"inkFull":14.0,"finalDamageCap":180.0},true)
	data["weapons"]["blaster"].merge({"directDamage":125,"splashDamageMax":60,"splashDamageMin":24,"inkPerShot":7.0,"special":"siege_shell","finalDamageCap":160.0},true)
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
