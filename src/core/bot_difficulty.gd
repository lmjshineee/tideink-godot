extends RefCounted
const IDS := ["casual","standard","veteran"]
const LABELS := ["休闲 AI","标准 AI","进阶 AI"]
# Decisions and aim change; HP, damage, ink, cover and visibility rules do not.
const PROFILES := {
	"casual":{"reaction":.55,"cadence":1.4,"aim_error":.055,"repath":1.5,"strafe":.65},
	"standard":{"reaction":.25,"cadence":1.12,"aim_error":.025,"repath":.9,"strafe":1.35},
	"veteran":{"reaction":.10,"cadence":1.0,"aim_error":.008,"repath":.5,"strafe":2.1}}
static func profile(id:String) -> Dictionary:return PROFILES.get(id,PROFILES.standard)
static func aim(from:Vector3, target:Vector3, id:String) -> Vector3:
	var radius:float=minf(1.2,from.distance_to(target)*float(profile(id).aim_error))
	return target+Vector3(randf_range(-radius,radius),randf_range(-radius*.5,radius*.5),randf_range(-radius,radius))
