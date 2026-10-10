extends "/Users/yunni/Joy/inkwave-game-cleaned/render-evidence/app-build-2026-10-10/remaining-fixtures-2/check_damage_contract.gd"

var output := ""
var native_report := {"kind":"controlled native primary damage and mouse input",
	"limits":"Fixed positions, frozen AI/match and explicit input ticks. Not natural timing, human feel, performance/temperature or export acceptance.",
	"source_sha256":{},"focus_resumes":0}

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64 and a new absolute output directory required");quit(1);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:quit(1);return
	root.size=Vector2i(1280,720)
	preload("res://src/core/match_setup.gd").pending_loadout={"settings_path":output.path_join("isolated-settings.cfg")}
	native_report.environment={"engine":Engine.get_version_info().string,"arm64":OS.has_feature("arm64"),"display":DisplayServer.get_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"window":[1280,720]}
	native_report.verification="explicit exported PCK; receipt supplies pack identity"
	if ProjectSettings.get_setting("application/config/version") != "0.3.0-preview.24":
		printerr("FAIL: wrong exported version");quit(1);return
	await super._run()

func input_tick(pressed: bool) -> void:
	if game.paused:native_report.focus_resumes+=1
	game.paused=false;game.pointer_locked=true
	mouse(pressed)
	combat.tick(1.0/30,Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),Input.is_physical_key_pressed(KEY_SHIFT))

func snap(label: String) -> void:
	game._update_hud();game.get_node("InkView").sync_dirty()
	await process_frame;await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	expect(picture!=null and not picture.is_empty(),"native image "+label)
	if picture!=null:expect(picture.save_png(output.path_join(label+".png"))==OK,"save "+label)

func native_motion(point: Vector2) -> void:
	# Keep the platform cursor at the injected position after captured-mode release.
	# Otherwise a delayed native motion can immediately undo mouse_entered.
	root.warp_mouse(point)
	for i in 2:await process_frame
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	Input.parse_input_event(motion);Input.flush_buffered_events()

