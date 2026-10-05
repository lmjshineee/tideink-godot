extends SceneTree
const Setup:=preload("res://src/core/match_setup.gd")
var output:=""
var report:={"kind":"seeded live physics bot idle diagnosis","seed":731,"maps":[]}
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if not output.is_absolute_path() or FileAccess.file_exists(output):printerr("FAIL: fresh absolute --output file required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	for map_id in ["tidewater","prism_gallery","viaduct"]:
		seed(731);Setup.map_id=map_id;Setup.team_size=5;Setup.screen="setup";Setup.random_map=false;Setup.map_seed=731;Setup.appearance_seed=731
		var game:Node3D=(load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game);await physics_frame
		game.set_physics_process(false);game.get_node("World/Walker").set_physics_process(false);game._start_round();game.paused=false
		var observations:={};var events:Array=[]
		for actor in game.all_actors():
			if actor!=game.get_node("World/Walker"):observations[actor.get_instance_id()]={"last":actor.global_position,"time":0.0,"reported":false}
		for frame in range(600):
			await physics_frame;game._physics_process(1.0/30)
			for actor in game.all_actors():
				if not observations.has(actor.get_instance_id()):continue
				var s:Dictionary=observations[actor.get_instance_id()]
				var moving:bool=actor.global_position.distance_to(s.last)>.005
				var intentional:bool=not game.actor_alive(actor) or game.bot_deployment.busy(actor) or game.bot_specials.busy(actor) or game.mobility.busy(actor) or (actor.target_actor!=null and actor.global_position.distance_to(actor.target_actor.global_position)<=actor._engagement_distance(game.get_node("Combat").weapons[actor.weapon_id])) or not game.items.supply.channels.get(actor.get_instance_id(),{}).is_empty()
				if moving or intentional:s.time=0.0;s.reported=false
				else:s.time+=1.0/30
				if s.time>=2 and not s.reported:
					s.reported=true
					events.append({"second":float(frame)/30,"actor":game.actor_id(actor),"weapon":actor.weapon_id,"position":actor.global_position,"ink":actor.ink_amount,"route_index":actor.route_index,"route_size":actor.route.size(),"goal":actor.route[actor.route_index] if actor.route_index<actor.route.size() else null,"on_wall":actor.team_mover.is_on_wall(),"velocity":actor.team_mover.velocity,"target":game.actor_id(actor.target_actor) if actor.target_actor!=null else -1,"enemy_swim":actor.get_meta("enemy_swimming",false)})
				s.last=actor.global_position
		report.maps.append({"map":map_id,"seconds":20,"unexplained_stops":events})
		print("AUDIT: ",map_id," unexplained stop episodes=",events.size())
		for voice in game.sound.get_children():
			if voice.has_method("stop"):voice.stop();voice.stream=null
		await create_timer(.1).timeout;game.queue_free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	print("PASS: recorded seeded bot movement and excluded combat, supply, death and ability windups");quit()
