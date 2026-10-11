extends RefCounted

# Half-width/height in radians. The same box drives shots and the HUD.
static func box(weapon:Dictionary,grounded:bool,bloom:float=0.0,precision:bool=false) -> Vector2:
	var angle:=float(weapon.get("spreadBaseGround",0.0) if grounded else weapon.get("spreadBaseAir",0.0))
	if String(weapon.kind)=="shooter":
		if grounded and bloom<=.001 and int(weapon.get("shots",1))==1:return Vector2.ZERO
		angle*=lerpf(float(weapon["spreadFirst"]),1.0,clampf(bloom,0,1))
	if precision:angle*=.35
	return Vector2(deg_to_rad(angle),deg_to_rad(angle)*float(weapon.get("spreadVertical",.55)))

static func sample(direction:Vector3,half_box:Vector2) -> Vector3:
	var basis:=axes(direction)
	return (direction+basis[0]*randf_range(-tan(half_box.x),tan(half_box.x))
		+basis[1]*randf_range(-tan(half_box.y),tan(half_box.y))).normalized()

static func axes(direction:Vector3) -> Array[Vector3]:
	var helper:=Vector3.UP if absf(direction.dot(Vector3.UP))<.9 else Vector3.RIGHT
	var right:=direction.cross(helper).normalized()
	return [right,direction.cross(right).normalized()]

static func canopy_box(weapon:Dictionary,grounded:bool) -> Vector2:
	return Vector2(deg_to_rad(float(weapon.pelletSpread)),deg_to_rad(float(weapon.pelletSpread)*(.75 if grounded else 1.15)))

static func bow_fan(charge:float) -> float:
	return lerpf(.105,.07,charge*2) if charge<.5 else lerpf(.07,.008,(charge-.5)*2)