func finish(label: String) -> void:
	reset_fight(bot,walker,132)
	walker.set_process_input(false) # Fixed aim fixture: ignore native cursor warp motion.
	game.deployment.clear();game.presentation.incoming.clear();game.damage_history.clear()
	walker.global_position=Vector3(0,.05,-28);walker.reset_movement_state();walker.active=true;walker.grounded=true
	bot.global_position=Vector3(0,.05,-22);bot.get_node("Body").set_form(false)
	game.phase_time=1;game.selected_weapon="charger";combat.select_weapon("charger")
	game._set_pointer_lock(true)
	var camera: Camera3D=walker.get_node("Camera3D")
	camera.global_position=walker.global_position+Vector3(2.5,2.5,-4)
	camera.look_at(bot.global_position+Vector3.UP*.9);camera.current=true
	for i in 31:
		await physics_frame;input_tick(true)
	expect(combat.charging and combat.charge_fraction==1 and game.bot_health==132,"real mouse hold charges without premature damage")
	await snap("mouse-full-charge")
	input_tick(false)
	expect(game.bot_health==0 and game.bot_respawn>0 and is_equal_approx(combat.ink_amount,86),"real mouse release costs 14 and splats full health")
	native_report.mouse_full_charge={"hold_ticks":31,"release":"left mouse up","ink_after":combat.ink_amount,"target_hp":game.bot_health,"target_respawn":game.bot_respawn}
	await snap("mouse-full-charge-splat")
	# Actual shield activation protects a fresh target from the same input.
	game.bot_health=132;game.bot_respawn=0;game.bot_invuln=0;bot.visible=true
	game.items.equip(bot,"shield");expect(game.items.use(bot),"actual target shield activation")
	combat.cooldown=0;combat.ink_amount=100;combat.last_fire_time=0
	for i in 31:
		await physics_frame;input_tick(true)
	input_tick(false)
	expect(is_equal_approx(game.bot_health,42) and game.items.state(bot).armor==0,"real shield absorbs 60 before mouse-fired HP damage")
	native_report.mouse_shield={"target_hp":game.bot_health,"remaining_armor":game.items.state(bot).armor,"ink_after":combat.ink_amount}
	await snap("mouse-shield-counterplay")
	reset_fight(bot,walker,132)
	walker.set_process_input(false) # Fixed aim fixture: ignore native cursor warp motion.
	game.deployment.clear();game.presentation.incoming.clear();game.damage_history.clear()
	walker.global_position=Vector3(0,.05,-28);walker.reset_movement_state();walker.active=true;walker.grounded=true
	bot.global_position=Vector3(0,.05,-22);bot.get_node("Body").set_form(false)
	game.selected_weapon="bow";combat.select_weapon("bow")
	camera.global_position=walker.global_position+Vector3(2.5,2.5,-4)
	camera.look_at(bot.global_position+Vector3.UP*.9)
	for i in 25:
		await physics_frame;input_tick(true)
	expect(combat.charge_fraction==1 and game.bot_health==132,"real bow hold completes draw without premature arrows")
	await snap("bow-full-draw")
	input_tick(false)
	var bow_release_ink: float=combat.ink_amount
	expect(is_equal_approx(bow_release_ink,94) and combat.bow.arrows.size()==3,"real bow release creates three arrows and costs six")
	for i in 30:
		await physics_frame;input_tick(false)
	expect(is_equal_approx(game.bot_health,27) and game.bot_respawn==0,"real full bow mouse release leaves 27 HP for follow-up")
	await snap("bow-full-draw-followup")
	combat.cooldown=0
	for i in 25:
		await physics_frame;input_tick(true)
	input_tick(false)
	for i in 30:
		await physics_frame;input_tick(false)
	expect(game.bot_health==0 and game.bot_respawn>0,"real bow charged follow-up finishes target")
	native_report.mouse_bow={"hold_ticks":25,"ink_at_release":bow_release_ink,"target_hp":game.bot_health}
	await snap("bow-full-draw-splat")
	game.show_preparation()
	# Let the selected-weapon deferred scroll and layout settle before each probe.
	for i in 12:await process_frame
	native_report.hovers=[]
	for id in ["charger","bow","dualie"]:
		# Exit the previous card before scrolling; the next hover needs a fresh enter.
		await native_motion(Vector2(20,20))
		for i in 4:await process_frame
		game.frontend.strips.weapon.ensure_control_visible(game.weapon_buttons[id])
		for i in 6:await process_frame
		var detail:Dictionary=preload("res://src/ui/loadout_details.gd").weapon(game,id)
		var required: String="150" if id=="charger" else ("105" if id=="bow" else "4 轮")
		expect(String(detail.body).contains(required),"loadout explains effective reward "+id)
		var hover_point: Vector2=game.weapon_buttons[id].get_global_rect().get_center()
		await native_motion(hover_point)
		# Hover opens after 0.15s; frame count alone is not a clock on this fixture.
		for probe in 20:
			await create_timer(.05).timeout
			if game.frontend.hover_panel.visible and game.frontend.hover_id==id:break
		await process_frame
		native_report.hovers.append({"weapon":id,"hover_id":game.frontend.hover_id,"hover_kind":game.frontend.hover_kind,"visible":game.frontend.hover_panel.visible,"age":game.frontend.clock-game.frontend.hover_since,"required":required,"body":game.frontend.hover_body.text,"target":hover_point,"viewport_mouse":root.get_mouse_position(),"mouse_mode":Input.mouse_mode})
		expect(game.frontend.hover_panel.visible and game.frontend.hover_body.text.contains(required),"actual native hover shows updated "+id)
		expect(game.frontend.hover_body.position.y+game.frontend.hover_body.get_minimum_size().y<=game.frontend.hover_panel.size.y-12,"complete native detail fits panel "+id)
		await snap("updated-loadout-"+id)
	native_report.cases=observations;native_report.status="passed" if failures.is_empty() else "failed";native_report.failures=failures.duplicate()
	var file:=FileAccess.open(output.path_join("combat.json"),FileAccess.WRITE)
	if file==null:expect(false,"write report")
	else:file.store_string(JSON.stringify(native_report,"\t"));file.close()
	await super.finish(label+"; actual native mouse hold/release and shield")
