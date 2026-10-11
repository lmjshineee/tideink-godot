extends "res://tests/godot/helpers/creative_fixture.gd"
var companions:Node3D
var home:=Vector3(0,20,-10)
func _initialize() -> void:call_deferred("_run")
func steps(count:int) -> void:
	for i in range(count):await physics_frame;companions.tick(1.0/30)
func deploy() -> Dictionary:
	companions.clear_all();await physics_frame
	walker.global_position=home;walker.update_form(false);combat.ink_amount=100;combat.special_active="";combat.action_lock=0
	game.player_health=120;game.player_respawn=0;game.items.equip(walker,"ink_buddy");game.items.state(walker).cooldowns.ink_buddy=0
	var camera:Camera3D=walker.get_node("Camera3D");camera.global_position=home+Vector3(0,1.4,-2);camera.look_at(home+Vector3(0,.9,8));camera.current=true;game.pointer_locked=true
	expect(game.items.use(walker),"actual player item launches creature")
	return companions.buddies.values()[0] if not companions.buddies.is_empty() else {}
func _run() -> void:
	await prepare(5,"tidewater");companions=game.items.buddies
	# Raised collision arena isolates mechanics from incidental map props.
	wall(Vector3(0,19.8,0),Vector3(40,.4,40));await physics_frame
	Engine.time_scale=4;Engine.physics_ticks_per_second=120
	for actor in game.all_actors():
		if actor==walker:continue
		if actor==bot:game.bot_respawn=999
		else:actor.respawn_time=999
	var b:Dictionary=await deploy()
	if b.is_empty():await finish("creature deployment");return
	var start:Vector3=b.body.global_position
	var furthest:=0.0
	for i in range(45):
		await steps(1);furthest=maxf(furthest,b.body.global_position.distance_to(start))
	print("AUDIT: thrown creature start=",start," end=",b.body.global_position," mode=",b.mode," floor=",b.body.is_on_floor())
	expect(b.mode!="flying" and b.body.is_on_floor() and furthest>4,"real capsule follows throw arc and lands on terrain")
	expect(combat.ink_amount==55 and game.items.state(walker).cooldowns.ink_buddy==12,"real resource spend without fixture refill")
	# Controlled ground encounter, with actual capsule movement and attack timer.
	b.body.global_position=home+Vector3(0,0,3);b.body.velocity=Vector3.ZERO;b.mode="search";b.time=12;b.scan=0
	walker.global_position=home-Vector3(0,0,10)
	bot.global_position=home+Vector3(0,0,9);game.bot_respawn=0;game.bot_invuln=0;game.bot_health=120;bot.health=120
	await physics_frame
	var from:Vector3=b.body.global_position
	await steps(65)
	expect(b.body.global_position.distance_to(from)>3 and companions.bites_total>0 and game.bot_health<120,"creature detects, physically pursues and bites a real enemy")
	expect(game.all_actors().size()==10,"summon does not become a player or scoreboard row")
	expect(game._attacker_description(walker,"ink_buddy").contains("墨仔伙伴"),"source display identifies the owner's creature")
	# The raised test floor is not a registered ink surface. Exercise real map paint.
	b.body.global_position=Vector3(12,.05,-23);b.body.velocity=Vector3.ZERO
	bot.global_position=b.body.global_position+Vector3(0,0,.8);game.bot_health=120;bot.health=120
	b.target=bot;b.mode="windup";b.windup=.01;await physics_frame;await steps(1)
	expect(float(walker.get_meta("match_stats").turf)>0,"bite on a real map surface reaches owner-attributed CPU ink ledger")
	# Windup is escapable. A new wall between start and impact prevents damage.
	b.body.global_position=home+Vector3(0,0,3);b.body.velocity=Vector3.ZERO
	bot.global_position=b.body.global_position+Vector3(0,0,.8);game.bot_health=120;bot.health=120
	b.target=bot;b.mode="windup";b.windup=.22
	var barrier:=wall(b.body.global_position+Vector3(0,.8,.4),Vector3(3,2,.08));await physics_frame
	await steps(8)
	expect(game.bot_health==120 and not companions.sees(b,bot),"actual thin wall blocks detection and windup impact")
	barrier.queue_free();await physics_frame
	# Shared shield and damage authority, not direct health writes.
	game.items.state(bot).armor=30;game.items.state(bot).time=6
	b.target=bot;b.mode="windup";b.windup=.01;await steps(1)
	expect(game.bot_health==120 and game.items.state(bot).armor==6,"creature bite spends shield before actor health")
	b.target=bot;b.mode="windup";b.windup=.01;await steps(1)
	expect(game.bot_health==102 and game.items.state(bot).armor==0,"shield overflow uses the same damage path")
	# Concealment and fog do not reveal hidden transforms.
	bot.global_position=b.body.global_position+Vector3(0,0,4);bot.set_meta("enemy_swimming",true)
	game.intel.clear_all();await physics_frame
	expect(not companions.sees(b,bot),"far concealed opponent is not detected")
	game.intel.tag(bot,0);expect(companions.sees(b,bot),"actual sonar tag can reveal concealed opponent")
	game.intel.clear_all();bot.set_meta("enemy_swimming",false)
	game.items.mist.create_volume(bot,(b.body.global_position+bot.global_position)*.5)
	expect(not companions.sees(b,bot),"hostile information fog blocks creature vision")
	game.items.mist.clear_all()
	var deck:=wall(b.body.global_position+Vector3(0,1,0),Vector3(5,.1,5))
	bot.global_position=b.body.global_position+Vector3(0,2,0);await physics_frame
	expect(not companions.sees(b,bot),"thin upper deck prevents cross-floor creature sight")
	companions.damage_area(bot.global_position+Vector3.UP*.5,4,100,1)
	expect(companions.buddies.has(b.id),"explosion cannot hit a creature through an upper deck")
	deck.queue_free();await physics_frame
	# Real bot weapon fire recognizes and hits the small creature capsule.
	bot.global_position=b.body.global_position+Vector3(0,0,-3);walker.global_position=Vector3(70,40,70)
	bot.select_weapon("canopy");bot.reaction_target=null;bot.reaction_time=0;bot.attack_cooldown=0;bot.ink_amount=100
	await physics_frame;bot._tick_team(1.0/30)
	for i in range(45):combat._update_projectiles(.01)
	expect(b.health<companions.HEALTH,"AI canopy pellets aim at the small creature's body and hit its actual capsule")
	combat.canopy.cancel(bot);combat.projectiles.clear()
	b=await deploy();b.body.global_position=home+Vector3(0,0,3);b.body.velocity=Vector3.ZERO;b.mode="search"
	bot.global_position=b.body.global_position+Vector3(0,0,-3);walker.global_position=Vector3(70,40,70)
	game.bot_health=120;bot.health=120;bot.select_weapon("shooter");bot.reaction_target=null;bot.reaction_time=0;bot.attack_cooldown=0;bot.ink_amount=100
	combat.weapons.shooter.spreadBaseGround=0;combat.weapons.shooter.spreadBaseAir=0
	await physics_frame;bot._tick_team(1.0/30)
	expect(int(bot.get_meta("buddy_target",0))==int(b.id) and bot.ink_amount<100 and not combat.projectiles.is_empty(),"AI spends real weapon ink countering a visible nearby hostile summon")
	for i in range(45):combat._update_projectiles(.01)
	expect(b.health<companions.HEALTH or not companions.buddies.has(b.id),"real opposing projectiles hit summon collision instead of aiming above it")
	if companions.buddies.has(b.id):
		expect(not companions.damage_hit({"collider":b.body},100,0),"friendly weapons do not damage own summon")
		companions.damage_area(b.body.global_position+Vector3.UP*.4,1,100,1)
	expect(companions.buddies.is_empty() and companions.destroyed_total>0,"unobstructed enemy damage safely destroys the creature")
	await finish("creature throw/physics/chase/bite, CPU ownership, shields, wall/deck/fog/concealment, AI counter and actual weapon destruction")
