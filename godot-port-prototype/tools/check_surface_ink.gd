extends SceneTree

const SurfaceInk = preload("res://surface_ink.gd")

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater_surfaces.json"))
	var ink = SurfaceInk.new(data)
	if ink.turf_total != 70180 or ink.surfaces.size() != 289:
		printerr("FAIL: Turf grid size")
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
	print("PASS: 70,180 scoreable cells; turf claim, idempotence, overwrite and unscored wall paint")
	quit()
