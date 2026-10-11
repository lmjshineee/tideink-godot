extends SceneTree
var output := ""
var stage: Node3D
var camera: Camera3D
var models: Array[Node3D] = []
var report := {"kind":"controlled native character art review", "human_aesthetic_acceptance":false,"images":[]}
const Visual := preload("res://src/actors/tidewater_character_visual.gd")

func _initialize() -> void: call_deferred("_run")
func frames(count: int = 3) -> void:
	for i in count: await process_frame
func animate(count: int) -> void:
	for i in count:
		for model in models:model._animate(1.0/30)
func snap(name_text: String) -> void:
	await frames();await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(name_text+".png"))!=OK:quit(1);return
	report.images.append(name_text)
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native display/new absolute output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	report.environment={"engine":Engine.get_version_info().string,"arm64":OS.has_feature("arm64"),"api":RenderingServer.get_video_adapter_api_version(),"adapter":RenderingServer.get_video_adapter_name()}
	report.source_sha256={}
	for path in preload("res://tools/lib/source_inventory.gd").scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
	for style in 4:report.source_sha256[Visual.Archetypes.path(style)]=FileAccess.get_sha256(Visual.Archetypes.path(style))
	for path in ["res://shaders/characters/character_skin.gdshader","res://shaders/characters/character_eyes.gdshader","res://shaders/characters/character_hair.gdshader","res://assets/characters/actions.json","res://tools/capture/capture_archetypes.gd"]:
		report.source_sha256[path]=FileAccess.get_sha256(path)
	root.size=Vector2i(1440,900);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	stage=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("182633");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("e3e7ed");env.environment.ambient_light_energy=.55;stage.add_child(env)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-30,-28,0);key.light_energy=1.0;stage.add_child(key)
	var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-20,150,0);rim.light_color=Color("9ec7df");rim.light_energy=.55;stage.add_child(rim)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.85;camera.current=true
	stage.add_child(camera);camera.position=Vector3(0,.9,5);camera.look_at(Vector3(0,.72,0))
	for i in 4:
		var model:=Visual.new();model.style_index=i;model.team=0;model.portrait_detail=true;model.ornament_seed=401+i;model.position.x=(i-1.5)*.77
		stage.add_child(model);model.set_physics_process(false);model.set_weapon("shooter");model._blink_remaining=999;model._blink_elapsed=1;models.append(model)
	animate(30);await snap("lineup-front")
	for model in models:model.rotation.y=-.55
	await snap("lineup-three-quarter")
	for model in models:model.rotation.y=PI
	await snap("lineup-back")
	for model in models:model.rotation.y=-.28;model.anim_speed=5;model.moving=true
	animate(9);await snap("lineup-run")
	for model in models:model.anim_speed=0;model.moving=false;model.visible=false
	animate(30)
	for i in 4:
		var subject:=models[i];subject.visible=true;subject.position.x=0;subject.rotation.y=-.3
		camera.size=.65;camera.position=Vector3(0,1.16,5);camera.look_at(Vector3(0,1.16,0))
		await snap("face-%d"%i)
		camera.size=1.8;camera.position=Vector3(0,.9,5);camera.look_at(Vector3(0,.72,0))
		for weapon in ["shooter","roller","charger","blaster","dualie","disc","bow","canopy"]:
			subject.set_weapon(weapon);subject.set_aim(true);animate(30);await snap("hold-%d-%s"%[i,weapon])
		var file:=FileAccess.open(output.path_join("character-%d.json"%i),FileAccess.WRITE)
		file.store_string(JSON.stringify({"archetype":subject.get_meta("archetype"),"model_path":Visual.Archetypes.path(i),"bones":subject.skeleton.get_bone_count(),"root_scale":subject.original_rig.scale},"\t"));file.close()
		subject.visible=false
	# Independent garment cuts on the SAME body, repeated with the other team
	# theme. Seed is the same across both; only the team theme changes.
	for model in models:model.queue_free()
	models.clear();await frames(3)
	for team in 2:
		for i in 4:
			var selected_seed:=0
			for candidate in 20000:
				var look:=Visual.Wardrobe.look(candidate)
				if look.top==i and look.trousers==(3-i) and look.shoes==(i+2)%4:selected_seed=candidate;break
			var model:=Visual.new();model.style_index=0;model.team=team;model.portrait_detail=true;model.ornament_seed=selected_seed
			model.position.x=(i-1.5)*.77;stage.add_child(model);model.set_physics_process(false);model.set_weapon("shooter");model._blink_remaining=999;model._blink_elapsed=1;models.append(model)
		camera.size=1.85;camera.position=Vector3(0,.9,5);camera.look_at(Vector3(0,.72,0));animate(30)
		await snap("wardrobe-team-%d-front"%team)
		for model in models:model.rotation.y=PI
		await snap("wardrobe-team-%d-back"%team)
		for model in models:model.rotation.y=-.28;model.anim_speed=5;model.moving=true
		animate(9);await snap("wardrobe-team-%d-run"%team)
		for model in models:model.queue_free()
		models.clear();await frames(3)
	report.status="passed";var file:=FileAccess.open(output.path_join("characters.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	stage.queue_free();await frames(3)
	print("PASS: four distinct production silhouettes, front/three-quarter/back/run, face closeups and eight held weapons each; visual review still required")
	quit()
