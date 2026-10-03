extends "res://tests/godot/helpers/creative_fixture.gd"
var counter: Node3D

func _initialize() -> void: call_deferred("_run")
func clear_shots() -> void:
	for shot in combat.projectiles: shot.visual.queue_free()
	combat.projectiles.clear()
	combat.bow.clear_all()
func start() -> void:
	clear_shots(); counter.cancel(walker)
	combat.special_active = ""; combat.special_points = combat.special_cost()
	game.player_health = 120; game.player_respawn = 0; game.player_invuln = 0
	expect(combat.try_special(), "player starts weapon-specific counter through actual meter gate")
	counter.intakes[walker.get_instance_id()].direction = Vector3(0,0,1)

func _run() -> void:
	await prepare()
	counter = combat.counter
	walker.global_position = Vector3(0,40,0); walker.update_form(false)
	bot.global_position = Vector3(0,40,8)
	combat.select_weapon("canopy"); combat.special_points = 0
	# Meter coverage uses real pellets on fresh authoritative terrain, rather than
	# granting points. Positions/resources are controlled; this is not a timed match.
	var rounds := 0
	for x in range(-21,22,3):
		for z in range(-24,25,3):
			if combat.special_ready(): break
			var floor_hit := game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,12,z),Vector3(x,-1,z),1))
			if floor_hit.is_empty() or floor_hit.normal.y < .68: continue
			walker.global_position = floor_hit.position + Vector3.UP*.05
			var target := walker.global_position + Vector3(0,0,4)
			combat.canopy.update_input(walker,.01,false,target); combat.canopy.tick(.7)
			combat.ink_amount = 100
			combat.canopy.update_input(walker,.01,true,target)
			for i in 12: combat._update_projectiles(.033)
			rounds += 1
		if combat.special_ready(): break
	expect(combat.special_ready() and combat.special_points == 150,"actual canopy pellets on fresh turf fill the 150-point counter meter")
	print("AUDIT: counter charged by ",rounds," real pellet volleys / controlled terrain positions and ink")
	game.pointer_locked = true
	key(KEY_F,true); key(KEY_F,false)
	expect(counter.busy(walker) and combat.special_points == 0,"actual F input releases a legitimately paint-charged counter")
	counter.cancel(walker); combat.special_active = ""
	walker.global_position = Vector3(0,40,0); combat.ink_amount = 20
	start()
	expect(combat.special_points == 0 and combat.ink_amount == 100 and combat.is_busy(), "meter consumed, tank refill and human-form action lock")
	var s: Dictionary = counter.intakes[walker.get_instance_id()]
	combat._spawn_projectile("shooter", Vector3(0,41.05,8),Vector3(0,0,-40),combat.weapons.shooter,1,bot)
	combat._update_projectiles(.2)
	expect(combat.projectiles.is_empty() and game.player_health == 120 and s.charge > 0 and s.absorbed == 1, "swept projectile enters cone before body and is absorbed once")
	var charge: float = s.charge
	game.items.equip(walker,"bomb")
	expect(not game.items.use(walker) and not combat.try_special(), "cannot stack items or another special during counter")
	walker.update_intent(.1,false,true,combat.is_busy())
	expect(not walker.squid_form and walker.firing_speed_limit == 2.5, "counter prevents dive and applies movement limit")
	walker.velocity = Vector3(11,2,0)
	for i in 30: walker._horizontal_step(.033,Vector2.RIGHT,false,false,false)
	expect(Vector2(walker.velocity.x,walker.velocity.z).length() <= 2.5001 and walker.velocity.y == 2,"airborne counter clamps inherited momentum/air minimum without removing vertical motion")
	walker.velocity = Vector3.ZERO
	combat.tick(.01,true,false)
	expect(combat.projectiles.is_empty() and combat.ink_amount == 100, "left trigger cannot emit pellets or spend ink during intake")
	s.direction = Vector3(0,0,1)
	combat._spawn_projectile("shooter",Vector3(0,41.05,3),Vector3(0,0,40),combat.weapons.shooter,1,bot)
	combat._update_projectiles(.03)
	expect(s.charge == charge and combat.projectiles.size() == 1, "outgoing bullet does not feed intake")
	clear_shots()
	combat._spawn_projectile("shooter",Vector3(5,41.05,0),Vector3(-40,0,0),combat.weapons.shooter,1,bot)
	for i in 15: combat._update_projectiles(.01)
	expect(game.player_health < 120 and s.charge == charge, "actual side shot remains dangerous")
	game.player_health = 120
	combat._spawn_projectile("shooter",Vector3(0,41.05,-5),Vector3(0,0,40),combat.weapons.shooter,1,bot)
	for i in 15: combat._update_projectiles(.01)
	expect(game.player_health < 120 and s.charge == charge, "actual rear shot bypasses directional intake")
	game.player_health = 120
	combat._fire_charger_ray(combat.weapons.charger,.5,Vector3(0,41.05,8),Vector3(0,0,-1),1,bot)
	expect(game.player_health < 120 and s.charge == charge, "charger ray cannot be absorbed")
	game.player_health = 120
	combat._burst_blaster(Vector3(.7,40.8,0),combat.weapons.blaster,false,1,null,bot)
	expect(game.player_health < 120 and s.charge == charge, "already exploded splash is not intercepted")
	start(); s = counter.intakes[walker.get_instance_id()]
	combat._spawn_projectile("shooter",Vector3(2,41.05,5),Vector3(0,0,-40),combat.weapons.shooter,0,walker)
	combat._update_projectiles(.1)
	expect(s.charge == 0 and combat.projectiles.size() == 1, "friendly bullets pass without feeding charge")
	clear_shots()
	var barrier := wall(Vector3(0,41,5),Vector3(12,6,.2))
	await physics_frame
	combat._spawn_projectile("blaster",Vector3(0,41.05,8),Vector3(0,0,-40),combat.weapons.blaster,1,bot)
	combat._update_projectiles(.2)
	expect(s.charge == 0 and combat.projectiles.is_empty(), "wall between mouth and front cone prevents remote absorption")
	barrier.queue_free(); await physics_frame
	# A thin floor separates the cone from a shot travelling on an upper level.
	s.direction = Vector3(0,.6,.8).normalized()
	var deck := wall(Vector3(0,42,3),Vector3(12,.15,12))
	await physics_frame
	combat._spawn_projectile("shooter",Vector3(0,44,6),Vector3(0,-20,-30),combat.weapons.shooter,1,bot)
	combat._update_projectiles(.2)
	expect(s.charge == 0, "upper-level projectile cannot be sucked through thin floor")
	deck.queue_free(); await physics_frame
	start(); s = counter.intakes[walker.get_instance_id()]
	bot.ink_amount = 100
	combat.bow.fire(bot,walker.global_position+Vector3.UP*1.05,1)
	for i in 20: combat.bow.tick(.01)
	expect(combat.bow.arrows.is_empty() and combat.bow.planted.is_empty() and s.absorbed == 3 and is_equal_approx(s.charge,100), "actual three arrows fill capped intake and never leave delayed explosions")
	combat._spawn_projectile("shooter",Vector3(0,41.05,6),Vector3(0,0,-40),combat.weapons.shooter,1,bot)
	combat._update_projectiles(.03)
	expect(s.charge == 100 and s.phase == "windup" and s.time == .4, "full capacity closes mouth with a visible exposed windup")
	game.player_health = 120
	combat._spawn_projectile("shooter",Vector3(0,41.05,3),Vector3(0,0,-40),combat.weapons.shooter,1,bot)
	for i in 10: combat._update_projectiles(.01)
	expect(game.player_health < 120, "windup stops absorption rather than granting immunity")
	clear_shots(); game.bot_health = 120; bot.health = 120
	s.direction = Vector3(0,0,1)
	counter.tick(.39)
	expect(combat.projectiles.is_empty() and counter.busy(walker), "counter shot waits full windup")
	counter.tick(.011)
	expect(not counter.busy(walker) and walker.action_move_limit == INF and combat.projectiles.size() == 1 and combat.projectiles[0].weapon.damage == 100, "one full-charge counter shot releases and restores movement")
	for i in 30: combat._update_projectiles(.01)
	expect(is_equal_approx(game.bot_health,20), "actual direct counter hit is 100 without head/splash stacking")
	expect(game._attacker_description(walker,"absorb_counter").contains("吸墨反击"), "counter has readable source name")
	# Empty intake times out into a weak shot; actual map collision stops it.
	start(); s = counter.intakes[walker.get_instance_id()]
	counter.tick(3.01); s.direction = Vector3(0,0,1)
	expect(s.phase == "windup" and s.charge == 0, "no incoming fire still times out instead of holding indefinitely")
	barrier = wall(Vector3(0,41,4),Vector3(12,6,.2)); await physics_frame
	counter.tick(.41); game.bot_health = 120; bot.health = 120
	for i in 25: combat._update_projectiles(.01)
	expect(game.bot_health == 120 and combat.projectiles.is_empty(), "weak retaliation still hits actual wall")
	barrier.queue_free(); await physics_frame
	start(); s = counter.intakes[walker.get_instance_id()]; s.phase = "windup"; s.time = .1
	combat.on_death(); counter.tick(.2)
	expect(counter.intakes.is_empty() and combat.projectiles.is_empty() and combat.special_active == "", "death cancels pending counter without postmortem release")
	# A bot starts the same intake only on acquired vision and keeps a physical body.
	walker.global_position = Vector3(0,.05,-20); walker.update_form(false)
	bot.global_position = Vector3(3,.05,-20); bot.select_weapon("canopy"); game.bot_health = 120; bot.health = 120
	var bs: Dictionary = game.bot_specials.state(bot)
	bs.points = 150; bs.cooldown = 0; bs.active = false
	game.intel.clear_all(); game.intel.refresh()
	game.bot_specials.tick(.01)
	expect(bs.active and bs.kind == "absorb_counter" and counter.busy(bot) and bs.points == 0, "AI spends actual canopy meter on same directional counter")
	var old := bot.global_position
	game._update_bot(.033)
	expect(bot.global_position.distance_to(old) <= .033*2.5+.03 and not bot.get_meta("enemy_swimming",false), "bot remains physical and respects counter speed/form limit")
	game.player_health = 120; game.player_invuln = 0
	counter.tick(3.01); counter.tick(.41)
	for i in 20: combat._update_projectiles(.01)
	expect(game.player_health < 120 and game.damage_history[-1].cause.contains("吸墨反击"), "actual AI retaliation records correct source and special name")
	counter.begin(bot,(walker.global_position-bot.global_position).normalized())
	game.bot_specials.on_death(bot)
	expect(not counter.busy(bot), "AI death cancels intake")
	game._finish_round()
	expect(counter.intakes.is_empty(), "round end clears intake geometry")
	await finish("counter actual cone interception, allies/direction/flanks, ray/splash exposure, map/deck occlusion, bow charge/cap/windup, primary/form/ink lock, one real capped retaliation, timeout/death/round cleanup and physical AI")
