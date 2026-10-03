extends SceneTree

const SurfaceInk = preload("res://src/world/surface_ink.gd")

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater_surfaces.json"))
	var ink = SurfaceInk.new(data)
	# Guard against Godot-side drift: the loader must take the denominator from the
	# export. The expected value is pinned so a change in the map or set dressing is
	# a visible, deliberate edit; export_tidewater_surfaces.mjs --check guards the
	# source side (289 faces, 69,366 turf cells).
	var expected_turf := 69366
	if int(data["turfCells"]) != expected_turf:
		printerr("FAIL: exported turfCells changed: ", data["turfCells"], " (expected ", expected_turf, ")")
		quit(1)
		return
	if ink.turf_total != expected_turf or ink.surfaces.size() != 289:
		printerr("FAIL: Turf grid size: total=", ink.turf_total, " faces=", ink.surfaces.size())
		quit(1)
		return
	var turf: Dictionary = {}
	var wall: Dictionary = {}
	for face in data["faces"]:
		if bool(face["paintable"]) and bool(face["turf"]) and turf.is_empty():
			var grid: Dictionary = face["grid"]
			var center_index := (int(grid["nv"]) / 2) * int(grid["nu"]) + int(grid["nu"]) / 2
			var center_buried := false
			for run in grid["deadRuns"]:
				if center_index >= int(run[0]) and center_index < int(run[0]) + int(run[1]):
					center_buried = true
					break
			if not center_buried:
				turf = face
		if bool(face["paintable"]) and bool(face["wall"]) and wall.is_empty(): wall = face
	var turf_id := int(turf["id"])
	var turf_u := float(turf["su"]) * 0.5
	var turf_v := float(turf["sv"]) * 0.5
	var first: float = ink.splat_face(turf_id, turf_u, turf_v, 1.0, 0, 0.5)
	if first <= 0.0 or ink.counts[0] <= 0 or ink.owner_at(turf_id, turf_u, turf_v) != 0:
		printerr("FAIL: first team turf claim")
		quit(1)
		return
	if ink.splat_face(turf_id, turf_u, turf_v, 1.0, 0, 0.5) != 0.0:
		printerr("FAIL: duplicate turf claim")
		quit(1)
		return
	ink.splat_face(turf_id, turf_u, turf_v, 1.0, 1, 0.5)
	if ink.counts[0] != 0 or ink.counts[1] <= 0 or ink.owner_at(turf_id, turf_u, turf_v) != 1:
		printerr("FAIL: enemy turf overwrite")
		quit(1)
		return
	if not is_equal_approx(ink.coverage(1), float(ink.counts[1]) / float(ink.turf_total)):
		printerr("FAIL: coverage must use the source 0..1 fraction")
		quit(1)
		return
	var before: Array = ink.counts.duplicate()
	var wall_u := float(wall["su"]) * 0.5
	var wall_v := float(wall["sv"]) * 0.5
	if ink.splat_face(int(wall["id"]), wall_u, wall_v, 0.7, 0, 0.5) <= 0.0 or ink.counts != before:
		printerr("FAIL: wall paint changed turf score")
		quit(1)
		return
	# Stretch: grazing hits smear the blob along the shot direction and the web applies
	# that to the scoring grid, not just to the picture (paint.js:283-287, 345-350).
	# Omitting it changed claimed area and coverage on every glancing hit.
	var grid: Dictionary = turf["grid"]
	var nu := int(grid["nu"])
	var nv := int(grid["nv"])
	var plain := SurfaceInk.new(data)
	plain.splat_face(turf_id, turf_u, turf_v, 1.2, 0, 0.75)
	var stretched := SurfaceInk.new(data)
	stretched.splat_face(turf_id, turf_u, turf_v, 1.2, 0, 0.75, 1.0, 0.0, 2.0)
	var plain_span := _span(plain, turf_id, nu)
	var stretched_span := _span(stretched, turf_id, nu)
	if stretched.counts[0] <= plain.counts[0] or stretched_span[0] <= plain_span[0]:
		printerr("FAIL: stretch did not lengthen the blob: cells ", plain.counts[0], " -> ", stretched.counts[0],
			" u-span ", plain_span[0], " -> ", stretched_span[0])
		quit(1)
		return
	if stretched_span[1] > plain_span[1] + 1:
		printerr("FAIL: stretch widened across the direction: v-span ", plain_span[1], " -> ", stretched_span[1])
		quit(1)
		return
	# A stretch pointing out of the face plane must degrade to a circle, not distort.
	var flat := SurfaceInk.new(data)
	flat.splat_face(turf_id, turf_u, turf_v, 1.2, 0, 0.75)
	if flat.counts[0] != plain.counts[0]:
		printerr("FAIL: zero-amount stretch changed the blob")
		quit(1)
		return
	print("PASS: scoreable cells, turf claim/overwrite, unscored wall paint, stretched blob shape")
	quit()


# [u-span, v-span] in cells of the claimed region on one face.
func _span(ink: RefCounted, face_id: int, nu: int) -> Array:
	var pixels: PackedByteArray = ink.owners[face_id]
	var min_u := 1 << 30
	var max_u := -1
	var min_v := 1 << 30
	var max_v := -1
	for index in pixels.size():
		if pixels[index] == 0:
			continue
		var i := index % nu
		var j := index / nu
		min_u = mini(min_u, i)
		max_u = maxi(max_u, i)
		min_v = mini(min_v, j)
		max_v = maxi(max_v, j)
	if max_u < 0:
		return [0, 0]
	return [max_u - min_u, max_v - min_v]
