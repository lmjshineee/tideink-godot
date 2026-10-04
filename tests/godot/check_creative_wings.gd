extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare(); walker.global_position = Vector3(0,.05,-20); walker.reset_movement_state(); walker.grounded = true
	game.items.equip(walker,"ink_wings"); combat.ink_amount = 39; await physics_frame
	expect(not game.items.use(walker) and game.items.state(walker).cooldowns.ink_wings == 0,"flight insufficient ink does not spend cooldown")
	combat.ink_amount = 100; expect(game.items.use(walker),"supported actual E item path opens wings")
	expect(game.wings.busy(walker) and combat.ink_amount == 60 and game.items.state(walker).cooldowns.ink_wings == 18,"actual flight resources and CD")
	var base: float = walker.global_position.y; key(KEY_SPACE,true)
	for i in 50: game.wings.tick(.033); walker._physics_process(.033)
	expect(walker.global_position.y >= base+4.4 and walker.global_position.y <= base+4.51,"flight uses physical ascent capped at relative 4.5m")
	key(KEY_SPACE,false); var y: float = walker.global_position.y; walker._physics_process(.033)
	expect(absf(walker.global_position.y-y) < .02,"release vertical control holds actual altitude")
	var ink_before: float = combat.ink_amount; combat.last_fire_time = 99; combat.tick(.1,false,false)
	expect(combat.ink_amount == ink_before,"wing busy state blocks normal refill")
	combat.special_points = combat.special_cost(); expect(not combat.try_special(),"cannot start special while flying")
	expect(not game.items.use(walker),"cannot use other items in flight")
	combat.select_weapon("shooter"); combat.cooldown = 0; combat.tick(.033,true,false)
	expect(combat.ink_amount < ink_before and not combat.projectiles.is_empty(),"regular primary shoots and spends ink in flight")
	key(KEY_SHIFT,true)
	for i in 3: walker._physics_process(.033)
	key(KEY_SHIFT,false)
	expect(walker.global_position.y < y-.2 and not walker.squid_form,"Shift physically descends while staying human")
	game.wings.cancel(walker); await physics_frame
	var old: float = walker.global_position.y; walker._physics_process(.1); expect(walker.global_position.y < old,"cancellation returns to normal gravity without teleport")
	walker.global_position = Vector3(0,.05,-20); walker.reset_movement_state(); walker.grounded = true; game.items.state(walker).cooldowns.ink_wings = 0; combat.ink_amount = 100; await physics_frame
	var roof := wall(walker.global_position+Vector3(0,2,0),Vector3(5,.1,5)); await physics_frame; expect(game.items.use(walker),"flight can begin under ceiling")
	key(KEY_SPACE,true)
	for i in 15: game.wings.tick(.033); walker._physics_process(.033)
	key(KEY_SPACE,false); expect(walker.global_position.y < .8,"thin roof blocks ascent rather than tunnelling")
	game.wings.cancel(walker); roof.queue_free(); await physics_frame
	walker.global_position = Vector3(70,40,70); bot.global_position = Vector3(0,.05,-20); bot.select_weapon("shooter"); bot.ink_amount = 100; bot.target_actor = null; game.items.equip(bot,"ink_wings"); await physics_frame
	expect(game.items.use(bot),"AI uses same supported flight path")
	var height: float = bot.global_position.y
	for i in 12: game.wings.tick(.033); bot._tick_team(.033)
	expect(bot.global_position.y > height+.5 and bot.ink_amount < 60,"bot collision body really ascends and uses drain")
	game.items.on_death(bot); expect(not game.wings.busy(bot) and game.items.state(bot).cooldowns.ink_wings == 18,"death cancels flight while keeping CD")
	walker.global_position = Vector3(70,40,70); bot.global_position = Vector3(0,.05,-20); bot.ink_amount = 100; game.items.state(bot).cooldowns.ink_wings = 0; bot.target_actor = null; await physics_frame; game.items.tick(.01)
	expect(not game.wings.busy(bot),"AI flight choice cannot invent unseen target")
	bot.global_position = Vector3(70,40,70); walker.global_position = Vector3(0,.05,-20); walker.reset_movement_state(); walker.grounded = true; await physics_frame
	game.items.state(walker).cooldowns.ink_wings = 0; combat.ink_amount = 100; expect(game.items.use(walker),"new supported cast for lifetime check")
	game.wings.tick(4.01); expect(not game.wings.busy(walker) and combat.ink_amount < 28,"four-second expiry drains ink and cancels automatically")
	game.items.state(walker).cooldowns.ink_wings = 0; combat.ink_amount = 41; expect(game.items.use(walker),"nearly empty tank can spend initial item cost")
	game.wings.tick(.2); expect(not game.wings.busy(walker) and combat.ink_amount == 0,"ink exhaustion ends flight without negative resource")
	game._finish_round(); expect(game.wings.flights.is_empty(),"round cleanup clears wings")
	await finish("wing supported cost/CD, actual capped ascent/hover/descent/gravity, thin roof, normal primary/resource drain/no refill, special/item locks, bot body movement/death/knowledge/cleanup")
