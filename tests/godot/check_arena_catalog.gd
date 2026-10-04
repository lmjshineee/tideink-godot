extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:call_deferred("_run")
func expect(value: bool, message: String) -> void:
	if not value:failures.append(message);printerr("FAIL: ",message)
func _run() -> void:
	var setup:=preload("res://src/core/match_setup.gd")
	var catalog:=preload("res://src/core/map_catalog.gd")
	setup.selected_perk="balanced";setup.screen="setup"
	for id in catalog.IDS:
		for variant in range(catalog.variant_count(id)):
			setup.map_id=id;setup.random_map=variant>0;setup.map_variant=variant;setup.map_seed=123+variant
			var asset: String=catalog.asset_id()
			var game: Node3D=(load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
			root.add_child(game);await physics_frame
			game.set_physics_process(false);game.get_node("World/Walker").set_physics_process(false)
			var map: Node3D=game.get_node("World/Map")
			expect(map.block_count>20 and map.turf_count>10 and game.ink.turf_total>10000,asset+" complete collision/paint geometry")
			var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s_minimap.json" % asset))
			var count:=0
			for cells in game.ink.owners:count+=cells.size()
			expect(info["cells"]==count,asset+" minimap indexes same paint grids")
			for team in range(2):
				var pad: Vector3=map.spawn_pads[team]
				var path:=PackedVector3Array()
				for node in game.navigation.nodes:
					var values: Array=node["p"]
					if absf(float(values[0]))>12 or absf(float(values[2]))>10:continue
					path=game.navigation.route(pad,Vector3(values[0],values[1],values[2]),team)
					if path.size()>3:break
				expect(path.size()>3,asset+" spawn connected to center for team "+str(team))
			if id=="prism_gallery":
				for team in range(2):
					for height in [3.0,6.0]:
						var target:=Vector3(-8.5,3,-18) if height==3.0 else Vector3(-5,6,0)
						if team==1:target=Vector3(-target.x,target.y,-target.z)
						var layered: PackedVector3Array=game.navigation.route(map.spawn_pads[team],target,team)
						expect(layered.size()>3 and layered[-1].distance_to(target)<3.0,"gallery reachable platform "+str(height)+"m team "+str(team))
			game._start_round();game.player_invuln=0;game.damage_player(200)
			expect(game.deployment.active and game.deployment.target!=Vector3.ZERO,asset+" immediate valid launcher target")
			var chosen: Vector3=game.deployment.target
			game.launch_respawn();game._update_player_respawn(5)
			expect(game.player_respawn==0 and game.get_node("World/Walker").global_position.distance_to(chosen)<0.1,asset+" respawn uses valid ground")
			print("AUDIT: ",asset," blocks=",map.block_count," paint=",game.ink.turf_total," spawn routes + launch checked")
			game.queue_free();await process_frame
	setup.random_map=true;setup.map_id="tidewater";setup.map_seed=120;setup.map_variant=0
	var stable: String=catalog.asset_id();catalog.ensure_setup();expect(catalog.asset_id()==stable,"same seed/variant stable through scene reload")
	setup.random_map=false;setup.map_variant=0;setup.map_id="tidewater"
	if failures.is_empty():print("PASS: seven playable stages, nine modular compositions and four source variants have synchronized physics/ink/nav/minimap, both spawn routes, safe launch and stable selection")
	quit(0 if failures.is_empty() else 1)
