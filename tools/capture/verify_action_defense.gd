extends "res://tests/godot/helpers/creative_fixture.gd"

var output := ""
var report := {"kind":"controlled native input and action/defense rendering","cases":[]}

func _initialize() -> void:call_deferred("_run")

func snap(label:String) -> void:
	game._update_hud();game.get_node("InkView").sync_dirty()
	await process_frame;await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	expect(picture!=null and not picture.is_empty(),"native rendered "+label)
	if picture!=null:expect(picture.save_png(output.path_join(label+".png"))==OK,"save "+label)

func input_tick() -> void:
	game.paused=false;game.pointer_locked=true;walker.active=true
	walker.update_intent(1.0/30,Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),Input.is_physical_key_pressed(KEY_SHIFT),combat.is_busy())
	combat.tick(1.0/30,walker.weapon_fire,walker.squid_form)
	walker._physics_process(1.0/30)

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64 and new absolute output directory required");quit(1);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:quit(1);return
	root.size=Vector2i(1280,720)
	preload("res://src/core/match_setup.gd").pending_loadout={"settings_path":output.path_join("isolated-settings.cfg")}
	await prepare(1,"tidewater")
	game.phase_time=2.5 # The match clock is frozen; finish the controlled GO overlay.
	DisplayServer.window_move_to_foreground()
	root.grab_focus()
	report.environment={"engine":Engine.get_version_info().string,"arch":"arm64","display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"window":[1280,720]}
	report.source_sha256={}
	for path in preload("res://tools/lib/source_inventory.gd").scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
	report.source_sha256["res://tools/capture/verify_action_defense.gd"]=FileAccess.get_sha256("res://tools/capture/verify_action_defense.gd")
	walker.set_process_input(false) # Ignore native cursor drift; keys are still parsed.
	walker.global_position=Vector3(0,.05,-28);walker.reset_movement_state();walker.grounded=true
	walker.camera_yaw=0;walker.camera_pitch=-.08;walker._update_camera()
	bot.global_position=Vector3(0,.05,-20);game.bot_health=120;bot.health=120
	game.selected_weapon="canopy";combat.select_weapon("canopy")
	game._set_pointer_lock(true);walker.active=true;game.player_last_damage=0
	combat.ink_amount=6
	mouse(true)
	for i in 10:
		await physics_frame;input_tick()
	expect(combat.canopy.holding(walker),"actual held mouse opens low-ink guard")
	report.cases.append({"case":"mouse-low-ink-guard","holding":combat.canopy.holding(walker),"ink":combat.ink_amount})
	await snap("01-low-ink-guard")
	mouse(false);input_tick()
	expect(not combat.canopy.holding(walker),"actual mouse release closes guard")
	for i in 12:
		await physics_frame;input_tick()
	combat.ink_amount=30;mouse(true)
	for i in 8:
		await physics_frame;input_tick()
	expect(combat.canopy.holding(walker),"actual repress reopens guard after soft recovery")
	await snap("02-reopened-guard")
	mouse(false);input_tick();combat.canopy.clear_all()
	# Actual F dispatch enters the weapon's new special. Meter setup is controlled.
	game.player_invuln=0;combat.ink_amount=1;combat.special_points=combat.special_cost()
	game.paused=false;game.pointer_locked=true;key(KEY_F,true);key(KEY_F,false)
	expect(combat.push_wall.active(walker) and combat.ink_amount==game.actor_ink_max(walker),"actual F creates wall and refills tank")
	if combat.push_wall.active(walker):
		var s:Dictionary=combat.push_wall.states[walker.get_instance_id()]
		var start:Vector3=s.cover.global_position
		for i in 30:
			await physics_frame;combat.advance_effects(1.0/30)
		expect(s.cover.global_position.distance_to(start)>3,"native wall visibly advances")
		report.cases.append({"case":"F-push-wall","hp":s.hp,"travel":s.cover.global_position.distance_to(start),"ink":combat.ink_amount})
		var camera:Camera3D=walker.get_node("Camera3D")
		camera.global_position=walker.global_position+Vector3(6,3.5,-5)
		camera.look_at(s.cover.global_position)
		await snap("03-pushing-wall")
		game.player_invuln=0;combat.fire_bot_charger(bot.global_position+Vector3.UP,walker.global_position+Vector3.UP,1,1,bot)
		expect(s.hp==450,"native hostile ray reduces wall health")
		await snap("04-wall-hit")
	combat.on_death();game.player_respawn=0;game.player_health=game.actor_max_health(walker)
	# Real Shift/W and turn+Space; no direct roll state injection.
	walker.reset_movement_state();walker.global_position=Vector3(0,.05,-28)
	walker.camera_yaw=0;walker.camera_pitch=-.08;walker._update_camera();walker.grounded=true
	game.paint_at_world(walker.global_position,0,10,.5)
	key(KEY_SHIFT,true);key(KEY_W,true)
	for i in 22:
		await physics_frame;input_tick()
	expect(walker.squid_form and Vector2(walker.velocity.x,walker.velocity.z).length()>6,"actual input builds swim momentum")
	key(KEY_W,false);key(KEY_D,true)
	var desired_axis:Vector2=walker._camera_relative_axis(Vector2.RIGHT).normalized()
	walker.set_process_input(true);key(KEY_SPACE,true);key(KEY_SPACE,false);walker.set_process_input(false)
	await physics_frame;input_tick()
	var roll_velocity:=Vector2(walker.velocity.x,walker.velocity.z)
	expect(walker.squid_roll_time>0 and roll_velocity.length()>8 and roll_velocity.normalized().dot(desired_axis)>.95 and walker.velocity.y>0,"actual turn+Space redirects and launches squid roll")
	report.cases.append({"case":"Shift-W-D-Space-roll","time":walker.squid_roll_time,"velocity":walker.velocity,"guard":walker.squid_roll_guard})
	await snap("05-squid-roll")
	key(KEY_D,false);key(KEY_SHIFT,false);walker.reset_movement_state()
	# Owned wall, real held Space, physical capsule and existing wall ownership.
	walker.global_position=Vector3(5.5,.1,0);walker.camera_yaw=-PI/2;walker.camera_pitch=-.08
	game.ink.splat_face(5,5,1.4,3,0,.5)
	key(KEY_SHIFT,true);key(KEY_W,true);key(KEY_SPACE,true)
	for i in 15:
		await physics_frame;input_tick()
	expect(walker.surge_time>0 and walker.velocity.y>15,"actual wall and held jump perform surge")
	report.cases.append({"case":"Shift-W-hold-Space-surge","time":walker.surge_time,"velocity":walker.velocity,"position":walker.global_position})
	await snap("06-wall-surge")
	key(KEY_SPACE,false);key(KEY_W,false);key(KEY_SHIFT,false);mouse(false)
	game._set_pointer_lock(false)
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures.duplicate()
	report.limits="Frozen AI/match; forced meter, ink and turf. Native automated input, not human feel, natural match, thermal or export acceptance."
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	else:expect(false,"write report")
	await finish("native low-ink/reopen mouse, F wall/refill/ray, actual squid roll and surge input")
