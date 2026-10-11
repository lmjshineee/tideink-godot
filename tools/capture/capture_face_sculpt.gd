extends SceneTree
## Identical pose/light/camera comparison of production faces, plus clay anatomy.
const Visual := preload("res://src/actors/tidewater_character_visual.gd")
var output := ""
var baseline := ""
var stage: Node3D
var camera: Camera3D
var subject: Node3D
var images: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func frames(count: int = 4) -> void:
	for i in count: await process_frame
func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:result.append(node)
	for child in node.get_children():result.append_array(meshes(child))
	return result
func animate(count: int = 35) -> void:
	for i in count:subject._animate(1.0/30)
func snap(file_name: String) -> Image:
	await frames();await RenderingServer.frame_post_draw
	var im := root.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	if im.save_png(output.path_join(file_name+".png"))!=OK:quit(1)
	images.append(file_name)
	return im
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--baseline="):baseline=arg.trim_prefix("--baseline=")
	if DisplayServer.get_name()=="headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native/new output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var source_sha256:={}
	for path in preload("res://tools/lib/source_inventory.gd").scripts():source_sha256[path]=FileAccess.get_sha256(path)
	for path in ["res://shaders/characters/character_skin.gdshader","res://shaders/characters/character_eyes.gdshader","res://shaders/characters/character_hair.gdshader","res://assets/characters/actions.json"]:
		source_sha256[path]=FileAccess.get_sha256(path)
	for style in 4:source_sha256[Visual.Archetypes.path(style)]=FileAccess.get_sha256(Visual.Archetypes.path(style))
	source_sha256["res://tools/capture/capture_face_sculpt.gd"]=FileAccess.get_sha256("res://tools/capture/capture_face_sculpt.gd")
	root.size=Vector2i(760,760);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	stage=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("233340");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("e3e7ed");env.environment.ambient_light_energy=.38;stage.add_child(env)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-28,-35,0);key.light_energy=.85;stage.add_child(key)
	var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-20,145,0);rim.light_energy=.35;rim.light_color=Color("9ec7df");stage.add_child(rim)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;camera.size=.55
	stage.add_child(camera)
	var comparison:=Image.create(760*4,760*2,false,Image.FORMAT_RGBA8)
	for version in ["before","after","clay"]:
		var sheet:=Image.create(760*3,760*4,false,Image.FORMAT_RGBA8)
		for style in 4:
			subject=Visual.new();subject.style_index=style;subject.team=0;subject.portrait_detail=true;subject.ornament_seed=401+style
			stage.add_child(subject);subject.set_physics_process(false);subject.set_weapon("shooter");subject._blink_remaining=999;subject._blink_elapsed=1
			if version=="before":
				var gltf:=GLTFDocument.new();var state:=GLTFState.new()
				var file_name:String=Visual.Archetypes.IDS[style]+".glb"
				if gltf.append_from_file(baseline.path_join(file_name),state)!=OK:printerr("FAIL: baseline");quit(1);return
				var old:=gltf.generate_scene(state);var sources:={}
				for m in meshes(old):
					var material:=m.mesh.surface_get_material(0)
					if material!=null and m.skin!=null:sources[material.resource_name]=m
				var old_skeleton:=old.find_child("Skeleton3D",true,false) as Skeleton3D
				for m in meshes(subject.original_rig):
					var material:=m.mesh.surface_get_material(0)
					if material!=null and material.resource_name in ["Skin","Eyes","TeamHair"]:
						var current_skin:Skin=m.skin
						var source:MeshInstance3D=sources[material.resource_name];m.mesh=source.mesh
						m.skin=source.skin.duplicate()
						for bind in m.skin.get_bind_count():
							var bone:int=source.skin.get_bind_bone(bind)
							var bone_name:String=old_skeleton.get_bone_name(bone) if bone>=0 else source.skin.get_bind_name(bind)
							m.skin.set_bind_bone(bind,subject.skeleton.find_bone(bone_name))
							# Neutral baseline geometry uses today's rest skeleton.
							for current_bind in current_skin.get_bind_count():
								var current_name:String=current_skin.get_bind_name(current_bind)
								if current_name==bone_name or current_skin.get_bind_bone(current_bind)==subject.skeleton.find_bone(bone_name):
									m.skin.set_bind_pose(bind,current_skin.get_bind_pose(current_bind));break
				old.free()
			if version=="clay":
				var mat:=StandardMaterial3D.new();mat.albedo_color=Color("b9c0c5");mat.roughness=.85;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
				for m in meshes(subject.original_rig):
					var material:=m.mesh.surface_get_material(0)
					if material==null:continue
					if material.resource_name in ["Skin","TeamHair","Eyes"]:m.material_override=mat
			animate()
			# Scale differs between archetypes; same local framing for old/new.
			var s:float=Visual.Archetypes.SCALE[style]
			camera.size=.55*s;camera.position=Vector3(0,1.20*s,4);camera.look_at(Vector3(0,1.20*s,0))
			for view in 3:
				subject.rotation.y=[0.,-.65,-PI/2][view]
				var im:=await snap("%s-%d-%s"%[version,style,["front","quarter","profile"][view]])
				sheet.blit_rect(im,Rect2i(0,0,760,760),Vector2i(view*760,style*760))
				if version in ["before","after"] and view==0:
					comparison.blit_rect(im,Rect2i(0,0,760,760),Vector2i(style*760,0 if version=="before" else 760))
			if version=="after":
				subject.rotation.y=PI;await snap("hair-%d-back"%style)
				subject.rotation.y=-.35;camera.position=Vector3(0,2.2*s,1.2);camera.look_at(Vector3(0,1.20*s,0));await snap("hair-%d-crown"%style)
				camera.position=Vector3(0,1.20*s,4);camera.look_at(Vector3(0,1.20*s,0))
				subject.rotation.y=-.4
				for expression in ["focus","charge","tired","blink"]:
					subject.aiming=expression=="focus";subject.face_charge=1. if expression=="charge" else 0.;subject.face_health=.2 if expression=="tired" else 1.
					animate()
					if expression=="blink":subject._blink_elapsed=.075;subject._apply_face(0.)
					await snap("expression-%d-%s"%[style,expression])
			subject.queue_free();await frames()
		sheet.save_png(output.path_join(version+"-sheet.png"))
	comparison.resize(1520,760,Image.INTERPOLATE_LANCZOS);comparison.save_png(output.path_join("comparison-front.png"))
	var file:=FileAccess.open(output.path_join("faces.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"passed","images":images,"source_sha256":source_sha256,"baseline_directory":baseline,"comparison":"same camera, current lighting/materials, neutral pose; top row baseline geometry, bottom row new geometry","human_aesthetic_acceptance":false,"engine":Engine.get_version_info().string,"arm64":OS.has_feature("arm64"),"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version()},"\t"));file.close()
	print("PASS: matched before/after and clay front/quarter/profile; expressions/blink captured")
	quit()
