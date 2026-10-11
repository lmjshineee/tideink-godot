extends Node3D

# Structural map slice: visible blocks, collision shapes and source spawn pads.
# Paintable faces, movement on ramps, and wall ink are separate migration steps.
const MatchSetup := preload("res://src/core/match_setup.gd")
var MAP_FILE := "res://assets/maps/tidewater.json"
var SURFACES_FILE := "res://assets/maps/tidewater_surfaces.json"
const SURFACE_SHADER = preload("res://shaders/world/tidewater_surface.gdshader")

var map_bounds := Rect2()
var block_count := 0
var spawn_pads: Array[Vector3] = []
var surfaces: Array[Dictionary] = []
var paintable_count := 0
var turf_count := 0
var _materials: Dictionary = {}
var _faces_by_block: Dictionary = {}


func _ready() -> void:
	MAP_FILE = "res://assets/maps/%s.json" % preload("res://src/core/map_catalog.gd").asset_id()
	SURFACES_FILE = "res://assets/maps/%s_surfaces.json" % preload("res://src/core/map_catalog.gd").asset_id()
	var content := FileAccess.get_file_as_string(MAP_FILE)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary or parsed.get("schema") != 1 or parsed.get("id") != preload("res://src/core/map_catalog.gd").asset_id():
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
		if face.has("polygon") and not _in_polygon(Vector2(local_u, local_v), face.polygon):
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
	if def["kind"] == "convex":
		_add_convex(block, def)
		return
	var half := _vector(geometry["half"])
	var size := half * 2.0
	var axes: Array = geometry["axes"]
	block.transform = Transform3D(Basis(_vector(axes[0]), _vector(axes[1]), _vector(axes[2])), _vector(geometry["center"]))
	block.collision_layer = 8 if bool(def.get("grate",false)) else 1
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
		visual.material_override = _material(String(def.get("color", "#dddddd")), int(def.get("pattern", 0)), size)
		block.add_child(visual)


func _add_convex(block: StaticBody3D, def: Dictionary) -> void:
	var geometry: Dictionary = def["geometry"]
	var points := PackedVector3Array()
	for value in geometry.vertices:
		points.append(_vector(value))
	block.collision_layer = 1
	block.collision_mask = 0
	add_child(block)
	var collision := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	collision.shape = hull
	block.add_child(collision)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for polygon in geometry.polygons:
		var a := points[int(polygon[0])]
		var normal := (points[int(polygon[1])] - a).cross(points[int(polygon[2])] - a).normalized()
		for i in range(1, polygon.size() - 1):
			# Source polygons use outward cross products; Godot fronts are clockwise.
			for index in [polygon[0], polygon[i + 1], polygon[i]]:
				vertices.append(points[int(index)])
				normals.append(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(String(def.color), int(def.pattern), _vector(def.max) - _vector(def.min))
	block.add_child(visual)


static func _in_polygon(point: Vector2, polygon: Array) -> bool:
	var positive := false
	var negative := false
	for i in polygon.size():
		var a := Vector2(float(polygon[i][0]), float(polygon[i][1]))
		var next: Array = polygon[(i + 1) % polygon.size()]
		var edge := Vector2(float(next[0]), float(next[1])) - a
		var side := edge.cross(point - a)
		positive = positive or side > 0.01
		negative = negative or side < -0.01
	return not (positive and negative)


func _material(hex: String, pattern: int, size: Vector3) -> ShaderMaterial:
	var key := "%s:%d:%s" % [hex, pattern, size]
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = SURFACE_SHADER
		material.set_shader_parameter("base_color", Color(hex))
		material.set_shader_parameter("pattern", pattern)
		material.set_shader_parameter("block_size", size)
		_materials[key] = material
	return _materials[key] as ShaderMaterial


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
