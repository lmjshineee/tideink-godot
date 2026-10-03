extends Node3D

const MODEL := preload("res://character-sculpt/sculpt-head.glb")
const SKIN := preload("res://character-sculpt/skin.gdshader")
const EYES := preload("res://character-sculpt/eyes.gdshader")
const HAIR := preload("res://character-sculpt/hair.gdshader")
var skeleton: Skeleton3D
var player: AnimationPlayer
var hair: ShaderMaterial
var skin: ShaderMaterial
var meshes: Array[MeshInstance3D] = []
var team := 0

func _ready() -> void:
	var imported := MODEL.instantiate()
	add_child(imported)
	_collect(imported)
	assert(skeleton != null and player != null)
	player.get_animation("idle").loop_mode=Animation.LOOP_LINEAR
	set_team(team)
	player.play("idle")

func _collect(node: Node) -> void:
	if node is Skeleton3D: skeleton=node
	if node is AnimationPlayer: player=node
	if node is MeshInstance3D:
		var item:=node as MeshInstance3D
		item.lod_bias=8.0
		meshes.append(item)
		for surface in item.mesh.get_surface_count():
			var original: Material=item.mesh.surface_get_material(surface)
			var semantic: String=original.resource_name
			var shader: Shader=SKIN if semantic=="SculptSkin" else EYES if semantic=="SculptEyes" else HAIR if semantic=="SculptHair" else null
			if shader != null:
				var material:=ShaderMaterial.new()
				material.shader=shader
				if semantic=="SculptSkin":
					material.set_shader_parameter("skin_color",Color("ffd5b8"))
					skin=material
				if semantic=="SculptHair": hair=material
				item.set_surface_override_material(surface,material)
			else:
				var standard:=original.duplicate() as StandardMaterial3D
				standard.metallic_specular=.28
				standard.cull_mode=BaseMaterial3D.CULL_DISABLED
				item.set_surface_override_material(surface,standard)
	for child in node.get_children(): _collect(child)

func set_team(value: int) -> void:
	team=value
	if hair != null: hair.set_shader_parameter("team_color",Color("ff681d") if team==0 else Color("2587ee"))

func pose_at(_value: String,time: float) -> void:
	player.play("idle")
	player.seek(time,true)
	player.pause()

func set_clay(value: bool) -> void:
	skin.set_shader_parameter("clay",value)
	hair.set_shader_parameter("clay",value)
