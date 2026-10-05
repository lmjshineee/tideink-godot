extends "res://tests/godot/helpers/creative_fixture.gd"

const Setup := preload("res://src/core/match_setup.gd")
const Palette := preload("res://src/core/team_palette.gd")
var output := ""
var verify_feedback := false
var frame_ms: Array[float] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or Engine.get_architecture_name() != "arm64":
		printerr("FAIL: native arm64 display required"); quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--verify-feedback": verify_feedback = true
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: new absolute evidence directory required"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	Setup.appearance_seed = 731; Setup.style_index = 0; Setup.randomized = true
	Palette.random_palette = {}; Palette.palette_index = 0
	Setup.pending_loadout = {"player":"shooter", "settings_path":"/private/tmp/tideink-wet-unused.cfg"}
	root.size = Vector2i(1280,720)
	await prepare(5, "tidewater")
	game.paused = false; game.phase_time = 2
	for p in [Vector3(6,.08,-23), Vector3(8,.08,-24), Vector3(9,.08,-26)]:
		game.paint_at_world(p,0,2,.31)
	game.paint_at_world(Vector3(10,.08,-24),1,2.1,.63)
	game.get_node("InkView").sync_dirty()
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true
	camera.fov = 52; camera.global_position = Vector3(12,4,-19); camera.look_at(Vector3(8,.05,-24))
	await capture("ink-overview")
	camera.fov = 57; camera.global_position = Vector3(12,1.5,-20); camera.look_at(Vector3(8,.1,-25))
	await capture("ink-low-angle")
	# Uncapped fixed view; excludes load/first shader compilation, CPU AI and input.
	Engine.max_fps = 0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in 30: await RenderingServer.frame_post_draw
	var previous: int = Time.get_ticks_usec()
	for i in 120:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		frame_ms.append((now - previous) / 1000.0); previous = now
	frame_ms.sort()
	Engine.max_fps = 30
	if verify_feedback:
		walker.global_position = Vector3(0,.05,-28)
		walker.get_node("Camera3D").current = true
		game.paint_at_world(walker.global_position + Vector3.UP*.08,1,1.3,.3)
		game.get_node("InkView").sync_dirty()
		walker.grounded = true; walker.ink_owner = walker._floor_ink_owner()
		game._set_pointer_lock(true)
		expect(walker.ink_owner == 1, "actual enemy floor beneath player")
		for i in 60: game._update_player_vitals(1.0/60)
		expect(absf(game.player_health - 118) < .01, "actual two HP environmental loss")
		expect(game.presentation.incoming.entries.is_empty() and game.presentation.incoming.numeric_pops.size() == 1, "enemy ink produces a number without a hit card")
		await capture("enemy-ink-number")
		# A weapon hit remains attributable alongside the small environmental number.
		game.damage_player(12,false,bot,"shooter")
		expect(game.presentation.incoming.entries.size() == 1, "weapon retains attacker source")
		await capture("weapon-and-ink")
		root.size = Vector2i(960,540)
		game.settings.ui_scale = 1.1; game._layout_hud()
		await capture("feedback-small")
	var report := {"kind":"controlled fixed native ink views, uncapped warmed frame sample and real vitals feedback", "architecture":Engine.get_architecture_name(), "renderer":RenderingServer.get_video_adapter_api_version(), "adapter":RenderingServer.get_video_adapter_name(), "frame_sample_count":frame_ms.size(), "frame_median_ms":frame_ms[60], "frame_p95_ms":frame_ms[114], "fixture_focus_pause_overridden":true, "verify_feedback":verify_feedback, "failures":failures, "source_sha256":{}}
	for path in preload("res://tools/lib/source_inventory.gd").scripts():
		report.source_sha256[path] = FileAccess.get_sha256(path)
	for path in ["res://shaders/world/surface_ink.gdshader", "res://scenes/world/tidewater_environment.tscn"]:
		report.source_sha256[path] = FileAccess.get_sha256(path)
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	await finish("native wet ink, bounded fixed-view frame sample and environmental/weapon HUD feedback")

func capture(label: String) -> void:
	await create_timer(.12).timeout
	game.paused = false; game._update_hud()
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK, "capture "+label)
