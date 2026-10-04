extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message);printerr("FAIL: ",message)
func _run() -> void:
	var setup:=preload("res://src/core/match_setup.gd")
	setup.selected_perk="vitality"
	setup.screen="setup"
	var game: Node3D=(load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game);await physics_frame;game.set_physics_process(false)
	var walker: Node3D=game.get_node("World/Walker");walker.set_physics_process(false)
	var combat: Node3D=game.get_node("Combat")
	expect(game.actor_max_health(walker)==120 and game.player_health==120 and game.perks.kind(walker)=="balanced","retired saved talent falls back to active baseline")
	game.perks.select_player("vitality")
	expect(game.actor_max_health(walker)==150 and game.player_health==150,"legacy talent remains readable through compatibility API")
	game.perks.select_player("reserve")
	expect(game.actor_ink_max(walker)==125 and combat.ink_amount==125,"capacity and display use same max")
	game.perks.select_player("runner")
	expect(absf(walker.player_config["runSpeed"]-6.6)<0.01,"runner uses actual movement config")
	game.perks.select_player("saver")
	expect(absf(game.perks.weapon(walker,combat.weapons["shooter"])["inkPerShot"]-0.76)<0.01,"ink saver transforms main costs")
	game.perks.select_player("adrenaline")
	var bots:=[]
	for actor in game.all_actors():bots.append(game.perks.kind(actor))
	game._start_round();game.player_health=60
	expect(game.perks.active(walker) and game.perks.outgoing(walker)==1.15 and game.perks.refill(walker)==1.5,"half-health trigger uses own maximum")
	game.player_health=61
	expect(not game.perks.active(walker) and game.perks.outgoing(walker)==1,"trigger exits above 50 percent")
	expect(not game.perks.select_player("vitality"),"changing talent rejected during play")
	var before: String=game.perks.kind(walker)
	game.randomize_player_kit()
	expect(game.perks.kind(walker)==before,"equipment reroll does not reroll perk")
	game.player_invuln=0;game.damage_player(200)
	expect(not game.perks.select_player("vitality"),"dead actor cannot change perk")
	game.randomize_player_kit();game.launch_respawn();game._update_player_respawn(5)
	expect(game.perks.kind(walker)==before,"perk persists through death and launch")
	for i in game.all_actors().size():expect(game.perks.kind(game.all_actors()[i])==bots[i],"every actor talent stays fixed")
	game.show_preparation();expect(not game.perks.select_player("bulwark"),"phase changes cannot unlock current match")
	# Fresh fixture state for independent protection/recovery checks.
	game.perks.locked=false;game.perks.select_player("bulwark");game._start_round();game.player_invuln=0
	game.damage_player(82,false,null,"blaster")
	expect(absf(game.player_health-54.4)<0.01,"explosive protection reduces damage before health")
	expect(game.damage_summary().contains("66"),"actual damage amount appears in summary")
	game.show_preparation();game.perks.locked=false;game.perks.select_player("recovery");game._start_round();game.player_health=50;game.player_last_damage=1.4
	walker.ink_owner=-1;walker.grounded=false
	game._update_player_vitals(0.1)
	expect(game.player_health>50,"recovery talent advances regen start")
	if failures.is_empty():print("PASS: all eight talent choices affect gameplay, per-actor maxima, threshold transition, match lock, death/reroll persistence, damage protection and visible history")
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
