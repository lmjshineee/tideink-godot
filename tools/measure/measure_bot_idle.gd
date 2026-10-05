extends SceneTree
const Setup:=preload("res://src/core/match_setup.gd")
var output:=""
var maps: Array[String] = []
var seconds := 20.0
var trace_actor := -1
var report:={"kind":"seeded live physics bot idle diagnosis","seed":731,"maps":[]}
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--map="): maps.append(arg.trim_prefix("--map="))
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--trace-actor="): trace_actor = int(arg.trim_prefix("--trace-actor="))
	if not output.is_absolute_path() or FileAccess.file_exists(output):printerr("FAIL: fresh absolute --output file required");quit(1);return
	if maps.is_empty(): maps.assign(preload("res://src/core/map_catalog.gd").IDS)
	if seconds < 6 or seconds > 60: printerr("FAIL: seconds must be 6..60"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	# Accelerated controlled physics: engine delta and the manual caller both use
	# 1/30s. This is not a natural wall-clock round or a performance benchmark.
	Engine.time_scale = 4.0; Engine.physics_ticks_per_second = 120
	report["time_scale"] = Engine.time_scale
	report["physics_hz"] = Engine.physics_ticks_per_second
	report["source_sha256"] = {}
	for path in preload("res://tools/lib/source_inventory.gd").scripts(): report.source_sha256[path] = FileAccess.get_sha256(path)
	for map_id in maps:
		if not preload("res://src/core/map_catalog.gd").IDS.has(map_id): printerr("FAIL: unknown map"); quit(1); return
		seed(731);Setup.map_id=map_id;Setup.team_size=5;Setup.screen="setup";Setup.random_map=false;Setup.map_seed=731;Setup.appearance_seed=731
		Setup.randomized=true;Setup.reroll_bots=false;Setup.selected_perk="balanced";Setup.ai_level="standard"
		Setup.pending_loadout={"settings_path":"/private/tmp/tideink-bot-audit-unused.cfg"}
		var game:Node3D=(load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game);await physics_frame
		# Match creates a separately randomized equipment RNG in _ready. Seed and
		# reroll through the real equipment API before starting the controlled run.
		game.equipment_rng.seed=731
		for actor in game.all_actors():
			game.perks.choices[actor.get_instance_id()]="balanced"
			if actor!=game.get_node("World/Walker"): game.randomize_bot_kit(actor)
		game.set_physics_process(false);game.get_node("World/Walker").set_physics_process(false);game._start_round();game.paused=false
		# Match _ready sets 30 Hz; restore acceleration only after it has run.
		Engine.physics_ticks_per_second=120
		Engine.max_fps=0
		var observations:={};var events:Array=[];var trace:Array=[]
		for actor in game.all_actors():
			if actor!=game.get_node("World/Walker"):observations[actor.get_instance_id()]={"start":actor.global_position,"last":actor.global_position,"time":0.0,"reported":false,"longest":0.0,"furthest":0.0}
		for frame in range(roundi(seconds*30)):
			await physics_frame;game.paused=false;game._physics_process(1.0/30)
			for actor in game.all_actors():
				if not observations.has(actor.get_instance_id()):continue
				var s:Dictionary=observations[actor.get_instance_id()]
				var moving:bool=actor.global_position.distance_to(s.last)>.005
				var intentional:bool=not game.actor_alive(actor) or game.bot_deployment.busy(actor) or game.bot_specials.busy(actor) or game.mobility.busy(actor) or game.wings.busy(actor) or int(actor.get_meta("decoy_target",0))!=0 or (actor.target_actor!=null and actor.global_position.distance_to(actor.target_actor.global_position)<=actor._engagement_distance(game.get_node("Combat").weapons[actor.weapon_id])) or not game.items.supply.channels.get(actor.get_instance_id(),{}).is_empty()
				if game.actor_id(actor)==trace_actor and frame%3==0:
					trace.append({"second":float(frame)/30,"position":actor.global_position,"moving":moving,"intentional":intentional,"route_index":actor.route_index,"route_size":actor.route.size(),"goal":actor.route[actor.route_index] if actor.route_index<actor.route.size() else null,"repath":actor.repath_time,"recovery_time":actor.recovery_time,"blocked_time":actor.blocked_time,"jump_time":actor.jump_time,"velocity":actor.team_mover.velocity,"target":game.actor_id(actor.target_actor) if actor.target_actor!=null else -1,"special":game.bot_specials.state(actor).duplicate(),"counter_busy":game.get_node("Combat").counter.busy(actor),"move_limit":game.get_node("Combat").counter.move_limit(actor),"supply":game.items.supply.destination(actor),"respawn":actor.respawn_time,"on_floor":actor.team_mover.is_on_floor(),"on_wall":actor.team_mover.is_on_wall(),"perk":game.perks.kind(actor),"escape":game.bot_specials.escape(actor)})
				if moving or intentional:s.time=0.0;s.reported=false
				else:s.time+=1.0/30
				s.longest=maxf(s.longest,s.time)
				s.furthest=maxf(s.furthest,actor.global_position.distance_to(s.start))
				if s.time>=2 and not s.reported:
					s.reported=true
					events.append({"second":float(frame)/30,"actor":game.actor_id(actor),"weapon":actor.weapon_id,"position":actor.global_position,"ink":actor.ink_amount,"route_index":actor.route_index,"route_size":actor.route.size(),"goal":actor.route[actor.route_index] if actor.route_index<actor.route.size() else null,"on_wall":actor.team_mover.is_on_wall(),"velocity":actor.team_mover.velocity,"target":game.actor_id(actor.target_actor) if actor.target_actor!=null else -1,"enemy_swim":actor.get_meta("enemy_swimming",false)})
				s.last=actor.global_position
		var actors:Array=[]
		for actor in game.all_actors():
			if observations.has(actor.get_instance_id()):
				var state:Dictionary=observations[actor.get_instance_id()]
				actors.append({"actor":game.actor_id(actor),"team":game.actor_team(actor),"weapon":actor.weapon_id,"item":game.items.state(actor).kind,"perk":game.perks.kind(actor),"longest_unexplained_stop":state.longest,"furthest_from_start":state.furthest})
		report.maps.append({"map":map_id,"seconds":seconds,"unexplained_stops":events,"actors":actors,"trace":trace})
		print("AUDIT: ",map_id," unexplained stop episodes=",events.size())
		for voice in game.sound.get_children():
			if voice.has_method("stop"):voice.stop();voice.stream=null
		await create_timer(.1).timeout;game.queue_free();await process_frame;await process_frame
	await create_timer(.1).timeout
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	print("PASS: recorded seeded bot movement and excluded combat, supply, death and ability windups");quit()
