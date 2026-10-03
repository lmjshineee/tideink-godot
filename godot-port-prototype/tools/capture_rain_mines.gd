extends "res://tools/capture_counter_mist.gd"

func advance(seconds: float) -> void:
	for i in ceili(seconds/.01): combat.rain_arrows.tick(.01)

func _run() -> void:
	evidence_prefix = "creative20-gl" if OS.get_cmdline_user_args().has("--gl") else "creative20"
	if DisplayServer.get_name() == "headless": printerr("FAIL: native renderer required"); quit(1); return
	root.size = Vector2i(1440,900)
	await prepare(5,"prism_gallery")
	for ch in "雨箭墨雷敌弹可拆": expect(game.presentation.body_font.has_char(ch.unicode_at(0)),"bundled battle HUD Chinese glyph "+ch)
	game.phase = "setup"; game.frontend._select_item("mine"); game._choose_player_weapon("bow"); game._update_hud()
	await create_timer(.25).timeout; await hover("item","mine")
	expect(game.frontend.hover_panel.visible and game.frontend.hover_body.text.contains("0.45"),"native mine description shows real warning window")
	await snap("mine-loadout")
	game.frontend._end_hover(); await hover("weapon","bow")
	expect(game.frontend.hover_panel.visible and game.frontend.hover_body.text.contains("170"),"native bow description contains its dedicated special")
	expect(game.frontend.hover_body.position.y+game.frontend.hover_body.size.y <= game.frontend.hover_panel.size.y,"full rain description fits native tooltip")
	await snap("rain-loadout")
	root.size = Vector2i(960,540); await create_timer(.25).timeout; await hover("weapon","bow")
	expect(game.frontend.hover_body.position.y+game.frontend.hover_body.size.y <= game.frontend.hover_panel.size.y,"full rain description fits small native tooltip")
	await snap("rain-loadout-small")
	game.frontend._end_hover(); await hover("item","mine")
	expect(game.frontend.hover_body.position.y+game.frontend.hover_body.size.y <= game.frontend.hover_panel.size.y,"mine description fits small native tooltip")
	await snap("mine-loadout-small")
	root.size = Vector2i(1440,900); await create_timer(.15).timeout
	game.frontend._end_hover(); game.phase = "playing"; game.phase_time = 4; game.deployment.clear()
	game.pointer_locked = true; game.paused = false
	for actor in game.all_actors():
		if actor != walker: actor.global_position = Vector3(200,40,200)
	var floor: Dictionary = game.deployment.landing(Vector2(-15,-13),false,INF,0,walker)
	expect(not floor.is_empty(),"native fixture uses actual standing floor")
	if floor.is_empty(): await finish("native floor"); return
	walker.global_position = floor.point; walker.grounded = true; walker.update_form(false)
	var home: Vector3 = walker.global_position
	var target := {}
	for offset in [Vector3(0,0,7),Vector3(7,0,0),Vector3(0,0,-7),Vector3(-7,0,0)]:
		target = combat.rain_arrows.target(walker,home+offset+Vector3.UP*.5)
		if not target.is_empty(): break
	expect(not target.is_empty(),"native rain has actual visible floor target")
	if target.is_empty(): await finish("native rain target"); return
	bot.global_position = target.point+Vector3.UP*.05; bot.visible = true; bot.set_meta("enemy_swimming",false)
	var body: Node3D = walker.get_node("Body"); body.set_physics_process(false); body.set_form(false); body.set_aim(true); body.set_weapon_pose(.2,false)
	body.rotation.y = atan2(bot.global_position.x-home.x,bot.global_position.z-home.z)
	for i in 25: body._physics_process(.033); await process_frame
	var camera: Camera3D = walker.get_node("Camera3D"); camera.current = true
	camera.global_position = home+Vector3(0,2,-3); camera.look_at(bot.global_position+Vector3.UP*.2)
	combat.special_points = 170; key(KEY_F,true); key(KEY_F,false)
	expect(combat.rain_arrows.busy(walker),"native real F activates bow rain")
	camera.global_position = home+Vector3(6,5,-5); camera.look_at((home+bot.global_position)*.5+Vector3.UP*1.2)
	await snap("rain-warning")
	advance(.64); expect(combat.rain_arrows.arrows.size() == 9,"native first real volley is nine physical arrows")
	await snap("rain-launch")
	advance(.45); await snap("rain-arc")
	advance(2); combat._update_special(.01)
	expect(game.bot_health < 120,"native real impacts damage opposing actor")
	await snap("rain-impact")
	bot.global_position = home+Vector3(6,.05,0); await physics_frame
	combat.ink_amount = 100; game.items.state(walker).cooldowns.mine = 0
	key(KEY_E,true); key(KEY_E,false)
	expect(game.items.mines.mines.size() == 1,"native real E places physical mine")
	if game.items.mines.mines.is_empty(): await finish("native mine input"); return
	var m: Dictionary = game.items.mines.mines.values()[0]
	camera.global_position = home+Vector3(3,1.8,-3); camera.look_at(home+Vector3.UP*.25)
	game.items.mines.tick(.81); await snap("mine-armed")
	bot.global_position = home+Vector3(1.5,.05,0); game.bot_health = 120; bot.health = 120; await physics_frame
	game.items.mines.tick(.01); expect(m.fuse >= 0,"native concealed proximity starts warning")
	await snap("mine-warning")
	game.items.mines.tick(.46); game.intel.refresh()
	expect(game.bot_health < 120 and game.intel.marker(bot,0).status == "sonar","native explosion damages and gives shared tag")
	await snap("mine-tag")
	await finish("Native rain/mine descriptions at two sizes, actual F/E inputs, physical arc/impact, armed device/fuse/explosion/team tag")
