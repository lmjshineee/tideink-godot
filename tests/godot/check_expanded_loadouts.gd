extends SceneTree
var failures:Array[String]=[]
func _initialize() -> void:call_deferred("_run")
func expect(ok:bool,message:String) -> void:
	if not ok:failures.append(message);printerr("FAIL: ",message)
func _run() -> void:
	var setup:=preload("res://src/core/match_setup.gd")
	setup.screen="setup";setup.map_id="modular_harbor";setup.map_seed=6;setup.random_map=true;setup.map_variant=6;setup.selected_perk="balanced";setup.selected_item="bomb"
	var game:Node3D=(load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game)
	await physics_frame;game.set_physics_process(false)
	var walker:CharacterBody3D=game.get_node("World/Walker");walker.set_physics_process(false)
	var combat:Node3D=game.get_node("Combat");var bot:Node3D=game.get_node("Bot")
	for actor in game.all_actors():game.perks.choices[actor.get_instance_id()]="balanced"
	expect(game.weapon_order.size()==8 and game.items.KINDS.size()==9 and game.perks.ORDER.size()==8,"expanded catalogs reach actual match rules")
	for id in game.weapon_order:
		game.weapon_buttons[id].pressed.emit();var body:Node3D=walker.get_node("Body")
		body._physics_process(.1)
		expect(body.current_weapon==id and body.original_weapons.has(id) and body.original_weapons[id].visible,"source mesh and animation installed for "+id)
	game._start_round();game.player_invuln=0
	for actor in game.all_actors():
		if actor!=walker:actor.global_position=Vector3(70,40,70)
	walker.global_position=Vector3(0,40,0)
	for id in ["dualie","heavy","rapid"]:
		game.player_health=120;game.player_respawn=0;game.damage_history.clear()
		combat.spawn_bot_shot(Vector3(0,40.8,-3),walker.global_position+Vector3.UP*.8,id,1,bot)
		expect(combat.projectiles.size()==(2 if id=="dualie" else 1),"paired / single attack dispatch "+id)
		for step in 100:combat._update_projectiles(.01)
		expect(game.player_health<120 and game.player_health>0,"one actual attack hits and leaves reaction HP "+id)
		expect(not game.damage_history.is_empty() and game.damage_history[0].cause.contains(game._weapon_text(id)),"in-flight weapon attribution preserves extension "+id)
		print("AUDIT: ",id," one attack leaves ",game.player_health," HP")
	game.perks.choices[walker.get_instance_id()]="leech";game.player_health=60;game.bot_health=20;bot.health=20;game.bot_invuln=0;game.bot_respawn=0
	game.damage_bot(80,walker,"heavy")
	expect(is_equal_approx(game.player_health,63),"leech uses actual 20 HP, not overkill")
	game.bot_respawn=0;game.bot_health=120;bot.health=120;game.items.state(bot).armor=60;game.items.state(bot).time=6;game.player_health=60
	game.damage_bot(30,walker,"dualie")
	expect(game.player_health==60,"fully shielded hit does not heal attacker")
	game.perks.choices[walker.get_instance_id()]="focus"
	var precision:Dictionary=game.perks.weapon(walker,combat.weapons.heavy)
	expect(is_equal_approx(precision.spreadBaseGround,combat.weapons.heavy.spreadBaseGround*.65) and precision.spreadBaseAir==combat.weapons.heavy.spreadBaseAir,"focus changes ground cone only")
	game.perks.choices[walker.get_instance_id()]="recycler";expect(game.perks.refill(walker)==1.25,"recycler modifies actual refill")
	game.perks.choices[walker.get_instance_id()]="subtech";game.items.equip(walker,"cluster");combat.ink_amount=100
	expect(game.items.use(walker) and is_equal_approx(game.items.state(walker).cooldowns.cluster,8) and combat.ink_amount==55,"item talent, CD and ink are applied")
	expect(combat.bombs.size()==1 and combat.bombs[0].config.damageMax==70 and combat.bombs[0].config.fuse==.3,"bottle captures own damage/fuse instead of reading grenade later")
	combat.bombs[0].visual.queue_free();combat.bombs.clear()
	game.randomize_player_kit();expect(game.items.state(walker).cooldowns.cluster==8,"reroll cannot clear new item cooldown")
	game.perks.choices[walker.get_instance_id()]="balanced";walker.global_position=Vector3(0,.05,-20);game.player_health=60;combat.ink_amount=100
	var ally:Node3D=game.extra_bots[0];ally.global_position=Vector3(1,.05,-20);ally.health=60;ally.respawn_time=0
	bot.global_position=Vector3(1,.05,-20);bot.health=60;game.bot_health=60;game.bot_respawn=0
	game.items.equip(walker,"healing");expect(game.items.use(walker),"healing field places on real terrain")
	game.items._advance_fields(.2)
	expect(game.player_health>60 and ally.health>60 and game.bot_health==60,"same-team unobstructed field heals without friendly/enemy confusion")
	var field:Dictionary=game.items.fields[0];field.kind="mist";field.team=1
	game.items._advance_fields(.2);expect(is_equal_approx(walker.external_speed_factor,.65),"hostile field changes actual walker movement factor")
	walker.global_position.y=3.05;game.items._advance_fields(.2)
	expect(walker.external_speed_factor==1,"lower field cannot slow a different platform")
	game.items._advance_fields(7);expect(game.items.fields.is_empty() and walker.external_speed_factor==1,"field expiry removes visuals and movement effect")
	expect(not game.perks.select_player("focus"),"new talents stay locked in match")
	game.queue_free();await process_frame
	if failures.is_empty():print("PASS: eight active weapon models and retained legacy and actual attacks, captured bottle rules, team/layer fields, cooldown retention and four locked talent effects")
	quit(0 if failures.is_empty() else 1)
