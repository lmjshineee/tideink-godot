extends SceneTree

# Short controlled native release probe. The timer is shortened for results;
# this is not a full match or a performance/human-play acceptance test.
var output := ""
var require_pack := false
var game: Node3D
var report := {"method":"Controlled native home/setup/input/results/restart; short timer, not a natural full match.","status":"running"}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--require-pack": require_pack = true
	if not output.is_absolute_path() or FileAccess.file_exists(output.path_join("native-ui.json")):
		_fail("use a new absolute output directory");return
	if DisplayServer.get_name() == "headless" or not OS.has_feature("arm64"):
		_fail("native arm64 display required");return
	if ProjectSettings.get_setting("application/config/name") != "TideInk" or ProjectSettings.get_setting("application/config/version") != "0.3.0-preview.16":
		_fail("unexpected exported project identity");return
	if require_pack and (FileAccess.file_exists("res://tools/run_checks.sh") or DirAccess.dir_exists_absolute("res://tests") or DirAccess.dir_exists_absolute("res://experiments")):
		_fail("pack includes excluded maintenance/experimental files");return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.grab_focus()
	var setup = load("res://src/core/match_setup.gd")
	setup.screen = "home";setup.team_size = 5;setup.duration_index = 1
	setup.map_id = "tidewater";setup.random_map = false;setup.map_seed = 731
	setup.selected_item = "bomb";setup.selected_perk = "balanced"
	setup.pending_loadout = {"player":"shooter","settings_path":output.path_join("isolated-settings.cfg")}
	game = (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game);current_scene = game
	await _frames(12)
	if game.phase != "home" or game.frontend.heading.text != "TIDEINK":
		_fail("home identity failed");return
	report["environment"] = {"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"graphics_api":RenderingServer.get_video_adapter_api_version(),"arm64":OS.has_feature("arm64"),"require_pack":require_pack}
	report["name"] = ProjectSettings.get_setting("application/config/name")
	report["version"] = ProjectSettings.get_setting("application/config/version")
	report["catalog"] = [game.weapon_order.size(),game.items.KINDS.size(),game.perks.ORDER.size()]
	if report.catalog != [8,9,8]: _fail("incorrect active catalog");return
	await _snapshot("home")
	_tap(KEY_ENTER);await _frames(8)
	if game.phase != "setup": _fail("Enter failed to open setup");return
	await _snapshot("setup")
	root.size = Vector2i(960,540);game.settings.ui_scale = 1.1;await _frames(8)
	await _snapshot("setup-small")
	root.size = Vector2i(1280,720);game.settings.ui_scale = 1.0;await _frames(4)
	_tap(KEY_ENTER)
	var start := Time.get_ticks_msec()
	while game.phase != "playing" and Time.get_ticks_msec()-start < 12000:
		await process_frame
	if game.phase != "playing" or game.all_actors().size() != 10:
		_fail("normal intro did not enter 5v5");return
	var walker: CharacterBody3D = game.get_node("World/Walker")
	var before := walker.global_position
	_key(KEY_W,true)
	var button := InputEventMouseButton.new();button.button_index = MOUSE_BUTTON_LEFT;button.pressed = true
	Input.parse_input_event(button);Input.flush_buffered_events()
	await _frames(35)
	_key(KEY_W,false);button.pressed = false;Input.parse_input_event(button);Input.flush_buffered_events()
	report["travel_m"] = before.distance_to(walker.global_position)
	if float(report.travel_m) < 0.5: _fail("native movement input failed");return
	await _snapshot("playing")
	game.round_left = 0.01 # Explicit controlled fixture; not natural match evidence.
	start = Time.get_ticks_msec()
	while game.phase != "results" and Time.get_ticks_msec()-start < 8000:
		await process_frame
	if game.phase != "results": _fail("results failed");return
	await _frames(6) # The UI consumes the phase on its following process frames.
	report["result_summary"] = game.tactics.hint.text
	if not String(report.result_summary).contains("m²") or not String(report.result_summary).contains("p"):
		_fail("area/points units missing from exported results");return
	await _snapshot("results")
	root.size = Vector2i(960,540);game.settings.ui_scale = 1.1;await _frames(8)
	await _snapshot("results-small")
	_tap(KEY_ENTER);await _frames(10)
	game = current_scene as Node3D # Restart reloads the production scene.
	if game.phase != "home": _fail("results Enter failed to return home");return
	report["status"] = "passed"
	_write()
	print("PASS: TideInk native identity, 8/9/8, two sizes, real input, controlled results and restart")
	quit()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new();event.keycode = code;event.physical_keycode = code;event.pressed = pressed
	Input.parse_input_event(event);Input.flush_buffered_events()

func _tap(code: Key) -> void:
	_key(code,true);_key(code,false)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(name+".png"))
	if result != OK: _fail("cannot save native image: "+name)

func _write() -> void:
	var file := FileAccess.open(output.path_join("native-ui.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"  ")+"\n")

func _fail(message: String) -> void:
	report["status"] = "failed";report["failure"] = message
	if not output.is_empty() and DirAccess.dir_exists_absolute(output): _write()
	printerr("FAIL: ",message);quit(1)
