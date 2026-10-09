extends "res://tests/godot/helpers/creative_fixture.gd"
const Catalog := preload("res://src/core/gear_catalog.gd")
const Setup := preload("res://src/core/match_setup.gd")

func _initialize() -> void: call_deferred("_run")

func mono(ability: String) -> Dictionary:
	var value := Catalog.empty()
	for piece in Catalog.PIECES:
		for index in 4: value[piece][index] = ability
	return value

func _run() -> void:
	for bad in [null, 3, [], {"head":[null,"damage",7,"run_speed","main_saver"],"clothes":42}]:
		var clean := Catalog.normalize(bad)
		expect(Catalog.valid(clean),"corrupt setup normalizes to exactly three four-slot pieces")
		expect(not clean.head.has("damage") and Catalog.points(clean).values().reduce(func(a,b):return a+b,0)<=57,"invalid abilities or extra slots cannot add power")
	var weighted := Catalog.empty(); weighted.head[0]="run_speed";weighted.head[1]="run_speed"
	expect(Catalog.points(weighted).run_speed==13,"main and secondary have different weights")
	for ability in Catalog.ABILITIES:
		expect(Catalog.points(mono(ability))[ability]==57,"all twelve slots cap at 57 points")
		expect(is_equal_approx(Catalog.bonus(ability,57),Catalog.CAPS[ability]),"reachable cap is exact")
		expect(Catalog.bonus(ability,10)>Catalog.bonus(ability,3) and Catalog.bonus(ability,6)-Catalog.bonus(ability,3)<Catalog.bonus(ability,3),"same-ability stacking has diminishing gain")
		expect(Catalog.bonus(ability,1000)==Catalog.bonus(ability,57) and Catalog.bonus(ability,-1)==0,"injected points cannot bypass bounds")
	await prepare(5,"tidewater")
	game.show_preparation();game.perks.locked=false
	var before: Dictionary=game.gear.loadout(walker)
	for bad in [{},{"head":[]}, {"head":["run_speed","none","none","damage"],"clothes":["none","none","none","none"],"shoes":["none","none","none","none"]}]:
		expect(not game.gear.select_player(bad) and game.gear.loadout(walker)==before,"invalid edit rejects atomically")
	expect(not game.gear.select_slot("weapon",0,"run_speed") and not game.gear.select_slot("head",4,"run_speed") and not game.gear.select_slot("head",0,"damage"),"unknown piece/index/ability rejected")
	var copy: Dictionary = game.gear.loadout(walker);copy.head[0]="run_speed"
	expect(game.gear.loadout(walker)==before,"read-only snapshot does not alias runtime loadout")
	var rng1:=RandomNumberGenerator.new();rng1.seed=731
	var rng2:=RandomNumberGenerator.new();rng2.seed=731
	expect(Catalog.roll(rng1,{})==Catalog.roll(rng2,{}),"seeded equipment roll is reproducible")
	var seen := {};game.equipment_rng.seed=29
	game.items.state(walker).cooldowns.bomb=4.5;combat.special_points=37;combat.ink_amount=61;game.player_health=82
	for i in 200:
		before=game.gear.loadout(walker)
		expect(game.gear.roll_player() and game.gear.loadout(walker)!=before,"gear roll always changes valid equipment")
		for piece in Catalog.PIECES:
			for ability in game.gear.loadout(walker)[piece]:seen[ability]=true
	expect(seen.size()==6 and not seen.has("none"),"roll reaches all six active abilities and fills all twelve slots")
	expect(game.items.state(walker).cooldowns.bomb==4.5 and combat.special_points==37 and combat.ink_amount==61 and game.player_health==82,"gear rolls cannot heal, refill, charge or clear cooldowns")
	game.gear.select_player(mono("run_speed"))
	expect(is_equal_approx(walker.player_config.runSpeed,6.3*1.12) and is_equal_approx(walker.player_config.swimSpeed,combat.weapon_data.player.swimSpeed*1.05),"run ability changes actual config independently of swimming")
	walker.velocity=Vector3.ZERO;walker.grounded=true;walker.ink_owner=-1;walker.update_form(false)
	for i in 90:walker._horizontal_step(1.0/30,Vector2(1,0),false,false,true)
	expect(is_equal_approx(Vector2(walker.velocity.x,walker.velocity.z).length(),6.3*1.12),"human movement integrator consumes boosted run speed")
	game.gear.select_player(mono("swim_speed"))
	expect(is_equal_approx(walker.player_config.runSpeed,6.3) and is_equal_approx(walker.player_config.swimSpeed,combat.weapon_data.player.swimSpeed*1.05*1.12),"swim ability changes actual config independently")
	walker.velocity=Vector3.ZERO;walker.ink_owner=0;walker.update_form(true)
	for i in 90:walker._horizontal_step(1.0/30,Vector2(1,0),true,false,true)
	expect(is_equal_approx(Vector2(walker.velocity.x,walker.velocity.z).length(),float(combat.weapon_data.player.swimSpeed)*1.05*1.12),"actual own-ink swim integrator consumes boosted speed")
	walker.update_form(false);walker.ink_owner=-1
	game.gear.select_player(mono("main_saver"));walker.global_position=Vector3(0,.05,-28);game.phase="playing"
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
			if String(key_name).to_lower().contains("damage"):expect(original[key_name]==w[key_name],"gear does not change damage or caps")
	game.perks.choices[walker.get_instance_id()]="dry_focus";combat.ink_amount=20
	expect(is_equal_approx(game.perks.weapon(walker,combat.weapons.shooter).inkPerShot,.85*.82*.65),"gear saving stacks once with conditional talent")
	game.perks.choices[walker.get_instance_id()]="balanced";game.phase="setup"
	combat.select_weapon("shooter");combat.on_death();combat.last_fire_time=99;walker.grounded=true;walker.ink_owner=0
	game.gear.select_player(mono("ink_recovery"));combat.ink_amount=30
	combat.tick(.1,false,true)
	expect(is_equal_approx(combat.ink_amount,30+float(combat.weapon_data.player.inkRefillSwim)*1.2*.1),"actual natural swim refill receives gear boost")
	game.gear._store(bot,mono("ink_recovery"));bot.global_position=Vector3(60,40,60);bot.select_weapon("shooter");bot.last_fire_time=99;bot.ink_amount=80;bot.charge_time=0;bot.paint_cooldown=999
	bot.tick(.1)
	expect(is_equal_approx(bot.ink_amount,80+float(combat.weapon_data.player.inkRefillKid)*1.2*.1),"bot actual idle refill uses same ability")
	game.gear.select_player(mono("special_charge"));game.comeback.reset();combat.special_points=0;combat.special_active=""
	var area:float=combat._paint_player(Vector3(0,.1,-20),1.3,.9)
	expect(area>0 and is_equal_approx(combat.special_points,area*1.15),"real new ground area charges modified meter")
	var meter:float=combat.special_points;combat._paint_player(Vector3(0,.1,-20),1.3,.9)
	expect(combat.special_points==meter,"repainting own ground cannot exploit charge boost")
	game.gear._store(bot,mono("special_charge"));game.bot_specials.state(bot).points=0;game.bot_specials.charge(bot,10)
	expect(is_equal_approx(game.bot_specials.state(bot).points,11.5),"bot and player share charge rules")
	game.gear.select_player(mono("sub_cooldown"));game.phase="playing";game.paused=false;game.player_respawn=0;game.player_health=132;combat.action_lock=0
	game.items.equip(walker,"bomb");game.items.state(walker).cooldowns.bomb=0;combat.ink_amount=100
	expect(game.items.use(walker) and is_equal_approx(game.items.state(walker).cooldowns.bomb,5.1),"actual sub cast uses capped new cooldown")
	expect(is_equal_approx(combat.ink_amount,100-float(combat.weapon_data.sub.bomb.inkCost)),"cooldown ability does not also change sub cost")
	before=game.gear.loadout(walker);var all_before:=[]
	game.phase="setup"
	game.gear._bots_prepared=false # Fresh lineup calibration; the shared fixture already began one round.
	game.frontend.gear_editor.open();expect(game.frontend.gear_editor.visible,"pre-match editor opens while editable")
	game._begin_intro()
	expect(not game.frontend.gear_editor.visible,"phase transition closes editor so hidden UI cannot swallow gameplay input")
	for actor in game.all_actors():
		all_before.append(game.gear.loadout(actor))
		var enabled_points: int=0
		for value in game.gear.totals(actor).values():enabled_points+=value
		expect(enabled_points==57,"both teams start with the same enabled slot budget")
	for phase in ["intro","playing","results","setup","home"]:
		game.phase=phase
		expect(not game.gear.roll_player() and not game.gear.select_player(Catalog.empty()) and not game.gear.select_slot("head",0,"run_speed"),"phase switch cannot bypass locked gear")
	game.phase="playing";game.player_invuln=0;game.damage_player(500,false,bot,"shooter")
	game.randomize_player_kit();game.randomize_bot_kit(bot);game.items.on_respawn(walker)
	expect(game.gear.loadout(walker)==before and is_equal_approx(game.items.state(walker).cooldowns.bomb,5.1),"death and kit rerolls preserve gear and existing sub cooldown")
	for i in game.all_actors().size():expect(game.gear.loadout(game.all_actors()[i])==all_before[i],"every actor gear remains fixed")
	game.phase="setup";game.perks.locked=false;game.gear.select_player(weighted)
	expect(Setup.selected_gear==weighted,"setup preferences persist across scene replacement")
	game.gear._bots_prepared=false;game.gear.prepare_bots()
	for actor in game.all_actors():
		var enabled_points: int=0
		for value in game.gear.totals(actor).values():enabled_points+=value
		expect(enabled_points==13,"sparse custom equipment gives both teams equal slot budget")
		var shape:Dictionary=game.gear.loadout(actor)
		expect(shape.head[0]!="none" and shape.head[1]!="none" and shape.head[2]=="none" and shape.clothes==["none","none","none","none"],"bots match enabled positions without inventing extra slots")
	await finish("three pieces/twelve slots, malformed input/alias/bounds negatives, weighted diminishing caps, 200 reproducible rolls, actual movement/all eight primary costs/player+bot refill/CPU charge/sub cooldown, match/death locks")
