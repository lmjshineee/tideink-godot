extends SceneTree
const Setup:=preload("res://src/core/match_setup.gd")
const Perks:=preload("res://src/abilities/tidewater_perks.gd")
var report:={"fixture":"Production projectile/beam/volley damage against an unmoving capsule with body aim in an isolated elevated lane; no regeneration or shields. Cadence follows config (full charger includes 0.28-second post-shot recovery). Fired attacks include projectiles still in transit at the kill. This is controlled measurement, not real player input, matchmaking or a balance verdict.","duels":[],"loadouts":[]}
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	Setup.screen="setup";Setup.team_size=5;Setup.map_id="tidewater";Setup.selected_perk="balanced"
	var game:Node3D=(load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game);await physics_frame;game.set_physics_process(false);game._start_round()
	var combat:Node3D=game.get_node("Combat");var walker:Node3D=game.get_node("World/Walker");walker.set_physics_process(false);var source:Node3D=game.get_node("Bot")
	for actor in game.all_actors():
		if actor!=walker:actor.global_position=Vector3(60,30,60)
	for talent in Perks.ORDER:
		game.perks.choices[walker.get_instance_id()]=talent
		for weapon in game.weapon_order:
			var config:Dictionary=game.perks.weapon(walker,combat.weapons[weapon])
			var cost:float=config.get("inkPerShot",config.get("inkFull",config.get("flickInk",0)))
			report.loadouts.append({"weapon":weapon,"talent":talent,"max_hp":game.actor_max_health(walker),"ink_capacity":game.actor_ink_max(walker),"ink_per_attack":cost,"attacks_per_reservoir":floori(game.actor_ink_max(walker)/cost),"run_speed":combat.weapon_data.player.runSpeed*game.perks.movement(walker)})
	for talent in Perks.ORDER:
		for weapon in game.weapon_order:
			for distance in [3.0,10.0]:
				await duel(game,weapon,talent,distance,false)
	for weapon in game.weapon_order:
		for distance in [3.0,10.0]:await duel(game,weapon,"balanced",distance,true)
	var file:=FileAccess.open("res://render-evidence/expand14-loadout-measurement.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	game.queue_free();await process_frame
	print("PASS: measured 182 production-attack duels and 84 talent/weapon capacity profiles; see controlled-fixture limits in JSON")
	quit()

func duel(game:Node3D,weapon:String,talent:String,distance:float,low_health:bool) -> void:
	var combat:Node3D=game.get_node("Combat");var walker:Node3D=game.get_node("World/Walker");var source:Node3D=game.get_node("Bot")
	# A death keeps already fired shots in real matches; each isolated trial must start empty.
	for field in ["projectiles","beams","bursts","bombs","storm_bombs","clouds"]:
		for effect in combat.get(field):
			if effect.has("visual") and is_instance_valid(effect.visual):effect.visual.queue_free()
		combat.get(field).clear()
	combat.on_death();game.deployment.clear();game.player_respawn=0;game.respawn_ready=false;game.player_invuln=0;game.phase="playing"
	game.perks.choices[walker.get_instance_id()]=talent;game.perks.choices[source.get_instance_id()]="adrenaline" if low_health else "balanced"
	game.player_health=game.actor_max_health(walker);game.bot_health=50 if low_health else 120;game.items.state(walker).armor=0;game.damage_history.clear()
	walker.global_position=Vector3(0,20,36);walker.squid_form=false;walker.get_node("Body").set_form(false)
	var from:=walker.global_position+Vector3(0,1,-distance);source.global_position=from-Vector3.UP
	var w:Dictionary=combat.weapons[weapon];var interval:float=w.get("fireInterval",w.get("flickInterval",w.get("chargeTime",1)))
	var elapsed:=0.0;var next:float=interval if weapon=="charger" else (float(w.flickWindup) if weapon=="roller" else 0.0);var attacks:=0;var damage:=0.0;var start:float=game.player_health
	if weapon=="charger":interval+=.28
	while elapsed<12 and game.player_respawn<=0:
		if elapsed+0.00001>=next:
			var aim:Vector3=walker.global_position+Vector3.UP
			if weapon=="charger":combat.fire_bot_charger(from,aim,1,1,source)
			elif weapon=="roller":combat.spawn_bot_flick(from,aim,1,source)
			else:
				var direction:Vector3=(aim-from).normalized()
				if w.kind=="shooter":direction=combat._ballistic_direction(from,direction,aim,float(w.projSpeed),float(w.straightTime),28,.8,float(w.range))
				combat._spawn_shot_pair(w,from,direction,1,source)
			attacks+=1;next+=interval
		combat.advance_effects(.0083333333);elapsed+=.0083333333
		damage=start-game.player_health
	report.duels.append({"weapon":weapon,"defender_talent":talent,"attacker_adrenaline":low_health,"distance_m":distance,"target_hp":start,"attacks":attacks,"damage_hp":damage,"hit_history":game.damage_history.duplicate(true),"kill":game.player_respawn>0,"ttk_seconds":snappedf(elapsed,.001) if game.player_respawn>0 else null,"limit_seconds":12})
	await process_frame
