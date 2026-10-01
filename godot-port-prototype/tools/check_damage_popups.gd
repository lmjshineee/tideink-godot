extends SceneTree
const Palette:=preload("res://team_palette.gd")
var failed:=false
func _initialize() -> void:call_deferred("_run")
func expect(ok:bool,label:String) -> void:
	if not ok:failed=true;printerr("FAIL: ",label)
func _run() -> void:
	var setup:=preload("res://match_setup.gd");setup.team_size=5;setup.selected_perk="balanced"
	var game:Node3D=(load("res://tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game);await physics_frame;game.set_physics_process(false)
	for actor in game.all_actors():game.perks.choices[actor.get_instance_id()]="balanced"
	game._start_round()
	var walker:Node3D=game.get_node("World/Walker");var bot:Node3D=game.get_node("Bot");var fx:Node3D=game.get_node("Combat").feedback;fx.set_process(false)
	game.items.equip(walker,"shield");game.items.use(walker);game.damage_player(82,false,bot,"blaster")
	expect(game.player_health==98 and fx.damage_pops.size()==1 and fx.damage_pops[0]["value"]==22,"number equals shield-adjusted actual HP lost")
	expect(fx.damage_pops[0]["label"].modulate==Palette.color(1),"incoming number follows current attacker team palette")
	game.bot_health=7;game.damage_bot(30,walker,"shooter")
	expect(fx.damage_pops.back()["value"]==7 and fx.damage_pops.back()["label"].modulate==Palette.color(0),"overkill clamps to remaining HP with local team color")
	var at:Vector3=fx.damage_pops[0]["label"].global_position;fx.advance_damage(0.1)
	expect(fx.damage_pops[0]["label"].global_position.y>at.y,"number visibly jumps and rises")
	var count:int=fx.damage_pops.size();fx.pop_damage(walker,3,1)
	expect(fx.damage_pops.size()==count and fx.damage_pops[0]["value"]==25,"quick multi-hit damage merges within bounded burst window")
	fx.advance_damage(0.71);expect(fx.damage_pops.is_empty(),"floating text expires without affecting damage")
	for i in range(50):
		fx.pop_damage(walker,1,0);fx.advance_damage(0.23)
	expect(fx.damage_labels.size()<=24 and fx.damage_pops.size()<=24,"label pool and simultaneous pops remain capped")
	fx.advance_damage(1);expect(fx.damage_pops.is_empty(),"all recycled labels expire")
	game.queue_free();await process_frame
	if not failed:print("PASS: actual post-shield and overkill HP, both palette colors, bounce/rise, merge, expiry and bounded label pool")
	quit(1 if failed else 0)
