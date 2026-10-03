extends "res://tools/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare()
	expect(game.weapon_order == ["shooter", "roller", "charger", "blaster", "dualie", "disc", "bow", "canopy"], "active catalog retires duplicate guns")
	expect(game.items.KINDS == ["bomb", "intel_mist", "beacon", "recall", "sonar", "mine", "echo_decoy", "supply_box", "ink_wings"] and game.perks.ORDER.size() == 8, "active item/perk pools")
	for i in 30:
		game.randomize_player_kit()
		expect(game.weapon_order.has(combat.selected_id) and game.items.KINDS.has(game.items.state(walker).kind), "reroll only active kits")
	combat.select_weapon("disc")
	walker.global_position = Vector3(0, 40, 0)
	bot.global_position = Vector3(0, 40, -6)
	game.bot_health = 120
	bot.health = 120
	combat.ink_amount = 100
	var discs: Node3D = combat.discs
	expect(discs.throw_primary(walker, bot.global_position + Vector3.UP * 1.05), "throw succeeds")
	expect(combat.ink_amount == 92 and not discs.throw_primary(walker, bot.global_position), "one primary in flight and one cost")
	for i in 130: discs.tick(0.01)
	expect(is_equal_approx(game.bot_health, 38), "outbound 48 and return 34 hit only once each")
	expect(discs.flights.is_empty(), "catch releases next throw")
	game.bot_health = 120
	bot.health = 120
	discs.throw_primary(walker, bot.global_position + Vector3.UP * 1.05)
	for i in 48: discs.tick(0.01)
	walker.global_position.x = 4
	discs.tick(0.01)
	expect(discs.flights.size() == 1 and discs.flights[0].returning and discs.flights[0].direction.x > 0.2, "moving owner bends return trajectory")
	for i in 180: discs.tick(0.01)
	walker.global_position = Vector3(0, 40, 0)
	bot.global_position = Vector3(0, 40, -9)
	game.bot_health = 120
	bot.health = 120
	var barrier := wall(Vector3(0, 41, -6), Vector3(4, 4, 0.5))
	await physics_frame
	discs.throw_primary(walker, bot.global_position + Vector3.UP)
	for i in 150: discs.tick(0.01)
	expect(game.bot_health == 120 and discs.flights.is_empty(), "solid wall blocks outbound hit and allows return")
	combat.special_points = 180
	expect(combat.try_special() and discs.windups.size() == 1 and discs.flights.is_empty(), "special consumes meter before telegraph")
	discs.tick(0.39)
	expect(discs.flights.is_empty(), "twins wait full telegraph")
	discs.tick(0.02)
	expect(discs.flights.size() == 2 and discs.flights[0].special and discs.flights[1].special, "two independent giant discs launch")
	for i in 130: discs.tick(0.01)
	expect(game.bot_health == 120 and discs.flights.is_empty(), "both giant discs respect wall and expire")
	walker.global_position.z = -5.4
	combat.special_active = ""
	discs.throw_primary(walker, bot.global_position + Vector3.UP)
	for i in 60: discs.tick(0.01)
	expect(game.bot_health == 120, "muzzle inside wall cannot tunnel through it")
	walker.global_position.z = 0
	barrier.queue_free()
	await physics_frame
	combat.advance_effects(0.01)
	combat.special_points = 180
	combat.try_special()
	game.player_respawn = 3
	discs.tick(0.41)
	expect(discs.windups.is_empty() and discs.flights.is_empty(), "death cancels unreleased twins")
	game.player_respawn = 0
	combat.special_active = ""
	bot.select_weapon("disc")
	bot.global_position = Vector3(0, 40, -5)
	game.bot_health = 120
	bot.health = 120
	bot.ink_amount = 100
	bot.tick(0.033)
	print("AUDIT: bot disc ",discs.primary_in_flight(bot)," ink ",bot.ink_amount," target ",bot.target_actor)
	expect(discs.primary_in_flight(bot) and bot.ink_amount >= 91.4 and bot.ink_amount <= 92, "team bot uses real primary and cost")
	for i in 140: discs.tick(0.01)
	game.bot_specials.state(bot).points = 180
	game.bot_specials.tick(0.033)
	expect(discs.winding_up(bot), "bot dispatches twin special rather than storm")
	await finish("creative active pools, per-pass returning disc damage, curved return, wall sweep, twin telegraph/death cleanup and bot dispatch")
