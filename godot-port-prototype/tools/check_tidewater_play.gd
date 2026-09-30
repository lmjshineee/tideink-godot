extends SceneTree


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	if ProjectSettings.get_setting("application/run/main_scene") != "res://tidewater_play.tscn":
		printerr("FAIL: Tidewater is not the default demo scene")
		quit(1)
		return
	var packed := load("res://tidewater_play.tscn") as PackedScene
	if packed == null:
		printerr("FAIL: real-map play scene did not load")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await physics_frame
	var map: Node3D = scene.get_node("World/Map")
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	var view: Node3D = scene.get_node("InkView")
	var combat: Node3D = scene.get_node("Combat")
	var ink: RefCounted = scene.get("ink")
	# 63 structural blocks + 82 set-dressing prop colliders; turf denominator from
	# export_tidewater_surfaces.mjs, which now includes the buried cells the props
	# create (it used to report 70,180 because it built the Level without them).
	if map.get("block_count") != 145 or view.get("face_mesh_count") != 0 or ink.get("turf_total") != 69366:
		printerr("FAIL: real-map scene wiring: blocks=", map.get("block_count"), " meshes=", view.get("face_mesh_count"), " turf=", ink.get("turf_total"))
		quit(1)
		return
	if scene.get("phase") != "setup" or bool(walker.get("active")) or (combat.get("weapons") as Dictionary).size() != 4:
		printerr("FAIL: weapon loadout setup")
		quit(1)
		return
	scene.call("_start_round")
	if scene.get("phase") != "playing" or not bool(walker.get("active")):
		printerr("FAIL: real-map round start")
		quit(1)
		return
	var face: Dictionary = (map.get("surfaces") as Array)[12]
	var center := _vector(face["origin"]) + _vector(face["u"]) * float(face["su"]) * 0.5 \
		+ _vector(face["v"]) * float(face["sv"]) * 0.5 + _vector(face["n"]) * 0.06
	if float(scene.call("paint_at_world", center, 0, 0.7, 0.5)) <= 0.0:
		printerr("FAIL: source face paint event")
		quit(1)
		return
	if float(ink.call("coverage", 0)) <= 0.0 or int(view.call("sync_dirty")) <= 0 or int(view.get("face_mesh_count")) <= 0:
		printerr("FAIL: real-map scoring or texture synchronization")
		quit(1)
		return
	if walker.get("ink") != ink:
		printerr("FAIL: walker and scoring use different ink states")
		quit(1)
		return
	scene.call("paint_at_world", walker.global_position + Vector3.UP * 0.06, 0, 0.9, 0.5)
	await physics_frame
	if int(walker.get("ink_owner")) != 0:
		printerr("FAIL: walker does not sample its own ink from the map")
		quit(1)
		return
	print("PASS: real-map collision, loadout, lazy ink visuals, turf scoring and walker ink ownership")
	quit()


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
