extends RefCounted
# A hit reveals only its attributed source at impact time, never live tracking.
const LIFETIME := 2.8
const CAPACITY := 3
var entries: Array[Dictionary] = []
func record(label:String, amount:float, origin:Vector3) -> void:
	if amount<=0:return
	for entry in entries:
		if entry.label==label and entry.time>2.2:
			entry.amount+=amount;entry.time=LIFETIME;entry.origin=origin;return
	entries.push_front({"label":label,"amount":amount,"origin":origin,"time":LIFETIME})
	while entries.size()>CAPACITY:entries.pop_back()
func tick(delta:float) -> void:
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
