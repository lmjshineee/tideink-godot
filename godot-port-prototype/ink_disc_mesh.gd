extends RefCounted

# Four swept blades and an open hub; shared by the held weapon and flying discs.
static func make(team: int, radius: float = 0.5) -> Node3D:
	var root := Node3D.new()
	var color: Color = preload("res://team_palette.gd").color(team)
	var ink := StandardMaterial3D.new()
	ink.albedo_color = color
	ink.metallic = 0.4
	ink.roughness = 0.25
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("e8f3f5")
	edge.metallic = 0.65
	edge.roughness = 0.22
	var hub := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.13
	ring.outer_radius = radius * 0.26
	ring.rings = 12
	ring.ring_segments = 24
	hub.set_meta("procedural_equipment", true)
	hub.mesh = ring
	hub.material_override = edge
	root.add_child(hub)
	for blade in range(4):
		var part := MeshInstance3D.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points := [Vector2(0.14, -0.12), Vector2(0.79, -0.34), Vector2(1.0, 0.05), Vector2(0.3, 0.22)]
		var thickness := radius * 0.065
		for side in [-1.0, 1.0]:
			for triangle in [[0, 1, 2], [0, 2, 3]]:
				var order: Array = triangle if side < 0 else [triangle[2], triangle[1], triangle[0]]
				for i in order:
					st.add_vertex(Vector3(points[i].x * radius, thickness * side, points[i].y * radius))
		for i in range(4):
			var a: Vector2 = points[i] * radius
			var b: Vector2 = points[(i + 1) % 4] * radius
			for p in [Vector3(a.x, thickness, a.y), Vector3(a.x, -thickness, a.y), Vector3(b.x, -thickness, b.y), Vector3(a.x, thickness, a.y), Vector3(b.x, -thickness, b.y), Vector3(b.x, thickness, b.y)]:
				st.add_vertex(p)
		st.generate_normals()
		part.set_meta("procedural_equipment", true)
		part.mesh = st.commit()
		part.material_override = ink
		part.rotation.y = blade * PI * 0.5
		root.add_child(part)
	return root
