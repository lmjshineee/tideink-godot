extends RefCounted
# Compose the existing compatible cloth vertex layouts into ONE skinned surface.
# No added scene meshes/draw calls and no per-frame assembly. Imported LODs remain
# available; all 64 top/trouser/shoe combinations share a bounded mesh cache.
const Archetypes := preload("res://src/actors/character_archetypes.gd")
static var _sources: Array[ArrayMesh] = []
static var _arrays: Array[Array] = []
static var _pieces: Array[Array] = []
static var _cache: Dictionary = {}

static func group(part: int, bind_y: float) -> int:
	if part in [4,5,15] or (part==16 and bind_y>0.3): return 1
	if part in [6,7,8,9,11,17,19,20] or part==16: return 2
	return 0

static func compatible(a: Array, b: Array) -> bool:
	# Import optimizes vertex order separately for each tailored mesh. Compare
	# the semantic vertices/faces independent of that order, never align by index.
	return _signature(a)==_signature(b)

static func _signature(arrays: Array) -> Array:
	var keys:=PackedInt64Array()
	var vertices: Dictionary={};var faces: Dictionary={}
	var bind: PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0]
	var tags: PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM1]
	for index in arrays[Mesh.ARRAY_VERTEX].size():
		var key:=hash([bind.slice(index*4,index*4+4),tags.slice(index*4,index*4+4),arrays[Mesh.ARRAY_TEX_UV][index],arrays[Mesh.ARRAY_TEX_UV2][index]])
		keys.append(key)
		if roundi(tags[index*4])!=21:vertices[key]=int(vertices.get(key,0))+1
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in range(0,indices.size(),3):
		if roundi(tags[indices[index]*4])==21:continue
		var triangle: Array=[keys[indices[index]],keys[indices[index+1]],keys[indices[index+2]]]
		triangle.sort();var key:=hash(triangle);faces[key]=int(faces.get(key,0))+1
	return [vertices,faces]

static func _prepare() -> bool:
	if _sources.size()==4:return true
	for i in 4:
		var scene: Node=(load(Archetypes.path(i)) as PackedScene).instantiate()
		for node in scene.find_children("*","MeshInstance3D",true,false):
			if node.mesh.surface_get_material(0).resource_name!="Cloth":continue
			var mesh: ArrayMesh=node.mesh
			var arrays: Array=mesh.surface_get_arrays(0)
			if not _arrays.is_empty() and not compatible(_arrays[0],arrays):
				push_error("Incompatible wardrobe semantic layout: "+Archetypes.IDS[i]);scene.free()
				_sources.clear();_arrays.clear();_pieces.clear();return false
			_sources.append(mesh);_arrays.append(arrays)
			var levels: Dictionary={0.0:arrays[Mesh.ARRAY_INDEX]}
			var surface: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),0)
			var width:=2 if mesh.surface_get_array_len(0)<65536 else 4
			for level in surface.get("lods",[]):
				var bytes: PackedByteArray=level.index_data
				var indices:=PackedInt32Array();indices.resize(bytes.size()/width)
				for index in indices.size():indices[index]=bytes.decode_u16(index*width) if width==2 else bytes.decode_u32(index*width)
				levels[float(level.edge_length)]=indices
			var parts: Array=[]
			for garment in 3:parts.append(_extract(arrays,levels,garment))
			_pieces.append(parts)
		scene.free()
	return _sources.size()==4

static func _extract(arrays: Array, levels: Dictionary, garment: int) -> Dictionary:
	var result: Array=arrays.duplicate(true)
	var count: int=arrays[Mesh.ARRAY_VERTEX].size()
	var map:=PackedInt32Array();map.resize(count);map.fill(-1)
	var selected:=PackedInt32Array()
	for index in count:
		if group(roundi(arrays[Mesh.ARRAY_CUSTOM1][index*4]),arrays[Mesh.ARRAY_CUSTOM0][index*4+1])==garment:
			map[index]=selected.size();selected.append(index)
	for channel in Mesh.ARRAY_INDEX:
		if result[channel]==null:continue
		var buffer: Variant=result[channel];buffer.clear()
		var stride: int=arrays[channel].size()/count
		for index in selected:
			for item in stride:buffer.append(arrays[channel][index*stride+item])
		result[channel]=buffer
	var filtered: Dictionary={}
	for edge in levels:
		var source: PackedInt32Array=levels[edge];var indices:=PackedInt32Array()
		for index in range(0,source.size(),3):
			if map[source[index]]<0:continue
			if map[source[index+1]]<0 or map[source[index+2]]<0:
				push_error("Imported wardrobe face crosses garment categories");continue
			indices.append(map[source[index]]);indices.append(map[source[index+1]]);indices.append(map[source[index+2]])
		filtered[edge]=indices
	result[Mesh.ARRAY_INDEX]=filtered[0.0]
	return {"arrays":result,"lods":filtered}

static func combined(top: int, trousers: int, shoes: int) -> ArrayMesh:
	if not _prepare():return null
	var choices: Array[int]=[posmod(top,4),posmod(trousers,4),posmod(shoes,4)]
	var key:=str(choices)
	if _cache.has(key):return _cache[key]
	var result: Array=_arrays[0].duplicate(true)
	for channel in Mesh.ARRAY_MAX:
		if result[channel]!=null:
			var empty: Variant=result[channel];empty.clear();result[channel]=empty
	var offsets: Array[int]=[];var vertex_offset:=0
	for garment in 3:
		offsets.append(vertex_offset)
		var arrays: Array=_pieces[choices[garment]][garment].arrays
		for channel in Mesh.ARRAY_INDEX:
			if result[channel]!=null:
				var buffer: Variant=result[channel];buffer.append_array(arrays[channel]);result[channel]=buffer
		for index in arrays[Mesh.ARRAY_INDEX]:result[Mesh.ARRAY_INDEX].append(index+vertex_offset)
		vertex_offset+=arrays[Mesh.ARRAY_VERTEX].size()
	var levels: Dictionary={}
	for threshold in [0.008,0.016,0.032,0.064,0.128]:
		var merged:=PackedInt32Array()
		for garment in 3:
			var piece: Dictionary=_pieces[choices[garment]][garment]
			var indices: PackedInt32Array=piece.arrays[Mesh.ARRAY_INDEX]
			var selected_edge:=0.0
			for edge in piece.lods:
				if edge<=threshold and edge>selected_edge:indices=piece.lods[edge];selected_edge=edge
			for index in indices:merged.append(index+offsets[garment])
		if merged.size()<result[Mesh.ARRAY_INDEX].size():levels[threshold]=merged
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result,[],levels,_sources[0].surface_get_format(0))
	mesh.surface_set_material(0,_sources[0].surface_get_material(0))
	mesh.set_meta("garment_sources",choices);mesh.set_meta("lod_levels",levels.size())
	_cache[key]=mesh
	return mesh
