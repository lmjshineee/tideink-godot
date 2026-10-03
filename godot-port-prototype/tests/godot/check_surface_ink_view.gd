extends SceneTree

const SurfaceInk = preload("res://src/world/surface_ink.gd")
const SurfaceInkView = preload("res://src/world/surface_ink_view.gd")


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater_surfaces.json"))
	var ink = SurfaceInk.new(data)
	var view = SurfaceInkView.new()
	root.add_child(view)
	view.setup(ink)
	if view.face_mesh_count != 0 or not view.images.is_empty() or not view.textures.is_empty() or view.get_child_count() != 0:
		printerr("FAIL: unpainted faces allocated visual resources")
		quit(1)
		return
	var face: Dictionary = data["faces"][12]
	var u := float(face["su"]) * 0.5
	var v := float(face["sv"]) * 0.5
	if ink.splat_face(12, u, v, 0.6, 0, 0.5) <= 0.0 or view.sync_dirty() != 1:
		printerr("FAIL: first face texture update")
		quit(1)
		return
	if view.face_mesh_count != 1 or view.images.size() != 1 or view.textures.size() != 1 or view.get_child_count() != 1:
		printerr("FAIL: first painted face was not allocated once")
		quit(1)
		return
	var grid: Dictionary = face["grid"]
	var i := clampi(int(floor(u / float(grid["cu"]))), 0, int(grid["nu"]) - 1)
	var j := clampi(int(floor(v / float(grid["cv"]))), 0, int(grid["nv"]) - 1)
	var image: Image = view.images[12]
	if image.get_pixel(i, j).a < 0.99 or view.sync_dirty() != 0:
		printerr("FAIL: owned cell pixel or duplicate upload")
		quit(1)
		return
	ink.splat_face(12, u, v, 0.6, 1, 0.5)
	if view.sync_dirty() != 1 or image.get_pixel(i, j) != SurfaceInkView.TEAM_MASKS[1] or view.images[12] != image or view.face_mesh_count != 1:
		printerr("FAIL: enemy repaint texture")
		quit(1)
		return
	var second: Dictionary = data["faces"][65]
	if ink.splat_face(65, float(second["su"]) * 0.5, float(second["sv"]) * 0.5, 0.6, 0, 0.5) <= 0.0 or view.sync_dirty() != 1:
		printerr("FAIL: second face paint event")
		quit(1)
		return
	if view.face_mesh_count != 2 or view.images.size() != 2 or view.textures.size() != 2 or view.get_child_count() != 2:
		printerr("FAIL: second face did not allocate exactly one visual")
		quit(1)
		return
	# Lit overlays require face normals and a tangent basis for floors, ramps and
	# walls. Verify against source geometry, not only material/node presence.
	for definition in data["faces"]:
		if not bool(definition["paintable"]):
			continue
		var mesh: ArrayMesh = SurfaceInkView._face_mesh(definition)
		var arrays := mesh.surface_get_arrays(0)
		var n := Vector3(definition["n"][0], definition["n"][1], definition["n"][2]).normalized()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		if normals.size() != 4 or tangents.size() != 16 or normals[0].distance_to(n) > 0.001:
			printerr("FAIL: lit surface normal: ", definition["id"])
			quit(1)
			return
		var t := Vector3(tangents[0], tangents[1], tangents[2])
		var basis_v := Vector3(definition["v"][0], definition["v"][1], definition["v"][2]).normalized()
		if absf(t.dot(n)) > 0.001 or n.cross(t).dot(basis_v) * tangents[3] < 0.99:
			printerr("FAIL: lit surface tangent basis: ", definition["id"])
			quit(1)
			return
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var a := vertices[indices[1]] - vertices[indices[0]]
		var b := vertices[indices[2]] - vertices[indices[0]]
		if a.cross(b).normalized().dot(n) > -0.99:
			printerr("FAIL: ink front face must use Godot clockwise winding")
			quit(1)
			return
	var coverage_before := [ink.coverage(0), ink.coverage(1)]
	var owners_before: Array = ink.owners.duplicate(true)
	if view.texture_upload_count != 3 or view.sync_dirty() != 0 or view.texture_upload_count != 3:
		printerr("FAIL: unchanged ink uploaded again")
		quit(1)
		return
	view.free()
	if coverage_before != [ink.coverage(0), ink.coverage(1)] or owners_before != ink.owners:
		printerr("FAIL: rendering changed authoritative ownership or score")
		quit(1)
		return
	print("PASS: lazy ink resources, dirty uploads, repaint, all face tangent bases; deleting visuals preserves ownership and score")
	quit()
