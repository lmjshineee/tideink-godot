extends "res://tools/creative_fixture.gd"
func _initialize() -> void:call_deferred("_run")
func reset_draw(at:Vector3) -> void:
	combat.bow.clear_all();combat.ink_amount=100;combat.charging=false;combat.charge_time=0;combat.charge_fraction=0;combat.cooldown=0
	game.player_health=120;game.bot_health=120;bot.health=120;bot.invuln=0;game.bot_invuln=0;game.bot_respawn=0;bot.global_position=at
	game.perks.choices[walker.get_instance_id()]="balanced"
	game.perks.choices[bot.get_instance_id()]="balanced"
func _run() -> void:
	await prepare()
	combat.select_weapon("bow");walker.global_position=Vector3(0,40,0);walker.grounded=true
	for range_m in [8.0,16.0,23.0]:
		reset_draw(Vector3(0,40,range_m))
		combat.bow.fire(walker,bot.global_position+Vector3.UP*.8,1)
		for i in 40:combat.bow.tick(1.0/30)
		var dealt:float=120-game.bot_health
		print("AUDIT: full bow range=",range_m," damage=",dealt)
		expect(dealt>=95 and dealt<120,"full draw converges three arrows at "+str(range_m)+"m, leaving reaction HP")
	# Offensive and defensive perks, including activation during flight, share
	# the whole volley cap. Each arrow still travels and hits the actual capsule.
	for late_boost in [false,true]:
		reset_draw(Vector3(0,40,16))
		game.perks.choices[bot.get_instance_id()]="enemy_swim"
		if not late_boost:
			game.perks.choices[walker.get_instance_id()]="adrenaline";game.player_health=50
		combat.bow.fire(walker,bot.global_position+Vector3.UP*.8,1)
		combat.bow.tick(.05)
		if late_boost:
			game.perks.choices[walker.get_instance_id()]="adrenaline";game.player_health=50
		for i in 40:combat.bow.tick(1.0/30)
		print("AUDIT: vulnerable target late_boost=",late_boost," damage=",120-game.bot_health)
		expect(is_equal_approx(game.bot_health,5),"boost plus vulnerable defender leaves 5 HP, including mid-flight activation")
	reset_draw(Vector3(0,40,23))
	var camera:Camera3D=walker.get_node("Camera3D")
	camera.global_position=walker.global_position+Vector3(3,3,-5);camera.look_at(bot.global_position+Vector3.UP*.8)
	game.pointer_locked=true
	combat.tick(.4,true,false)
	expect(is_equal_approx(combat.charge_fraction,.5) and combat.ink_amount==100,"half draw ready in 0.4 seconds without upfront ink spend")
	combat.tick(.001,false,false)
	expect(combat.bow.arrows.size()==3 and is_equal_approx(combat.ink_amount,95),"half-draw actual release costs 5 ink")
	reset_draw(Vector3(0,40,23));combat.ink_amount=4
	combat.tick(.8,true,false)
	expect(combat.charge_fraction<.5,"low ink cannot claim explosive-ready draw")
	combat.tick(.001,false,false)
	expect(combat.bow.arrows.size()==3 and combat.ink_amount>=0,"low ink still releases three affordable quick arrows")
	reset_draw(Vector3(0,40,23))
	var barrier:=wall(Vector3(0,41,7),Vector3(8,8,.3))
	await physics_frame
	combat.ink_amount=100;combat.bow.clear_all()
	combat.bow.fire(walker,Vector3(0,41,7),.5)
	for i in 12:combat.bow.tick(1.0/30)
	expect(combat.bow.planted.size()==3,"half draw plants three real explosive arrows")
	barrier.queue_free();combat.bow.clear_all()
	await physics_frame
	# At half draw the center arrow hits and the sides miss onto the wall;
	# direct damage and delayed splash use one budget rather than six attacks.
	reset_draw(Vector3(0,40,8))
	barrier=wall(Vector3(0,41,9),Vector3(8,8,.3));await physics_frame
	combat.bow.fire(walker,bot.global_position+Vector3.UP*.8,.5)
	for i in 12:combat.bow.tick(1.0/30)
	var direct_damage:float=120-game.bot_health
	expect(direct_damage>0 and combat.bow.planted.size()==2,"half-draw center hits while side arrows plant behind target")
	for i in 24:combat.bow.tick(1.0/30)
	var combined:float=120-game.bot_health
	print("AUDIT: half draw direct=",direct_damage," direct plus delayed blast=",combined)
	expect(combined>direct_damage and combined<=110,"actual direct and blast combine under one volley budget")
	barrier.queue_free();combat.bow.clear_all();await physics_frame
	# The same production bot dispatch chooses affordable close/partial shots.
	for scenario in [{"distance":4.0,"ink":100.0,"cost":3.0,"draw":0.0},{"distance":8.0,"ink":6.5,"cost":5.0,"draw":.5}]:
		reset_draw(Vector3(0,40,scenario.distance));bot.select_weapon("bow")
		bot.ink_amount=scenario.ink;bot.charge_time=0;bot.attack_cooldown=0;bot.last_fire_time=0
		for i in 15:
			bot.tick(1.0/30)
			if not combat.bow.arrows.is_empty():break
		print("AUDIT: AI distance=",scenario.distance," ink left=",bot.ink_amount," arrows=",combat.bow.arrows.size())
		expect(combat.bow.arrows.size()==3 and bot.ink_amount<=scenario.ink-scenario.cost,"AI fires affordable real arrows at close or low-ink range")
		if not combat.bow.arrows.is_empty():expect(is_equal_approx(combat.bow.arrows[0].charge,scenario.draw),"AI chooses quick close draw or half low-ink draw")
	await finish("full-draw range, shared final cap with changing perks, affordable draw/release, half-draw real direct plus explosion, close/partial AI dispatch")
