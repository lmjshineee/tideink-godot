extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare()
	var sonar: Node3D = game.items.sonar
	var intel: Node3D = game.intel
	game.items.equip(walker,"sonar")
	walker.global_position = Vector3(0,.05,-20); walker.update_form(false)
	combat.ink_amount = 39
	expect(not game.items.use(walker) and game.items.state(walker).cooldowns.sonar == 0, "insufficient ink does not consume sonar CD")
	combat.ink_amount = 100
	bot.global_position = walker.global_position
	await physics_frame
	expect(not game.items.use(walker) and combat.ink_amount == 100 and game.items.state(walker).cooldowns.sonar == 0,"other actor blocks placement after collision sync")
	bot.global_position = Vector3(70,40,70)
	await physics_frame
	expect(game.items.use(walker), "sonar placed via real floor clearance")
	var id := walker.get_instance_id()
	if not sonar.stations.has(id): await finish("sonar placement"); return
	var s: Dictionary = sonar.stations[id]
	var home: Vector3 = s.point
	expect(combat.ink_amount == 60 and s.health == 60 and game.items.state(walker).cooldowns.sonar == 18, "deployment costs ink and starts persistent cooldown")
	bot.global_position = home + Vector3(0,0,6)
	bot.set_meta("enemy_swimming",true)
	intel.clear_all(); await physics_frame
	sonar.tick(.39)
	expect(intel.marker(bot,0).is_empty(), "pulse has deployment prelude")
	for i in 16: sonar.tick(.033)
	expect(not intel.marker(bot,0).is_empty() and intel.marker(bot,0).status == "sonar", "travelling wave reveals submerged enemy")
	expect(game.bot_health == 120 and game.player_health == 120, "sonar does not cause damage")
	intel.tick(2.1)
	expect(intel.marker(bot,0).is_empty(), "sonar reveal expires without continuous scan")
	# Restart pulse at the same actual device; this time an opaque wall intervenes.
	var barrier := wall(home + Vector3(0,1,3),Vector3(10,4,.2))
	await physics_frame
	s.next = .01; s.radius = -1.0
	for i in 30: sonar.tick(.033)
	expect(intel.marker(bot,0).is_empty(), "wall blocks pulse detection")
	barrier.queue_free(); await physics_frame
	bot.global_position = home + Vector3(0,4,4)
	var deck := wall(home+Vector3(0,2,2),Vector3(20,.2,20))
	await physics_frame
	s.next = .01; s.radius = -1.0
	for i in 30: sonar.tick(.033)
	expect(intel.marker(bot,0).is_empty(), "thin floor stops pulse across height")
	deck.queue_free(); await physics_frame
	bot.global_position = home + Vector3(0,13,0)
	s.next = .01; s.radius = -1.0
	for i in 30: sonar.tick(.033)
	expect(intel.marker(bot,0).is_empty(), "radius uses 3D distance rather than flat map distance")
	game.items.on_death(walker)
	game.randomize_player_kit()
	expect(sonar.stations.has(id) and game.items.state(walker).cooldowns.sonar == 18, "owner death and reroll preserve deployed station and CD")
	expect(not sonar.damage_hit({"collider":s.visual},100,0), "allied fire cannot damage station")
	await physics_frame
	var origin := home + Vector3(0,.55,3)
	var aim: Vector3 = home + Vector3.UP*.55
	var friendly: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,aim,combat.world_mask(0)))
	expect(friendly.is_empty(), "allied projectiles pass through station layer")
	walker.global_position = home + Vector3(4,0,0)
	combat._fire_charger_ray(combat.weapons.charger,1,origin,(aim-origin).normalized(),1,bot)
	expect(not sonar.stations.has(id), "actual enemy charger destroys physical station")
	walker.global_position = home
	game.items.equip(walker,"sonar"); game.items.state(walker).cooldowns.sonar = 0; combat.ink_amount = 100
	game.items.use(walker)
	sonar.tick(8.1)
	expect(not sonar.stations.has(id), "station expires and removes wave/collider")
	# AI deployment uses acquired information, rather than arbitrary hidden enemy transforms.
	bot.set_meta("enemy_swimming",false); bot.global_position = Vector3(3,.05,-20); bot.ink_amount = 100
	game.items.equip(bot,"sonar"); bot.target_actor = null; intel.clear_all()
	game.items.tick(.1)
	expect(not sonar.stations.has(bot.get_instance_id()), "bot does not deploy from unknown enemy position")
	bot.target_actor = walker
	game.items.tick(.1)
	expect(sonar.stations.has(bot.get_instance_id()) and bot.ink_amount == 60, "bot deploys same station/cost on actual acquired threat")
	game._finish_round()
	expect(sonar.stations.is_empty() and intel.contacts[0].is_empty(), "round ending clears stations and intel")
	await finish("sonar real placement, ink/CD, travelling concealment tag, lifetime, spherical range, wall/deck occlusion, actual hostile projectile destruction, owner lifecycle and bot knowledge")
