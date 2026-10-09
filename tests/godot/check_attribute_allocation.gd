extends "res://tests/godot/helpers/creative_fixture.gd"
const Catalog := preload("res://src/core/attribute_catalog.gd")
const Setup := preload("res://src/core/match_setup.gd")

func _initialize() -> void: call_deferred("_run")

func mono(ability: String) -> Dictionary:
	var value := Catalog.empty(); value[ability] = Catalog.MAX_RANK
	return value

func _run() -> void:
	for bad in [null, 3, [], {"health":1000,"run_speed":-10,"swim_speed":2.5,"damage":99}, {"health":true,"ink_capacity":"8"}]:
		var clean := Catalog.normalize(bad)
		expect(Catalog.valid(clean) and Catalog.spent(clean)<=20,"corrupt allocation normalizes without extra ranks or budget")
	for ability in Catalog.ABILITIES:
		expect(is_equal_approx(Catalog.bonus(ability,8),Catalog.CAPS[ability]),"rank eight reaches exact local cap")
		expect(Catalog.bonus(ability,2)-Catalog.bonus(ability,1)<Catalog.bonus(ability,1),"marginal gains diminish")
		expect(Catalog.bonus(ability,1000)==Catalog.bonus(ability,8) and Catalog.bonus(ability,-1)==0,"injected ranks cannot exceed bounds")
	await prepare(5,"tidewater")
	game.show_preparation();game.perks.locked=false
	var before: Dictionary=game.attributes.loadout(walker)
	var over := Catalog.empty(); over.health=8;over.ink_capacity=8;over.run_speed=8
	var floating := Catalog.empty();floating.health=1.5
	var extra := Catalog.empty();extra.damage=1
	for bad in [{},over,floating,extra]:
		expect(not game.attributes.select_player(bad) and game.attributes.loadout(walker)==before,"invalid whole allocation rejects atomically")
	expect(not game.attributes.adjust("damage",1) and not game.attributes.adjust("health",9) and not game.attributes.adjust("health",-1),"unknown attribute/big step/negative rank rejected")
	var copy: Dictionary=game.attributes.loadout(walker);copy.health=8
	expect(game.attributes.loadout(walker)==before,"read-only allocation snapshot does not alias state")
	var rng1:=RandomNumberGenerator.new();rng1.seed=731
	var rng2:=RandomNumberGenerator.new();rng2.seed=731
	expect(Catalog.roll(rng1,{})==Catalog.roll(rng2,{}),"seeded point roll reproduces")
	var seen := {};game.equipment_rng.seed=29
	game.items.state(walker).cooldowns.bomb=4.5;combat.special_points=37;combat.ink_amount=61;game.player_health=82
	for i in 200:
		before=game.attributes.loadout(walker)
		expect(game.attributes.roll_player() and game.attributes.loadout(walker)!=before,"roll changes valid allocation")
		var value:Dictionary=game.attributes.loadout(walker)
		expect(Catalog.valid(value) and Catalog.spent(value)==20,"roll spends exactly twenty without exceeding rank eight")
		for ability in Catalog.ABILITIES:
			if value[ability]>0:seen[ability]=true
	expect(seen.size()==8,"roll reaches all eight attributes")
	expect(game.items.state(walker).cooldowns.bomb==4.5 and combat.special_points==37 and combat.ink_amount==61 and game.player_health==82,"point edits cannot restore resources or reset existing cooldown")
	game.attributes.select_player(Catalog.empty())
	for i in 8:expect(game.attributes.adjust("health",1),"purchase a single health rank")
	expect(not game.attributes.adjust("health",1) and is_equal_approx(game.actor_max_health(walker),132*1.18),"health rank cap reaches actual maximum")
	expect(game.player_health==82,"raising health cap does not heal")
	game.player_health=game.actor_max_health(walker);game.attributes.select_player(Catalog.empty())
	expect(game.player_health==132,"refunding health clamps existing health to lower maximum")
	game.attributes.select_player(mono("ink_capacity"))
	expect(is_equal_approx(game.actor_ink_max(walker),110*1.25) and combat.ink_amount==61,"capacity ranks affect actual tank without refill")
	combat.ink_amount=game.actor_ink_max(walker);game.attributes.select_player(Catalog.empty())
	expect(is_equal_approx(combat.ink_amount,110),"refunding capacity clamps existing ink")
	game.attributes.select_player(mono("run_speed"))
	expect(is_equal_approx(walker.player_config.runSpeed,6.3*1.12) and is_equal_approx(walker.player_config.swimSpeed,combat.weapon_data.player.swimSpeed*1.05),"run ability changes actual config independently of swimming")
	walker.velocity=Vector3.ZERO;walker.grounded=true;walker.ink_owner=-1;walker.update_form(false)
	for i in 90:walker._horizontal_step(1.0/30,Vector2(1,0),false,false,true)
	expect(is_equal_approx(Vector2(walker.velocity.x,walker.velocity.z).length(),6.3*1.12),"human movement integrator consumes boosted run speed")
	game.attributes.select_player(mono("swim_speed"))
	expect(is_equal_approx(walker.player_config.runSpeed,6.3) and is_equal_approx(walker.player_config.swimSpeed,combat.weapon_data.player.swimSpeed*1.05*1.12),"swim ability changes actual config independently")
	walker.velocity=Vector3.ZERO;walker.ink_owner=0;walker.update_form(true)
	for i in 90:walker._horizontal_step(1.0/30,Vector2(1,0),true,false,true)
	expect(is_equal_approx(Vector2(walker.velocity.x,walker.velocity.z).length(),float(combat.weapon_data.player.swimSpeed)*1.05*1.12),"actual own-ink swim integrator consumes boosted speed")
	walker.update_form(false);walker.ink_owner=-1
	game.attributes.select_player(mono("main_saver"));walker.global_position=Vector3(0,.05,-28);game.phase="playing"
	for id in game.weapon_order:
		combat.select_weapon(id);combat.ink_amount=100;combat.last_fire_time=0;combat.last_fire=false
		for flight in combat.discs.flights:flight.visual.queue_free()
		combat.discs.flights.clear();combat.canopy.state(walker).shot_cd=0
		var original: Dictionary=combat.weapons[id].duplicate(true)
		var w: Dictionary=game.perks.weapon(walker,combat.weapons[id]);var spent:float
		match id:
			"shooter","blaster","dualie":combat.tick(.001,true,false);spent=w.inkPerShot
			"charger":combat._fire_charger(w,1,Vector3(0,0,1));spent=w.inkFull
			"bow":combat.bow.fire(walker,walker.global_position+Vector3(0,0,20),1);spent=w.inkFull
			"disc":combat.discs.throw_primary(walker,walker.global_position+Vector3(0,0,10));spent=w.inkPerShot
			"canopy":combat.canopy.update_input(walker,.001,true,walker.global_position+Vector3(0,0,8));spent=w.inkPerShot
			"roller":combat.tick(.001,true,false);spent=w.flickInk
		var cost_key: String="inkFull" if id in ["charger","bow"] else "flickInk" if id=="roller" else "inkPerShot"
		expect(is_equal_approx(spent,float(original[cost_key])*.82) and absf(combat.ink_amount-(100-spent))<.001,"real eight-weapon primary ink saving: "+id)
		expect(combat.weapons[id]==original,"effective configuration does not mutate source weapon: "+id)
		for key_name in original:
			if String(key_name).to_lower().contains("damage"):expect(original[key_name]==w[key_name],"attributes does not change damage or caps")
	game.perks.choices[walker.get_instance_id()]="dry_focus";combat.ink_amount=20
	expect(is_equal_approx(game.perks.weapon(walker,combat.weapons.shooter).inkPerShot,.85*.82*.65),"attributes saving stacks once with conditional talent")
	game.perks.choices[walker.get_instance_id()]="balanced";game.phase="setup"
	combat.select_weapon("shooter");combat.on_death();combat.last_fire_time=99;walker.grounded=true;walker.ink_owner=0
	game.attributes.select_player(mono("ink_recovery"));combat.ink_amount=30
	combat.tick(.1,false,true)
	expect(is_equal_approx(combat.ink_amount,30+float(combat.weapon_data.player.inkRefillSwim)*1.2*.1),"actual natural swim refill receives attributes boost")
	game.attributes._store(bot,mono("ink_recovery"));bot.global_position=Vector3(60,40,60);bot.select_weapon("shooter");bot.last_fire_time=99;bot.ink_amount=80;bot.charge_time=0;bot.paint_cooldown=999
	bot.tick(.1)
	expect(is_equal_approx(bot.ink_amount,80+float(combat.weapon_data.player.inkRefillKid)*1.2*.1),"bot actual idle refill uses same ability")
	game.attributes.select_player(mono("special_charge"));game.comeback.reset();combat.special_points=0;combat.special_active=""
	var area:float=combat._paint_player(Vector3(0,.1,-20),1.3,.9)
	expect(area>0 and is_equal_approx(combat.special_points,area*1.15),"real new ground area charges modified meter")
	var meter:float=combat.special_points;combat._paint_player(Vector3(0,.1,-20),1.3,.9)
	expect(combat.special_points==meter,"repainting own ground cannot exploit charge boost")
	game.attributes._store(bot,mono("special_charge"));game.bot_specials.state(bot).points=0;game.bot_specials.charge(bot,10)
	expect(is_equal_approx(game.bot_specials.state(bot).points,11.5),"bot and player share charge rules")
	game.attributes.select_player(mono("sub_cooldown"));game.phase="playing";game.paused=false;game.player_respawn=0;game.player_health=132;combat.action_lock=0
	game.items.equip(walker,"bomb");game.items.state(walker).cooldowns.bomb=0;combat.ink_amount=100
	expect(game.items.use(walker) and is_equal_approx(game.items.state(walker).cooldowns.bomb,5.1),"actual sub cast uses capped new cooldown")
	expect(is_equal_approx(combat.ink_amount,100-float(combat.weapon_data.sub.bomb.inkCost)),"cooldown ability does not also change sub cost")
	game.phase="setup";game.attributes.roll_player();before=game.attributes.loadout(walker)
	var all_before:=[]
	game.attributes._bots_prepared=false
	game.frontend.attribute_editor.open();expect(game.frontend.attribute_editor.visible,"point editor opens before match")
	game._begin_intro()
	expect(not game.frontend.attribute_editor.visible,"intro closes point editor and releases input")
	for actor in game.all_actors():
		all_before.append(game.attributes.loadout(actor))
		expect(Catalog.spent(game.attributes.loadout(actor))==20,"all actors receive same twenty-point budget")
	game._start_round()
	expect(is_equal_approx(game.player_health,game.actor_max_health(walker)),"actual start fills point-adjusted health cap")
	expect(is_equal_approx(combat.ink_amount,game.actor_ink_max(walker)),"actual start fills point-adjusted ink capacity")
	for phase in ["intro","playing","results","setup","home"]:
		game.phase=phase
		expect(not game.attributes.roll_player() and not game.attributes.adjust("health",-1) and not game.attributes.select_player(Catalog.empty()),"phase spoofing cannot unlock points")
	game.phase="playing";game.player_invuln=0;game.damage_player(500,false,bot,"shooter")
	game.randomize_player_kit();game.randomize_bot_kit(bot);game.items.on_respawn(walker)
	expect(game.attributes.loadout(walker)==before and is_equal_approx(game.items.state(walker).cooldowns.bomb,5.1),"death/kit reroll preserve points and cooldown")
	for i in game.all_actors().size():expect(game.attributes.loadout(game.all_actors()[i])==all_before[i],"all actor points locked for whole match")
	game.phase="setup";game.perks.locked=false
	var sparse:=Catalog.empty();sparse.health=8;sparse.run_speed=5;game.attributes.select_player(sparse)
	expect(Setup.selected_attributes==sparse,"session preferences retain allocated ranks")
	game.attributes._bots_prepared=false;game.attributes.prepare_bots()
	for actor in game.all_actors():expect(Catalog.spent(game.attributes.loadout(actor))==13,"unspent points give bots same sparse budget")
	await finish("eight attributes/twenty-point budget, malformed/alias/rank/over-budget negatives, 200 reproducible rolls, actual health/ink/movement/eight weapon costs/refill/CPU charge/sub cooldown and whole-match locks")
