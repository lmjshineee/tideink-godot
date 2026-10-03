extends "res://tools/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func snap(label: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://render-evidence/creative18-" + label + ".png")

func _run() -> void:
	if DisplayServer.get_name() == "headless": printerr("FAIL: native Metal required"); quit(1); return
	root.size = Vector2i(1440,900)
	await prepare(5,"prism_gallery")
	game.phase = "setup"; game.frontend._select_item("sonar")
	game._choose_player_weapon("bow"); game._update_hud()
	var preview: Control = game.frontend.preview
	preview.set_pose("shoot"); preview.yaw = 1.2; preview.pitch = .08; preview.distance = 2.7; preview._update_camera()
	await create_timer(.4).timeout
	await snap("bow-held")
	preview.set_process(false); preview.model.set_physics_process(false)
	preview.model.set_weapon_charge(1)
	await snap("bow-drawn")
	game.frontend._begin_hover("item","sonar"); await snap("sonar-loadout")
	game.frontend._end_hover(); game.phase = "playing"; game._update_hud()
	game.deployment.clear(); game.pointer_locked = true; game.paused = false; game.phase_time = 4
	# Keep uninvolved teams apart, so distant fixture actors cannot reveal each other.
	for actor in game.all_actors():
		if actor != walker: actor.global_position = Vector3(200,40,200) if game.actor_team(actor) == 0 else Vector3(-200,40,-200)
	var floor: Dictionary = game.deployment.landing(Vector2(-15,-13),false,INF,0,walker)
	expect(not floor.is_empty(),"native fixture real standing floor")
	if floor.is_empty(): await finish("native floor"); return
	walker.global_position = floor.point; walker.grounded = true; walker.update_form(false)
	bot.global_position = walker.global_position + Vector3(0,0,6); bot.visible = true
	bot.set_meta("enemy_swimming",true); bot.get_node("Body").set_form(true)
	var camera: Camera3D = walker.get_node("Camera3D")
	camera.current = true
	camera.global_position = walker.global_position + Vector3(6,6,-8); camera.look_at(walker.global_position + Vector3(0,.6,3))
	var body: Node3D = walker.get_node("Body")
	body.set_physics_process(false); body.rotation.y = 0; body.set_form(false); body.set_aim(true); body.set_weapon_pose(0,false)
	for i in 25: body._physics_process(.033); await process_frame
	game.intel.clear_all(); game.intel.refresh(); game._update_hud()
	expect(game.intel.marker(bot,0).is_empty(),"native hidden enemy has no map marker")
	await snap("enemy-hidden")
	combat.ink_amount = 100; game.items.state(walker).cooldowns.sonar = 0
	print("AUDIT: native deploy phase=",game.phase," paused=",game.paused," kind=",game.items.state(walker).kind," alive=",game.actor_alive(walker)," busy=",game.mobility.busy(walker)," floor=",walker.global_position," landing=",game.deployment.landing(Vector2(walker.global_position.x,walker.global_position.z),false,walker.global_position.y,0,walker))
	expect(game.items.use(walker),"native sonar deploy")
	for i in 24: game.items.sonar.tick(.033); game.intel.tick(.033)
	game._update_hud()
	expect(not game.intel.marker(bot,0).is_empty() and game.intel.marker(bot,0).status == "sonar","native pulse reveals concealed target")
	await snap("sonar-pulse")
	key(KEY_TAB,true); game._update_hud()
	expect(game.roster_rows[6].text.contains("位置未知"),"unknown enemy health stays private on expanded roster")
	await snap("sonar-map"); key(KEY_TAB,false)
	game.intel.tick(2.2); game._update_hud()
	expect(game.intel.marker(bot,0).is_empty(),"native marker expiry")
	await snap("enemy-hidden-again")
	game.items.sonar.clear_all(); game.intel.clear_all()
	await finish("Metal held/drawn bow, sonar loadout, hidden/revealed/expired enemy and small/expanded maps captured")
