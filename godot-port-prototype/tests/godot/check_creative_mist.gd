extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare()
	var mist: Node3D = game.items.mist
	var intel: Node3D = game.intel
	expect(game.items.KINDS.has("intel_mist") and not game.items.KINDS.has("mist"), "information mist replaces legacy numerical slow field in active pool")
	walker.global_position = Vector3(0,.05,-20); walker.update_form(false)
	var camera: Camera3D = walker.get_node("Camera3D")
	camera.global_position = Vector3(0,3,-23); camera.look_at(Vector3(0,.05,-16))
	game.pointer_locked = true
	game.items.equip(walker,"intel_mist"); combat.ink_amount = 34
	expect(not game.items.use(walker) and game.items.state(walker).cooldowns.intel_mist == 0, "ink failure preserves cooldown")
	combat.ink_amount = 100
	await physics_frame
	expect(game.items.use(walker) and combat.ink_amount == 65 and game.items.state(walker).cooldowns.intel_mist == 15 and mist.volumes.size() == 1, "real aimed map deployment pays ink and starts cooldown")
	expect(not game.items.use(walker), "cannot bypass cooldown while field exists")
	game.items.on_death(walker); game.randomize_player_kit()
	expect(mist.volumes.size() == 1 and game.items.state(walker).cooldowns.intel_mist == 15, "deployed fog and cooldown survive death/reroll")
	mist.tick(6.01)
	expect(mist.volumes.is_empty(), "fog lifetime removes visual and vision rule")
	# Wall rejects placement without payment, and an actual ceiling caps height.
	game.items.equip(walker,"intel_mist"); game.items.state(walker).cooldowns.intel_mist = 0; combat.ink_amount = 100
	var barrier := wall(Vector3(0,1.5,-18),Vector3(8,3,.2)); await physics_frame
	# Aim now hits the wall, which is not a valid floor target.
	var at_wall: bool = game.items.use(walker)
	expect(not at_wall or mist.volumes[0].point.z < -18, "wall-targeted mist stays on visible side instead of skipping obstruction")
	mist.clear_all(); game.items.state(walker).cooldowns.intel_mist = 0; combat.ink_amount = 100
	barrier.queue_free(); await physics_frame
	var ceiling := wall(Vector3(0,2.5,-16),Vector3(10,.2,10)); await physics_frame
	# A low ceiling occupies the throw target: placement can fail or remain below it.
	var placed: bool = game.items.use(walker)
	expect(placed and mist.volumes[0].center.y + mist.volumes[0].size.y < 2.5, "actual deployment below ceiling succeeds and caps expansion at overhead floor")
	ceiling.queue_free(); await physics_frame; mist.clear_all()
	walker.global_position = Vector3(0,40,0); bot.global_position = Vector3(0,40,8); bot.set_meta("enemy_swimming",false)
	intel.clear_all(); intel.refresh()
	expect(intel.marker(bot,0).status == "seen", "clear sight initially records current enemy")
	var last: Vector3 = intel.marker(bot,0).point
	mist.create_volume(bot,Vector3(0,40,4))
	bot.global_position.x = .5; intel.tick(.2)
	expect(not intel.can_see(walker,bot) and not bot.health_bar.visible and intel.marker(bot,0).status == "last" and intel.marker(bot,0).point == last, "enemy fog blocks sight/health and freezes last known position")
	expect(intel.can_see(bot,walker), "owner's team sees through its own information mist")
	intel.tick(1.6)
	expect(intel.marker(bot,0).is_empty() and game.minimap.actor_marks() == game.expanded_map.actor_marks(), "enemy disappears from both maps after observation memory")
	intel.on_shot(bot); intel.refresh()
	expect(intel.marker(bot,0).is_empty(), "shot flash does not grant magical vision through fog")
	expect(not intel.visible_point(Vector3(0,41,8),0), "fog also blocks enemy deployed-object map observation")
	intel.tag(bot,0); intel.refresh()
	expect(intel.can_see(walker,bot) and intel.marker(bot,0).status == "sonar" and intel.labels[bot.get_instance_id()].visible, "sonar counters fog with temporary actionable/world information")
	barrier = wall(Vector3(0,41,6),Vector3(10,6,.2)); await physics_frame
	expect(not intel.can_see(walker,bot), "sonar counter to fog still cannot shoot through actual wall")
	barrier.queue_free(); await physics_frame
	intel.tick(3.6)
	expect(intel.marker(bot,0).is_empty(), "sonar expiry restores mist concealment")
	bot.global_position = Vector3(0,40,8); game.bot_health = 120; bot.health = 120
	combat._spawn_projectile("shooter",walker.global_position+Vector3.UP*.85,Vector3(0,0,40),combat.weapons.shooter,0,walker)
	for i in 25: combat._update_projectiles(.01)
	expect(game.bot_health < 120 and mist.volumes.size() == 1, "actual projectile passes mist and can hit an unseen target")
	expect(game.items.move_factor(bot) == 1 and game.items.move_factor(walker) == 1, "information mist applies no duplicate movement penalty")
	expect(not mist.obscures(Vector3(0,46,0),Vector3(0,46,8),0), "volume uses height, not a flat XZ disk")
	# Exact intersection catches a ray crossing with both endpoints outside; grazing misses.
	expect(mist.obscures(Vector3(-8,42,4),Vector3(8,42,4),0) and not mist.obscures(Vector3(-8,42,8),Vector3(8,42,8),0), "swept ellipsoid distinguishes crossing from grazing")
	mist.clear_all(); intel.clear_all()
	walker.global_position = Vector3(0,.05,-20); bot.global_position = Vector3(0,.05,-12)
	game.bot_health = 80; bot.health = 80; bot.ink_amount = 100; game.items.equip(bot,"intel_mist")
	game.items.tick(.01)
	expect(mist.volumes.is_empty() and bot.ink_amount == 100, "AI refuses mist from an unknown enemy transform")
	intel.refresh(); game.items.tick(.01)
	expect(mist.volumes.size() == 1 and mist.volumes[0].owner == bot and bot.ink_amount == 65, "injured AI places same fog toward acquired contact")
	mist.clear_all(); intel.clear_all()
	mist.create_volume(walker,Vector3(0,.05,-16))
	bot.select_weapon("canopy"); bot.attack_cooldown = 0; bot.target_actor = null
	var bs: Dictionary = game.bot_specials.state(bot)
	bs.points = 150; bs.cooldown = 0; bs.active = false
	intel.refresh()
	var shots: int = combat.projectiles.size()
	bot.tick(.033); game.bot_specials.tick(.033)
	expect(bot.target_actor == null and combat.projectiles.size() == shots and bs.points == 150 and not bs.active, "AI primary and special both respect enemy fog")
	intel.tag(walker,1); intel.refresh(); game.bot_specials.tick(.033)
	expect(bs.active and combat.counter.busy(bot), "same AI can react to sonar-acquired opponent through fog")
	game._finish_round()
	expect(mist.volumes.is_empty(), "round end clears fog and its information effect")
	await finish("information mist real placement/cost/CD, lifetime/ceiling, frozen map memory, team visibility/health/flash, sonar counter without wall bypass, real projectile passage, 3D swept volume and knowledge-driven AI item/primary/special")
