extends SceneTree

# Full wall-clock round through production input and physics. Never alter the
# match clock, phase, health, ink ledger, actor positions or bot behavior.
const Setup := preload("res://src/core/match_setup.gd")
const Inventory := preload("res://tools/lib/source_inventory.gd")
var output := ""
var game: Node3D
var walker: CharacterBody3D
var combat: Node3D
var held := {}
var route := PackedVector3Array()
var route_index := 0
var goal_index := 0
var last_jump := -5.0
var ready_since := -1.0
var was_dead := false
var respawn_confirmed := false
var last_position := Vector3.ZERO
var frames := PackedFloat64Array()
var report := {
	"status":"running",
	"method":"Native wall-clock 180-second 5v5; automated keyboard/mouse input, production bots and natural timer/results/restart.",
	"limits":"One automated round is not human feel/balance, networking, long-term temperature, GPU timing or export acceptance. Frame intervals include the 30 FPS cap, screenshots and desktop scheduling. First five seconds are warmup and excluded. Any focus-pause resumes are recorded fixture actions; production focus pause is unchanged.",
	"temperature_measured":false,
	"timeline":[], "phase_events":[], "respawns":[], "focus_resumes":[],
	"travel_m":0.0, "jump_inputs":0, "dive_frames":0,
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=").simplify_path()
	if not output.begins_with("res://render-evidence/") or output == "res://render-evidence/":
		output = ""
		_fail("--output must name a new subdirectory of res://render-evidence/")
		return
	if FileAccess.file_exists(output.path_join("match.json")):
		printerr("FAIL: output already contains match.json; use a new evidence directory")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		_fail("native display required; headless cannot establish rendered frame times")
		return
	if not OS.has_feature("arm64"):
		_fail("this measurement requires native arm64")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create evidence directory")
		return
	root.size = Vector2i(1280,720)
	Setup.screen = "home"
	Setup.map_id = "tidewater"
	Setup.map_seed = 731
	Setup.map_variant = 0
	Setup.random_map = false
	Setup.team_size = 5
	Setup.duration_index = 1
	Setup.selected_item = "bomb"
	Setup.selected_perk = "balanced"
	Setup.reroll_bots = false
	Setup.pending_loadout = {"player":"shooter", "settings_path":output.path_join("isolated-settings.cfg")}
	game = (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	walker = game.get_node("World/Walker")
	combat = game.get_node("Combat")
	await _wait_frames(6)
	report["environment"] = {
		"engine":Engine.get_version_info(), "arm64":OS.has_feature("arm64"),
		"display":DisplayServer.get_name(), "adapter":RenderingServer.get_video_adapter_name(),
		"graphics_api":RenderingServer.get_video_adapter_api_version(),
		"window":[root.size.x,root.size.y], "fps_cap":Engine.max_fps,
		"physics_hz":Engine.physics_ticks_per_second, "render_scale":root.scaling_3d_scale,
		"ui_scale":game.settings.ui_scale, "map":Setup.map_id, "variant":Setup.map_variant,
		"map_seed":Setup.map_seed, "bot_kits_reroll_on_death":Setup.reroll_bots,
	}
	var hashes := {}
	var sources: Array[String] = Inventory.scripts()
	sources.append_array(["res://project.godot", "res://assets/integrity.json",
		"res://scenes/match/tidewater_play.tscn", "res://tools/measure/measure_native_match.gd"])
	for path in sources:
		hashes[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	report["source_sha256"] = hashes
	report["initial_roster"] = _roster()
	_phase("home",0.0)
	if not (await _snapshot("home")): return
	_tap(KEY_ENTER)
	await _wait_frames(3)
	if game.phase != "setup":
		_fail("Enter did not open setup")
		return
	_phase("setup",0.0)
	if not (await _snapshot("setup")): return
	_tap(KEY_ENTER)
	var startup := Time.get_ticks_msec()
	_phase(String(game.phase),0.0)
	while game.phase == "intro" and Time.get_ticks_msec()-startup < 15000:
		await process_frame
	if game.phase != "playing" or not is_equal_approx(game.round_time,180.0) or game.all_actors().size() != 10:
		_fail("normal intro must enter a 180-second round with ten actors")
		return
	_phase("playing",0.0)
	var start := Time.get_ticks_usec()
	var previous := start
	var next_sample := 0.0
	var map_saved := false
	var play_saved := false
	var respawn_saved := false
	last_position = walker.global_position
	while game.phase == "playing":
		await process_frame
		var now := Time.get_ticks_usec()
		var wall := float(now-start)/1000000.0
		var elapsed: float = game.round_time-game.round_left
		if wall > 390.0:
			_fail("full round exceeded wall-clock timeout")
			return
		if wall >= 5.0:
			frames.append(float(now-previous)/1000.0)
		previous = now
		if game.paused:
			report.focus_resumes.append({"wall_seconds":wall,"game_seconds":elapsed})
			print("AUDIT: controlled replay resumes focus pause at ",snappedf(elapsed,.01))
			game._set_pointer_lock(true)
		_drive(elapsed)
		var moved := walker.global_position.distance_to(last_position)
		if not was_dead and moved < 2.0:
			report.travel_m += moved
		last_position = walker.global_position
		if elapsed >= next_sample:
			report.timeline.append({"wall_seconds":wall,"game_seconds":elapsed,
				"remaining_seconds":game.round_left,"deaths":game.local_deaths,
				"health":game.player_health,"ink":combat.ink_amount,
				"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,
				"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,
				"static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576})
			next_sample = floorf(elapsed)+1.0
			if int(elapsed)%20 == 0:
				print("AUDIT: game=",roundi(elapsed)," wall=",roundi(wall)," deaths=",game.local_deaths)
		_key(KEY_TAB,elapsed >= 20.0 and elapsed < 22.0 and not was_dead)
		if elapsed >= 20.5 and not was_dead and not map_saved:
			if not (await _snapshot("tactical-map")): return
			map_saved = true
		if elapsed >= 30.0 and not was_dead and not play_saved:
			if not (await _snapshot("playing")): return
			play_saved = true
		if was_dead and game.respawn_ready and not respawn_saved:
			if not (await _snapshot("respawn-choice")): return
			respawn_saved = true
	_release()
	report["play_wall_seconds"] = float(Time.get_ticks_usec()-start)/1000000.0
	_phase(String(game.phase),report.play_wall_seconds)
	if game.phase != "finish" or game.round_left != 0.0:
		_fail("round must end naturally through finish at zero time")
		return
	while game.phase == "finish" and float(Time.get_ticks_usec()-start)/1000000.0 < 405.0:
		await process_frame
	if game.phase != "results":
		_fail("finish did not enter results")
		return
	_phase("results",float(Time.get_ticks_usec()-start)/1000000.0)
	await _wait_frames(8)
	if not (await _snapshot("results")): return
	var totals := [0.0,0.0]
	var roster := _roster()
	for actor in roster:
		totals[int(actor.team)] += float(actor.stats.turf)
	for team in range(2):
		if absf(totals[team]-float(game.turf_area[team])) > .01:
			_fail("individual turf does not sum to the authoritative team ledger")
			return
		if absf(float(game.judged_coverage[team])-float(game.ink.coverage(team))) > .00001:
			_fail("results coverage diverged from CPU ink ownership")
			return
	if not game.tactics.panel.visible or not game.tactics.map.visible or game.tactics.row_cells.size() != 10:
		_fail("results must show map and ten rows")
		return
	if frames.is_empty() or float(report.travel_m) < 10.0:
		_fail("replay did not produce enough rendered frames or real movement")
		return
	if report.respawns.is_empty():
		_fail("round did not exercise a natural death and explicit respawn confirmation")
		return
	var completed_respawns := 0
	for respawn in report.respawns:
		if respawn.has("landed_game_seconds"):
			if not respawn.has("confirmed_game_seconds") or float(respawn.get("wait_without_confirmation_seconds",0)) < .8:
				_fail("respawn landed without the required wait and explicit confirmation")
				return
			completed_respawns += 1
		else:
			respawn["pending_at_match_end"] = true
	if completed_respawns == 0:
		_fail("no natural death completed an explicitly confirmed respawn")
		return
	report["completed_respawns"] = completed_respawns
	var personal_area: float = walker.get_meta("match_stats")["turf"]
	if game.tactics.hint.text != "你的涂地  %.0f m² · 积分 %.0f p" % [personal_area,game.turf_total]:
		_fail("results overview must distinguish personal area from live-only points")
		return
	report["personal_turf_m2"] = personal_area
	report["live_points"] = game.turf_total
	report["points_per_m2"] = game._points_per_m2
	report["results_summary"] = game.tactics.hint.text
	report["final_roster"] = roster
	report["coverage"] = game.judged_coverage.duplicate()
	report["team_cumulative_turf_m2"] = totals
	report["player_natural_deaths"] = game.local_deaths
	report["frame_intervals_ms"] = Array(frames)
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	var slow := 0
	for value in frames:
		total += value
		if value > 50.0: slow += 1
	report["performance"] = {"samples":frames.size(),"warmup_seconds":5,
		"mean_fps":frames.size()*1000.0/total,
		"p50_frame_ms":_percentile(sorted,.50),"p95_frame_ms":_percentile(sorted,.95),
		"p99_frame_ms":_percentile(sorted,.99),"max_frame_ms":sorted[-1],"frames_over_50ms":slow}
	var hover := InputEventMouseMotion.new()
	hover.position = game.tactics.hint.get_global_transform_with_canvas()*(game.tactics.hint.size*.5)
	hover.global_position = hover.position
	hover.relative = Vector2.ONE
	root.grab_focus()
	root.push_input(hover,true)
	await create_timer(1.0).timeout
	if not (await _snapshot("results-tooltip")): return
	root.size = Vector2i(960,540)
	game.settings.ui_scale = 1.1
	game._update_hud()
	await _wait_frames(12)
	if not (await _snapshot("results-small")): return
	report["results_windows"] = [{"size":[1280,720],"ui_scale":1.0},{"size":[960,540],"ui_scale":1.1}]
	root.size = Vector2i(1280,720)
	_tap(KEY_ENTER)
	await _wait_frames(12)
	game = current_scene
	if not is_instance_valid(game) or game.phase != "home":
		_fail("results Enter did not reload home")
		return
	_phase("home",float(Time.get_ticks_usec()-start)/1000000.0)
	if not (await _snapshot("restart-home")): return
	report["status"] = "passed"
	report["checks"] = ["home/setup/intro input", "180-second natural timer", "ten actors",
		"explicit respawn confirmation after wait", "finish/results/home",
		"individual-to-team turf ledger", "CPU coverage matches results", "ten result rows", "separate personal area and live points"]
	if not _write_report(): return
	print("PASS: native arm64 full 180-second 5v5; natural death, explicit respawn, results, ledger and restart; ",output)
	quit()

func _drive(elapsed: float) -> void:
	var dead: bool = game.player_respawn > 0.0
	if dead:
		_release()
		if not was_dead:
			report.respawns.append({"death_game_seconds":elapsed,"confirmation":"Enter at aimed base destination"})
			route.clear()
			ready_since = -1.0
			respawn_confirmed = false
		was_dead = true
		if game.respawn_ready and not respawn_confirmed:
			if ready_since < 0.0:
				ready_since = elapsed
				report.respawns[-1]["ready_game_seconds"] = elapsed
			elif elapsed-ready_since >= .8:
				report.respawns[-1]["wait_without_confirmation_seconds"] = elapsed-ready_since
				report.respawns[-1]["destination_key"] = game.deployment.selected_key
				report.respawns[-1]["target"] = [game.deployment.target.x,game.deployment.target.y,game.deployment.target.z]
				_tap(KEY_ENTER)
				respawn_confirmed = true
				report.respawns[-1]["confirmed_game_seconds"] = elapsed
		return
	if was_dead:
		report.respawns[-1]["landed_game_seconds"] = elapsed
		was_dead = false
	if combat.special_ready(): _tap(KEY_F)
	if elapsed > 10.0 and fmod(elapsed,18.0) < .05: _tap(KEY_E)
	if route.is_empty() or route_index >= route.size():
		var goal := Vector3(6.0 if goal_index%2 == 0 else -6.0,0.0,[0.0,-10.0,10.0][goal_index%3])
		route = game.navigation.route(walker.global_position,goal,0)
		route_index = 1 if route.size() > 1 else 0
		goal_index += 1
	_key(KEY_W,false)
	if route_index < route.size():
		var offset := route[route_index]-walker.global_position
		if Vector2(offset.x,offset.z).length() < .45 and absf(offset.y) < .65:
			route_index += 1
		elif Vector2(offset.x,offset.z).length() > .01:
			var yaw := atan2(offset.x,offset.z)
			var look := InputEventMouseMotion.new()
			look.relative = Vector2(-wrapf(yaw-float(walker.camera_yaw),-PI,PI)/float(walker.look_sensitivity),
				(float(walker.camera_pitch)+.22)/float(walker.look_sensitivity))
			Input.parse_input_event(look)
			Input.flush_buffered_events()
			_key(KEY_W,true)
			if walker.grounded and elapsed-last_jump > 1.2 and (offset.y > .45 or int(elapsed)%7 == 0):
				_tap(KEY_SPACE)
				last_jump = elapsed
				report.jump_inputs += 1
	var squid: bool = walker.ink_owner == 0 and int(elapsed)%8 >= 5 and combat.ink_amount < 70.0
	_key(KEY_SHIFT,squid)
	if walker.squid_form: report.dive_frames += 1
	_button(not squid and combat.ink_amount > 3.0 and fmod(elapsed,3.0) < 2.0)

func _roster() -> Array:
	var roster: Array = []
	for actor in game.all_actors():
		roster.append({"id":game.actor_id(actor),"team":game.actor_team(actor),"local_player":actor==walker,
			"weapon":game.selected_weapon if actor==walker else actor.weapon_id,
			"perk":game.perks.kind(actor),"item":game.items.state(actor).kind,
			"stats":actor.get_meta("match_stats").duplicate(true)})
	return roster

func _percentile(sorted: PackedFloat64Array, fraction: float) -> float:
	return sorted[clampi(int(ceil(sorted.size()*fraction))-1,0,sorted.size()-1)]

func _phase(phase_name: String, wall: float) -> void:
	report.phase_events.append({"phase":phase_name,"seconds_since_play_start":wall})
	print("AUDIT: phase ",phase_name)

func _key(code: Key, pressed: bool) -> void:
	if held.get(code,false) == pressed: return
	held[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _button(pressed: bool) -> void:
	if held.get("mouse",false) == pressed: return
	held["mouse"] = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tap(code: Key) -> void:
	_key(code,true)
	_key(code,false)

func _release() -> void:
	for code in [KEY_W,KEY_SHIFT,KEY_SPACE,KEY_TAB]: _key(code,false)
	_button(false)

func _wait_frames(count: int) -> void:
	for i in count: await process_frame

func _snapshot(label: String) -> bool:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	if screenshot.is_empty() or screenshot.save_png(output.path_join(label+".png")) != OK:
		_fail("could not save native screenshot "+label)
		return false
	return true

func _write_report() -> bool:
	var file := FileAccess.open(output.path_join("match.json"),FileAccess.WRITE)
	if file == null:
		printerr("FAIL: cannot write match report")
		quit(1)
		return false
	file.store_string(JSON.stringify(report,"  ")+"\n")
	return true

func _fail(message: String) -> void:
	_release()
	report["status"] = "failed"
	report["failure"] = message
	if not output.is_empty() and DirAccess.dir_exists_absolute(output): _write_report()
	printerr("FAIL: ",message)
	quit(1)
