extends SceneTree

var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _run() -> void:
	var setup := preload("res://match_setup.gd")
	setup.team_size = 5
	for map_id in ["tidewater","kelpline"]:
		setup.map_id = map_id
		var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
		root.add_child(game)
		await physics_frame
		game.set_physics_process(false)
		var walker: CharacterBody3D = game.get_node("World/Walker")
		walker.set_physics_process(false)
		for actor in game.all_actors(): game.perks.choices[actor.get_instance_id()]="balanced"
		game._start_round()
		var combat: Node3D = game.get_node("Combat")
		var bot: Node3D = game.get_node("Bot")
		expect(game.player_health==120 and game.bot_health==120,"equal 120 HP for player/main opponent")
		for actor in game.extra_bots:
			expect(game.actor_health(actor)==120,"equal 120 HP for every ally/opponent")
		var walker_items: Dictionary = game.items.state(walker)
		var place := Vector3(0,2.25,36)
		game.player_health = 85
		combat.set("ink_amount",10)
		game.items.equip(walker,"refill")
		expect(game.items.use(walker),"equipped refill usable")
		expect(game.player_health==120 and combat.get("ink_amount")==85,"refill heals 35 HP and 75 ink")
		expect(not game.items.use(walker),"cooldown rejects repeated use")
		expect(not game.items.use(walker,"shield"),"cannot use unequipped item")
		game.items.tick(12.1)
		game.player_health = 85
		expect(game.items.use(walker),"refill is reusable without pickup after CD")
		game.items.equip(walker,"shield")
		expect(game.items.use(walker),"shield usable")
		game.damage_player(70,false,bot,"shooter")
		expect(game.player_health==110 and walker_items["armor"]==0,"shield absorbs 60 then breaks")
		walker_items["armor"] = 30.0
		walker_items["time"] = 0.01
		game.items.tick(0.02)
		expect(walker_items["armor"]==0,"shield expires")
		game.player_health = 120
		game.damage_player(30,false,bot,"shooter")
		game.damage_player(30,false,bot,"shooter")
		game.damage_player(30,false,bot,"shooter")
		expect(game.player_health==30 and game.player_respawn==0,"three core hits leave counterplay")
		game.damage_player(30,false,bot,"shooter")
		game._update_player_respawn(4.1)
		expect(game.player_respawn>0 and game.respawn_ready and walker.visible and game.deployment.active,"countdown automatically enters visible launcher")
		var before: Vector3 = game.deployment.target
		game.deployment.aim(Vector2(75,-25))
		var chosen: Vector3 = game.deployment.target
		expect(chosen!=before and chosen.distance_to(game.deployment.base_position())<16,"aim chooses nearby clear base landing")
		game.launch_respawn()
		game._update_player_respawn(0.35)
		expect(game.player_respawn>0 and not walker.active and walker.global_position.y>chosen.y+1,"launch has controlled arc")
		game._update_player_respawn(0.4)
		expect(game.player_respawn==0 and walker.active and walker.global_position.distance_to(chosen)<0.1,"single action launches to chosen point")
		expect(float(walker_items["cooldowns"]["shield"])>0,"respawn cannot reset cooldown")
		game.player_invuln = 0
		game.player_health=50
		game.damage_player(82,false,bot,"blaster")
		game.launch_respawn()
		game._update_player_respawn(5)
		expect(game.player_respawn==0,"early Space queues fast default launch")
		for actor in game.all_actors():
			if actor==walker: continue
			expect(game.weapon_order.has(actor.weapon_id) and game.items.KINDS.has(game.items.state(actor)["kind"]),"bots receive random legal weapon/item")
		var observed := {}
		for i in range(24):
			game.randomize_bot_kit(bot)
			observed[bot.weapon_id+game.items.state(bot)["kind"]] = true
		expect(observed.size()>3,"bot equipment has actual random variation")
		game.items.equip(walker,"bomb")
		combat.set("ink_amount",100)
		expect(game.items.use(walker),"equipped bomb can throw")
		expect(not game.items.use(walker),"bomb has cooldown")
		game.items.equip(bot,"bomb")
		bot.set("ink_amount",100)
		expect(game.items.use(bot),"opponent shares bomb rules")
		var enemy_bomb: Dictionary = combat.get("bombs").back()
		expect(enemy_bomb["team"]==1 and enemy_bomb["source_actor"]==bot,"bomb preserves team and attacker")
		combat.call("_explode_bomb",bot.global_position,combat.get("weapon_data")["sub"]["bomb"],1,bot)
		expect(game.bot_respawn==0,"enemy bomb cannot hurt thrower or allies")
		# Test actual special damage and expiry at an open supply location.
		walker.global_position = place
		bot.global_position = place+Vector3(0.1,0,0)
		game.bot_invuln = 0
		game.bot_health = 120
		combat.set("ink_amount",1)
		combat.set("special_points",combat.call("special_cost"))
		expect(combat.call("try_special"),"special activation accepted")
		expect(combat.get("ink_amount")==100,"special restores ink")
		walker.set("slam_impact_pending",true)
		combat.call("_update_special",0.02)
		expect(game.bot_respawn>0,"slam close core kills")
		expect(combat.get("bursts").size()>0,"slam shockwave exists")
		walker.call("cancel_slam")
		game._update_bot(6)
		game.bot_invuln = 0
		game.bot_health = 120
		bot.global_position = place+Vector3(0.1,0,0)
		combat.call("_spawn_cloud",place,Vector3.ZERO)
		combat.set("special_points",0)
		combat.call("_update_clouds",1.0)
		expect(absf(game.bot_health-78)<0.01,"storm applies 42 DPS at exposed target")
		expect(combat.get("special_points")==0,"storm cannot recharge its own special")
		combat.call("_spawn_cloud",place,Vector3.ZERO)
		combat.call("_spawn_cloud",place,Vector3.ZERO)
		expect(combat.get("clouds").size()==2,"rain is bounded to two concurrent clouds")
		combat.call("_update_clouds",9.0)
		expect(combat.get("clouds").is_empty(),"storm and rain are cleaned up")
		expect(int(bot.get_meta("match_stats")["kills"])>=2,"kill ledger follows attacker")
		game._finish_round()
		game._judge_round()
		game.phase = "results"
		game._update_hud()
		game.tactics._process(0)
		expect(game.tactics.panel.visible and game.tactics.map.visible and game.tactics.row_cells.size()==10,"final map and all ten result rows")
		for index in range(game.tactics.roster.size()):
			var actor: Node3D = game.tactics.roster[index]
			var stats: Dictionary = actor.get_meta("match_stats")
			var cells: Array = game.tactics.row_cells[index]
			expect(cells[0].text.begins_with("%02d" % game.actor_id(actor)) and cells[2].text==str(int(stats.kills)) and cells[3].text==str(int(stats.deaths)) and cells[4].text=="%.0f" % float(stats.damage) and cells[5].text=="%.0f" % float(stats.turf),"each result row displays the corresponding actor's recorded stats")
		print("AUDIT: ",map_id," landing=",chosen," HP=120 shield=60 storm=42 DPS launcher respawn")
		game.queue_free()
		await process_frame
	if failures.is_empty():
		print("PASS: both maps, equal health, real item absorption/heal/cooldowns, launcher respawn and invalidation, special damage/ink/expiry, final map and kill ledger")
	quit(0 if failures.is_empty() else 1)
