extends Node3D

const MODEL := preload("res://experiments/character-redesign/wave.glb")
const EYES := preload("res://experiments/character-redesign/eyes.gdshader")
const SKIN := preload("res://experiments/character-redesign/skin.gdshader")
var skeleton: Skeleton3D
var player: AnimationPlayer
var hair: StandardMaterial3D
var accent: StandardMaterial3D
var meshes: Array[MeshInstance3D] = []
var mode := "idle"
var team := 0

func _ready() -> void:
	var imported := MODEL.instantiate()
	add_child(imported)
	_collect(imported)
	assert(skeleton != null and player != null,"Wave rig/animations missing")
	for key in player.get_animation_list():
		if key != "RESET":
			player.get_animation(key).loop_mode = Animation.LOOP_LINEAR
	set_team(team)
	set_mode(mode)

func _collect(node: Node) -> void:
	if node is Skeleton3D: skeleton = node
	if node is AnimationPlayer: player = node
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.lod_bias = 8.0
		meshes.append(mesh_node)
		for surface in mesh_node.mesh.get_surface_count():
			var source: Material = mesh_node.mesh.surface_get_material(surface)
			if source == null: continue
			var semantic: String = source.resource_name
			if semantic == "WaveEyes":
				var eyes := ShaderMaterial.new()
				eyes.shader = EYES
				node.set_surface_override_material(surface,eyes)
			elif semantic == "WaveSkin":
				var skin := ShaderMaterial.new()
				skin.shader = SKIN
				skin.set_shader_parameter("skin_color",Color("ffd9c2"))
				node.set_surface_override_material(surface,skin)
			else:
				var material: StandardMaterial3D = source.duplicate()
				material.cull_mode = BaseMaterial3D.CULL_DISABLED if semantic in ["WaveJacket","WaveAccent","WaveTeeth"] else BaseMaterial3D.CULL_BACK
				material.metallic_specular = .28 if semantic == "WaveSkin" else .42
				if semantic == "WaveSkin": material.roughness = .76
				if semantic == "WaveTeamHair":
					material.roughness = .37
					hair = material
				if semantic == "WaveAccent": accent = material
				node.set_surface_override_material(surface,material)
	for child in node.get_children(): _collect(child)

func set_team(value: int) -> void:
	team = value
	if hair != null: hair.albedo_color = Color("ff741b") if team == 0 else Color("268dee")
	if accent != null: accent.albedo_color = Color("f89532") if team == 0 else Color("6bc9ff")

func set_mode(value: String) -> void:
	mode = value
	if player != null:
		player.play(mode,.15)

func pose_at(value: String,time: float) -> void:
	mode = value
	player.play(value)
	player.seek(time,true)
	player.pause()
