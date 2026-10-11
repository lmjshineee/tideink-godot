extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	await prepare(5,"tidewater")
	wall(Vector3(0,39.8,12),Vector3(30,.4,40));await physics_frame
	for id in game.weapon_order:
		combat.on_death();combat.select_weapon(id)
		walker.reset_movement_state();walker.update_form(false);walker.global_position=Vector3(0,40.05,0)
		walker.camera_yaw=0;walker.camera_pitch=-.3;walker._update_camera();game.pointer_locked=true
		game.player_health=132;game.player_invuln=0;combat.ink_amount=1;combat.special_points=combat.special_cost()
		expect(combat.try_special(),"real activation succeeds: "+id)
		expect(combat.ink_amount==game.actor_ink_max(walker) and game.player_invuln>=1.0,"special fills tank and grants at least one second of real protection: "+id)
		expect(combat.special_guard.guards.has(walker.get_instance_id()),"real guard mesh is created: "+id)
		game.damage_player(200,false,bot,"charger");expect(game.player_health==132,"startup blocks lethal damage: "+id)
		game.player_last_damage=0;game._update_player_vitals(.85)
		game.damage_player(50,false,bot,"shooter");expect(game.player_health==132,"guard remains meaningful after 850 ms: "+id)
		game._update_player_vitals(.51);combat.special_guard.tick(.01)
		expect(game.player_invuln==0 and not combat.special_guard.guards.has(walker.get_instance_id()),"guard and mesh expire together: "+id)
		combat.on_death();game.damage_player(20,false,bot,"shooter");expect(game.player_health==112,"normal damage resumes after finite guard: "+id)
	for actor in [bot,game.extra_bots[0]]:
		actor.select_weapon("blaster");combat.grant_special_protection(actor)
		var hp:float=game.actor_health(actor)
		game.damage_actor(actor,200,1-game.actor_team(actor),walker,"charger")
		expect(game.actor_health(actor)==hp,"both bot paths receive actual startup invulnerability")
	combat.grant_special_protection(walker);combat.on_death()
	expect(not combat.special_guard.guards.has(walker.get_instance_id()),"death cancels player visuals without another combat tick")
	game.bot_specials.on_death(bot)
	expect(not combat.special_guard.guards.has(bot.get_instance_id()),"death cancels bot visuals without another combat tick")
	game._finish_round()
	expect(combat.special_guard.guards.is_empty(),"round end cleans guard visuals")
	await finish("all eight real special casts refill, finite 1s+ protection/visible mesh, 850ms survival, expiry and both bot paths")
