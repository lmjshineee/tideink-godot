extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message);printerr("FAIL: ",message)
func _run() -> void:
	var setup := preload("res://src/core/match_setup.gd")
	setup.team_size = 5
	for map_id in ["tidewater","kelpline"]:
		setup.map_id = map_id
		var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
		root.add_child(game)
		await physics_frame
		game.set_physics_process(false)
		var walker: CharacterBody3D = game.get_node("World/Walker")
		walker.set_physics_process(false)
		for actor in game.all_actors(): game.perks.choices[actor.get_instance_id()]="balanced"
		game._start_round()
		var names := {}
		for actor in game.all_actors():
			var label: String = game.actor_name(actor)
			expect(not label.is_empty() and not names.has(label),"every actor has a distinct name")
			names[label] = true
			if actor!=walker:
				expect(actor.identity_label.text.contains(label),"head label contains bot name")
		var bot: Node3D = game.get_node("Bot")
		var stable_name: String = game.actor_name(bot)
		game.player_health=100
		game.damage_player(200,false,bot,"shooter")
		expect(game.deployment.active and game.player_respawn==4 and not game.respawn_ready,"launcher is visible immediately, with full countdown")
		expect(game.presentation.death_by.contains(stable_name),"knockout displays actual attacker name")
		var before: Vector3 = game.deployment.target
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(75,-25)
		game._input(motion)
		var chosen: Vector3 = game.deployment.target
		expect(chosen!=before,"can aim before countdown completes")
		game.launch_respawn()
		game._update_player_respawn(1)
		expect(game.player_respawn==3 and not game.deployment.flying and game.deployment.queued,"early launch preserves countdown and queues the chosen point")
		game._update_player_respawn(3.8)
		expect(game.player_respawn==0 and walker.global_position.distance_to(chosen)<0.1,"queued target used after countdown")
		game.player_invuln = 0
		var combat: Node3D = game.get_node("Combat")
		# Isolate the actual damage rules at an open point, away from bystanders.
		for actor in game.extra_bots: actor.global_position=Vector3(60,30,60)
		walker.global_position = Vector3(0,2.25,36)
		bot.global_position = walker.global_position+Vector3(0.1,0,0)
		bot.call("select_weapon","shooter")
		game.bot_specials.charge(bot,160)
		game.bot_specials.tick(0.01)
		expect(game.bot_specials.busy(bot),"charged enemy starts slam windup")
		expect(game.player_health==120,"telegraph precedes impact damage")
		game.bot_specials.tick(0.5)
		expect(bot.get_node("Body").position.y>1 and game.player_health==120,"windup is visible and can be countered")
		game.bot_specials.tick(0.4)
		expect(game.player_respawn>0 and game.presentation.death_by.contains(stable_name) and game.presentation.death_by.contains("砸地"),"enemy slam uses actual name and shared damage")
		expect(game.bot_specials.state(bot)["points"]==0,"slam cannot recharge itself")
		expect(game.actor_name(bot)==stable_name,"name survives kit changes")
		game.launch_respawn();game._update_player_respawn(5)
		game.player_invuln=0
		walker.global_position=Vector3(0,2.25,36)
		game.player_health=120
		bot.global_position=walker.global_position+Vector3(0.1,0,0)
		var bot_hp: float = game.bot_health
		combat._spawn_cloud(walker.global_position,Vector3.ZERO,1,bot)
		combat._update_clouds(1.0)
		expect(absf(game.player_health-78)<0.01 and game.bot_health==bot_hp,"enemy rain hurts opponents only at shared 42 DPS")
		expect(game.bot_specials.state(bot)["points"]==0,"enemy rain cannot charge meter")
		var ally: Node3D = game.extra_bots[0]
		ally.global_position=walker.global_position
		expect(game.bot_specials.escape(ally).length()>0,"bot chooses escape route for enemy rain")
		combat._spawn_cloud(walker.global_position,Vector3.ZERO,0,ally)
		combat._spawn_cloud(walker.global_position,Vector3.ZERO,0,ally)
		expect(combat.clouds.size()==2,"mixed-team clouds remain bounded")
		game.damage_bot(1000)
		game._update_bot(6)
		expect(game.actor_name(bot)==stable_name,"respawn does not rename actor")
		game.queue_free();await process_frame
	if failures.is_empty():print("PASS: unique original names/head labels/attribution, immediate countdown aiming and queued launch, enemy telegraph/slam/rain/friendly fire/meter/dodge, stable respawn names")
	quit(0 if failures.is_empty() else 1)
