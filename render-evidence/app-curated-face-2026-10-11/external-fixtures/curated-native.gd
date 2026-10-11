extends "/private/tmp/tideink-followup-6747da7/creative_fixture.gd"
const Setup=preload("res://src/core/match_setup.gd")
var output := ""
var report := {"kind":"controlled native curated maps and menu input","human_review":false,"cases":[]}
func _initialize() -> void:call_deferred("_run")
func frames(n: int=6) -> void:
	for i in n:await process_frame
func click(control: Control) -> void:
	var point:=control.get_global_transform_with_canvas()*(control.size*.5)
	root.warp_mouse(point);await frames(2)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await frames(2)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await frames(3)
func bind_game() -> void:
	game=current_scene;walker=game.get_node("World/Walker");combat=game.get_node("Combat");bot=game.get_node("Bot")
	game.set_physics_process(false);walker.set_physics_process(false);game._set_pointer_lock(false);game.paused=false
	game._layout_hud();game.frontend.sync();game._update_hud()
func snap(name_text: String) -> void:
	await frames(8);await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(name_text+".png"))==OK,"native screenshot "+name_text)
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64 and new absolute output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	report.environment={"engine":Engine.get_version_info().string,"arm64":OS.has_feature("arm64"),"api":RenderingServer.get_video_adapter_api_version()}
	report.verification="explicit unchanged exported PCK; receipt supplies pack identity"
	Setup.pending_loadout={"settings_path":output.path_join("settings.cfg")}
	await prepare(5,"tidewater");current_scene=game;game.show_preparation();game.perks.locked=false
	bind_game()
	for id in ["sunset_park","lantern_depot"]:
		for size in [Vector2i(1280,720),Vector2i(960,540)]:
			root.size=size;root.content_scale_size=size;game.settings.ui_scale=1.1 if size.x==960 else 1.0
			game._layout_hud();game.frontend.sync();await frames(10)
			if Setup.map_id!=id:
				game.frontend.strips.map.ensure_control_visible(game.frontend.map_buttons[id]);await frames(8)
				await click(game.frontend.map_buttons[id]);await frames(20);bind_game()
			expect(Setup.map_id==id and game.frontend.stage_preview.asset_id==id,"actual map-button input loads chosen geometry")
			expect(game.frontend.map_buttons.size()==5,"five curated maps in native selector")
			expect(game.frontend.get("rule_choice")==null and game.get("area")==null,"removed mode has no visible control or match state")
			await snap(id+"-menu-"+str(size.x))
		root.size=Vector2i(1280,720);root.content_scale_size=root.size;game.settings.ui_scale=1;game._layout_hud()
		game._start_round();game._set_pointer_lock(false);game.hud_root.visible=false
		var camera:=Camera3D.new();game.add_child(camera);camera.position=Vector3(34,40,-47);camera.look_at(Vector3(0,0,0));camera.current=true;camera.fov=66
		await snap(id+"-overview")
		camera.position=Vector3(16,9,-23);camera.look_at(Vector3(0,1,0));await snap(id+"-midfield")
		camera.queue_free();await frames(3)
		walker.get_node("Camera3D").current=true;walker.global_position=game.get_node("World/Map").spawn_pads[0]+Vector3.UP*.05
		game.hud_root.visible=true;game.phase="playing";game.phase_time=5;game.round_left=180;game.player_invuln=5
		# Actual viewport input reaches the production movement/weapon code.
		game._set_pointer_lock(true);game.set_physics_process(true);walker.set_physics_process(true)
		var before:=walker.global_position;key(KEY_W,true);mouse(true)
		for i in 24:await physics_frame
		key(KEY_W,false);mouse(false)
		for i in 4:await physics_frame
		expect(walker.global_position.distance_to(before)>.5,"actual W moves on new map")
		expect(combat.ink_amount<game.actor_ink_max(walker),"actual held fire consumes ink")
		game.set_physics_process(false);walker.set_physics_process(false);game._set_pointer_lock(false);game.paused=false
		game._update_hud();await snap(id+"-player-view")
		report.cases.append({"map":id,"blocks":game.get_node("World/Map").block_count,"scoring_cells":game.ink.turf_total,"travel":walker.global_position.distance_to(before),"ink":combat.ink_amount})
		game.perks.locked=false;game.show_preparation();bind_game()
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures
	var file:=FileAccess.open(output.path_join("maps.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	await finish("native Metal two maps, mouse selection, 1280/960 UI, actual W/fire, overview/midfield/player view, five-map pool and no area mode")
