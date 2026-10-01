extends SceneTree

# Native UI fixture: replay measured actor stats into a controlled result screen.
const Setup := preload("res://match_setup.gd")
var failures: Array[String] = []
var data_path := "res://render-evidence/match-loadouts-case-0.json"
var output_path := "res://render-evidence"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--data="): data_path = arg.trim_prefix("--data=")
		if arg.begins_with("--outdir="): output_path = arg.trim_prefix("--outdir=")
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: native display required")
		quit(1)
		return
	Setup.team_size = 5
	Setup.map_id = "tidewater"
	Setup.map_variant = 0
	Setup.screen = "home"
	Setup.pending_loadout = {"settings_path":"/private/tmp/inkwave-turf-results-unused.cfg"}
	var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.get_node("World/Walker").set_physics_process(false)
	var measured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	for actor in game.all_actors():
		for sample in measured.rounds[0].actors:
			if int(sample.id) == game.actor_id(actor):
				actor.set_meta("match_stats",sample.stats.duplicate(true))
				if actor != game.get_node("World/Walker"):
					actor.select_weapon(sample.weapon)
	# Only result layout is under test; this controlled ink fixture is not a full match.
	game.paint_at_world(Vector3(0,2.5,-38),0,3.0,0.5)
	game.paint_at_world(Vector3(0,2.5,36),1,3.0,0.5)
	for actor in game.all_actors():
		for sample in measured.rounds[0].actors:
			if int(sample.id) == game.actor_id(actor):
				actor.set_meta("match_stats",sample.stats.duplicate(true))
				if sample.local_player:
					game.turf_total = float(sample.stats.turf)*game._points_per_m2
	game._finish_round()
	game._judge_round()
	for spec in [[1280,720,1.0],[960,540,1.1]]:
		root.size = Vector2i(spec[0],spec[1])
		root.content_scale_size = root.size
		game.settings.ui_scale = spec[2]
		for i in range(4):
			await process_frame
		game._layout_hud()
		game._update_hud()
		for i in range(8):
			await process_frame
		RenderingServer.force_draw(false)
		var panel: Panel = game.tactics.panel
		var panel_rect := panel.get_global_rect()
		var contained := true
		for row in game.tactics.row_panels:
			contained = contained and panel_rect.grow(0.5).encloses(row.get_global_rect())
			for cell in row.get_children():
				contained = contained and row.get_global_rect().grow(0.5).encloses(cell.get_global_rect())
		var overlap: bool = panel_rect.intersects(game.tactics.map.get_global_rect()) or panel_rect.intersects(game.result_actions.get_global_rect())
		print("AUDIT: ",spec," panel=",panel_rect," map=",game.tactics.map.get_global_rect()," map_texture=",game.tactics.map.map_image.get_global_rect()," rows_contained=",contained," overlap=",overlap)
		if not contained or overlap:
			failures.append("results data/map overflow at %s" % [spec])
		root.get_texture().get_image().save_png(output_path.path_join("turf-results-%dx%d.png" % [spec[0],spec[1]]))
	# The new table must not intercept the existing return button's real mouse input.
	var button: Button = game.result_actions.get_child(0)
	var point := button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	for i in range(4):
		await process_frame
	game = current_scene
	if game.phase != "home":
		failures.append("native return button did not reach the home menu")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: native 5v5 turf result columns fit 1280x720 and 960x540 / 110%, enlarged borderless map, mouse return button; measured stats, controlled ink/result fixture")
	else:
		for message in failures:
			printerr("FAIL: ",message)
	quit(0 if failures.is_empty() else 1)
