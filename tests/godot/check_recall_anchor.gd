extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare()
	var recall: Node3D = game.items.recall
	game.items.equip(walker, "recall")
	walker.global_position = Vector3(0, 0.05, -20)
	combat.ink_amount = 100
	expect(game.items.use(walker), "anchor placed on real level")
	var id := walker.get_instance_id()
	if not recall.anchors.has(id): await finish("recall setup"); return
	var a: Dictionary = recall.anchors[id]
	var home: Vector3 = a.point
	expect(combat.ink_amount == 75 and a.health == 40 and game.items.state(walker).cooldowns.recall == 0, "mark costs ink, active anchor delays cooldown")
	game.player_health = 61
	combat.ink_amount = 33
	walker.global_position += Vector3(4, 0, 0)
	expect(game.items.use(walker), "second press returns immediately")
	expect(walker.global_position.distance_to(home) < 0.01 and game.player_health == 61 and combat.ink_amount == 33, "recall preserves current resources")
	expect(combat.action_lock == 0.35 and game.items.state(walker).cooldowns.recall == 14 and not recall.anchors.has(id), "return removes anchor, starts cooldown and weapon lock")
	combat.select_weapon("shooter")
	combat.tick(0.01, true, false)
	expect(combat.projectiles.is_empty(), "return firing lock blocks actual primary")
	game.items.state(walker).cooldowns.recall = 0
	combat.action_lock = 0
	combat.ink_amount = 100
	game.items.use(walker)
	walker.global_position = home + Vector3(19, 0, 0)
	expect(not game.items.use(walker) and recall.anchors.has(id), "range rejection preserves usable anchor")
	walker.global_position = home + Vector3(4, 0, 0)
	var obstruction := wall(home + Vector3.UP * 0.8, Vector3(1, 1.6, 1))
	await physics_frame
	expect(not game.items.use(walker) and walker.global_position.distance_to(home) > 3, "occupied anchor cannot teleport through solid body")
	obstruction.queue_free()
	await physics_frame
	expect(not recall.damage_hit({"collider": recall.anchors[id].visual}, 50, 0), "friendly fire leaves anchor")
	# Actual enemy projectile passes through the terrain ray and hits anchor layer.
	var at: Vector3 = home + Vector3(0, 0.45, 3)
	combat.spawn_bot_shot(at, home + Vector3.UP * 0.45, "heavy", 1, bot)
	for i in 40: combat._update_projectiles(0.01)
	expect(not recall.anchors.has(id) and game.items.state(walker).cooldowns.recall == 14, "enemy bullets destroy anchor and start cooldown")
	game.items.state(walker).cooldowns.recall = 0
	walker.global_position = home
	combat.ink_amount = 100
	game.items.use(walker)
	recall.tick(12.1)
	expect(not recall.anchors.has(id) and game.items.state(walker).cooldowns.recall == 14, "expiry starts cooldown")
	game.items.state(walker).cooldowns.recall = 0
	game.items.use(walker)
	game.items.on_death(walker)
	expect(not recall.anchors.has(id), "death clears anchor")
	game.randomize_player_kit()
	expect(game.items.state(walker).cooldowns.recall == 14, "reroll does not reset recall cooldown")
	game.items.equip(bot, "recall")
	bot.global_position = Vector3(3, 0.05, -20)
	bot.ink_amount = 100
	expect(game.items.use(bot), "bot can mark away from enemy spawn")
	bot.global_position.x += 4
	bot.health = 50
	game.bot_health = 50
	game.items.tick(0.1)
	expect(not recall.anchors.has(bot.get_instance_id()) and bot.global_position.x < 4 and bot.get_meta("action_lock", 0) == 0.35, "low-health bot uses its own return and fire lock")
	await finish("recall mark/return cost, current resources, fire lock, occupied/range guards, enemy bullet destruction, expiry/death/reroll cooldown and bot use")
