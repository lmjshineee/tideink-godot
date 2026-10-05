extends RefCounted
# A hit reveals only its attributed source at impact time, never live tracking.
const LIFETIME := 2.8
const CAPACITY := 3
var entries: Array[Dictionary] = []
const NUMBER_LIFETIME := 0.8
var numeric_pops: Array[Dictionary] = []

static func number_text(amount: float) -> String:
	return "−%.0f" % amount if absf(amount - roundf(amount)) < .01 else "−%.1f" % amount

func clear() -> void:
	entries.clear()
	numeric_pops.clear()

func record(label:String, amount:float, origin:Vector3, numeric_only:bool = false) -> void:
	if amount<=0:return
	if numeric_only:
		# Environmental ticks must not evict a named weapon hit or invent a compass.
		if amount < .05: return # Hide imperceptible fractions instead of drawing −0.0.
		numeric_pops.push_front({"amount":amount, "age":0.0})
		while numeric_pops.size()>CAPACITY: numeric_pops.pop_back()
		return
	for entry in entries:
		if entry.label==label and entry.time>2.2:
			entry.amount+=amount;entry.time=LIFETIME;entry.origin=origin;return
	entries.push_front({"label":label,"amount":amount,"origin":origin,"time":LIFETIME})
	while entries.size()>CAPACITY:entries.pop_back()
func tick(delta:float) -> void:
	for i in range(numeric_pops.size()-1,-1,-1):
		numeric_pops[i].age += delta
		if numeric_pops[i].age >= NUMBER_LIFETIME: numeric_pops.remove_at(i)
	for i in range(entries.size()-1,-1,-1):
		entries[i].time-=delta
		if entries[i].time<=0:entries.remove_at(i)
func direction(entry:Dictionary, camera:Camera3D, player:Vector3) -> Vector2:
	if not (entry.origin as Vector3).is_finite():return Vector2.ZERO
	var offset:Vector3=entry.origin-player;offset.y=0
	if offset.length_squared()<.01:return Vector2.ZERO
	var facing:Vector3=-camera.global_basis.z;facing.y=0;facing=facing.normalized()
	var right:=facing.cross(Vector3.UP)
	return Vector2(offset.dot(right),-offset.dot(facing)).normalized()
