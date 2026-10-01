extends RefCounted

# Local playtest balance. Exported web config stays reproducible and unmodified.
static func apply(data: Dictionary) -> void:
	data["player"].merge({"hp":120,"regenDelay":1.8,"regenRate":24,"regenRateSwim":65,
		"respawnTime":4.0,"climbSpeed":9.5,"climbAccel":58},true)
	data["weapons"]["shooter"].merge({"specialCost":150,"damage":30},true)
	data["weapons"]["roller"].merge({"rollDamage":60,"flickDamageNear":72,"flickDamageFar":22},true)
	data["weapons"]["charger"].merge({"damageMin":32,"damageMax":100},true)
	data["weapons"]["blaster"].merge({"directDamage":82,"splashDamageMax":55,"splashDamageMin":24},true)
	data["sub"]["bomb"].merge({"damageMax":100,"damageMin":30},true)
	data["weapons"]["roller"]["specialCost"] = 140
	data["weapons"]["charger"]["specialCost"] = 155
	data["weapons"]["blaster"]["specialCost"] = 155
	data["specials"]["slam"].merge({"radius":6.0,"killRadius":3.2,"damageMin":70},true)
	data["specials"]["storm"].merge({"duration":8.0,"radius":4.2,"dps":42},true)
	preload("res://equipment_catalog.gd").extend(data)

static func shooter_damage(base: float, distance: float, reach: float) -> float:
	# Keep a strong four-hit core; the last quarter of range rewards closing distance.
	return base * lerpf(1.0,0.78,clampf((distance/reach-0.75)/0.25,0.0,1.0))
