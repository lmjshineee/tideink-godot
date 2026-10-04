extends "res://tests/godot/helpers/creative_fixture.gd"
var mines: Node3D
var home: Vector3
func _initialize() -> void: call_deferred("_run")
func deploy() -> Dictionary:
	mines.clear_all(); combat.ink_amount = 100; combat.special_active = ""
	game.items.equip(walker,"mine"); game.items.state(walker).cooldowns.mine = 0
	game.player_respawn = 0; walker.global_position = Vector3(0,.05,-20)
	bot.global_position = Vector3(70,40,70); game.bot_health = 120; bot.health = 120; game.bot_invuln = 0
	await physics_frame
	expect(game.items.use(walker),"mine places on actual standing surface")
	if mines.mines.is_empty(): return {}
	var m: Dictionary = mines.mines.values()[0]; home = m.point
	return m
func _run() -> void:
	await prepare(); mines = game.items.mines
	walker.global_position = Vector3(0,.05,-20); walker.update_form(false)
	game.items.equip(walker,"mine"); combat.ink_amount = 29
	expect(not game.items.use(walker) and game.items.state(walker).cooldowns.mine == 0,"insufficient ink preserves cooldown")
	var m: Dictionary = await deploy()
	if m.is_empty(): await finish("mine placement"); return
	expect(combat.ink_amount == 70 and game.items.state(walker).cooldowns.mine == 10 and m.health == 25,"real item cost, durable CD and destructible HP")
	bot.global_position = home + Vector3(1.8,.05,0); bot.set_meta("enemy_swimming",true); await physics_frame
	mines.tick(.79); expect(m.fuse < 0 and game.bot_health == 120,"arming prevents instant proximity damage")
	mines.tick(.02); expect(m.fuse == .45 and m.warning.visible,"submerged enemy starts actual warning instead of immediate damage")
	mines.tick(.44); expect(game.bot_health == 120,"enemy has full escape interval")
	bot.global_position = home + Vector3(5,.05,0); await physics_frame
	mines.tick(.02); expect(mines.mines.is_empty() and game.bot_health == 120 and game.intel.marker(bot,0).is_empty(),"escaping radius avoids damage and tag")
	m = await deploy(); bot.global_position = home + Vector3(1,.05,0); await physics_frame
	mines.tick(.81); mines.tick(.46)
	expect(game.bot_health < 95 and game.bot_health > 70 and game.player_health == 120,"single mine has falloff, is nonlethal and causes no friendly fire")
	expect(game.intel.marker(bot,0).status == "sonar" and game._attacker_description(walker,"mine").contains("感应墨雷"),"actual explosion shares temporary position tag and readable source")
	bot.global_position = Vector3(70,40,70); game.intel.tick(2.1)
	expect(game.intel.marker(bot,0).is_empty(),"mine mark expires normally")
	m = await deploy(); bot.global_position = home + Vector3(1,.05,0)
	var barrier := wall(home+Vector3(.5,1,0),Vector3(.1,3,5)); await physics_frame
	mines.tick(1); expect(m.fuse < 0,"thin wall blocks proximity trigger")
	m.fuse = .01; mines.tick(.02)
	expect(game.bot_health == 120 and game.intel.marker(bot,0).is_empty(),"thin wall blocks explosion and tag")
	barrier.queue_free(); await physics_frame
	m = await deploy(); bot.global_position = home + Vector3(0,1.15,0)
	var deck := wall(home+Vector3(0,.7,0),Vector3(5,.1,5)); await physics_frame
	mines.tick(1); expect(m.fuse < 0,"thin deck blocks nearby other-floor enemy")
	m.fuse = .01; mines.tick(.02); expect(game.bot_health == 120,"explosion cannot pass thin deck")
	deck.queue_free(); await physics_frame
	m = await deploy(); bot.global_position = home + Vector3(0,4,0); await physics_frame
	mines.tick(1); expect(m.fuse < 0,"sensor uses height rather than XZ disk")
	bot.global_position = home + Vector3(0,.05,3); bot.set_meta("enemy_swimming",false); await physics_frame
	expect(not mines.damage_hit({"collider":m.visual},100,0),"friendly fire cannot disarm own mine")
	var count: int = mines.explosions_total
	walker.global_position = home + Vector3(4,.05,0); await physics_frame
	combat._fire_charger_ray(combat.weapons.charger,1,bot.global_position+Vector3.UP,(m.point+Vector3.UP*.12-bot.global_position-Vector3.UP).normalized(),1,bot)
	expect(mines.mines.is_empty() and mines.explosions_total == count and game.player_health == 120,"real enemy ray safely destroys physical device without triggering it")
	m = await deploy(); bot.global_position = home + Vector3(1,.05,0); await physics_frame
	mines.tick(.81); mines.damage_area(home+Vector3.UP*.2,1,25,1)
	mines.tick(.5); expect(mines.mines.is_empty() and mines.explosions_total == count,"warning-period explosive disarm cancels blast")
	m = await deploy(); game.items.on_death(walker); game.items.equip(walker,"bomb")
	expect(mines.mines.size() == 1 and game.items.state(walker).cooldowns.mine == 10,"owner death/reroll preserve mine and cooldown")
	game.items.equip(walker,"mine"); game.items.state(walker).cooldowns.mine = 0; combat.ink_amount = 100
	expect(not game.items.use(walker),"cannot stack mines on the same spot")
	var first: int = mines.mines.keys()[0]
	for x in [2,4]:
		walker.global_position = Vector3(x,.05,-20); await physics_frame
		combat.ink_amount = 100; game.items.state(walker).cooldowns.mine = 0
		expect(game.items.use(walker),"separate second/third position accepts actual placement")
	expect(mines.mines.size() == 2 and not mines.mines.has(first),"third mine replaces oldest with strict owner limit")
	mines.tick(30.1); expect(mines.mines.is_empty(),"lifetime removes physical devices without detonating")
	walker.global_position = Vector3(70,40,70); bot.global_position = Vector3(0,.05,-20); bot.ink_amount = 100; game.bot_health = 90; bot.health = 90
	game.items.equip(bot,"mine"); game.intel.clear_all(); await physics_frame
	game.items.tick(.1); expect(mines.mines.is_empty() and bot.ink_amount == 100,"AI does not use unknown enemy transforms for deployment")
	walker.global_position = Vector3(0,.05,-14); await physics_frame; game.intel.refresh()
	game.items.tick(.1)
	expect(mines.mines.size() == 1 and bot.ink_amount == 70,"injured AI deploys same mine when team has actual contact")
	var enemy_mine: Dictionary = mines.mines.values()[0]
	walker.global_position = enemy_mine.point + Vector3(2,.05,0); await physics_frame
	expect(mines.escape(walker).length() > 0,"known visible mine produces escape route")
	barrier = wall(enemy_mine.point+Vector3(1,1,0),Vector3(.1,3,5)); await physics_frame
	expect(mines.escape(walker) == Vector3.ZERO,"AI cannot react to mine through a physical wall")
	game._finish_round(); expect(mines.mines.is_empty(),"round completion clears mines")
	await finish("mines actual placement/resources/CD, arming/fuse/escape, concealed tag, 3D wall/deck occlusion, real hostile disarm, lifetime/owner limit/death, knowledge-driven AI and cleanup")
