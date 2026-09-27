extends RefCounted

# CPU-only port of the source game's per-face ownership grid. Rendering comes later.
const PaintField = preload("res://paint_field.gd")
const WOB_MAX := 1.5
const EMPTY := 0

var surfaces: Array[Dictionary] = []
var owners: Array[PackedByteArray] = []
var buried: Array[PackedByteArray] = []
var turf_total := 0
var counts := [0, 0]
var version := 0
var _dirty_cells: Dictionary = {}


func _init(surface_data: Dictionary) -> void:
	turf_total = int(surface_data["turfCells"])
	for face in surface_data["faces"]:
		surfaces.append(face)
		var grid: Variant = face["grid"]
		var ownership := PackedByteArray()
		var dead := PackedByteArray()
		if grid is Dictionary:
			var cells := int(grid["nu"]) * int(grid["nv"])
			ownership.resize(cells)
			ownership.fill(EMPTY)
			dead.resize(cells)
			dead.fill(0)
			for run in grid["deadRuns"]:
				for index in range(int(run[0]), int(run[0]) + int(run[1])):
					dead[index] = 1
		owners.append(ownership)
		buried.append(dead)


func owner_at(face_id: int, local_u: float, local_v: float) -> int:
	var grid: Variant = surfaces[face_id]["grid"]
	if not grid is Dictionary:
		return -1
	var i := clampi(int(floor(local_u / float(grid["cu"]))), 0, int(grid["nu"]) - 1)
	var j := clampi(int(floor(local_v / float(grid["cv"]))), 0, int(grid["nv"]) - 1)
	var value := owners[face_id][j * int(grid["nu"]) + i]
	return -1 if value == EMPTY else value - 1


func coverage(team: int) -> float:
	return float(counts[team]) / float(turf_total)


# The visual layer consumes only changed cells and uploads each affected face once.
func consume_dirty_cells() -> Dictionary:
	var result := _dirty_cells
	_dirty_cells = {}
	return result


# A spherical splat can mark the floor, a ramp and an adjacent wall at once.
# This is the unstretched CPU rule; animated ink growth and GPU atlas are separate.
func splat_world(center: Vector3, radius: float, team: int, seed: float) -> float:
	var claimed := 0.0
	for face in surfaces:
		if not bool(face["paintable"]):
			continue
		var relative := center - _vector(face["origin"])
		var distance := relative.dot(_vector(face["n"]))
		if distance > radius or distance < -0.12:
			continue
		var local_u := relative.dot(_vector(face["u"]))
		var local_v := relative.dot(_vector(face["v"]))
		var projected_radius := sqrt(maxf(0.0, radius * radius - distance * distance))
		var extent := projected_radius * 2.05
		if local_u < -extent or local_u > float(face["su"]) + extent:
			continue
		if local_v < -extent - (projected_radius * 1.9 if bool(face["wall"]) else 0.0) or local_v > float(face["sv"]) + extent:
			continue
		claimed += splat_face(int(face["id"]), local_u, local_v, projected_radius, team, seed)
	return claimed


func splat_face(face_id: int, local_u: float, local_v: float, radius: float, team: int, seed: float) -> float:
	if radius <= 0.02:
		return 0.0
	var face: Dictionary = surfaces[face_id]
	var grid: Variant = face["grid"]
	if not grid is Dictionary:
		return 0.0
	var nu := int(grid["nu"])
	var nv := int(grid["nv"])
	var cu := float(grid["cu"])
	var cv := float(grid["cv"])
	var extent := radius * WOB_MAX
	var i0 := maxi(0, int(floor((local_u - extent) / cu)))
	var i1 := mini(nu - 1, int(floor((local_u + extent) / cu)))
	var j0 := maxi(0, int(floor((local_v - extent) / cv)))
	var j1 := mini(nv - 1, int(floor((local_v + extent) / cv)))
	if i1 < i0 or j1 < j0:
		return 0.0
	var pixels: PackedByteArray = owners[face_id]
	var dead: PackedByteArray = buried[face_id]
	var claimed := 0.0
	var changed := PackedInt32Array()
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var dx := (float(i) + 0.5) * cu - local_u
			var dy := (float(j) + 0.5) * cv - local_v
			var distance := sqrt(dx * dx + dy * dy)
			if distance > radius * WOB_MAX:
				continue
			if distance / (radius * PaintField.blob_wobble(atan2(dy, dx), seed)) > 0.97:
				continue
			var index := j * nu + i
			var before := pixels[index]
			if before == team + 1:
				continue
			pixels[index] = team + 1
			changed.append(index)
			claimed += cu * cv
			if bool(face["turf"]) and dead[index] == 0:
				if before != EMPTY:
					counts[before - 1] -= 1
				counts[team] += 1
	if claimed > 0.0:
		owners[face_id] = pixels
		if _dirty_cells.has(face_id):
			var pending: PackedInt32Array = _dirty_cells[face_id]
			pending.append_array(changed)
			_dirty_cells[face_id] = pending
		else:
			_dirty_cells[face_id] = changed
		version += 1
	return claimed


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
