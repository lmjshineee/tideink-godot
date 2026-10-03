extends "res://tools/capture_counter_mist.gd"

func hover(kind: String, id: String) -> void:
	var front: Control = game.frontend
	var control: Control = front.item_buttons[id] if kind=="item" else front.perk_buttons[id]
	for attempt in 4:
		front.strips[kind].ensure_control_visible(control)
		control.grab_focus(); await process_frame; await process_frame
		var motion := InputEventMouseMotion.new()
		motion.position = control.get_global_transform_with_canvas()*control.size*.5
		root.push_input(motion,true); await process_frame; await process_frame
		front._begin_hover(kind,id); await create_timer(.25).timeout; front._layout_hover()
		if front.hover_panel.visible and front.hover_kind==kind and front.hover_id==id: break
	print("AUDIT: stable item hover=",front.hover_panel.visible," kind=",front.hover_kind," id=",front.hover_id)

func hover_perk(id: String) -> void:
	var front: Control = game.frontend
	await hover("perk",id)
	expect(front.hover_panel.visible and front.hover_kind=="perk" and front.hover_id==id,"real perk tooltip visible: "+id)
	expect(front.hover_body.position.y+front.hover_body.size.y <= front.hover_panel.size.y,"full perk detail fits: "+id)

func _run() -> void:
	evidence_prefix = "creative22-gl" if OS.get_cmdline_user_args().has("--gl") else "creative22"
	if DisplayServer.get_name()=="headless": printerr("FAIL: native renderer required"); quit(1); return
	root.size = Vector2i(1280,720); await prepare(5,"prism_gallery")
	game.phase = "setup"; game._choose_player_weapon("shooter")
	for ch in "墨翼背包翻墙加速残墨引爆极限省墨涂地充能逆风支援":
		expect(game.presentation.body_font.has_char(ch.unicode_at(0)),"native bundled glyph: "+ch)
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = pixels; await create_timer(.2).timeout; game.frontend._end_hover()
		game.frontend._select_item("ink_wings"); game.frontend.strips.item.ensure_control_visible(game.frontend.item_buttons.ink_wings)
		game.frontend.item_buttons.ink_wings.grab_focus()
		await process_frame; await process_frame; await hover("item","ink_wings")
		expect(game.frontend.hover_body.text.contains("4.5") and game.frontend.hover_panel.visible,"wing item detail shows real height limit")
		expect(game.frontend.hover_body.position.y+game.frontend.hover_body.size.y <= game.frontend.hover_panel.size.y,"wing item detail fits")
		await snap("wing-loadout"+("-small" if pixels.x<1000 else ""))
		for id in ["vault_runner","last_ink","dry_focus","turf_engine"]:
			game.frontend._end_hover(); await hover_perk(id); await snap(id+("-small" if pixels.x<1000 else ""))
	root.size = Vector2i(1280,720); await create_timer(.15).timeout; game.frontend._end_hover()
	game.phase = "playing"; game.phase_time = 4; game.deployment.clear(); game.pointer_locked = true; game.paused = false
	for actor in game.all_actors():
		if actor!=walker: actor.global_position = Vector3(200,40,200)
	var landing: Dictionary = game.deployment.landing(Vector2(-15,-13),false,INF,0,walker)
	expect(not landing.is_empty(),"actual supported launch location")
	if landing.is_empty(): await finish("native wing launch"); return
	walker.global_position = landing.point; walker.reset_movement_state(); walker.grounded = true
	var home: Vector3 = walker.global_position
	game.paint_at_world(Vector3(0,.9,0),0,22,.3); game.paint_at_world(home+Vector3.UP*.1,1,5,.5)
	game.get_node("InkView").sync_dirty()
	var gap: float = (game.ink.coverage(0)-game.ink.coverage(1))*100
	expect(gap>20,"real paint cells create controlled deficit, not spoofed HUD")
	game.comeback.tick(12)
	for i in 81: game.comeback.tick(.1)
	expect(game.comeback.team==1,"actual deficit activates enemy-side support")
	game.tactics._process(.5)
	var camera: Camera3D = walker.get_node("Camera3D"); camera.current = true
	camera.global_position = home+Vector3(5,4,-6); camera.look_at(home+Vector3.UP)
	game.presentation.ability_flash = 0
	combat.special_points = combat.special_cost()*.42
	await snap("live-support"); var clock: float = game.tactics.live_clock
	await create_timer(.35).timeout; expect(game.tactics.live_clock>clock,"support pulse runs with frame time")
	await snap("live-support-pulse")
	root.size = Vector2i(960,540); root.content_scale_size = root.size; game.settings.ui_scale = 1.1; await create_timer(.2).timeout; game._layout_hud(); game._update_hud(); game.tactics._process(.033)
	expect(game.tactics.live_rect.end.x<game.score_panel.position.x,"native compact live shares clear timer")
	await snap("live-support-small")
	var old_health: float = game.player_health
	var old_ink: float = combat.ink_amount
	var old_time: float = game.round_left
	combat.special_points = combat.special_cost(); game.player_health = 19; combat.ink_amount = 16; game.round_left = 8
	await snap("hud-ready-low-small")
	game.player_health = old_health; combat.ink_amount = old_ink; game.round_left = old_time
	root.size = Vector2i(1280,720); root.content_scale_size = root.size; game.settings.ui_scale = 1.0; await create_timer(.2).timeout; game._layout_hud(); game._update_hud()
	await snap("hud-ready")
	expect(combat.counter.begin(walker,Vector3.FORWARD),"real counter intake starts for HUD state")
	combat.counter.intakes[walker.get_instance_id()].charge = 67
	await snap("hud-counter")
	combat.counter.cancel(walker)
	expect(combat.rain_arrows.begin(walker,home),"real rain volley starts on supported visible point")
	await snap("hud-rain")
	combat.rain_arrows.cancel(walker)
	combat.special_points = combat.special_cost()*.42
	game.items.equip(walker,"ink_wings"); game.items.state(walker).cooldowns.ink_wings = 0; combat.ink_amount = 100; await physics_frame
	game.paused = false; game.pointer_locked = true
	key(KEY_E,true); key(KEY_E,false); expect(game.wings.busy(walker),"actual E activates item wings")
	key(KEY_SPACE,true)
	for i in 50:
		game.wings.tick(1.0/30); walker._physics_process(1.0/30); await physics_frame
	key(KEY_SPACE,false); game.wings.tick(.01)
	expect(walker.global_position.y>home.y+4.3 and walker.global_position.y<=home.y+4.51,"native actual ascent and height cap")
	camera.global_position = walker.global_position+Vector3(3,2,-4); camera.look_at(walker.global_position+Vector3.UP*.8)
	await snap("wing-flight")
	mouse(true); combat.cooldown = 0; combat.tick(.033,Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),false); mouse(false)
	expect(not combat.projectiles.is_empty(),"native real primary input fires during item flight")
	await snap("wing-primary")
	var old_y: float = walker.global_position.y; key(KEY_SHIFT,true)
	for i in 10: game.wings.tick(1.0/30); walker._physics_process(1.0/30); await physics_frame
	key(KEY_SHIFT,false)
	expect(walker.global_position.y<old_y-.8 and not walker.squid_form,"native Shift descends with human body")
	print("AUDIT: actual coverage=",game.ink.coverage(0)*100,"/",game.ink.coverage(1)*100," flight y=",old_y,"->",walker.global_position.y," ink=",combat.ink_amount)
	game._finish_round()
	for i in 30: game._physics_process(.1)
	expect(game.phase=="results","native actual finish timer enters results")
	expect(is_equal_approx(game.judged_coverage[0],game.ink.coverage(0)) and is_equal_approx(game.judged_coverage[1],game.ink.coverage(1)),"native final shares derive from actual ink cells")
	game._update_hud()
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = pixels; await create_timer(.2).timeout; game._layout_hud(); game.tactics._process(.033)
		expect(game.tactics.map.size.x>=game.tactics.size.x*.44 and game.tactics.map.show_border==false,"native larger borderless left map")
		for label in game.tactics.coverage_labels: expect(label.position.y>=game.tactics.map.get_rect().end.y,"native final shares below map")
		await snap("results"+("-small" if pixels.x<1000 else ""))
	await finish("Native item wings / primary / physical capped ascent and descent, timed support + pulse from true paint, all four perk details and two-size borderless larger results")
