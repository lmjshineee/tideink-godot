extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	scene.call("_start_round")
	scene.call("_set_pointer_lock", false)
	scene.call("_physics_process", 1.0)
	if not is_equal_approx(float(scene.get("round_left")), 90.0):
		_fail("pausing advanced the round clock")
		return
	scene.call("_set_pointer_lock", true)
	for step in range(360):
		scene.call("_physics_process", 0.25)
	if scene.get("phase") != "finish" or float(scene.get("round_left")) != 0.0:
		_fail("90-second round did not finish")
		return
	var ink: RefCounted = scene.get("ink")
	var blue_coverage := float(ink.call("coverage", 1))
	if blue_coverage <= 0.0:
		_fail("opponent painted no turf during the full round")
		return
	scene.call("_physics_process", 2.6)
	if scene.get("phase") != "judge" or int(scene.get("winner")) != 1:
		_fail("full-round judge did not score the opponent's turf")
		return
	scene.call("_physics_process", 5.1)
	if scene.get("phase") != "results" or scene.get("result") != String(scene.get("team_names")[1]) + "胜利":
		_fail("full round did not reach the result screen")
		return
	print("PASS: paused clock, 90-second opponent turf loop and final result")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
