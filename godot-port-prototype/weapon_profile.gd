extends RefCounted
const CATEGORIES := [["range","射程"],["damage","伤害"],["rate","射速"],["mobility","机动"],["paint","涂地"]]
static func rating(weapon: Dictionary, key: String) -> int:
	if key=="damage":
		var damage := float(weapon.get("damage",weapon.get("directDamage",weapon.get("damageMax",weapon.get("flickDamageNear",0)))))
		return clampi(roundi(damage/100.0*5.0),1,5)
	return clampi(roundi(float(weapon["stats"][key])*5.0),1,5)
static func stars(weapon: Dictionary) -> String:
	var lines := PackedStringArray()
	for field in CATEGORIES:
		var count := rating(weapon,field[0])
		lines.append(field[1]+"  "+"★".repeat(count)+"☆".repeat(5-count))
	return "\n".join(lines)
