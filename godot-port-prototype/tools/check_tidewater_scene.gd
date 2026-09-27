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
	if map.get("block_count") != 63 or bodies != 63 or ramps != 10 or collisions != 63:
		printerr("FAIL: blocks=", map.get("block_count"), " bodies=", bodies, " ramps=", ramps, " collisions=", collisions)
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
	print("PASS: 63 bodies, 10 ramps, 63 colliders, 2 spawns, 289 faces; turf/wall lookup")
	quit()

static func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
