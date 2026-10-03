extends "res://tools/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare()
	walker.global_position = Vector3(0, 0.05, -20)
	walker.reset_movement_state()
	walker.grounded = true
	game.paint_at_world(walker.global_position + Vector3.UP * 0.1, 1, 3, 0)
	walker.ink_owner = walker._floor_ink_owner()
	expect(walker.ink_owner == 1 and not walker.can_dive(), "ordinary actor cannot dive into actual enemy ink")
	game.perks.choices[walker.get_instance_id()] = "enemy_swim"
	game.perks.apply_movement()
	expect(walker.can_dive(), "selected talent enables enemy ground dive")
	walker.update_intent(0.033, false, true, false)
	expect(walker.squid_form, "normal form intent enters enemy ink")
	walker.velocity = Vector3.ZERO
	for i in 80: walker._horizontal_step(0.033, Vector2(0, 1), true, true, true)
	expect(absf(Vector2(walker.velocity.x, walker.velocity.z).length() - 8) < 0.05, "enemy swim integrator reaches 8m/s")
	walker.velocity = Vector3.ZERO
	walker.ink_owner = 0
	for i in 80: walker._horizontal_step(0.033, Vector2(0, 1), true, false, true)
	expect(absf(Vector2(walker.velocity.x, walker.velocity.z).length() - 11.8) < 0.05, "own swim remains faster")
	walker.ink_owner = 1
	game.player_health = 120
	game.player_ink_damage = 0
	game._update_player_vitals(1)
	expect(game.player_health == 114, "enemy ink damage reduces to six HP per second")
	combat.ink_amount = 50
	combat.last_fire_time = 99
	combat.tick(0.2, false, true)
	expect(combat.ink_amount == 50, "enemy diving cannot refill ink")
	game.damage_player(30, false, bot, "shooter")
	expect(absf(game.player_health-81)<.01, "incoming weapon damage rises ten percent")
	game.player_last_damage = 99
	game._update_player_vitals(0.1)
	expect(game.player_health < 81, "enemy ground prevents health regen")
	walker.grounded = false
	walker.update_form(false)
	expect(not walker.can_dive(), "enemy talent does not enable an airborne dive")
	# Real native input request and movement through the CharacterBody wall collision.
	game.perks.choices[walker.get_instance_id()] = "balanced"
	game.perks.apply_movement()
	combat.select_weapon("dualie")
	walker.update_form(false)
	walker.global_position = Vector3(0, 0.05, -20)
	walker.reset_movement_state()
	walker.grounded = true
	walker.camera_yaw = 0
	combat.ink_amount = 100
	var wall_body := wall(Vector3(-1.4, 1, -20), Vector3(0.3, 3, 4))
	await physics_frame
	mouse(true)
	key(KEY_D, true)
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	expect(game.mobility.rolling(walker) and combat.ink_amount == 88, "left mouse plus direction and space requests costed dodge")
	for i in 6:
		walker._physics_process(0.033)
		game.mobility.tick(0.033)
	print("AUDIT: dodge position ", walker.global_position, " grounded ",walker.grounded)
	expect(walker.global_position.x < -0.2 and walker.global_position.x > -1.3 and walker.global_position.y < 0.3, "dodge moves on ground and stops against real wall")
	expect(game.mobility.recovering(walker), "slide ends in brief recovery")
	var shots_before: int = combat.projectiles.size()
	combat.tick(0.033, true, false)
	expect(combat.projectiles.size() == shots_before, "recovery blocks firing")
	game.mobility.tick(0.17)
	expect(game.mobility.precision(walker), "post-roll precision active")
	var cone: float = combat._spread_degrees(combat.weapons.dualie)
	game.mobility.state(walker).precision = 0
	expect(is_equal_approx(cone, combat._spread_degrees(combat.weapons.dualie) * 0.35), "precision changes actual spread cone")
	expect(game.mobility.request(walker, Vector3.LEFT), "second dodge allowed")
	game.mobility.tick(0.19)
	expect(not game.mobility.request(walker, Vector3.LEFT), "third chained dodge refused")
	mouse(false)
	key(KEY_D, false)
	game.mobility.tick(1)
	expect(game.mobility.request(walker, Vector3.LEFT), "chain recovers")
	walker.update_intent(0.033, false, true, false)
	expect(not walker.squid_form, "slide cannot change to diving shape midway")
	game.items.on_death(walker)
	expect(not game.mobility.busy(walker), "death clears active slide")
	wall_body.queue_free()
	var ally: Node3D = game.extra_bots[0]
	ally.global_position = Vector3(0.5, 0.05, -20)
	ally.team_mover.global_position = ally.global_position
	for i in 3:
		ally.team_mover.velocity = Vector3.DOWN
		ally.team_mover.move_and_slide()
	ally.global_position = ally.team_mover.global_position
	ally.team_mover.position = Vector3.ZERO
	game.perks.choices[ally.get_instance_id()] = "enemy_swim"
	print("AUDIT: bot swim team ",ally.team," floor ",ally.floor_ink_owner()," grounded ",ally.team_mover.is_on_floor(), " at ",ally.global_position)
	game.perks.bot_form(ally, false)
	expect(ally.get_meta("enemy_swimming", false) and is_equal_approx(ally.team_mover.get_child(0).shape.height, 0.54), "bot uses enemy swim and matching collision shape")
	for id in game.weapon_order:
		ally.select_weapon(id); ally.global_position = Vector3(.5,.05,-20); ally.team_mover.global_position = ally.global_position
		for i in 3:
			ally.team_mover.velocity = Vector3.DOWN; ally.team_mover.move_and_slide()
		ally.global_position = ally.team_mover.global_position; ally.team_mover.position = Vector3.ZERO
		ally.ink_amount = 50; ally.last_fire_time = 99; ally.target_actor = null
		ally.tick(.033)
		expect(ally.ink_amount == 50 and game.perks.travel_speed(ally,6)==8,"bot enemy swim cannot refill or paint away its risk: "+id)
	game.perks.bot_form(ally, true)
	expect(not ally.get_meta("enemy_swimming", true), "bot surfaces to fight")
	ally.select_weapon("dualie")
	ally.last_damage = 0.2
	bot.global_position = ally.global_position + Vector3(0, 0, 4)
	game.mobility.consider_bot_roll(ally, bot)
	expect(game.mobility.rolling(ally) and ally.ink_amount == 38, "threatened dualie bot chooses a costed lateral dodge")
	await finish("enemy ink dive intent, actual speed/damage/resource rules, mouse-space dodge, solid wall collision, recovery fire lock, precision and chain limits")
