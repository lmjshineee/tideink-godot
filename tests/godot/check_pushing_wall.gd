extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	await prepare(5,"tidewater")
	game.player_health=120
	expect(preload("res://src/ui/loadout_icons.gd").icon("special","pushing_wall").resource_path.ends_with("special-pushing_wall.svg"),"new wall icon loads as a real tintable texture")
	var floor_body:=wall(Vector3(0,39.8,12),Vector3(30,.4,40))
	walker.global_position=Vector3(0,40.05,0);walker.update_form(false)
	bot.global_position=Vector3(0,40.05,8)
	combat.select_weapon("canopy");combat.special_points=combat.special_cost();combat.ink_amount=1
	walker.camera_yaw=0;walker.camera_pitch=0;walker._update_camera();game.pointer_locked=true
	await physics_frame
	expect(combat.try_special(),"actual canopy special activates pushing wall")
	expect(combat.ink_amount==game.actor_ink_max(walker) and combat.special_points==0 and game.player_invuln==1.0,"successful cast consumes meter, fills tank and grants startup protection")
	game.damage_player(50,false,bot,"shooter")
	expect(game.player_health==120,"startup protection prevents actual HP damage")
	game.player_last_damage=0;game._update_player_vitals(1.01)
	var wall_module:Node3D=combat.push_wall
	var s:Dictionary=wall_module.states[walker.get_instance_id()]
	await physics_frame
	combat.fire_bot_charger(bot.global_position+Vector3.UP,walker.global_position+Vector3.UP,1,1,bot)
	expect(s.hp==485 and game.player_health==120,"hostile full ray hits wall instead of owner")
	if game.player_respawn>0:
		await finish("wall initial failure");return
	game.bot_health=120;bot.health=120
	combat._fire_charger_ray(combat.weapons.charger,.5,walker.global_position+Vector3.UP,Vector3(0,0,1),0,walker)
	expect(game.bot_health<120 and s.hp==485,"friendly ray passes through wall")
	game.damage_player(20,false,bot,"shooter")
	expect(game.player_health==100,"startup expires while wall still exists")
	var start:Vector3=s.cover.global_position
	for i in 30:wall_module.tick(1.0/30)
	expect(s.cover.global_position.z-start.z>3.7,"large barrier actually advances")
	expect(combat.special_points==0,"wall trail cannot recharge itself")
	var obstacle:=wall(s.cover.global_position+Vector3(2.35,0,1),Vector3(.2,4,.2))
	await physics_frame
	for i in 30:wall_module.tick(1.0/30)
	expect(wall_module.active(walker) and s.stopped,"whole-panel sweep stops at a corner obstruction while retaining defense")
	wall_module.damage_area(s.cover.global_position+Vector3(2.45,0,0),.5,500,1)
	expect(not wall_module.active(walker),"splash near panel edge can break wall")
	obstacle.queue_free();await physics_frame
	combat.special_active="";combat.special_points=combat.special_cost();game.player_invuln=0;combat.ink_amount=17
	obstacle=wall(walker.global_position+Vector3(0,1,.45),Vector3(7,4,.2));await physics_frame
	expect(not combat.try_special() and combat.ink_amount==17 and combat.special_ready() and game.player_invuln==0,"obstructed cast spends no meter, ink or startup protection")
	obstacle.queue_free();await physics_frame
	expect(combat.try_special(),"cast can retry after clearance")
	combat.on_death();expect(not wall_module.active(walker),"owner death clears wall collision immediately")
	# Both teams enter through their visibility-gated bot decision.
	for actor in [bot,game.extra_bots[0]]:
		game.bot_specials.on_death(actor);actor.select_weapon("canopy")
		actor.global_position=Vector3(0,.05,-28)
		var opponent:Node3D=walker if game.actor_team(actor)==1 else bot
		opponent.global_position=Vector3(0,.05,-20)
		var bs:Dictionary=game.bot_specials.state(actor);bs.points=160;bs.cooldown=0
		await physics_frame;game.intel.clear_all();game.intel.refresh();game.bot_specials.tick(.01)
		expect(bs.active and bs.kind=="pushing_wall" and bs.points==0 and wall_module.active(actor),"team %d bot casts actual defensive wall" % game.actor_team(actor))
		game.bot_specials.on_death(actor)
	game._finish_round();expect(wall_module.states.is_empty(),"round end clears every wall")
	floor_body.queue_free()
	await finish("push-wall meter/refill/startup, enemy and friendly ray, real motion/corner stop, edge splash, denied cast, death and both teams")
