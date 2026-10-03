extends "res://tools/capture_counter_mist.gd"
func _run() -> void:
	evidence_prefix = "creative21-gl" if OS.get_cmdline_user_args().has("--gl") else "creative21"
	if DisplayServer.get_name() == "headless": printerr("FAIL: native renderer required"); quit(1); return
	root.size = Vector2i(1440,900); await prepare(5,"prism_gallery")
	game.phase = "setup"; game._choose_player_weapon("shooter")
	for ch in "敌墨潜游回声诱饵接力补给": expect(game.tactics.item_label.get_theme_font("font").has_char(ch.unicode_at(0)),"deterministic tactical HUD Chinese glyph "+ch)
	for ch in "回声诱饵接力补给盒领取敌方可抢": expect(game.presentation.body_font.has_char(ch.unicode_at(0)),"native Chinese glyph "+ch)
	for size in [Vector2i(1440,900),Vector2i(960,540)]:
		root.size = size; await create_timer(.25).timeout
		for id in ["echo_decoy","supply_box"]:
			game.frontend._select_item(id); game._update_hud(); game.frontend._end_hover()
			game.frontend.strips.item.ensure_control_visible(game.frontend.item_buttons[id]); await process_frame; await process_frame; await hover("item",id)
			expect(game.frontend.hover_panel.visible,"native new item hover visible")
			expect(game.frontend.hover_body.position.y+game.frontend.hover_body.size.y <= game.frontend.hover_panel.size.y,"full new item explanation fits at both window sizes")
			await snap(id+"-loadout"+("-small" if size.x < 1000 else ""))
	root.size = Vector2i(1440,900); await create_timer(.15).timeout; game.frontend._end_hover(); game.phase = "playing"; game.phase_time = 4; game.deployment.clear()
	game.pointer_locked = true; game.paused = false
	for actor in game.all_actors():
		if actor != walker: actor.global_position = Vector3(200,40,200)
	var floor: Dictionary = game.deployment.landing(Vector2(-15,-13),false,INF,0,walker)
	expect(not floor.is_empty(),"native actual support floor")
	if floor.is_empty(): await finish("native floor"); return
	walker.global_position = floor.point; walker.grounded = true; walker.update_form(false)
	var home: Vector3 = walker.global_position; var target := {}
	for offset in [Vector3(0,0,5),Vector3(5,0,0),Vector3(0,0,-5),Vector3(-5,0,0)]:
		target = game.items.decoys.target(walker,home+offset)
		if not target.is_empty(): break
	expect(not target.is_empty(),"native fake has visible supported placement")
	if target.is_empty(): await finish("native fake target"); return
	var camera: Camera3D = walker.get_node("Camera3D"); camera.current = true
	camera.global_position = home+Vector3(0,1.5,-2); camera.look_at(target.point)
	game.items.equip(walker,"echo_decoy"); combat.ink_amount = 100; game.items.state(walker).cooldowns.echo_decoy = 0
	key(KEY_E,true); key(KEY_E,false)
	expect(game.items.decoys.decoys.size() == 1,"native actual E places character decoy")
	if game.items.decoys.decoys.is_empty(): await finish("native decoy input"); return
	var d: Dictionary = game.items.decoys.decoys.values()[0]
	camera.global_position = home+Vector3(6,3,-5); camera.look_at(d.point+Vector3.UP*.85)
	game.items.decoys.tick(.1); await snap("ally-decoy")
	# Create the opposing fake through the same bot/item path, including its team materials.
	var fake_point: Vector3 = d.point
	game.items.decoys.clear_all(); bot.global_position = home; walker.global_position = fake_point+Vector3.UP*.05
	bot.ink_amount = 100; game.items.equip(bot,"echo_decoy"); game.intel.refresh(); await physics_frame
	expect(game.items.use(bot),"native real opposing actor deploys its own fake")
	if game.items.decoys.decoys.is_empty(): await finish("native enemy fake"); return
	d = game.items.decoys.decoys.values()[0]
	walker.global_position = home; bot.global_position = Vector3(200,40,200); await physics_frame
	game.items.decoys.tick(.01); camera.look_at(d.point+Vector3.UP*.85)
	expect(d.label.visible and not d.label.text.contains("诱饵"),"unrevealed hostile fake copies owner name without fake label")
	await snap("enemy-decoy")
	game.items.equip(walker,"sonar"); combat.ink_amount = 100; game.items.state(walker).cooldowns.sonar = 0; await physics_frame
	key(KEY_E,true); key(KEY_E,false)
	for i in 90: game.items.sonar.tick(.01)
	expect(d.revealed[0] and d.label.visible and d.label.text.contains("诱饵"),"native physical sonar reveals fake label and translucent body")
	game.items.decoys.tick(.01); await snap("sonar-revealed")
	game.items.decoys.clear_all(); game.items.sonar.clear_all(); await physics_frame
	game.items.equip(walker,"supply_box"); combat.ink_amount = 100; game.items.state(walker).cooldowns.supply_box = 0
	key(KEY_E,true); key(KEY_E,false)
	expect(game.items.supply.boxes.size() == 1,"native actual E places physical supply box")
	if game.items.supply.boxes.is_empty(): await finish("native supply input"); return
	var b: Dictionary = game.items.supply.boxes.values()[0]
	game.perks.choices[walker.get_instance_id()] = "enemy_swim"
	combat.last_fire_time = 99; game.player_last_damage = 99
	camera.global_position = home+Vector3(2,1.5,-2); camera.look_at(home+Vector3.UP*.4)
	for i in 30: game.items.supply.tick(.01)
	expect(game.items.hud_text().contains("领取补给"),"native channel HUD visible for real receiver")
	await snap("supply-channel")
	for i in 31: game.items.supply.tick(.01)
	expect(combat.ink_amount == 95 and b.stock == 1,"native real owner takes one limited pack")
	await snap("supply-received")
	bot.global_position = b.point+Vector3(.8,.05,0); bot.target_actor = null; bot.ink_amount = 20; bot.last_fire_time = 99; game.bot_last_damage = 99; bot.set_meta("enemy_swimming",false); bot.set_meta("action_lock",0); await physics_frame
	for i in 61: game.items.supply.tick(.01)
	expect(bot.ink_amount == 55 and game.items.supply.stolen_total == 1 and game.items.supply.boxes.is_empty(),"native opponent steals final pack")
	await snap("supply-stolen")
	await finish("Native decoy/supply descriptions at two sizes and Chinese glyphs, real E deployments, allied/hostile/revealed fake silhouette, swept sonar, timed HUD/limited draw/opponent stealing")
