extends "/Users/yunni/Joy/inkwave-game-cleaned/render-evidence/app-build-2026-10-10/remaining-fixtures-3/creative_fixture.gd"

var observations: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")

func reset_fight(victim: Node3D, attacker: Node3D, hp: float = 120.0) -> void:
	combat.on_death()
	for shot in combat.projectiles: shot.visual.queue_free()
	combat.projectiles.clear()
	combat.bow.clear_all()
	game.phase = "playing"; game.paused = false
	game.player_respawn = 0; game.bot_respawn = 0
	game.player_invuln = 0; game.bot_invuln = 0
	game.player_health = hp; game.bot_health = hp
	combat.ink_amount = 100; combat.last_fire_time = 0; combat.cooldown = 0
	for actor in game.all_actors():
		game.perks.choices[actor.get_instance_id()] = "balanced"
		game.items.state(actor).armor = 0.0
		actor.visible = true
		actor.set_meta("friendly_swimming",false); actor.set_meta("enemy_swimming",false)
		if actor != walker:
			actor.health = hp; actor.invuln = 0; actor.respawn_time = 0; actor.ink_amount = 100
		actor.global_position = Vector3(70+game.actor_id(actor)*3,40,70)
		actor.set_meta("match_stats",{"damage":0.0,"kills":0,"deaths":0,"turf":0.0})
	walker.update_form(false); walker.grounded = true
	attacker.global_position = Vector3(0,40,0)
	victim.global_position = Vector3(0,40,4)

func shoot(id: String, attacker: Node3D, victim: Node3D, height: float = .9) -> void:
	var w: Dictionary = game.perks.weapon(attacker,combat.weapons[id])
	var origin: Vector3 = attacker.global_position+Vector3.UP*height
	var target: Vector3 = victim.global_position+Vector3.UP*height
	var direction := (target-origin).normalized()
	if String(w.kind) == "shooter":
		direction = combat._ballistic_direction(origin,direction,target,float(w.projSpeed),float(w.straightTime),28,.8,float(w.range))
	combat._spawn_shot_pair(w,origin,direction,game.actor_team(attacker),attacker)
	for i in 45: combat._update_projectiles(1.0/30)

func observe(label: String, victim: Node3D, initial: float = 120.0) -> void:
	var hp: float = game.actor_health(victim)
	observations.append({"case":label,"hp":hp,"actual_damage":initial-hp,"alive":game.actor_alive(victim)})
	print("AUDIT: ",label," HP=",hp," actual damage=",initial-hp)

