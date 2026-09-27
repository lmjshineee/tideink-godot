extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	var ink: RefCounted = scene.get("ink")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	scene.call("_input", enter)
	if scene.get("phase") != "intro" or bool(walker.get("active")):
		_fail("Enter did not start a frozen intro")
		return
	scene.call("_physics_process", 4.1)
	if scene.get("phase") != "intro" or float(scene.get("round_left")) != 90.0:
		_fail("intro shortened the round timer")
		return
	scene.call("_physics_process", 0.2)
	if scene.get("phase") != "playing" or not bool(walker.get("active")) or float(scene.get("player_invuln")) != 0.0:
		_fail("intro did not enter unprotected initial play")
		return
	var face: Dictionary = ink.get("surfaces")[12]
	if float(ink.call("splat_face", 12, float(face["su"]) * 0.5, float(face["sv"]) * 0.5, 0.6, 0, 0.5)) <= 0.0:
		_fail("could not prepare orange turf for judging")
		return
	scene.set("round_left", 9.4)
	scene.call("_update_hud")
	if not (scene.get("hud") as Label).text.contains("最后 10 秒"):
		_fail("final countdown did not use the source threshold")
		return
	scene.set("round_left", 0.05)
	var before_bot := float(scene.get("bot_health"))
	scene.call("_physics_process", 0.1)
	if scene.get("phase") != "finish" or float(scene.get("round_left")) != 0.0 or bool(walker.get("active")):
		_fail("time up did not freeze the match")
		return
	scene.call("damage_bot", 10.0)
	if float(scene.get("bot_health")) != before_bot:
		_fail("damage continued during the finish phase")
		return
	scene.call("_physics_process", 2.5)
	if scene.get("phase") != "finish":
		_fail("finish pause ended too early")
		return
	scene.call("_physics_process", 0.2)
	if scene.get("phase") != "judge" or int(scene.get("winner")) != 0 or scene.get("result") != "橙队胜利":
		_fail("judge did not use the authoritative turf coverage")
		return
	scene.call("_physics_process", 5.0)
	if scene.get("phase") != "judge":
		_fail("judge reveal ended too early")
		return
	scene.call("_physics_process", 0.2)
	if scene.get("phase") != "results":
		_fail("judge did not reach results")
		return

	var tied := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(tied)
	tied.call("_start_round")
	tied.set("round_left", 0.01)
	tied.call("_physics_process", 0.02)
	tied.call("_physics_process", 2.7)
	if tied.get("phase") != "judge" or int(tied.get("winner")) not in [0, 1] or tied.get("result") == "平局":
		_fail("equal coverage did not resolve to a source-style winner")
		return
	print("PASS: intro, final countdown, frozen finish, turf judge, tie-break and results")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
