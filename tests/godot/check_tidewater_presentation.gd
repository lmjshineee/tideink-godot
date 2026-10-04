extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	preload("res://src/core/match_setup.gd").team_size = 5
	var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	game.set("settings_path","/private/tmp/inkwave-presentation-test.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	var overlay: Control = game.get("presentation")
	var sound: Node = game.get("sound")
	if (sound.get("manifest")["sounds"] as Dictionary).size() != 68:
		fail("missing original audio"); return
	for id in sound.get("manifest")["sounds"]:
		var stream: AudioStreamWAV = sound.call("_stream",id)
		if stream == null or stream.get_length() <= 0 or stream.data.is_empty():
			fail("unplayable sound "+id); return
	game.call("_begin_intro")
	sound.call("sync",0.1)
	if overlay.get("display_phase") != "intro" or not (overlay.get("portraits") as Control).visible:
		fail("intro did not show team characters"); return
	game.call("_start_round")
	sound.call("sync",0.1)
	game.set("bot_painting",true)
	game.call("damage_bot",1.0)
	if float(overlay.get("hit_flash")) > 0:
		fail("teammate hit incorrectly flashes local reticle"); return
	game.set("bot_painting",false)
	game.call("damage_bot",1.0)
	if float(overlay.get("hit_flash")) <= 0:
		fail("local hit missing reticle feedback"); return
	if sound.get("music_track") != "battle":
		fail("battle music transition"); return
	game.set("round_left",59.0)
	sound.call("sync",0.1)
	if sound.get("music_track") != "battle_final":
		fail("last-minute music transition"); return
	game.call("damage_player",200.0)
	game.call("_update_hud")
	sound.call("sync",0.1)
	if (game.get("menu_panel") as Control).visible or (game.get("crosshair") as Control).visible:
		fail("death loadout/crosshair visibility"); return
	for scale in [0.9,1.0,1.1]:
		game.get("settings").set("ui_scale",scale)
		for viewport_size in [Vector2i(1280,720),Vector2i(960,540)]:
			root.size = viewport_size
			root.content_scale_size = viewport_size
			await process_frame
			game.call("_layout_hud")
			game.call("_update_hud")
			var actual := overlay.size * (game.get("hud_root") as Control).scale
			if actual.distance_to(Vector2(viewport_size)) > 1:
				fail("full-screen overlay does not cover viewport: %s / %s" % [actual,viewport_size]); return
	game.call("_choose_player_weapon","roller")
	game.call("launch_respawn")
	game.call("_update_player_respawn",6.0)
	game.call("_update_hud")
	sound.call("sync",0.1)
	if game.get("selected_weapon") != "roller" or game.get("player_respawn") > 0:
		fail("death loadout/respawn flow"); return
	game.call("_finish_round")
	sound.call("sync",0.1)
	game.call("_judge_round")
	sound.call("sync",0.1)
	if game.get("phase") != "results" or overlay.get("display_phase") != "results" or not String(sound.get("music_track")).begins_with("results_") or not (game.get("result_actions") as Control).visible:
		fail("immediate result presentation, music or replay controls"); return
	var model := preload("res://src/ui/tidewater_settings.gd").new()
	model.master_volume = 0.0
	model.music_volume = 0.32
	model.sfx_volume = 0.71
	model.save_to("/private/tmp/inkwave-presentation-test.cfg")
	var restored := preload("res://src/ui/tidewater_settings.gd").new()
	restored.load_from("/private/tmp/inkwave-presentation-test.cfg")
	sound.call("apply_settings",restored)
	if restored.music_volume != 0.32 or restored.sfx_volume != 0.71 or AudioServer.get_bus_volume_db(0) > -70:
		fail("volume persistence/mute"); return
	DirAccess.remove_absolute("/private/tmp/inkwave-presentation-test.cfg")
	var visual: Node3D = game.get_node("World/Walker/Body")
	var skeleton: Skeleton3D = visual.get("skeleton")
	visual.call("set_dance","victory",2)
	visual.call("_animate",0.2)
	var pose := skeleton.get_bone_pose_rotation(skeleton.find_bone("uArmL"))
	visual.call("_animate",0.2)
	if pose.is_equal_approx(skeleton.get_bone_pose_rotation(skeleton.find_bone("uArmL"))):
		fail("original result dance does not animate actual rig"); return
	print("PASS: 68 playable original sounds, music phase/last-minute transitions, full-screen intro/death/results at six size/scale combinations, death loadout/respawn, volume persistence and original result bone animation")
	quit()

func fail(message: String) -> void:
	printerr("FAIL: ",message)
	quit(1)
