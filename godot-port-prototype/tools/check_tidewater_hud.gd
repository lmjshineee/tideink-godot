extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var size := scene.get_viewport().get_visible_rect().size
	var score: Panel = scene.get("score_panel")
	var menu: Panel = scene.get("menu_panel")
	var result: Panel = scene.get("result_panel")
	if not menu.visible or result.visible or absf(score.position.x + score.size.x * 0.5 - size.x * 0.5) > 1.0:
		_fail("setup HUD has an off-center score panel or wrong overlay visibility")
		return
	scene.call("_start_round")
	var combat: Node3D = scene.get_node("Combat")
	var ink: RefCounted = scene.get("ink")
	var face: Dictionary = ink.get("surfaces")[12]
	ink.call("splat_face", 12, float(face["su"]) * 0.5, float(face["sv"]) * 0.5, 1.1, 0, 0.5)
	combat.set("ink_amount", 37.0)
	combat.set("special_points", 190.0)
	scene.set("player_health", 64.0)
	scene.set("round_left", 9.4)
	scene.call("_update_hud")
	if (scene.get("timer_label") as Label).text != "0:10" or not (scene.get("hud") as Label).text.contains("最后 10 秒"):
		_fail("timer or final countdown does not match round state")
		return
	var status: Label = scene.get("hud")
	if status.get_theme_font("font").get_string_size(status.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		status.get_theme_font_size("font_size")).x > status.size.x:
		_fail("status controls overflow the 1280-wide demo viewport")
		return
	if absf(float((scene.get("orange_bar") as ProgressBar).value) - float(ink.call("coverage", 0)) * 100.0) > 0.01:
		_fail("score bar does not read authoritative ink coverage")
		return
	if absf(float((scene.get("ink_bar") as ProgressBar).value) - 37.0) > 0.01 \
		or absf(float((scene.get("health_bar") as ProgressBar).value) - 64.0) > 0.01:
		_fail("ink or health meter does not read live combat state")
		return
	if absf(float((scene.get("special_bar") as ProgressBar).value) - 100.0) > 0.01 \
		or not (scene.get("special_label") as Label).text.contains("F/Q"):
		_fail("special meter does not show the ready input")
		return
	scene.call("_finish_round")
	if not result.visible or (scene.get("crosshair") as Label).visible:
		_fail("finish overlay or crosshair visibility")
		return
	scene.call("_judge_round")
	if not (scene.get("result_label") as Label).text.contains(String(scene.get("team_names")[0]) + "胜利"):
		_fail("result panel does not show the judge result")
		return
	print("PASS: HUD layout, score/time/ink/health/special bindings and phase overlays")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
