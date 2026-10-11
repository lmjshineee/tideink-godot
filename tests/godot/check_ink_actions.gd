extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	await prepare(1,"tidewater")
	game.player_health=120
	walker.global_position=Vector3(0,.05,-28)
	game.paint_at_world(walker.global_position,0,3,.5)
	walker.update_form(true);walker.grounded=true;walker.ink_owner=0
	walker.velocity=Vector3(0,0,10);walker.jump_buffer=.1
	var ink_before:float=combat.ink_amount
	expect(walker.try_squid_roll(Vector2.RIGHT),"fast own-ink swim + turn + buffered jump starts roll")
	expect(walker.velocity.x>=10 and walker.velocity.y==8.5 and not walker.grounded,"roll redirects real momentum and jumps")
	game.damage_player(50,false,bot,"shooter")
	expect(is_equal_approx(game.player_health,100),"roll reduces a real 50-damage hit to 20, without full immunity")
	expect(combat.ink_amount==ink_before,"squid action does not spend or refill ink")
	walker.advance_ink_actions(.23)
	game.damage_player(20,false,bot,"shooter")
	expect(is_equal_approx(game.player_health,80),"roll protection expires after .22 seconds")
	walker.grounded=true;walker.jump_buffer=.1
	expect(not walker.try_squid_roll(-Vector2.RIGHT),"cannot spam rolls through the cooldown")
	walker.reset_movement_state();walker.update_form(true);walker.grounded=true;walker.ink_owner=1
	walker.velocity=Vector3(0,0,10);walker.jump_buffer=.1
	expect(not walker.try_squid_roll(Vector2.RIGHT),"enemy ink cannot grant roll protection")
	walker.ink_owner=0;walker.velocity=Vector3(0,0,3)
	expect(not walker.try_squid_roll(Vector2.RIGHT),"slow or standing squid jumps normally")
	walker.velocity=Vector3(0,0,10)
	expect(not walker.try_squid_roll(Vector2(0,1)),"straight swim jump does not accidentally roll")
	# Full physical wall-climb seam, including ownership and the held space key.
	walker.reset_movement_state();walker.global_position=Vector3(5.5,.1,0)
	game.ink.splat_face(5,5,1.4,3,0,.5)
	walker.update_form(true);key(KEY_SPACE,true)
	var attached:=false
	for i in 14:
		attached=walker._update_climb(1.0/30,true,Vector2(-1,0)) or attached
		walker.move_and_slide()
	expect(attached and walker.surge_time>0 and walker.velocity.y>15,"holding jump .45s on a real owned ink wall launches surge")
	key(KEY_SPACE,false)
	expect(not walker.charge_surge(.5,true,true),"unpainted upper wall caps surge")
	walker.reset_movement_state();walker.global_position=Vector3(5.5,.1,0);walker.update_form(true)
	expect(walker._update_climb(.033,true,Vector2.LEFT) and walker.climbing,"owned wall attaches before kick")
	walker.jump_buffer=.1
	expect(walker._update_climb(.033,true,Vector2.RIGHT) and not walker.climbing and walker.velocity.x>10 and walker.velocity.y==8.5,"away + jump performs an actual protected wall kick")
	expect(walker.squid_roll_guard==.22 and walker.climb_exit>0,"wall kick has finite guard and reattach cooldown")
	walker.reset_movement_state()
	expect(walker.squid_roll_guard==0 and walker.surge_charge==0 and walker.surge_time==0,"respawn reset clears action protection and charge")
	# Scatter remains centred and bounded, with air penalty and independent dualies.
	combat.select_weapon("shooter");walker.grounded=true;combat.bloom=0
	expect(combat._spread_degrees(combat.weapons.shooter)==0,"settled ground first shot is precise")
	combat.bloom=1;var ground:float=combat._spread_degrees(combat.weapons.shooter)
	walker.grounded=false
	expect(combat._spread_degrees(combat.weapons.shooter)>ground,"jump fire has a wider cone")
	var average:=Vector3.ZERO
	for i in 800:
		var shot:Vector3=combat._spread_direction(Vector3.FORWARD,deg_to_rad(10))
		expect(absf(shot.x/-shot.z)<=tan(deg_to_rad(10.01)) and absf(shot.y/-shot.z)<=tan(deg_to_rad(5.51)),"random shot remains inside its rectangle")
		average+=shot
	expect(absf(average.x/800)<.015 and absf(average.y/800)<.015,"scatter has no directional bias")
	combat.select_weapon("dualie")
	combat._spawn_shot_pair(combat.weapons.dualie,Vector3(0,40,0),Vector3.FORWARD,0,walker)
	var count:int=combat.projectiles.size()
	expect(not combat.projectiles[count-1].velocity.is_equal_approx(combat.projectiles[count-2].velocity),"dual barrels roll independent shot scatter")
	await finish("real roll damage/momentum, enemy/slow/straight/cooldown negatives, owned wall surge and scatter")
