extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var packed := load("res://tidewater_map.tscn") as PackedScene
	if packed == null:
		printerr("FAIL: map scene did not load")
		quit(1)
		return
	var map := packed.instantiate()
	root.add_child(map)
	await process_frame
	var bodies := 0
	var ramps := 0
	var collisions := 0
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater.json"))
	for child in map.get_children():
		if child is StaticBody3D:
			bodies += 1
			var source: Dictionary = manifest["blocks"][child.get_meta("source_id")]
			if child.position.distance_to(_vector(source["geometry"]["center"])) > 0.00001:
				printerr("FAIL: block position: ", source["id"])
				quit(1)
				return
			if "_ramp" in child.name:
				ramps += 1
			for part in child.get_children():
				if part is CollisionShape3D:
					collisions += 1
	# 63 structural blocks + 82 set-dressing prop colliders, all solid. The prop
	# colliders are hidden and unpaintable but must exist as collision, or players
	# walk through benches and crates that the web game collides with.
	var structural := int(manifest.get("structuralBlocks", 0))
	var expected: int = structural + int((manifest.get("dressing") as Dictionary).get("propColliders", 0))
	if map.get("block_count") != expected or bodies != expected or ramps != 10 or collisions != expected:
		printerr("FAIL: blocks=", map.get("block_count"), " bodies=", bodies, " ramps=", ramps, " collisions=", collisions, " expected=", expected)
		quit(1)
		return
	if structural != 63 or expected != 145:
		printerr("FAIL: structural/prop split changed: structural=", structural, " total=", expected)
		quit(1)
		return
	# Export provenance and grid invariants. These fields have no runtime consumer, so the
	# only thing that keeps them honest is being asserted here; the consumption gate
	# (check_config_consumption.gd) records that division of labour in its allowlist.
	var surfaces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater_surfaces.json"))
	if String(manifest.get("source", "")).is_empty() or String(surfaces.get("source", "")).is_empty():
		printerr("FAIL: export provenance is missing from the map or surfaces JSON")
		quit(1)
		return
	if String(manifest.get("layout", "")) != String(manifest.get("id", "")) \
			or String(surfaces.get("layout", "")) != String(manifest.get("layout", "")):
		printerr("FAIL: the two exports disagree about the layout they describe")
		quit(1)
		return
	# The two exports must agree about the set dressing: they are built from the same prop
	# kit, and the whole 70,180 vs 69,366 denominator defect was one of them being built
	# without those colliders. Disagreement here means one export is stale.
	var map_dressing: Dictionary = manifest.get("dressing", {})
	var surface_dressing: Dictionary = surfaces.get("dressing", {})
	if int(map_dressing.get("propColliders", -1)) != int(surface_dressing.get("propColliders", -2)) \
			or int(map_dressing.get("items", -1)) != int(surface_dressing.get("items", -2)):
		printerr("FAIL: the two exports disagree about set dressing: ", map_dressing, " vs ", surface_dressing)
		quit(1)
		return
	if absf(float(surfaces.get("cellSize", 0.0)) - 0.25) > 0.000001:
		printerr("FAIL: the ink grid is not the source's 0.25 m cell: ", surfaces.get("cellSize"))
		quit(1)
		return
	var counted_cells := 0
	for face in surfaces.get("faces", []):
		var grid: Variant = face.get("grid")
		if grid is Dictionary:
			counted_cells += int(grid["nu"]) * int(grid["nv"])
	if counted_cells != int(surfaces.get("gridCells", -1)):
		printerr("FAIL: gridCells (%s) does not match the per-face grids (%d)" % [
			surfaces.get("gridCells"), counted_cells])
		quit(1)
		return
	if (map.get("spawn_pads") as Array).size() != 2:
		printerr("FAIL: missing spawn pads")
		quit(1)
		return
	if map.get("paintable_count") != 285 or map.get("turf_count") != 61:
		printerr("FAIL: source surface counts")
		quit(1)
		return
	var checked_turf := false
	var checked_wall := false
	for face in map.get("surfaces"):
		if not face["paintable"] or (checked_turf and checked_wall):
			continue
		if (face["turf"] and not checked_turf) or (face["wall"] and not checked_wall):
			var origin := _vector(face["origin"])
			var point := origin + _vector(face["u"]) * float(face["su"]) * 0.5 + _vector(face["v"]) * float(face["sv"]) * 0.5
			var found: Dictionary = map.call("find_surface", point, _vector(face["n"]), int(face["block"]))
			if found.is_empty() or found["id"] != face["id"]:
				printerr("FAIL: source face lookup: ", face["id"])
				quit(1)
				return
			checked_turf = checked_turf or face["turf"]
			checked_wall = checked_wall or face["wall"]
	if not checked_turf or not checked_wall:
		printerr("FAIL: missing surface examples")
		quit(1)
		return
	print("PASS: ", expected, " bodies (", structural, " structural + props), 10 ramps, 2 spawns, 289 faces; "
		+ str(counted_cells), " grid cells at ", surfaces.get("cellSize"), " m; provenance and turf/wall lookup")
	quit()

static func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
