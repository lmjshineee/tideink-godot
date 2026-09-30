extends SceneTree


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	scene.call("_start_round")
	var combat: Node3D = scene.get_node("Combat")
	var ink: RefCounted = scene.get("ink")
	combat.call("tick", 0.01, false, false, true)
	if (combat.get("bombs") as Array).size() != 0:
		_fail("bomb spawned before right-button release")
		return
	combat.call("tick", 0.01, false, false, false)
	if (combat.get("bombs") as Array).size() != 1 or absf(float(combat.get("ink_amount")) - 30.0) > 0.01:
		_fail("bomb release did not use source ink cost")
		return
	var bomb: Dictionary = (combat.get("bombs") as Array)[0]
	bomb["position"] = Vector3(0.0, 3.2, 39.2)
	bomb["velocity"] = Vector3(0.0, -10.0, 0.0)
	combat.call("advance_effects", 0.12)
	if float(bomb["fuse"]) <= 0.0 or float(bomb["fuse"]) >= 0.95:
		_fail("bomb did not arm when it hit the spawn platform")
		return
	bomb["fuse"] = 0.01
	combat.call("advance_effects", 0.02)
	if (combat.get("bombs") as Array).size() != 0 or float(ink.call("coverage", 0)) <= 0.0:
		_fail("bomb explosion did not paint scoring turf")
		return
	if float(scene.get("bot_respawn")) <= 0.0:
		_fail("bomb blast did not damage the nearby opponent")
		return
	combat.set("ink_amount", 69.0)
	combat.call("tick", 0.01, false, false, true)
	combat.call("tick", 0.01, false, false, false)
	if (combat.get("bombs") as Array).size() != 0 or float(combat.get("ink_amount")) >= 70.0:
		_fail("bomb was thrown without enough ink")
		return
	print("PASS: bomb input, ink cost, landing fuse, turf paint, blast damage and low-ink gate")
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
