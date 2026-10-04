extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var setup := preload("res://src/core/match_setup.gd")
	setup.team_size = 5
	var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	var combat: Node3D = game.get_node("Combat")
	var walker: Node3D = game.get_node("World/Walker")
	walker.set_physics_process(false)
	for kind in ["blaster","charger","roller"]:
		game._start_round()
		for actor in game.all_actors():
			if actor!=walker: actor.global_position=Vector3(60,30,60)
		walker.global_position=Vector3(0,2.25,36)
		game.player_invuln=0
		var from := Vector3(0,3.25,34)
		if kind=="charger":
			combat.fire_bot_charger(from,walker.global_position+Vector3.UP,1,1,game.get_node("Bot"))
		elif kind=="blaster":
			combat._spawn_projectile("blaster",from,Vector3(0,0,23),combat.weapons["blaster"],1,game.get_node("Bot"))
			combat._update_projectiles(0.12)
		else:
			combat.spawn_bot_flick(Vector3(0,3.4,35),walker.global_position+Vector3.UP,1,game.get_node("Bot"))
			for step in range(160):combat._update_projectiles(0.01)
		print("AUDIT: single ",kind," attack HP=",game.player_health," respawn=",game.player_respawn)
		if game.player_respawn>0: failures.append("Full-health actor survives a single normal "+kind+" attack")
		if kind=="roller" and game.player_health<40: failures.append("A flick volley has one shared victim damage budget")
	if failures.is_empty(): print("PASS: normal direct hits and a whole roller volley cannot silently one-shot full health")
	else:
		for failure in failures: printerr("FAIL: ",failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
