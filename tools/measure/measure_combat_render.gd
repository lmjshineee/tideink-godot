extends SceneTree
# Controlled ten-actor combat view. Measures per-frame rendering, not temperature
# or a natural round. One process/case; never writes the player's saved settings.
const Setup := preload("res://src/core/match_setup.gd")
var output := ""
var fps := 60
var lod := 6.0
var hide_characters := false
var models: Array[Node3D] = []

func _initialize() -> void: call_deferred("_run")

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(_meshes(child))
	return result

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--fps="): fps=int(arg.trim_prefix("--fps="))
		if arg.begins_with("--lod="): lod=float(arg.trim_prefix("--lod="))
		if arg=="--hide-characters": hide_characters=true
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or fps not in [30,60]:
		printerr("FAIL: native arm64/new absolute output/30 or 60 FPS required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	seed(7219)
	Setup.randomized=true;Setup.style_index=0;Setup.appearance_seed=419
	Setup.map_id="tidewater";Setup.random_map=false;Setup.map_seed=731;Setup.map_variant=0
	Setup.team_size=5;Setup.screen="home";Setup.reroll_bots=false
	Setup.pending_loadout={"player":"shooter","settings_path":output.path_join("isolated.cfg")}
	preload("res://src/core/team_palette.gd").select(0)
	root.size=Vector2i(1280,720)
	var game: Node3D=(load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game);current_scene=game
	game._start_round();game.phase_time=5.0;game._update_hud();game.frontend.sync();game.settings.fps_cap=fps;game.settings.render_scale=1.0
	game.settings.apply_to(game.get_node("World/Walker"));Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.process_mode=Node.PROCESS_MODE_DISABLED
	var index:=0
	for actor in game.all_actors():
		# Raised controlled platform avoids stage obstacles hiding the ten actors.
		actor.position=Vector3((index%5-2)*1.5,12.06,9+floori(index/5.0)*5)
		var body: Node3D=actor.get_node("Body")
		# Deterministic body/seed instead of the normal entropy-based roster.
		var replacement: Node3D=preload("res://src/actors/tidewater_character_visual.gd").new()
		replacement.style_index=index%4;replacement.team=game.actor_team(actor);replacement.ornament_seed=419+index
		actor.remove_child(body);body.free();replacement.name="Body";actor.add_child(replacement)
		replacement.rotation.y=PI;replacement.set_weapon("shooter");replacement.set_physics_process(false)
		replacement.visible=not hide_characters
		if lod>0:
			for mesh in _meshes(replacement): mesh.lod_bias=lod
		models.append(replacement);index+=1
	var camera: Camera3D=game.get_node("World/Walker/Camera3D")
	camera.global_position=Vector3(0,14.0,0);camera.look_at(Vector3(0,13.0,12));camera.current=true
	for p in [Vector3(-3,0.2,10),Vector3(3,0.2,14)]: game.paint_at_world(p,0,3.5,0.5)
	game.get_node("InkView").sync_dirty()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 90:
		game.paused=false;game.pause_panel.visible=false;game.presentation.queue_redraw()
		await RenderingServer.frame_post_draw
	var frames: Array[float]=[];var cpu: Array[float]=[];var gpu: Array[float]=[];var primitives: Array[float]=[];var draws: Array[float]=[]
	var last:=Time.get_ticks_usec()
	for i in 240:
		game.paused=false;game.pause_panel.visible=false;game.presentation.queue_redraw()
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		primitives.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		draws.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	game.paused=false;game.pause_panel.visible=false;game.presentation.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("combat.png"))
	for samples in [frames,cpu,gpu,primitives,draws]: samples.sort()
	var report: Dictionary={"engine":Engine.get_version_info(),"arm64":OS.has_feature("arm64"),"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"fps_cap":Engine.max_fps,"render_scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"lod_override":lod,"characters_hidden":hide_characters,"actors":10,"samples":240,"frame_median_ms":frames[120],"frame_p95_ms":frames[228],"render_cpu_median_ms":cpu[120],"render_gpu_median_ms":gpu[120],"primitives_median":primitives[120],"draws_median":draws[120],"temperature_measured":false,"note":"Ten actors raised above the map to avoid occlusion; actors/AI/animation paused; focus pause overlay suppressed by fixture. Render cost excludes startup. Zero GPU timing means unavailable. Frame times include cap/desktop scheduling; clock/power state unmeasured. Not a sustained thermal or natural-match result."}
	var file:=FileAccess.open(output.path_join("render.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PASS: controlled combat render "+JSON.stringify(report))
	game.queue_free();await process_frame;await process_frame;quit()
