extends SceneTree
var stage: Node3D
var models: Array[Node3D] = []
var camera: Camera3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: native display required"); quit(1); return
	root.size = Vector2i(1280,720)
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202735")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cad8ec")
	env.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30,-28,0)
	key.light_energy = 1.0
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20,150,0)
	rim.light_color = Color("7dbeec")
	rim.light_energy = 0.5
	stage.add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.8
	camera.position = Vector3(0,1.15,5)
	stage.add_child(camera)
	camera.look_at(Vector3(0,0.7,0))
	camera.current = true
	for i in range(4):
		var model := preload("res://src/actors/tidewater_character_visual.gd").new()
		model.style_index = i
		model.team = i%2
		model.position.x = (i-1.5)*0.72
		stage.add_child(model)
		model.set_physics_process(false)
		model.set_weapon(["shooter","roller","charger","blaster"][i])
		models.append(model)
	for i in 30:
		for model in models:model.call("_animate",1.0/30.0)
	await frames(8)
	await save("appearance-lineup")
	for i in range(4):
		models[i].rotation.y = -0.38
	await frames(3)
	await save("appearance-three-quarter")
	for model in models:
		model.anim_speed = 5.0
		model.moving = true
	for i in 10:
		for model in models:model.call("_animate",1.0/30.0)
	await frames(2)
	await save("appearance-running")
	for model in models:
		model.anim_speed = 0.0
		model.moving = false
	for i in 30:
		for model in models:model.call("_animate",1.0/30.0)
	for model in models:
		model.visible = false
	var subject := models[0]
	subject.visible = true
	subject.position.x = 0
	subject.rotation.y = 0
	camera.position = Vector3(0,0.84,5)
	camera.look_at(Vector3(0,0.84,0))
	camera.size = 0.72
	for angle in [0.0,-PI/2.0,PI]:
		subject.rotation.y = angle
		await frames(2)
		await save("appearance-body-"+str(angle))
	subject.rotation.y = -0.38
	subject.set_aim(true)
	for pitch in [-0.65,0.65]:
		subject.aim_pitch = pitch
		for i in 25:subject.call("_animate",1.0/30.0)
		await frames(2)
		await save("appearance-body-aim-"+str(pitch))
	subject.aim_pitch = 0.0
	subject.set_aim(false)
	for i in 30:subject.call("_animate",1.0/30.0)
	subject.rotation.y = 0
	camera.position = Vector3(0,1.22,5)
	camera.look_at(Vector3(0,1.22,0))
	camera.size = 0.65
	for expression in ["idle","focus","low","tired"]:
		subject.set_aim(expression=="focus")
		subject.set_expression_state(0.05 if expression=="low" else 1.0,0.15 if expression=="tired" else 1.0,0.0,false)
		subject.set("_blink_remaining",10.0)
		for i in range(20):
			subject.call("_animate",1.0/30.0)
		await frames(2)
		await save("appearance-face-"+expression)
	stage.queue_free()
	await frames(2)
	for id in ["tidewater","kelpline"]:
		preload("res://src/core/match_setup.gd").map_id = id
		var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
		game.set("settings_path","/private/tmp/inkwave-appearance.cfg")
		root.add_child(game)
		current_scene = game
		game.set_physics_process(false)
		game.call("_begin_intro")
		for time in [0.0,1.8,3.6,4.19]:
			game.set("phase_time",time)
			game.call("_update_hud")
			await frames(2)
			await save("appearance-intro-"+id+"-"+str(time))
		game.call("_start_round")
		await frames(2)
		if root.get_camera_3d() != game.get_node("World/Walker/Camera3D"):
			printerr("FAIL: intro did not return camera");quit(1);return
		game.queue_free()
		await frames(2)
	DirAccess.remove_absolute("/private/tmp/inkwave-appearance.cfg")
	print("PASS: four material variants, front/three-quarter/run, shoulder/crotch front/side/back and aimed poses, four close-up expressions and both source intro paths captured; gameplay camera restored")
	quit()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var capture_label := label.replace("appearance-","feedback8-") if OS.get_cmdline_user_args().has("--feedback8") else label.replace("appearance-","restored-") if OS.get_cmdline_user_args().has("--restored") else label.replace("appearance-","original-") if OS.get_cmdline_user_args().has("--original") else label
	if root.get_texture().get_image().save_png("res://render-evidence/"+capture_label+".png") != OK:
		printerr("FAIL: screenshot "+label);quit(1)
