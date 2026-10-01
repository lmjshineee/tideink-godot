extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:call_deferred("_run")
func expect(value: bool,message: String) -> void:
	if not value:failures.append(message);printerr("FAIL: ",message)
func _run() -> void:
	var setup:=preload("res://match_setup.gd");setup.selected_perk="balanced"
	var game: Node3D=(load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game);await physics_frame;game.set_physics_process(false)
	var walker: Node3D=game.get_node("World/Walker");walker.set_physics_process(false)
	var combat: Node3D=game.get_node("Combat")
	var observed:=[]
	for height in [0.25,0.9,1.28]:
		game._start_round()
		for actor in game.all_actors():
			if actor!=walker:actor.global_position=Vector3(60,30,60);game.perks.choices[actor.get_instance_id()]="balanced"
		walker.global_position=Vector3(0,2.25,36);game.player_invuln=0
		var origin:=walker.global_position+Vector3(0,height,-4)
		combat.fire_bot_charger(origin,walker.global_position+Vector3.UP*height,1,1,game.get_node("Bot"))
		observed.append(120-game.player_health)
		print("AUDIT: charge impact height=",height," damage=",observed.back()," text=",game.last_damage_text)
	expect(absf(observed[0]-85)<0.01 and absf(observed[1]-100)<0.01 and absf(observed[2]-108)<0.01,"actual ray distinguishes legs/torso/head")
	expect(game.last_damage_text.contains("头部") and game.last_damage_text.contains("4.0m"),"hit region and distance visible")
	var rules:=preload("res://gameplay_rules.gd")
	expect(rules.shooter_damage(30,2,12.5)==30 and absf(rules.shooter_damage(30,12.5,12.5)-23.4)<0.01,"near/far falloff retains source behavior")
	expect(combat.hit_region(0.4,0.55,true)=="潜墨" and combat.region_multiplier("潜墨")==1,"squid capsule has no artificial head zone")
	var attacker: Node3D=game.get_node("Bot");game.perks.choices[attacker.get_instance_id()]="adrenaline";game.bot_health=60
	expect(game._modified_damage(108,walker,attacker,"charger")==115,"normal hit remains bounded with head and low-health bonuses")
	game.player_health=120;game.player_respawn=0;game.items.equip(walker,"shield");game.items.use(walker)
	game.damage_player(100,false,null,"charger","躯干",4)
	expect(game.player_health==80 and game.items.state(walker)["armor"]==0,"shield absorbs before HP and provenance shows remaining damage")
	game.damage_history.clear();game.player_health=120;game.perks.choices[attacker.get_instance_id()]="balanced"
	game.damage_player(10,false,attacker,"shooter","头部",4)
	game.damage_player(10,false,attacker,"shooter","腿部",5)
	var summary: String=game.damage_summary()
	expect(summary.contains("−20") and not summary.contains("头部") and not summary.contains("腿部"),"death summary groups same attacker/weapon across regions and distances")
	if failures.is_empty():print("PASS: native capsule ray zones, distance falloff, squid form, boosted-shot limit and shield-before-health")
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
