extends SceneTree

const SurfaceInk = preload("res://surface_ink.gd")
const SurfaceInkView = preload("res://surface_ink_view.gd")


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
	if view.sync_dirty() != 1 or image.get_pixel(i, j).b <= image.get_pixel(i, j).r or view.images[12] != image or view.face_mesh_count != 1:
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
	print("PASS: ink visuals allocated on first paint; dirty-face updates and enemy repaint")
	quit()
