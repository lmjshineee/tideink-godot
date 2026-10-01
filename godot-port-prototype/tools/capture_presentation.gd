extends SceneTree
var mouse_notified := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: native display required"); quit(1); return
	root.size = Vector2i(1280,720)
	preload("res://match_setup.gd").team_size = 5
	var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	game.set("settings_path","/private/tmp/inkwave-presentation-gui.cfg")
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	await frames(3)
	var music: AudioStreamPlayer = game.get("sound").get("music_player")
	if not music.playing or music.get_playback_position() <= 0:
		printerr("FAIL: native audio playback did not advance"); quit(1); return
	await save("menu")
	game.call("_open_settings")
	await frames(2)
	await save("settings")
	game.get("settings_panel").call("close_panel")
	game.call("show_preparation")
	await frames(2)
	await click(game.get("frontend").get("preparation").get_node("Actions").get_child(1))
	if game.get("phase") != "intro":
		printerr("FAIL: start mouse input"); quit(1); return
	game.get("sound").call("sync",0.1)
	await frames(8)
	await save("lineup")
	game.set("phase_time",3.2)
	game.call("_update_hud")
	await frames(2)
	await save("ready")
	game.call("_start_round")
	game.get("sound").call("sync",0.1)
	await frames(2)
	await save("go")
	game.set("phase_time",2.0)
	game.call("_update_hud")
	await frames(2)
	await save("hud")
	game.call("damage_actor",game.get_node("World/Walker"),100.0,1,game.get("extra_bots")[5],"blaster")
	game.call("_update_hud")
	await frames(2)
	await save("death")
	await click(game.get("weapon_buttons")["charger"])
	if game.get("selected_weapon") != "charger":
		printerr("FAIL: full-screen death intercepted loadout mouse input"); quit(1); return
	game.get("settings").set("ui_scale",1.1)
	root.size = Vector2i(960,540)
	game.call("_layout_hud")
	game.call("_update_hud")
	await frames(2)
	await save("death-small")
	game.call("_update_player_respawn",6.0)
	game.call("_finish_round")
	game.call("_judge_round")
	game.set("phase","results")
	game.get("sound").call("sync",0.1)
	game.call("_update_hud")
	await frames(12)
	await save("results")
	var replay := (game.get("result_actions") as Control).get_child(0) as Button
	await click(replay)
	await frames(3)
	if current_scene.get("phase") != "setup":
		printerr("FAIL: full-screen results replay mouse input"); quit(1); return
	print("PASS: native audio playback advances; full-screen lineup/READY/GO/death/results, mouse start/death loadout/replay, 110% UI at 960x540; phase/damage fixtures, not full-match manual acceptance")
	quit()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var prefix := "feedback8-" if OS.get_cmdline_user_args().has("--feedback8") else "clean-" if OS.get_cmdline_user_args().has("--clean") else "restored-" if OS.get_cmdline_user_args().has("--restored") else "original-" if OS.get_cmdline_user_args().has("--original") else "presentation-"
	root.get_texture().get_image().save_png("res://render-evidence/"+prefix+label+".png")

func click(control: Control) -> void:
	var position := control.get_global_transform_with_canvas()*(control.size*0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.relative = Vector2(1,1)
	root.push_input(motion,true)
	await frames(2)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		root.push_input(event,true)
		await frames(1)
