extends "res://tools/creative_fixture.gd"
var decoys: Node3D
var home := Vector3(0,.05,-20)
func _initialize() -> void: call_deferred("_run")
func deploy() -> Dictionary:
	decoys.clear_all(); walker.global_position = home; walker.update_form(false); combat.ink_amount = 100; combat.special_active = ""; combat.action_lock = 0
	game.items.equip(walker,"echo_decoy"); game.items.state(walker).cooldowns.echo_decoy = 0
	bot.global_position = Vector3(70,40,70); game.bot_health = 120; bot.health = 120
	var camera: Camera3D = walker.get_node("Camera3D"); camera.current = true; camera.global_position = home+Vector3(0,1.5,-2); camera.look_at(home+Vector3(0,-.05,5))
	game.pointer_locked = true; await physics_frame
	expect(game.items.use(walker),"actual aim-visible floor accepts decoy")
	return decoys.decoys.values()[0] if not decoys.decoys.is_empty() else {}
func _run() -> void:
	await prepare(); decoys = game.items.decoys
	combat.weapons.shooter.spreadBaseGround = 0
	var d: Dictionary = await deploy()
	if d.is_empty(): await finish("decoy placement"); return
	expect(combat.ink_amount == 75 and d.health == 20 and game.items.state(walker).cooldowns.echo_decoy == 12,"resources/health and per-kind cooldown")
	game.items.state(walker).cooldowns.echo_decoy = 0; combat.ink_amount = 24
	expect(not game.items.use(walker) and game.items.state(walker).cooldowns.echo_decoy == 0 and decoys.decoys.size() == 1,"refused low-ink placement preserves old fake and CD")
	game.items.state(walker).cooldowns.echo_decoy = 12; combat.ink_amount = 75
	expect(decoys.target(walker,home+Vector3(0,0,9)).is_empty(),"placement cannot reach beyond actual 8m sphere")
	var placement_wall := wall(home+Vector3(0,1,2),Vector3(6,3,.1)); await physics_frame
	expect(decoys.target(walker,home+Vector3(0,-.05,4)).is_empty(),"placement cannot project through thin wall")
	placement_wall.queue_free(); await physics_frame

	var roster: int = game.all_actors().size(); var meter: float = combat.special_points; var hp: float = game.player_health
	decoys.tick(1)
	expect(game.all_actors().size() == roster and combat.special_points == meter and game.player_health == hp,"fake animation produces no actor, damage or charge")
	walker.global_position = Vector3(70,40,70); bot.global_position = d.point+Vector3(0,.05,-5); bot.select_weapon("shooter"); bot.attack_cooldown = 0; bot.ink_amount = 100; await physics_frame
	expect(not decoys.target_for(bot,13).is_empty(),"bot sees actual fake capsule")
	bot._tick_team(.016)
	expect(bot.target_actor == null and int(bot.get_meta("decoy_target",0)) == d.id and bot.ink_amount < 100 and not combat.projectiles.is_empty(),"fooled AI aims fake and spends real primary ink")
	for i in 50: combat._update_projectiles(.01)
	expect(decoys.decoys.is_empty() and game.player_health == hp and game.bot_health == 120,"real opposing bullets destroy fake without player damage")
	d = await deploy(); bot.global_position = d.point+Vector3(0,.05,-4); await physics_frame
	var barrier := wall(d.point+Vector3(0,1,-2),Vector3(5,3,.1)); await physics_frame
	expect(decoys.target_for(bot,13).is_empty(),"thin wall hides fake from AI")
	decoys.scan(bot.global_position+Vector3.UP*.75,0,12,1)
	expect(not d.revealed[1],"sonar cannot reveal fake through wall")
	barrier.queue_free(); await physics_frame
	game.items.equip(bot,"sonar"); bot.ink_amount = 100; game.items.state(bot).cooldowns.sonar = 0
	expect(game.items.use(bot),"hostile actual sonar station deployed")
	for i in 90: game.items.sonar.tick(.01)
	expect(d.revealed[1] and decoys.target_for(bot,13).is_empty(),"actual swept sonar identifies fake and stops bot wasting shots")
	expect(not decoys.damage_hit({"collider":d.visual},50,0),"friendly weapons pass own fake")
	# Opposing fake uses a real visible contact and its own team materials/identity.
	decoys.clear_all(); game.items.sonar.clear_all(); walker.global_position = home; bot.global_position = home+Vector3(0,.05,5)
	game.intel.clear_all(); await physics_frame; game.intel.refresh(); bot.ink_amount = 100; game.items.equip(bot,"echo_decoy"); game.items.state(bot).cooldowns.echo_decoy = 0
	expect(game.items.use(bot),"opposing fake deploys through same item path")
	if not decoys.decoys.is_empty():
		var hostile: Dictionary = decoys.decoys.values()[0]
		expect(hostile.body.team == 1 and hostile.label.text.contains(game.actor_name(bot)) and not hostile.label.text.contains("诱饵"),"enemy fake copies actual owner identity rather than announcing fake")
		walker.global_position = home+Vector3(4,.05,0); await physics_frame
		game.items.mist.create_volume(bot,(walker.global_position+hostile.point)*.5)
		decoys.tick(.01); expect(not hostile.body.visible and not hostile.label.visible,"enemy fog hides fake body and label without leaking identity")
		game.items.mist.clear_all(); decoys.tick(.01)
		expect(hostile.body.visible,"fake visibility returns when hostile fog ends")
		decoys.scan(walker.global_position+Vector3.UP*.75,0,12,0)
		expect(hostile.label.text.contains("诱饵") and decoys.marks_for(0)[0].known,"sonar changes fake world/map identity for observer team")
	d = await deploy(); bot.global_position = d.point+Vector3(0,.05,-4); await physics_frame; decoys.tick(.01)

	decoys.tick(.01); expect(decoys.marks_for(0).size() == 1,"own decoy has separately identified shared map mark")
	walker.global_position = Vector3(70,40,70); bot.global_position = Vector3(70,40,70); decoys.tick(.01)
	expect(decoys.marks_for(1).size() == 1 and decoys.marks_for(1)[0].status == "last","last fake contact freezes after LOS lost")
	decoys.tick(1.6); expect(decoys.marks_for(1).is_empty(),"hidden fake expires from enemy map")
	game.items.on_death(walker); game.items.equip(walker,"bomb")
	expect(decoys.decoys.size() == 1 and game.items.state(walker).cooldowns.echo_decoy == 12,"death and reroll keep device and CD")
	decoys.tick(8); expect(decoys.decoys.is_empty(),"fake lifetime expires safely")
	d = await deploy(); bot.global_position = d.point+Vector3(0,2,0); var deck := wall(d.point+Vector3(0,1,0),Vector3(6,.1,6)); await physics_frame
	expect(decoys.target_for(bot,13).is_empty(),"other-floor fake has real thin-deck occlusion")
	decoys.damage_area(bot.global_position+Vector3.UP*.3,4,30,1); expect(decoys.decoys.size() == 1,"explosion cannot destroy fake through deck")
	deck.queue_free(); await physics_frame
	decoys.damage_area(d.point+Vector3.UP*.8,1,30,1); expect(decoys.decoys.is_empty(),"visible explosion safely removes fake")
	walker.global_position = home; bot.global_position = home+Vector3(0,.05,5); walker.global_position = Vector3(70,40,70); game.intel.clear_all(); game.items.equip(bot,"echo_decoy"); game.items.state(bot).cooldowns.echo_decoy = 0; bot.ink_amount = 100; game.bot_health = 90
	await physics_frame; game.items.tick(.01); expect(decoys.decoys.is_empty(),"AI cannot place toward unknown enemy transform")
	walker.global_position = home; await physics_frame; game.intel.refresh(); game.items.tick(.01)
	expect(decoys.decoys.size() == 1,"injured AI places fake toward real shared contact")
	game._finish_round(); expect(decoys.decoys.is_empty(),"round cleanup removes fake visuals/collision")
	await finish("echo decoy actual resources/aim/roster, fake-target primary fire, physical destruction, sonar counter, LOS/decks/map/memory, knowledge-based AI, persistent CD/death and cleanup")
