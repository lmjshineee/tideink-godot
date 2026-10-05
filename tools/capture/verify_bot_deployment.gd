extends "res://tests/godot/helpers/creative_fixture.gd"

# Controlled native fixtures use the real respawn controller and physics ticks.
# Placement/death are fixtures; this is not natural-match or human acceptance.
const Inventory := preload("res://tools/lib/source_inventory.gd")
var output := ""
var report := {"kind":"controlled native bot deployment fixtures","cases":[],"focus_resumes":0}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name()=="headless" or Engine.get_architecture_name()!="arm64":
		printerr("FAIL: native arm64 display required");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if output.is_empty() or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: --output must name a new absolute evidence directory");quit(1);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		printerr("FAIL: cannot create evidence directory");quit(1);return
	root.size=Vector2i(1280,720)
	Engine.max_fps=30
	root.scaling_3d_scale=.75
	report.display=DisplayServer.get_name()
	report.engine=Engine.get_version_info().string
	report.architecture=Engine.get_architecture_name()
	report.source_sha256={}
	for path in Inventory.scripts(): report.source_sha256[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
	for map_id in ["tidewater","prism_gallery"]:
		await prepare(5,map_id)
		_resume_fixture()
		var requester: Node3D=bot
		if map_id=="tidewater":
			for actor in game.extra_bots:
				if actor.team==0: requester=actor;break
			walker.global_position=Vector3(0,.05,-24);walker.velocity=Vector3.ZERO
			# Real keyboard events open and cancel the player's selector.
			key(KEY_J,true);key(KEY_J,false);await process_frame
			expect(game.deployment.selector_open,"native J opens manual player selector")
			await _capture("player-manual-selector")
			key(KEY_ESCAPE,true);key(KEY_ESCAPE,false);await process_frame
			expect(not game.deployment.selector_open and not game.deployment.active,"native Esc cancels player choice without launching")
			_resume_fixture()
		else:
			walker.global_position=Vector3(70,40,70)
			var carrier: Node3D=game.extra_bots[0]
			for actor in game.extra_bots:
				if actor.team==1: carrier=actor;break
			carrier.global_position=Vector3(-8.5,6.05,-3);carrier.team_mover.velocity=Vector3.ZERO
			await physics_frame
			game.paint_at_world(carrier.global_position+Vector3.UP*.06,1,4,.3)
			expect(game.deployment.place_beacon(carrier),"native team-one beacon on high floor")
		var d: Node3D=game.bot_deployment
		requester.global_position=d.base_position(requester)
		for actor in game.all_actors():
			if actor==walker or actor==requester: continue
			if actor==bot: game.bot_respawn=999
			else: actor.respawn_time=999
			actor.visible=false
		var camera:=Camera3D.new();game.add_child(camera)
		camera.global_position=Vector3(17,19,-36) if map_id=="tidewater" else Vector3(-21,20,14)
		camera.look_at(Vector3(0,3,-29) if map_id=="tidewater" else Vector3(-8,7,-3));camera.current=true
		await physics_frame
		game.damage_actor(requester,1000,1-game.actor_team(requester),bot if requester!=bot else walker,"shooter")
		game.damage_actor(requester,1000,1-game.actor_team(requester),bot if requester!=bot else walker,"shooter")
		expect(not game.actor_alive(requester) and not d.busy(requester),"native death starts countdown before automatic choice")
		game.set_physics_process(true)
		var start:=Time.get_ticks_msec()
		var charged:=false;var airborne:=false
		var result:={"map":map_id,"team":game.actor_team(requester),"fixture":"forced death, fixed ally/beacon, other bots parked/dead"}
		while Time.get_ticks_msec()-start<15000 and d.completed==0:
			await process_frame
			if game.paused:
				report.focus_resumes+=1;_resume_fixture()
			if not d.busy(requester): continue
			var s: Dictionary=d.state(requester)
			if not charged:
				charged=true;result.destination=s.key;result.target=s.target
				await _capture(map_id+"-windup")
			if s.flying and float(s.time)>float(s.duration)*.4 and not airborne:
				airborne=true;await _capture(map_id+"-flight")
		game.set_physics_process(false)
		expect(charged and airborne and d.completed==1 and not d.busy(requester),map_id+" real controller completes charge, flight and landing")
		result.completed=d.completed;result.fallbacks=d.fallbacks;result.started=d.started
		result.position=requester.global_position;result.health=game.actor_health(requester);result.ink=requester.ink_amount
		result.elapsed_ms=Time.get_ticks_msec()-start
		if map_id=="prism_gallery":
			expect(requester.global_position.y>5.8,"native landing retains six-metre floor")
			if not game.deployment.beacons.is_empty(): result.beacon_uses=game.deployment.beacons[0].uses
		await _capture(map_id+"-landed")
		report.cases.append(result)
		if map_id=="tidewater": game.queue_free();await process_frame
	report.failures=failures
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file==null: expect(false,"write native report")
	else: file.store_string(JSON.stringify(report,"\t"))
	await finish("native manual player J/Esc and actual bot respawn teammate/beacon flight on two floors")

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"save "+label)

func _resume_fixture() -> void:
	# Unlocking production input intentionally pauses. Resume only this fixture.
	game._set_pointer_lock(false)
	game.paused=false
	game._update_hud()