func _run() -> void:
	await prepare(5,"tidewater")
	var ally: Node3D = game.extra_bots[0]
	# Player, primary opponent and additional actor all use the same damage path.
	for victim in [walker,bot,ally]:
		var attacker: Node3D = bot if game.actor_team(victim)==0 else walker
		for height in [.25,.9,1.28]:
			reset_fight(victim,attacker)
			for count in 2: shoot("shooter",attacker,victim,height)
			expect(is_equal_approx(game.actor_health(victim),52),"two near shots leave 52 HP at every height/path")
			shoot("shooter",attacker,victim,height)
			expect(is_equal_approx(game.actor_health(victim),18),"third near shot still leaves reaction HP")
			shoot("shooter",attacker,victim,height)
			expect(not game.actor_alive(victim),"fourth near shot splats at every height/path")
			observe("near shooter actor %d height %.2f" % [game.actor_id(victim),height],victim)
		for id in ["charger","blaster"]:
			reset_fight(victim,attacker)
			if id=="charger":combat.fire_bot_charger(attacker.global_position+Vector3.UP*.9,victim.global_position+Vector3.UP*.9,1,game.actor_team(attacker),attacker)
			else:
				shoot(id,attacker,victim)
				expect(is_equal_approx(game.actor_health(victim),25),"blaster direct requires follow-up")
				shoot(id,attacker,victim)
			expect(not game.actor_alive(victim),id+" direct splats through every actor path")
			expect(is_equal_approx(float(attacker.get_meta("match_stats").damage),120),"overkill ledger records only actual 120 HP loss")
			observe(id+" actor "+str(game.actor_id(victim)),victim)
	# Far shooter, partial charge, finite shield and walls remain real counterplay.
	reset_fight(bot,walker);bot.global_position.z=12
	for count in 4:shoot("shooter",walker,bot)
	expect(game.actor_alive(bot) and game.bot_health>0,"four distant shots do not claim near-range splat")
	observe("far shooter after four",bot)
	shoot("shooter",walker,bot);expect(not game.actor_alive(bot),"five distant accurate shots splat")
	reset_fight(bot,walker)
	combat._fire_charger_ray(combat.weapons.charger,.98,walker.global_position+Vector3.UP*.9,Vector3.BACK,0,walker)
	expect(game.actor_alive(bot) and game.bot_health>25,"almost-full charge still cannot splat")
	observe("98 percent charge",bot)
	for id in ["charger","blaster"]:
		reset_fight(bot,walker);game.items.state(bot).armor=60
		if id=="charger":combat.fire_bot_charger(walker.global_position+Vector3.UP*.9,bot.global_position+Vector3.UP*.9,1,0,walker)
		else:shoot(id,walker,bot)
		var expected: float = 30.0 if id=="charger" else 85.0
		expect(is_equal_approx(game.bot_health,expected) and game.items.state(bot).armor==0,"finite shield protects once from "+id)
		observe("shield vs "+id,bot)
	reset_fight(bot,walker)
	var blocker := wall(Vector3(0,41,2),Vector3(4,4,.2));await physics_frame
	for id in ["charger","blaster","shooter"]:
		reset_fight(bot,walker)
		if id=="charger":combat.fire_bot_charger(walker.global_position+Vector3.UP*.9,bot.global_position+Vector3.UP*.9,1,0,walker)
		else:shoot(id,walker,bot)
		expect(game.bot_health==120,"wall blocks "+id+" direct and splash")
	blocker.queue_free();await physics_frame
	reset_fight(bot,walker);bot.global_position.z=31
	combat.fire_bot_charger(walker.global_position+Vector3.UP*.9,bot.global_position+Vector3.UP*.9,1,0,walker)
	expect(game.bot_health==120,"full charge cannot hit beyond actual range")
	# A full flick is one volley, never nine independent boosted attacks.
	for perk in ["balanced","adrenaline","dry_focus"]:
		reset_fight(bot,walker,300);game.perks.choices[walker.get_instance_id()]=perk
		if perk=="adrenaline":game.player_health=50;game.perks.choices[bot.get_instance_id()]="enemy_swim"
		if perk=="dry_focus":combat.ink_amount=10
		bot.global_position.z=1.1
		combat.spawn_bot_flick(walker.global_position+Vector3.UP*.9,bot.global_position+Vector3.UP*.9,0,walker)
		var volley: Dictionary = combat.projectiles[0].volley
		for i in 100:combat._update_projectiles(.01)
		var dealt: float = 300-game.bot_health
		var cap: float = 84.0 if perk=="dry_focus" else 105.0
		expect(dealt>0 and dealt<=cap+.001,"shared post-perk flick cap: "+perk)
		expect(is_equal_approx(float(volley.final_hits.get(bot.get_instance_id(),0)),dealt),"final volley budget matches actual pre-armour result")
		observe("flick shared cap "+perk,bot,300)
	# Change a perk after the first real hit, then hit again with the same volley.
	reset_fight(bot,walker,300)
	var shared := {}
	combat._spawn_projectile("drop",Vector3(0,40.9,3.3),Vector3.BACK*20,combat.weapons.roller,0,walker,shared)
	combat._update_projectiles(.04)
	var first_damage: float = 300-game.bot_health
	expect(first_damage>0,"first unboosted drop lands before late perk activation")
	game.perks.choices[walker.get_instance_id()]="adrenaline";game.player_health=50
	game.perks.choices[bot.get_instance_id()]="enemy_swim"
	combat._spawn_projectile("drop",Vector3(0,40.9,3.3),Vector3.BACK*20,combat.weapons.roller,0,walker,shared)
	combat._update_projectiles(.04)
	expect(300-game.bot_health<=105.001,"late attacker and defender modifiers cannot bypass one volley cap")
	observe("flick late boost",bot,300)
	reset_fight(bot,walker);bot.global_position.z=1.1
	combat.spawn_bot_flick(walker.global_position+Vector3.UP*.9,bot.global_position+Vector3.UP*.9,0,walker)
	for i in 100:combat._update_projectiles(.01)
	expect(is_equal_approx(game.bot_health,15),"near flick leaves HP for a follow-up")
	observe("near flick",bot)
	reset_fight(walker,bot);game.perks.choices[bot.get_instance_id()]="dry_focus";bot.ink_amount=10
	combat.fire_bot_charger(bot.global_position+Vector3.UP*.9,walker.global_position+Vector3.UP*.9,.98,1,bot)
	expect(is_equal_approx(game.player_health,120-(32+(93-32)*.98)*.8),"bot charge consumes effective dry-focus damage")
	# Rolling requires movement, frontal contact and a clear path, for both teams.
	for attacking_bot in [false,true]:
		reset_fight(walker if attacking_bot else bot,bot if attacking_bot else walker)
		var victim: Node3D = walker if attacking_bot else bot
		var attacker: Node3D = bot if attacking_bot else walker
		victim.global_position.z=1.1
		if attacking_bot:
			bot.roll_hit_cooldown=0
			bot._update_roll(1.0/30,bot.global_position-Vector3.BACK*.15,combat.weapons.roller,combat)
		else:
			walker.get_node("Body").rotation.y=0;walker.velocity=Vector3.BACK*4.4
			combat._roll_damage(combat.weapons.roller)
		expect(is_equal_approx(game.actor_health(victim),25),"moving roller contact leaves reaction HP for both teams")
		observe("roller contact bot="+str(attacking_bot),victim)
	await finish("primary role thresholds on all actor paths, equal regions, distance/charge/shield/wall/range counterplay, actual HP ledger, shared finite boosted flick and effective bot perk")
