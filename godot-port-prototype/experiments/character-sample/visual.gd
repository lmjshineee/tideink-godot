extends "res://src/actors/tidewater_character_visual.gd"

# Independent art experiment. The game continues to instantiate the base visual.
# Reuses the existing animation adapter; the production controller is unchanged.
const SAMPLE_SKIN := preload("res://experiments/character-sample/skin.gdshader")
const SAMPLE_EYES := preload("res://experiments/character-sample/eyes.gdshader")
const SAMPLE_HAIR := preload("res://experiments/character-sample/hair.gdshader")
var _sample_materials: Dictionary = {}

func _install_original() -> void:
	var path := "res://experiments/character-sample/wave.glb"
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	_hide_primitive_meshes(kid)
	_hide_primitive_meshes(squid)
	original_rig = packed.instantiate()
	original_rig.name = "OriginalRig"
	kid.add_child(original_rig)
	skeleton = _find_skeleton(original_rig)
	_load_weapon_poses()
	_kid_rig = original_rig.find_child("KidRig",true,false) as Node3D
	if _action_data.is_empty():
		_action_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/actions.json"))
	for bone_name in _action_data["bones"]:
		_action_bones.append(skeleton.find_bone(bone_name))
	for values in _action_data["rest"]:
		_action_rest.append(_sample_values(values))
	for bone_name in _action_data["gaitBones"]:
		_gait_bones.append(skeleton.find_bone(bone_name))
	for weapon in _action_data["gaits"]:
		var clips := {}
		for mode in _action_data["gaits"][weapon]:
			var frames := []
			for frame in _action_data["gaits"][weapon][mode]["frames"]:
				var poses: Array[Transform3D] = []
				for values in frame["bones"]:poses.append(_sample_values(values))
				frames.append({"bones":poses,"kid":_sample_values(frame["kid"])})
			clips[mode] = frames
		_gaits[weapon] = clips
	for bone_name in _action_data["faceBones"]:
		var bone := skeleton.find_bone(bone_name)
		_face_bones.append(bone)
		_face_poses.append(skeleton.get_bone_rest(bone))
	_blink_remaining += style_index*0.7+team*0.35+fmod(float(get_instance_id()),7.0)*0.12
	var squid_root := original_rig.find_child("SquidRig", true, false) as Node3D
	if squid_root != null:
		squid_root.reparent(squid)
		squid_root.position.y = 0.2
	_materialize_original(original_rig)
	_materialize_original(squid)
	for id in weapon_models:
		var model := original_rig.find_child("Weapon_" + id, true, false) as Node3D
		if model != null:
			original_weapons[id] = model

	for id in Equipment.EXTRA:
		var source:Node3D=original_weapons[Equipment.base(id)]
		var copy:Node3D=source.duplicate();copy.name="Weapon_"+id;source.get_parent().add_child(copy)
		copy.scale*=Vector3(1,1,1.35) if id=="heavy" else (Vector3.ONE*.82 if id=="rapid" else Vector3.ONE*.8)
		original_weapons[id]=copy
		if id=="dualie":
			var left:=BoneAttachment3D.new();left.bone_name="handL";skeleton.add_child(left)
			var twin:Node3D=source.duplicate();left.add_child(twin);twin.scale*=.8
			original_weapons["dualie_left"]=twin


func _materialize_original(node: Node) -> void:
	super._materialize_original(node)
	if not node is MeshInstance3D or node.get_parent() == kid:
		return
	var mesh_node := node as MeshInstance3D
	var material := mesh_node.material_override as ShaderMaterial
	if material == null:
		return
	var imported := mesh_node.mesh.surface_get_material(0)
	var semantic := imported.resource_name if imported != null else "Equipment"
	if semantic == "Skin":
		face_material.shader = SAMPLE_SKIN
	elif semantic == "Eyes":
		eye_material.shader = SAMPLE_EYES
		eye_material.set_shader_parameter("iris_color", Color("37cbb4"))
		eye_material.set_shader_parameter("iris_dark", Color("114652"))
	else:
		# Never recolor the production material cache used by the left comparison.
		if not _sample_materials.has(semantic):
			var copy := material.duplicate() as ShaderMaterial
			if semantic == "TeamHair":
				copy.shader = SAMPLE_HAIR
			if semantic == "Cloth":
				copy.set_shader_parameter("shirt_color",Color("263249"))
				copy.set_shader_parameter("shorts_color",Color("53617b"))
				copy.set_shader_parameter("shoe_color",Color("efeee7"))
				copy.set_shader_parameter("sole_color",Color("c6c9cc"))
				copy.set_shader_parameter("sock_color",Color("f0e9d7"))
				copy.set_shader_parameter("pattern",1)
			_sample_materials[semantic] = copy
		mesh_node.material_override = _sample_materials[semantic]
