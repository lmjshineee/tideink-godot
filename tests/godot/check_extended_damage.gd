extends "res://tests/godot/check_damage_contract.gd"

func bow_hit(attacker: Node3D, victim: Node3D, charge: float, remove_one: bool = false) -> void:
	expect(combat.bow.fire(attacker,victim.global_position+Vector3.UP*.9,charge),"affordable bow release")
	if remove_one:
		var missed: Dictionary= combat.bow.arrows.pop_back()
		missed.visual.queue_free()
	for i in 50:combat.bow.tick(1.0/30)

func _run() -> void:
	await prepare(5,"tidewater")
	var ally: Node3D = game.extra_bots[0]
	for victim in [walker,bot,ally]:
		var attacker: Node3D = bot if game.actor_team(victim)==0 else walker
		reset_fight(victim,attacker)
		for count in 2:shoot("dualie",attacker,victim)
		expect(is_equal_approx(game.actor_health(victim),36),"two accurate dual pairs leave 36 through every actor path")
		shoot("dualie",attacker,victim)
		expect(not game.actor_alive(victim),"third dual pair splats")
		expect(is_equal_approx(float(attacker.get_meta("match_stats").damage),120),"dual overkill does not inflate damage ledger")
		observe("dualie actor "+str(game.actor_id(victim)),victim)
		reset_fight(victim,attacker)
		bow_hit(attacker,victim,1)
		expect(not game.actor_alive(victim),"full three-arrow hit splats through every actor path")
		expect(is_equal_approx(float(attacker.get_meta("match_stats").damage),120),"bow overkill records actual HP loss")
		observe("bow actor "+str(game.actor_id(victim)),victim)
	reset_fight(bot,walker);bot.global_position.z=10.3
	for count in 3:shoot("dualie",walker,bot)
	expect(game.bot_health>0,"far dual pairs retain falloff counterplay")
	shoot("dualie",walker,bot);expect(game.bot_health==0,"four far pairs splat")
	reset_fight(bot,walker);bow_hit(walker,bot,1,true)
	expect(is_equal_approx(game.bot_health,36),"missing one full arrow leaves 36 HP")
	observe("two full arrows",bot)
	reset_fight(bot,walker);bow_hit(walker,bot,.5)
	expect(game.bot_health>0,"half draw cannot claim an immediate full-HP splat")
	observe("half draw",bot)
	reset_fight(bot,walker)
	game.items.equip(bot,"shield");expect(game.items.use(bot),"real shield activation")
	bow_hit(walker,bot,1)
	expect(is_equal_approx(game.bot_health,54) and game.items.state(bot).armor==0,"shield absorbs 60 before full bow's 126 damage")
	observe("shield against full bow",bot)
	reset_fight(bot,walker);game.perks.choices[walker.get_instance_id()]="dry_focus";combat.ink_amount=20
	bow_hit(walker,bot,1)
	expect(is_equal_approx(game.bot_health,19.2),"low-ink full draw trades damage for ink savings")
	observe("dry full bow",bot)
	for late in [false,true]:
		reset_fight(bot,walker,300);bot.global_position.z=16
		game.perks.choices[bot.get_instance_id()]="enemy_swim"
		if not late:game.perks.choices[walker.get_instance_id()]="adrenaline";game.player_health=50
		combat.bow.fire(walker,bot.global_position+Vector3.UP*.9,1);combat.bow.tick(.05)
		if late:game.perks.choices[walker.get_instance_id()]="adrenaline";game.player_health=50
		for i in 50:combat.bow.tick(1.0/30)
		expect(is_equal_approx(game.bot_health,160),"one physical volley shares final 140 cap despite changing perks")
		observe("boosted bow late "+str(late),bot,300)
	reset_fight(bot,walker)
	var barrier:=wall(Vector3(0,41,2),Vector3(4,4,.2));await physics_frame
	bow_hit(walker,bot,1)
	for count in 4:shoot("dualie",walker,bot)
	expect(game.bot_health==120,"real thin wall blocks arrows, explosions and dual pairs")
	barrier.queue_free();await physics_frame
	reset_fight(bot,walker);bot.global_position.z=6
	combat.discs.throw_primary(walker,bot.global_position+Vector3.UP*1.05)
	for i in 140:combat.discs.tick(.01)
	expect(is_equal_approx(game.bot_health,38) and combat.discs.flights.is_empty(),"one disc remains two distinct 48/34 passes with real catch")
	observe("one disc round trip",bot)
	combat.discs.throw_primary(walker,bot.global_position+Vector3.UP*1.05)
	for i in 140:combat.discs.tick(.01)
	expect(game.bot_health==0,"second disc supplies the follow-up")
	reset_fight(bot,walker)
	var direction: Vector3=(bot.global_position+Vector3.UP*.9-(walker.global_position+Vector3.UP*1.05)).normalized()
	combat.canopy._shot(walker,direction,combat.weapons.canopy)
	for i in 45:combat._update_projectiles(1.0/30)
	expect(is_equal_approx(game.bot_health,30) and is_equal_approx(combat.ink_amount,95.5),"six real canopy pellets deal 90 and cost 4.5")
	observe("one canopy volley",bot)
	combat.canopy._shot(walker,direction,combat.weapons.canopy)
	for i in 45:combat._update_projectiles(1.0/30)
	expect(game.bot_health==0,"second canopy volley splats")
	await finish("extended weapon roles, all actor paths, falloff/missing arrow/half draw/shield/dry/wall counterplay, shared boosted volley, real disc catch and canopy pellets")
