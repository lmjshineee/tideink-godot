extends Node3D

# Structural map slice: visible blocks, collision shapes and source spawn pads.
# Paintable faces, movement on ramps, and wall ink are separate migration steps.
const MAP_FILE := "res://assets/maps/tidewater.json"
const SURFACES_FILE := "res://assets/maps/tidewater_surfaces.json"

var map_bounds := Rect2()
var block_count := 0
var spawn_pads: Array[Vector3] = []
var surfaces: Array[Dictionary] = []
var paintable_count := 0
var turf_count := 0
var _materials: Dictionary = {}
var _faces_by_block: Dictionary = {}


func _ready() -> void:
	var content := FileAccess.get_file_as_string(MAP_FILE)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary or parsed.get("schema") != 1 or parsed.get("id") != "tidewater":
		push_error("Could not load Tidewater source map: " + MAP_FILE)
		return
	_build(parsed)
	var surface_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SURFACES_FILE))
	if not surface_data is Dictionary or surface_data.get("schema") != 1 or surface_data.get("blockCount") != block_count:
		push_error("Could not load Tidewater face definitions: " + SURFACES_FILE)
		return
	for face in surface_data["faces"]:
		surfaces.append(face)
		var block_id := int(face["block"])
		if not _faces_by_block.has(block_id):
			_faces_by_block[block_id] = []
		_faces_by_block[block_id].append(face)
		if bool(face["paintable"]):
			paintable_count += 1
			if bool(face["turf"]):
				turf_count += 1


func _build(data: Dictionary) -> void:
	var bounds: Dictionary = data["bounds"]
	map_bounds = Rect2(
		Vector2(float(bounds["minX"]), float(bounds["minZ"])),
		Vector2(float(bounds["maxX"]) - float(bounds["minX"]), float(bounds["maxZ"]) - float(bounds["minZ"]))
	)
	for values in data["spawnPads"]:
		var position := _vector(values)
		spawn_pads.append(position)
		var marker := Marker3D.new()
		marker.name = "Spawn_%d" % (spawn_pads.size() - 1)
		marker.position = position
		add_child(marker)
	for def in data["blocks"]:
		_add_block(def)
	block_count = (data["blocks"] as Array).size()


# Use a ray hit's collider source_id, position and normal to locate its source face.
# Faces are indexed by source block, so a hit checks at most that block's faces.
func find_surface(point: Vector3, normal: Vector3, block_id: int, paintable_only: bool = true) -> Dictionary:
	var best: Dictionary = {}
	var best_gap := 0.10
	for face in _faces_by_block.get(block_id, []):
		if paintable_only and not bool(face["paintable"]):
			continue
		var face_normal := _vector(face["n"])
		if face_normal.dot(normal) < 0.90:
			continue
		var relative := point - _vector(face["origin"])
		var gap := absf(relative.dot(face_normal))
		if gap > best_gap:
			continue
		var local_u := relative.dot(_vector(face["u"]))
		var local_v := relative.dot(_vector(face["v"]))
		if local_u < -0.01 or local_v < -0.01 or local_u > float(face["su"]) + 0.01 or local_v > float(face["sv"]) + 0.01:
			continue
		best = face
		best_gap = gap
	return best


func _add_block(def: Dictionary) -> void:
	var block := StaticBody3D.new()
	block.name = "Block_%02d_%s" % [int(def["id"]), String(def["kind"])]
	block.set_meta("source_id", int(def["id"]))
	block.set_meta("paintable", bool(def.get("paint", true)) and not bool(def.get("grate", false)))
	block.set_meta("pattern", int(def.get("pattern", 0)))
	block.set_meta("tag", String(def.get("tag", "")))
	var geometry: Dictionary = def["geometry"]
	var half := _vector(geometry["half"])
	var size := half * 2.0
	var axes: Array = geometry["axes"]
	block.transform = Transform3D(Basis(_vector(axes[0]), _vector(axes[1]), _vector(axes[2])), _vector(geometry["center"]))
	block.collision_layer = 1
	block.collision_mask = 0
	add_child(block)
	if bool(def.get("solid", true)):
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		block.add_child(collision)
	if not bool(def.get("hidden", false)):
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = _material(String(def.get("color", "#dddddd")))
		block.add_child(visual)


func _material(hex: String) -> StandardMaterial3D:
	if not _materials.has(hex):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(hex)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[hex] = material
	return _materials[hex] as StandardMaterial3D


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
