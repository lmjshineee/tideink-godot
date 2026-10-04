extends SceneTree

# Verify responsive behavior and resource reuse through the actual scene/UI.
var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func tab(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.physical_keycode = KEY_TAB
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	game._update_hud()

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/inkwave-cleanup-" + label + ".png"
	expect(root.get_texture().get_image().save_png(path) == OK, "save " + label)
	print("CAPTURE: ", path)

func _run() -> void:
	var initial_resize_connections := root.get_signal_connection_list("size_changed").size()
	var setup := preload("res://src/core/match_setup.gd")
	setup.screen = "setup"
	setup.team_size = 5
	setup.selected_perk = "balanced"
	setup.pending_loadout = {"player": "shooter"}
	game = (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.get_node("World/Walker").set_physics_process(false)
	var result_style: StyleBox = game.result_panel.get_theme_stylebox("panel")
	for dimensions in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size = dimensions
		game.settings.ui_scale = 1.1
		await process_frame
		game._layout_hud()
		game.show_preparation()
		expect(game.frontend.preparation.visible, "preparation survives HUD extraction")
		await capture("setup-%d" % dimensions.x)
		game._start_round()
		game._set_pointer_lock(false)
		game.paused = false
		game.player_health = 64
		game.get_node("Combat").ink_amount = 37
		game.roster_rows[0].text = "hidden sentinel"
		game._update_hud()
		var timer_rect: Rect2 = game.score_panel.get_rect()
		var result_rect: Rect2 = game.result_panel.get_rect()
		for i in 100:
			game._update_hud()
		expect(game.result_panel.get_theme_stylebox("panel") == result_style,
			"HUD refresh must reuse the result style resource")
		expect(game.score_panel.get_rect() == timer_rect and game.result_panel.get_rect() == result_rect,
			"refresh preserves responsive geometry")
		expect(game.roster_rows[0].text == "hidden sentinel", "hidden roster skips row refresh")
		game.player_health = 55
		tab(true)
		expect(game.scoreboard_panel.visible and game.roster_rows[0].text.contains("生命 55"),
			"opening Tab reads current health immediately")
		tab(false)
		expect(not game.scoreboard_panel.visible, "releasing Tab closes tactical list")
		expect(absf(game.health_bar.value - 55.0 / 120.0 * 100.0) < .01,
			"live health bindings remain intact")
		await capture("playing-%d" % dimensions.x)
		game._finish_round()
		game._judge_round()
		expect(game.result_panel.visible and game.result_actions.visible,
			"results preserve return/quit controls")
		await capture("results-%d" % dimensions.x)
	game.queue_free()
	await process_frame
	expect(root.get_signal_connection_list("size_changed").size() == initial_resize_connections,
		"scene teardown disconnects HUD resize callbacks")
	root.size = Vector2i(1100,650)
	await process_frame
	if failures.is_empty():
		print("PASS: HUD resource reuse, responsive layout, hidden roster, live Tab/health/results and scene teardown")
	quit(0 if failures.is_empty() else 1)
