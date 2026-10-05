extends "res://tests/godot/helpers/creative_fixture.gd"

const Inventory := preload("res://tools/lib/source_inventory.gd")
var output := ""
var camera:Camera3D
var report := {"kind":"controlled native AI beacon placement and player input","cases":[]}
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64 and a new absolute output directory required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	report.engine=Engine.get_version_info().string;report.display=DisplayServer.get_name();report.source_sha256={}
	report.adapter=RenderingServer.get_video_adapter_name();report.api=RenderingServer.get_video_adapter_api_version()
	for path in Inventory.scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
	await prepare(5,"tidewater")
	# Freeze only this controlled scene after the opening HUD animation.
	game.phase_time=1.0
	report.fixture="fixed actor positions; match physics paused; real item ticks; opening HUD advanced to 1 second"
	walker.global_position=Vector3(200,0,200)
	camera=Camera3D.new();game.add_child(camera);camera.current=true
	for team in range(2):
		var actor:Node3D=bot if team==1 else game.extra_bots[0]
		for other in game.all_actors():
			if other==walker:continue
			if other==bot:game.bot_respawn=999 if other!=actor else 0
			else:other.respawn_time=999 if other!=actor else 0
		actor.reset();actor.ink_amount=100;game.items.equip(actor,"beacon")
		var state:Dictionary=game.items.state(actor);state.cooldowns.beacon=0;state.beacon_try=0
		var base:Vector3=game.get_node("World/Map").spawn_pads[team]
		actor.global_position=base+Vector3.UP*.05
		game.paint_at_world(actor.global_position+Vector3.UP*.06,team,4,.3)
		camera.global_position=base+Vector3(10,9,10);camera.look_at(base+Vector3.UP)
		var serial:int=game.deployment.beacon_serial
		for frame in range(30):await physics_frame;game.items.tick(1.0/30)
		var base_rejected:bool=game.deployment.beacon_serial==serial and actor.ink_amount==100 and state.cooldowns.beacon==0
		expect(base_rejected,"native AI rejects spawn placement without spending")
		await capture("team-%d-base" % team)
		var forward:=1.0 if team==0 else -1.0
		actor.global_position=Vector3(12,.05,base.z+forward*16)
		game.paint_at_world(actor.global_position+Vector3.UP*.06,team,4,.4)
		state.beacon_try=0
		camera.global_position=actor.global_position+Vector3(6,4,6);camera.look_at(actor.global_position+Vector3.UP)
		for frame in range(12):await physics_frame;game.items.tick(1.0/30)
		var forward_placed:bool=game.deployment.beacon_serial==serial+1 and actor.ink_amount==65
		expect(forward_placed,"native AI places a real forward beacon")
		report.cases.append({"team":team,"base_rejected":base_rejected,"forward_placed":forward_placed,"ink":actor.ink_amount,"cooldown":state.cooldowns.beacon,"point":game.deployment.beacons[-1].point if forward_placed else null})
		await capture("team-%d-forward" % team)
	# The strategy gate belongs only to bots. Exercise the player's actual E key.
	walker.global_position=game.get_node("World/Map").spawn_pads[0]+Vector3.UP*.05
	game.paint_at_world(walker.global_position+Vector3.UP*.06,0,4,.5)
	game.items.equip(walker,"beacon");combat.ink_amount=100
	game._set_pointer_lock(true);game.paused=false
	var previous:int=game.deployment.beacon_serial
	await physics_frame
	key(KEY_E,true);key(KEY_E,false);await process_frame
	expect(game.deployment.beacon_serial==previous+1 and combat.ink_amount==65,"player can still intentionally place a base beacon using actual E input")
	report.player_base_input="E";report.player_base_placed=game.deployment.beacon_serial==previous+1
	camera.global_position=walker.global_position+Vector3(10,8,10);camera.look_at(walker.global_position+Vector3.UP)
	await capture("player-base-E")
	report.status="passed" if failures.is_empty() else "failed"
	var file:=FileAccess.open(output.path_join("beacons.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	await finish("native AI beacon strategy for both teams and intentional player base placement")
func capture(label:String) -> void:
	game._update_hud()
	await process_frame;camera.current=true;await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	expect(picture!=null and not picture.is_empty(),"native capture "+label)
	if picture!=null:expect(picture.save_png(output.path_join(label+".png"))==OK,"save native image "+label)
