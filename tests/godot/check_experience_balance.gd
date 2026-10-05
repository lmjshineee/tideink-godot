extends "res://tests/godot/helpers/creative_fixture.gd"
const Difficulty:=preload("res://src/core/bot_difficulty.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	await prepare(1,"tidewater")
	var frontend:Control=game.frontend
	game.show_preparation()
	for i in range(Difficulty.IDS.size()):
		frontend.ai_choice.select(i);frontend.ai_choice.item_selected.emit(i)
		expect(game.ai_level==Difficulty.IDS[i] and preload("res://src/core/match_setup.gd").ai_level==game.ai_level,"AI selection reaches match state")
	frontend.ai_choice.get_popup().popup()
	var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.pressed=true;game._input(enter)
	expect(game.phase=="setup","match shortcut does not intercept an open loadout popup")
	frontend.ai_choice.get_popup().hide()
	game._start_round();game.paused=false;game.phase_time=2
	frontend.ai_choice.item_selected.emit(0)
	expect(game.ai_level=="veteran","mid-match UI cannot change locked AI difficulty")
	walker.global_position=Vector3(0,.05,-28);walker.update_form(false);walker.grounded=true;walker.ink_owner=0
	# Every weapon spends precisely its effective configuration, including saver.
	for perk in ["balanced","saver"]:
		game.perks.choices[walker.get_instance_id()]=perk
		for id in game.weapon_order:
			combat.select_weapon(id);combat.ink_amount=100;combat.last_fire_time=0;combat.last_fire=false
			for flight in combat.discs.flights:flight.visual.queue_free()
			combat.discs.flights.clear();combat.canopy.state(walker).shot_cd=0
			var w:Dictionary=game.perks.weapon(walker,combat.weapons[id]);var expected:float
			match id:
				"shooter","blaster","dualie":
					combat.tick(.001,true,false);expected=w.inkPerShot
				"charger":
					combat._fire_charger(w,1,Vector3(0,0,1));expected=w.inkFull
				"bow":
					combat.bow.fire(walker,walker.global_position+Vector3(0,0,20),1);expected=w.inkFull
				"disc":
					combat.discs.throw_primary(walker,walker.global_position+Vector3(0,0,10));expected=w.inkPerShot
				"canopy":
					combat.canopy.update_input(walker,.001,true,walker.global_position+Vector3(0,0,8));expected=w.inkPerShot
				"roller":
					combat.tick(.001,true,false);expected=w.flickInk
			expect(absf(combat.ink_amount-(100-expected))<.001,"actual ink cost: "+perk+" "+id)
	game.perks.choices[walker.get_instance_id()]="balanced"
	# Shield is a real selectable loadout and armour stays finite across death/CD.
	expect("shield" in game.items.KINDS,"shield present in random/selectable pool")
	combat.on_death();game.items.equip(walker,"shield");game.player_health=120;combat.ink_amount=100
	expect(game.items.use(walker),"shield equipped and activated")
	game.damage_player(82,false,bot,"blaster")
	expect(game.player_health==98 and game.items.state(walker).armor==0,"shield absorbs actual damage before HP")
	var cd:float=game.items.state(walker).cooldowns.shield;game.items.on_death(walker);game.items.on_respawn(walker)
	expect(game.items.state(walker).cooldowns.shield==cd,"shield cooldown is not reset by death/respawn")
	# Bot charging pauses free refill, then normal idle refill resumes.
	bot.global_position=Vector3(60,40,60);walker.global_position=Vector3(-60,40,-60);bot.select_weapon("charger")
	bot.ink_amount=30;bot.last_fire_time=99;bot.charge_time=.5
	bot.tick(.01);expect(bot.ink_amount<=30,"bot does not refill inside pending charge")
	bot.tick(.1);expect(bot.ink_amount>30,"bot refills when idle after charge cancellation")
	await finish("AI selection and match lock, all eight effective ink costs with perks, selectable finite shield and fair bot refill")
