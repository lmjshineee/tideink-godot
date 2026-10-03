extends "res://tools/capture_counter_mist.gd"

func _run() -> void:
	evidence_prefix="swim25-gl" if OS.get_cmdline_user_args().has("--gl") else "swim25"
	if DisplayServer.get_name()=="headless": printerr("FAIL: native display required"); quit(1); return
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	await prepare(5,"modular_harbor")
	game.phase="setup"; game.perks.locked=false
	game.frontend._select_perk(game.perks.ORDER.find("enemy_swim")); game._update_hud()
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=pixels; root.content_scale_size=pixels; game.settings.ui_scale=1.1
		game._layout_hud(); game._update_hud(); await create_timer(.1).timeout
		var button: Control=game.frontend.perk_buttons.enemy_swim
		game.frontend.strips.perk.ensure_control_visible(button)
		for attempt in 3:
			var motion := InputEventMouseMotion.new()
			motion.position=button.get_global_transform_with_canvas()*(button.size*.5)
			root.push_input(motion,true); button.grab_focus(); game.frontend._begin_hover("perk","enemy_swim")
			await create_timer(.25).timeout; game.frontend._layout_hover()
			if game.frontend.hover_panel.visible and game.frontend.hover_kind=="perk" and game.frontend.hover_id=="enemy_swim": break
		expect(game.frontend.hover_panel.visible and game.frontend.hover_body.text.contains("6") and game.frontend.hover_body.text.contains("20") and game.frontend.hover_body.text.contains("10%"),"native talent detail shows current damage, cap and weakness")
		expect(game.frontend.hover_body.position.y+game.frontend.hover_body.size.y<=game.frontend.hover_panel.size.y,"native detail fits panel")
		await snap("detail-"+str(pixels.x))
	game.frontend._end_hover(); game._start_round(); game.phase_time=4; game.deployment.clear()
	root.size=Vector2i(1280,720); root.content_scale_size=root.size; game.settings.ui_scale=1
	game._layout_hud(); game._set_pointer_lock(true); game.paused=false
	walker.global_position=Vector3(0,.05,-20); walker.reset_movement_state(); walker.camera_yaw=0; walker.camera_pitch=-.2
	game.paint_at_world(walker.global_position+Vector3.UP*.1,1,4,0)
	# Fixture placement must settle the real foot probe before starting the stopwatch.
	for i in 3: walker._physics_process(1.0/30)
	expect(walker.grounded and walker.ink_owner==1,"native fixture starts with actual hostile foot contact")
	combat.ink_amount=50; game.player_invuln=0; game.player_health=120; game.player_ink_damage=0
	key(KEY_SHIFT,true); game.set_physics_process(true); walker.set_physics_process(true)
	var before: float=game.round_left
	await create_timer(1.1).timeout
	var elapsed: float=before-game.round_left
	print("AUDIT: native Shift enemy dive ",elapsed," s, HP loss=",120-game.player_health," ink=",combat.ink_amount," squid=",walker.squid_form)
	expect(walker.squid_form and walker.ink_owner==1,"native actual Shift enters enemy ink")
	expect(absf((120-game.player_health)-6*elapsed)<.3,"native physical frames drain six HP/s")
	expect(combat.ink_amount==50,"native hostile swim does not refill ink")
	await snap("diving")
	await create_timer(2.8).timeout
	expect(absf(game.player_health-100)<.01 and game.player_ink_damage==20,"native continuous exposure stops at twenty HP")
	game.set_physics_process(false); walker.set_physics_process(false); key(KEY_SHIFT,false)
	root.size=Vector2i(960,540); root.content_scale_size=root.size; game.settings.ui_scale=1.1; game._layout_hud()
	await snap("cap-small")
	walker.update_form(false); game.player_health=120; game.player_invuln=0
	var from: Vector3=walker.global_position+Vector3(0,.9,-4)
	combat.fire_bot_charger(from,walker.global_position+Vector3.UP*.9,1,1,bot)
	expect(game.player_respawn<=0 and absf(game.player_health-10)<.01,"native real charge ray leaves talent alive")
	await snap("charge-survival")
	await finish("native actual Shift/physics six HP per second, twenty-HP limit, no refill, normal charge survival, two-size updated talent detail")
