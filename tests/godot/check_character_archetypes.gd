extends SceneTree
const Visual := preload("res://src/actors/tidewater_character_visual.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children():result.append_array(meshes(child))
	return result
func expect(value: bool, text: String) -> void:
	if not value:failures.append(text)
func skinned_point(part: MeshInstance3D, skeleton: Skeleton3D, vertex: int) -> Vector3:
	var arrays:=part.mesh.surface_get_arrays(0)
	var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var joints:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var point:=Vector3.ZERO
	for slot in 4:
		var bind:int=joints[vertex*4+slot];var w:float=weights[vertex*4+slot]
		if w<=0:continue
		var bone:int=part.skin.get_bind_bone(bind)
		if bone<0:bone=skeleton.find_bone(part.skin.get_bind_name(bind))
		point+=(skeleton.get_bone_global_pose(bone)*part.skin.get_bind_pose(bind)*points[vertex])*w
	return point
func _run() -> void:
	var geometry := []
	for i in 4:
		var visual:=Visual.new();visual.style_index=i;visual.ornament_seed=913;root.add_child(visual);visual.set_physics_process(false)
		expect(visual.skeleton.get_bone_count()==87,"animation rig retained")
		expect(visual.get_meta("archetype")==Visual.Archetypes.IDS[i],"selected archetype actually loaded")
		for name_text in ["Streetwear","RunnerVisor","EarDefenders","HighTop","CoatTailL","CoatTailR","SafetyBootL","SafetyBootR"]:
			expect(visual.skeleton.get_node_or_null(name_text)==null,"rejected clothing/headgear blocks must not return")
		var signature:=[]
		for part in meshes(visual.original_rig):
			if part.get_meta("procedural_equipment",false):
				# Authored weapon meshes also carry this flag; clothing is skinned GLB.
				continue
			var semantic:String=part.mesh.surface_get_material(0).resource_name
			if semantic in ["Skin","Cloth","TeamHair","Eyes"]:
				var arrays:=part.mesh.surface_get_arrays(0)
				signature.append(hash(arrays[Mesh.ARRAY_VERTEX]));expect(not (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty(),"real skinned geometry exists")
				expect(arrays[Mesh.ARRAY_BONES].size()>0 and arrays[Mesh.ARRAY_WEIGHTS].size()>0,"skinning retained on new geometry")
		geometry.append(signature)
		visual.set_weapon("shooter");visual._blink_remaining=999;visual._blink_elapsed=1
		for frame in 40:visual._animate(1.0/30)
		for part in meshes(visual.original_rig):
			if part.skin==null or part.mesh.surface_get_material(0).resource_name!="Eyes":continue
			var arrays:=part.mesh.surface_get_arrays(0)
			var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var neutral:=[];var centers:=[]
			for vertex in uvs.size():
				if uvs[vertex].length()<.000001:centers.append(vertex);neutral.append(skinned_point(part,visual.skeleton,vertex))
			expect(centers.size()==2,"two eye centers survive native GLB import")
			visual._blink_elapsed=.075;visual._apply_face(0.)
			for center in centers.size():
				expect(skinned_point(part,visual.skeleton,centers[center]).distance_to(neutral[center])<.0001,"blink stays centered in sculpted eye socket")
			visual._blink_elapsed=1;visual._apply_face(0.)
		for weapon in ["shooter","roller","charger","blaster","dualie","disc","bow","canopy"]:
			visual.set_weapon(weapon);visual.set_aim(true);visual.set_action("shoot");visual.set_expression_state(.1,.2,.6,false)
			for frame in 24:visual._animate(1.0/30)
			expect(visual.original_weapons[weapon].is_visible_in_tree(),"new silhouette holds actual weapon "+weapon)
			for bone in visual.skeleton.get_bone_count():expect(visual.skeleton.get_bone_global_pose(bone).is_finite(),"animation remains finite")
		visual.set_form(true);expect(not visual.kid.visible and visual.squid.visible,"alternate form hides all clothes")
		visual.set_form(false);expect(visual.kid.visible,"human form restores archetype")
		visual.queue_free();await process_frame
	for i in 4:
		for j in range(i+1,4):
			expect(geometry[i]!=geometry[j],"archetypes have distinct body/face/hair/cloth vertex data")
	if failures.is_empty():print("PASS: four production archetypes use authored body/face/hair/clothes without block accessories; preserved 87-bone skinning, eight weapon poses and alternate form")
	else:printerr("FAIL: "+str(failures))
	quit(0 if failures.is_empty() else 1)
