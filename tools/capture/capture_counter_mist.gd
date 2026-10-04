extends "res://tests/godot/helpers/creative_fixture.gd"
var evidence_prefix := "creative19-gl" if OS.get_cmdline_user_args().has("--gl") else "creative19"
func _initialize() -> void: call_deferred("_run")
func snap(label: String) -> void:
	game.paused = false; game._update_hud()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://render-evidence/"+evidence_prefix+"-"+label+".png")

func hover(kind: String, id: String) -> void:
	var front: Control = game.frontend
	var control: Control = game.weapon_buttons[id] if kind == "weapon" else front.item_buttons[id]
	for attempt in 3:
		var motion := InputEventMouseMotion.new()
		motion.position = control.get_global_transform_with_canvas()*(control.size*.5)
		root.push_input(motion,true)
		front._begin_hover(kind,id)
		await create_timer(.25).timeout
		front._layout_hover()
		if front.hover_panel.visible and front.hover_kind == kind and front.hover_id == id: break
	print("AUDIT: hover ",kind," ",id," panel=",front.hover_panel.visible," body-height=",front.hover_body.size.y," panel-height=",front.hover_panel.size.y)

func _run() -> void:
	if DisplayServer.get_name() == "headless": printerr("FAIL: native Metal required"); quit(1); return
	root.size = Vector2i(1440,900)
	await prepare(5,"prism_gallery")
	game.phase = "setup"; game.frontend._select_item("intel_mist")
	game._choose_player_weapon("canopy"); game._update_hud()
	await create_timer(.25).timeout
	await hover("item","intel_mist")
	expect(game.frontend.hover_panel.visible and game.frontend.hover_body.text.contains("35"),"native information mist detail is actually visible")
	await snap("mist-loadout")
	game.frontend._end_hover(); await hover("weapon","canopy")
	expect(game.frontend.hover_panel.visible and game.frontend.hover_body.text.contains("150"),"native counter detail shows current cost")
	expect(game.frontend.hover_body.position.y+game.frontend.hover_body.size.y <= game.frontend.hover_panel.size.y,"native full counter detail stays inside tooltip")
	await snap("counter-loadout")
	root.size = Vector2i(960,540); await create_timer(.25).timeout
	await hover("weapon","canopy")
	expect(game.frontend.hover_body.position.y+game.frontend.hover_body.size.y <= game.frontend.hover_panel.size.y,"native small counter detail stays inside tooltip")
	await snap("counter-loadout-small")
	root.size = Vector2i(1440,900); await create_timer(.15).timeout
	game.frontend._end_hover(); game.phase = "playing"; game.phase_time = 4; game.deployment.clear()
	game.pointer_locked = true; game.paused = false
	for actor in game.all_actors():
		if actor != walker: actor.global_position = Vector3(200,40,200) if game.actor_team(actor) == 0 else Vector3(-200,40,-200)
	var floor: Dictionary = game.deployment.landing(Vector2(-15,-13),false,INF,0,walker)
	expect(not floor.is_empty(),"native source fixture has actual standing floor")
	if floor.is_empty(): await finish("native floor"); return
	walker.global_position = floor.point; walker.grounded = true; walker.update_form(false)
	var home: Vector3 = walker.global_position
	bot.global_position = home + Vector3(0,0,8); bot.visible = true; bot.set_meta("enemy_swimming",false)
	var body: Node3D = walker.get_node("Body")
	body.set_physics_process(false); body.rotation.y = 0; body.set_form(false); body.set_aim(true); body.set_weapon_pose(0,false)
	for i in 25: body._physics_process(.033); await process_frame
	var camera: Camera3D = walker.get_node("Camera3D")
	camera.current = true
	camera.global_position = home + Vector3(5,4,-6); camera.look_at(home+Vector3(0,1,3))
	combat.special_points = 150
	expect(combat.try_special(),"native counter activation")
	var s: Dictionary = combat.counter.intakes[walker.get_instance_id()]
	s.direction = Vector3(0,0,1)
	combat.counter._pose(s)
	await snap("counter-intake")
	for i in 4:
		combat._spawn_projectile("shooter",home+Vector3(0,1.05,8),Vector3(0,0,-40),combat.weapons.shooter,1,bot)
		combat._update_projectiles(.2)
	expect(s.phase == "windup" and s.charge == 100,"native hostile shots close fully charged intake")
	await snap("counter-windup")
	combat.counter.tick(.41); combat._update_projectiles(.08)
	expect(combat.projectiles.size() == 1 and combat.projectiles[0].kind == "counter","native real retaliation projectile")
	await snap("counter-projectile")
	for shot in combat.projectiles: shot.visual.queue_free()
	combat.projectiles.clear(); combat.special_active = ""
	game.intel.clear_all()
	camera.global_position = home + Vector3(0,2,-4); camera.look_at(bot.global_position+Vector3.UP*.85)
	game.items.mist.create_volume(bot,home+Vector3(0,0,4))
	game.intel.refresh()
	expect(not game.intel.can_see(walker,bot) and game.intel.marker(bot,0).is_empty(),"native enemy fog denies sight and map marker")
	await create_timer(.25).timeout
	await snap("enemy-mist")
	game.intel.tag(bot,0); game.intel.refresh()
	expect(game.intel.can_see(walker,bot) and game.intel.labels[bot.get_instance_id()].visible,"native sonar marker counters information mist")
	expect(game.presentation.fog_tags().size() == 1,"native sonar fog HUD overlay projected from current tag")
	await snap("mist-sonar")
	# Render from inside a hostile volume; back-facing bounds + depth integration
	# must work without replacing the screen with an opaque surface sphere.
	camera.global_position = home+Vector3(0,1.5,4); camera.look_at(bot.global_position+Vector3.UP*.85)
	await snap("inside-enemy-mist")
	game.items.mist.clear_all(); game.intel.clear_all()
	game.items.mist.create_volume(walker,home+Vector3(0,0,4))
	camera.global_position = home+Vector3(0,2,-4); camera.look_at(bot.global_position+Vector3.UP*.85)
	game.intel.refresh()
	expect(game.intel.can_see(walker,bot),"native friendly fog preserves own team sight")
	await snap("friendly-mist")
	game.items.mist.tick(6.01); game.intel.refresh()
	await snap("mist-expired")
	await finish("Native renderer counter loadout/intake/full-charge/windup/projectile and hostile/friendly/inside/sonar/expired mist captured")
