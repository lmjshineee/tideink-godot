extends "res://tools/creative_fixture.gd"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare(); var home := Vector3(0,.05,-20); walker.global_position = home; walker.reset_movement_state(); walker.grounded = true
	game.perks.choices[walker.get_instance_id()] = "vault_runner"; game.perks.apply_movement()
	walker._on_land(5); expect(game.perks.vault_factor(walker) == 1,"ordinary landing gives no wall boost")
	# Actual ledge exit trajectory and arrival trigger boost only on higher support.
	var ledge := wall(home+Vector3(0,.4,1),Vector3(4,.8,2)); await physics_frame
	walker.global_position = home+Vector3(0,.3,-.6); walker._ledge_pop(Vector3(0,0,1)); walker.global_position = home+Vector3(0,.8,1); walker._on_land(5)
	expect(game.perks.vault_factor(walker) == 1.35 and game.perks.incoming(walker,"shooter") == 1.15,"successful crest grants brief speed and vulnerability")
	walker.update_form(false); walker.velocity = Vector3.ZERO
	for i in 60: walker._horizontal_step(.033,Vector2(1,0),false,false,true)
	expect(Vector2(walker.velocity.x,walker.velocity.z).length() > 7.9,"boost changes actual human movement integrator")
	game.perks.tick(1); expect(game.perks.vault_factor(walker) == 1 and game.perks.incoming(walker,"shooter") == 1,"boost and vulnerability expire")
	game.perks.on_vault(walker); expect(game.perks.vault_factor(walker) == 1,"six-second cooldown blocks repeated wall boost")
	ledge.queue_free(); await physics_frame
	game.perks.choices[walker.get_instance_id()] = "dry_focus"; combat.ink_amount = 20
	for id in game.weapon_order:
		var reduced: Dictionary = game.perks.weapon(walker,combat.weapons[id]); var base: Dictionary = combat.weapons[id]
		var key: String = "inkFull" if id in ["bow","charger"] else "flickInk" if id == "roller" else "inkPerShot"
		expect(is_equal_approx(reduced[key],float(base[key])*.65),"low-ink cost covers "+id)
	combat.select_weapon("shooter"); combat.ink_amount = 20; combat.last_fire_time = 0; combat.cooldown = 0; combat.tick(.033,true,false)
	expect(is_equal_approx(combat.projectiles.back().weapon.damage,combat.weapons.shooter.damage*.8),"real low-ink shot stores reduced damage at firing time")
	var shot: Dictionary = combat.projectiles.back(); combat.ink_amount = 100
	expect(is_equal_approx(shot.weapon.damage,combat.weapons.shooter.damage*.8) and game.perks.weapon(walker,combat.weapons.shooter).damage == combat.weapons.shooter.damage,"refilling cannot restore already-fired shot damage")
	for projectile in combat.projectiles: projectile.visual.queue_free()
	combat.projectiles.clear(); game.perks.choices[walker.get_instance_id()] = "turf_engine"; combat.special_points = 0; combat.special_active = ""
	walker.global_position = home; var area: float = combat._paint_player(home+Vector3.UP*.1,1.3,.22)
	expect(area > 0 and is_equal_approx(combat.special_points,area*1.25),"real new paint has 25 percent extra meter")
	var points: float = combat.special_points; combat._paint_player(home+Vector3.UP*.1,1.3,.22)
	expect(combat.special_points == points and game.perks.outgoing(walker) == .9,"own repaint produces no meter and attacks carry damage tradeoff")
	game.comeback.team = 0; combat.special_points = 0; combat._add_turf(10)
	expect(is_equal_approx(combat.special_points,14.375),"comeback and painting talent stack through one capped charge path")
	game.comeback.reset(); game.perks.choices[bot.get_instance_id()] = "turf_engine"; game.bot_specials.state(bot).points = 0; game.bot_specials.charge(bot,10)
	expect(is_equal_approx(game.bot_specials.state(bot).points,12.5),"bot receives same painting talent charge")
	game.perks.choices[walker.get_instance_id()] = "last_ink"; walker.global_position = home; bot.global_position = home+Vector3(1,.05,0); game.bot_health = 120; game.player_health = 120; game.player_invuln = 0; await physics_frame
	game.damage_player(200,false,bot,"shooter"); game.damage_player(30,false,bot,"shooter"); var meter: float = combat.special_points
	expect(game.perks.death_bursts.size() == 1 and is_equal_approx(game.player_respawn,4.75),"actual death schedules telegraphed burst with respawn cost")
	game.perks.tick(.64); expect(game.bot_health == 120,"warning gives escape time")
	game.perks.tick(.02); expect(game.bot_health < 120 and game.bot_health > 85 and combat.special_points == meter,"delayed real explosion damages foe without special self-charge")
	game.items.on_respawn(walker); expect(game.perks.death_bursts.is_empty(),"respawn does not create a second death explosion")
	game.player_respawn = 0; game.player_health = 120; walker.global_position = home; bot.global_position = home+Vector3(0,1.3,0); game.bot_health = 120
	var deck := wall(home+Vector3(0,.7,0),Vector3(5,.1,5)); await physics_frame
	game.damage_player(200,false,bot,"shooter"); game.damage_player(30,false,bot,"shooter"); game.perks.tick(.7); expect(game.bot_health == 120,"thin deck blocks residual explosion")
	deck.queue_free(); await physics_frame; game.player_respawn = 0; game.player_health = 120; walker.global_position = home; bot.global_position = home+Vector3(5,.05,0); game.damage_player(200,false,bot,"shooter"); game.damage_player(30,false,bot,"shooter"); game.perks.tick(.7)
	expect(game.bot_health == 120,"walking outside blast avoids residual damage")
	game._finish_round(); expect(game.perks.death_bursts.is_empty(),"round cleanup clears delayed death payloads")
	for voice in game.sound.get_children():
		if voice.has_method("stop"): voice.stop()
	await create_timer(.06).timeout; game.queue_free(); await process_frame; await prepare(5,"tidewater")
	game.perks.choices[walker.get_instance_id()] = "vault_runner"; game.perks.apply_movement()
	walker.reset_movement_state(); walker.global_position = Vector3(5.5,.1,0); walker.camera_yaw = -PI/2; walker.intent_driven = false
	game.ink.splat_face(5,5,1.4,3,0,.5); await physics_frame; key(KEY_SHIFT,true); key(KEY_W,true)
	var actual_boost := false; var crest_height := 0.0
	for i in 120:
		walker._physics_process(1.0/30); game.perks.tick(1.0/30)
		crest_height = maxf(crest_height,walker.global_position.y)
		actual_boost = actual_boost or game.perks.vault_factor(walker)>1
		if walker.climb_exit > 0: key(KEY_SHIFT,false)
	key(KEY_SHIFT,false); key(KEY_W,false)
	expect(actual_boost and crest_height > 2.6,"real own-ink wall climb, crest trajectory and supported arrival trigger boost")
	print("AUDIT: actual wall crest peak=",crest_height," boosts=",walker.get_meta("vault_casts",0))
	await finish("four behavioral perks: real crest/speed/risk/CD, all main low-ink costs and immutable fired damage, actual paint/repaint/player+bot charge and damage tradeoff, real delayed death/respawn/3D escape/deck/no-charge lifecycle")
