extends Node3D

# Lit visual projection of the authoritative 0.25 m face grids.
# Create a face's mesh and texture when it first receives ink.
# Only changed cells and faces are uploaded after that.
const TeamPalette := preload("res://src/core/team_palette.gd")
# Data channels, not display colors. Filtering preserves team weights even when
# a selected palette has equal/reversed blue components.
const TEAM_MASKS := [Color(1.0, 0.0, 0.0, 1.0), Color(0.0, 1.0, 0.0, 1.0)]
const CLEAR := Color(0.0, 0.0, 0.0, 0.0)
const INK_SHADER = preload("res://shaders/world/surface_ink.gdshader")

var ink: RefCounted
var images: Dictionary = {}
var textures: Dictionary = {}
var face_mesh_count := 0
var texture_upload_count := 0
var team_colors: Array[Color] = []


func setup(surface_ink: RefCounted) -> void:
	ink = surface_ink
	team_colors = [TeamPalette.color(0), TeamPalette.color(1)]


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
			var color: Color = CLEAR if value == 0 else TEAM_MASKS[value - 1]
			image.set_pixel(cell % nu, cell / nu, color)
		var texture: ImageTexture = textures[face_id]
		texture.update(image)
		texture_upload_count += 1
	return dirty.size()


func _create_face(face_id: int) -> void:
	var face: Dictionary = ink.surfaces[face_id]
	var grid: Dictionary = face["grid"]
	var image := Image.create_empty(int(grid["nu"]), int(grid["nv"]), false, Image.FORMAT_RGBA8)
	image.fill(CLEAR)
	var texture := ImageTexture.create_from_image(image)
	images[face_id] = image
	textures[face_id] = texture
	var material := ShaderMaterial.new()
	material.shader = INK_SHADER
	material.set_shader_parameter("ink_texture", texture)
	material.set_shader_parameter("surface_size", Vector2(float(face["su"]), float(face["sv"])))
	material.set_shader_parameter("team_a", team_colors[0])
	material.set_shader_parameter("team_b", team_colors[1])
	var visual := MeshInstance3D.new()
	visual.name = "InkFace_%d" % face_id
	visual.mesh = _face_mesh(face)
	visual.material_override = material
	# Ink receives terrain/actor shadows, but must not shadow its own floor.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	face_mesh_count += 1


static func face_offset(face: Dictionary) -> float:
	# Wall stickers sit 12 mm above the wall; the wet ink must sit above them.
	return 0.024 if absf(float(face["n"][1])) < 0.45 else 0.012


static func _face_mesh(face: Dictionary) -> ArrayMesh:
	var origin := _vector(face["origin"]) + _vector(face["n"]) * face_offset(face)
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
	var normal := _vector(face["n"]).normalized()
	var tangent := _vector(face["u"]).normalized()
	var handedness := 1.0 if normal.cross(tangent).dot(_vector(face["v"])) > 0.0 else -1.0
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal, normal])
	var tangents := PackedFloat32Array()
	for i in range(4):
		tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, handedness]))
	arrays[Mesh.ARRAY_TANGENT] = tangents
	# Source u/v use a right-handed basis; Godot front faces are clockwise.
	# Correct winding prevents double-sided lighting from flipping the normals.
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2]) if handedness > 0.0 else PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
