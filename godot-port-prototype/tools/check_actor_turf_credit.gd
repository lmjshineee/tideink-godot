extends SceneTree

const Setup := preload("res://match_setup.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ",message)

func turf(actor: Node3D) -> float:
	return float(actor.get_meta("match_stats")["turf"])

func _run() -> void:
	Setup.team_size = 5
	Setup.map_id = "tidewater"
	Setup.map_variant = 0
	var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	for actor in game.all_actors():
		game.perks.choices[actor.get_instance_id()] = "balanced"
	game._start_round()
	var walker: CharacterBody3D = game.get_node("World/Walker")
	walker.set_physics_process(false)
	var feet := walker.global_position
	var ally: Node3D = game.extra_bots[0]
	var bot: Node3D = game.get_node("Bot")
	var combat: Node3D = game.get_node("Combat")
	var at := feet + Vector3.UP*0.3
	var area: float = game.paint_at_world(at,0,1.3,0.5)
	expect(area > 0.0 and is_equal_approx(turf(walker),area),"player receives newly claimed area")
	expect(game.paint_at_world(at,0,1.3,0.5) == 0.0 and is_equal_approx(turf(walker),area),"same-team repaint adds no contribution")
	game.bot_painting = true
	game.painting_actor = ally
	var before_points: float = game.turf_total
	area = game.paint_at_world(at+Vector3(4,0,0),0,1.3,0.5)
	expect(area > 0.0 and is_equal_approx(turf(ally),area),"ally attack context receives its own area")
	expect(is_equal_approx(game.turf_total,before_points),"ally paint does not inflate local points")
	game.painting_actor = bot
	area = game.paint_at_world(at,1,1.3,0.5)
	expect(area > 0.0 and is_equal_approx(turf(bot),area),"enemy overpaint is credited to its actual owner")
	game.bot_painting = false
	game.painting_actor = null
	for actor in game.all_actors():
		actor.global_position = Vector3(60,30,60)
	# A projectile reaches the deck after its firing context has been cleared.
	var before := turf(ally)
	combat._spawn_projectile("shooter",feet+Vector3(-6,3,0),Vector3(0,-8,0),combat.weapons.shooter,0,ally)
	for i in range(90):
		combat.advance_effects(1.0/120.0)
	expect(turf(ally) > before,"delayed allied projectile retains ownership")
	expect(game.painting_actor == null and not game.bot_painting,"projectile restores caller context")
	# Special impacts have an explicit source and cannot refill their own meter.
	before = turf(ally)
	var ally_points: float = game.bot_specials.state(ally).points
	combat._slam_at(feet+Vector3(3,0,0),0,ally,combat.weapon_data.specials.slam)
	expect(turf(ally) > before,"slam credits its caster after the attack context has ended")
	expect(is_equal_approx(float(game.bot_specials.state(ally).points),ally_points),"slam cannot recharge itself")
	before = turf(bot)
	game.bot_respawn = 2.0
	var bot_points: float = game.bot_specials.state(bot).points
	combat._spawn_cloud(feet+Vector3(-3,0,0),Vector3.ZERO,1,bot)
	combat._update_clouds(0.6)
	expect(turf(bot) > before,"persistent rain credits its caster even after death")
	expect(is_equal_approx(float(game.bot_specials.state(bot).points),bot_points),"rain cannot recharge itself")
	expect(is_equal_approx(game.turf_total,before_points),"allied specials do not become local points")
	# Kill splats bypass the normal projectile context; credit their explicit attacker.
	game.bot_respawn = 0.0
	game.bot_invuln = 0.0
	game.bot_health = 1.0
	bot.global_position = feet
	before = turf(ally)
	game.damage_bot(1000.0,ally,"shooter")
	expect(turf(ally) > before and is_equal_approx(game.turf_total,before_points),"main bot death splat belongs to allied attacker")
	var enemy: Node3D = game.extra_bots[-1]
	enemy.invuln = 0.0
	enemy.health = 1.0
	enemy.global_position = feet+Vector3(-4,0,0)
	game.paint_at_world(enemy.global_position+Vector3.UP*0.3,1,2.0,0.5,Vector3.ZERO,0.0,enemy)
	before = turf(ally)
	game.damage_actor(enemy,1000.0,0,ally,"shooter")
	expect(turf(ally) > before,"extra bot death splat belongs to allied attacker")
	walker.global_position = feet+Vector3(6,0,0)
	game.player_invuln = 0.0
	game.player_health = 1.0
	game.paint_at_world(walker.global_position+Vector3.UP*0.3,0,2.0,0.5)
	before = turf(enemy)
	game.damage_player(1000.0,false,enemy,"shooter")
	expect(turf(enemy) > before,"player death splat belongs to its actual attacker")
	var totals := [0.0,0.0]
	for actor in game.all_actors():
		totals[game.actor_team(actor)] += turf(actor)
	expect(is_equal_approx(totals[0],float(game.turf_area[0])) and is_equal_approx(totals[1],float(game.turf_area[1])),"individual contributions sum to both team ledgers")
	game.phase = "results"
	game.tactics._process(0.0)
	expect(game.tactics.header_cells[5].text == "涂地 m²" and game.tactics.row_panels.size() == 10,"results expose individual turf contribution for all ten actors")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: individual turf attribution, repaint/overpaint, allied delayed projectile, slam/rain/dead caster, three kill splats, team totals and results text")
	quit(0 if failures.is_empty() else 1)
