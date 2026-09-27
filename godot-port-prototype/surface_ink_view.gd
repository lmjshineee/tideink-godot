extends Node3D

# A simple visual projection of the authoritative 0.25 m face grids.
# Create a face's mesh and texture when it first receives ink.
# Only changed cells and faces are uploaded after that.
const TEAM_COLORS := [Color("ff8a14"), Color("2f5bff")]
const CLEAR := Color(0.0, 0.0, 0.0, 0.0)

var ink: RefCounted
var images: Dictionary = {}
var textures: Dictionary = {}
var face_mesh_count := 0


func setup(surface_ink: RefCounted) -> void:
	ink = surface_ink


func sync_dirty() -> int:
	var dirty: Dictionary = ink.consume_dirty_cells()
	for key in dirty:
		var face_id := int(key)
		if not images.has(face_id):
			_create_face(face_id)
		var face: Dictionary = ink.surfaces[face_id]
		var grid: Dictionary = face["grid"]
		var nu := int(grid["nu"])
		var image: Image = images[face_id]
		var owners: PackedByteArray = ink.owners[face_id]
		for index in dirty[key]:
			var cell := int(index)
			var value := int(owners[cell])
			var color: Color = CLEAR if value == 0 else TEAM_COLORS[value - 1]
			image.set_pixel(cell % nu, cell / nu, color)
		var texture: ImageTexture = textures[face_id]
		texture.update(image)
	return dirty.size()


func _create_face(face_id: int) -> void:
	var face: Dictionary = ink.surfaces[face_id]
	var grid: Dictionary = face["grid"]
	var image := Image.create_empty(int(grid["nu"]), int(grid["nv"]), false, Image.FORMAT_RGBA8)
	image.fill(CLEAR)
	var texture := ImageTexture.create_from_image(image)
	images[face_id] = image
	textures[face_id] = texture
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = texture
	var visual := MeshInstance3D.new()
	visual.name = "InkFace_%d" % face_id
	visual.mesh = _face_mesh(face)
	visual.material_override = material
	add_child(visual)
	face_mesh_count += 1


static func _face_mesh(face: Dictionary) -> ArrayMesh:
	var origin := _vector(face["origin"]) + _vector(face["n"]) * 0.012
	var horizontal := _vector(face["u"]) * float(face["su"])
	var vertical := _vector(face["v"]) * float(face["sv"])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		origin, origin + horizontal, origin + horizontal + vertical, origin + vertical,
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
