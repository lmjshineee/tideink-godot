extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	await prepare(5,"tidewater")
	walker.global_position=Vector3(0,.05,-28)
	bot.global_position=Vector3(0,.05,-22)
	var ids:=[]
	for id in game.weapon_order:
		var kind:String=combat.weapons[id].special
		expect(kind not in ids,"exclusive special for "+id);ids.append(kind)
		combat.select_weapon(id);combat.special_points=combat.special_cost()*.73
		combat.on_death()
		expect(is_equal_approx(combat.special_fraction(),.73),"player death retains percentage: "+id)
		combat.select_weapon("roller" if id!="roller" else "shooter")
		expect(is_equal_approx(combat.special_fraction(),.73),"player kit change retains percentage: "+id)
		bot.select_weapon(id);var state:Dictionary=game.bot_specials.state(bot)
		state.points=float(combat.weapons[id].specialCost)*.73;game.bot_specials.on_death(bot)
		bot.select_weapon("roller" if id!="roller" else "shooter")
		expect(is_equal_approx(float(state.points)/float(combat.weapons[bot.weapon_id].specialCost),.73),"bot death and kit change retain percentage: "+id)
	# Real primary fire during overdrive uses boosted cadence and reduced actual ink spending.
	combat.select_weapon("shooter");combat.special_points=combat.special_cost()
	expect(combat.try_special(),"shooter overdrive activation")
	var count:int=combat.projectiles.size();combat.tick(.1,true,false)
	expect(combat.projectiles.size()>count and combat.ink_amount<100 and combat.ink_amount>99,"overdrive allows primary and spends half-cost ink")
	combat.special_points=0;combat.advance_effects(6.1)
	expect(combat.special_active=="" and combat.special_points==0,"overdrive expires and special cannot recharge itself")
	combat.on_death()
	# Actual aura, friendly-fire and collision authority; no free armour.
	combat.select_weapon("dualie");combat.special_points=combat.special_cost()
	bot.global_position=walker.global_position+Vector3(2,0,0);game.bot_health=120
	var ally:Node3D=game.extra_bots[0];ally.global_position=walker.global_position+Vector3(-2,0,0)
	var friendly:float=game.actor_health(ally)
	expect(combat.try_special(),"dualie moving vortex activation")
	combat.weapon_specials.tick(.5)
	expect(absf(game.bot_health-108)<.01 and game.actor_health(ally)==friendly,"vortex hurts visible enemies only at 24 DPS")
	var blocker:=wall(walker.global_position+Vector3(1,1,0),Vector3(.2,3,5));await physics_frame
	var before:float=game.bot_health;combat.weapon_specials.tick(.5)
	expect(game.bot_health==before,"wall blocks vortex damage")
	blocker.queue_free();await physics_frame
	game.player_health=120;game.damage_player(25,false,bot,"shooter")
	expect(game.player_health==95,"vortex gives no armour or invincibility")
	combat.on_death();expect(not combat.weapon_specials.active(walker),"death cancels owned vortex")
	# Pressure salvo locks primary; swept real wall collision blocks every shell.
	combat.select_weapon("blaster");combat.special_points=combat.special_cost()
	expect(combat.try_special() and combat.is_busy(),"blaster pressure salvo starts and locks primary")
	var active:Dictionary=combat.weapon_specials.states[walker.get_instance_id()]
	active.direction=Vector3.FORWARD
	blocker=wall(walker.global_position+Vector3(0,1,-1),Vector3(6,3,.3));bot.global_position=walker.global_position+Vector3(0,0,-3);game.bot_health=120
	await physics_frame
	var launched:int=combat.weapon_specials.launched
	for i in range(50):combat.advance_effects(.04)
	print("AUDIT salvo launches=",combat.weapon_specials.launched-launched," hp=",game.bot_health)
	expect(combat.weapon_specials.launched-launched==3 and game.bot_health==120,"three pressure shells collide with real wall; no through-wall blast")
	expect(combat.special_points==0,"pressure salvo does not recharge from trail or blast")
	blocker.queue_free();await physics_frame
	# Vulnerability cannot turn three direct shots into an uncapped cast. A high
	# fixture HP separates the budget from ordinary death/removal of the target.
	combat.special_points=combat.special_cost();expect(combat.try_special(),"bounded pressure salvo activation")
	combat.weapon_specials.states[walker.get_instance_id()].direction=Vector3.FORWARD
	bot.global_position=walker.global_position+Vector3(0,0,-4);game.bot_health=400
	game.perks.choices[bot.get_instance_id()]="enemy_swim"
	await physics_frame
	for i in range(50):combat.advance_effects(.04)
	expect(absf(game.bot_health-250)<.01,"shared pressure cap is 150 final HP even with defender vulnerability")
	game.perks.choices[bot.get_instance_id()]="balanced";game.bot_health=120
	# Cancel unlaunched shots but retain an already flying shell and its cast budget.
	combat.special_points=combat.special_cost();expect(combat.try_special(),"second pressure salvo activation")
	combat.weapon_specials.tick(.26);var flying:int=combat.weapon_specials.shells.size();launched=combat.weapon_specials.launched
	combat.on_death();combat.weapon_specials.tick(.05)
	expect(combat.weapon_specials.launched==launched and flying>0,"death cancels remaining launches without respawning or refunding shots")
	combat.weapon_specials.clear()
	# Both teams use the new special module through actual bot decision logic.
	for actor in [bot,ally]:
		for weapon in ["shooter","dualie","blaster"]:
			combat.weapon_specials.clear();game.bot_specials.on_death(actor)
			actor.select_weapon(weapon);actor.global_position=Vector3(0,.05,-28)
			var opponent:Node3D=walker if game.actor_team(actor)==1 else bot
			opponent.global_position=Vector3(2,.05,-28)
			var s:Dictionary=game.bot_specials.state(actor);s.cooldown=0;s.points=combat.weapons[weapon].specialCost
			await physics_frame;game.bot_specials.tick(.01)
			expect(s.active and s.points==0 and combat.weapon_specials.active(actor),"bot casts own exclusive special: team %d %s" % [game.actor_team(actor),weapon])
	await finish("eight exclusive specials, actual new activations, death/reroll progress, walls, friendly fire and both-team bot casting")
