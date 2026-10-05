extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare(1,"viaduct")
	game.ai_level="standard"
	walker.global_position=Vector3(200,0,200)
	bot.reset(); bot.select_weapon("shooter")
	game.items.state(bot).cooldowns.bomb=999
	Engine.time_scale=4.0; Engine.physics_ticks_per_second=120
	seed(731)
	await physics_frame
	game._update_bot(1.0/30)
	var goal:Vector3=bot.route[-1]
	var length:=0.0
	for i in range(1,bot.route.size()): length+=bot.route[i-1].distance_to(bot.route[i])
	var closest:=bot.global_position.distance_to(goal)
	var arrived:=false
	for frame in range(900):
		await physics_frame
		game._update_bot(1.0/30)
		combat.advance_effects(1.0/30)
		game.intel.tick(1.0/30)
		closest=minf(closest,bot.global_position.distance_to(goal))
		if closest < .6:
			arrived=true
			break
	expect(arrived,"patrolling bot physically reaches its chosen destination without being distracted by invisible opponents")
	print("AUDIT: initial patrol goal=",goal," path_m=",length," nearest_m=",closest)
	# A persistent patrol must still yield to a real observation, while a wall
	# must not leak the opponent's position into the route selector.
	bot.reset();bot.global_position=Vector3(6,.05,31)
	bot.route=game.navigation.route(bot.global_position,Vector3(10,0,31),1)
	bot.route_index=1;bot.route_purpose="patrol";bot.repath_time=999
	var patrol_goal:Vector3=bot.route[-1]
	wall(Vector3(6,1.5,25),Vector3(5,3,1))
	walker.global_position=Vector3(6,.05,22)
	await physics_frame
	expect(not game.intel.can_see(bot,walker),"terrain occludes the nearby opponent")
	game._update_bot(1.0/30)
	expect(bot.target_actor==null and bot.route[-1]==patrol_goal,"unseen opponent does not interrupt patrol or reveal coordinates")
	walker.global_position=Vector3(6,.05,29)
	await physics_frame
	expect(game.intel.can_see(bot,walker),"opponent is now genuinely visible")
	game._update_bot(1.0/30)
	expect(bot.target_actor==walker and bot.route[-1].distance_to(walker.global_position)<1,"visible opponent redirects a patrol without waiting for its path-refresh timer")
	await finish("bot completes a patrol through real terrain before choosing another destination")
