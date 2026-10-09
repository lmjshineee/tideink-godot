extends "res://tests/godot/check_bot_ink_refill.gd"

var output := ""
var camera: Camera3D
var captured := {}
var report := {"kind":"controlled native both-team low-ink movement and refill",
	"limits":"Fixed positions/ink, frozen match and other actors, accelerated 30 Hz simulated physics; actual bot decisions and collision movement. Not natural timing, human feel, performance, temperature or export acceptance.",
	"cases":[],"focus_resumes":0,"source_sha256":{}}

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64 and a new absolute evidence directory required");quit(1);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:quit(1);return
	preload("res://src/core/match_setup.gd").pending_loadout={"settings_path":output.path_join("isolated-settings.cfg")}
	root.size=Vector2i(1280,720)
	report.environment={"engine":Engine.get_version_info().string,"arm64":OS.has_feature("arm64"),
		"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"api":RenderingServer.get_video_adapter_api_version(),"window":[1280,720]}
	var sources:Array[String]=preload("res://tools/lib/source_inventory.gd").scripts()
	sources.append_array(["res://project.godot","res://assets/integrity.json",
		"res://tests/godot/check_bot_ink_refill.gd","res://tools/capture/verify_bot_ink_refill.gd"])
	for path in sources:report.source_sha256[path]=FileAccess.get_sha256(path)
	await super._run()

func _place(actor: Node3D, at: Vector3) -> void:
	await super._place(actor,at)
	game.phase_time=1.0
	var view:Node3D=game.get_node("InkView")
	for child in view.get_children():child.queue_free()
	view.images.clear();view.textures.clear();view.setup(game.ink)
	if camera==null:
		camera=Camera3D.new();game.add_child(camera)
	camera.global_position=at+Vector3(6,4,6);camera.look_at(at+Vector3.UP*.6);camera.current=true

func _step(actor: Node3D) -> void:
	if game.paused:
		report.focus_resumes+=1;game.paused=false
	await super._step(actor)
	var owner:int=actor.floor_ink_owner()
	var swim:bool=actor.get_meta("friendly_swimming",false)
	var label:="team-%d-%s-floor-%d" % [actor.team,"submerged" if swim else "human",owner]
	if not captured.has(label):
		captured[label]=true
		report.cases.append({"label":label,"team":actor.team,"floor_owner":owner,"submerged":swim,
			"ink":actor.ink_amount,"refill_active":actor.ink_brain.active,"height":actor.team_mover.get_child(0).shape.height,
			"position":[actor.global_position.x,actor.global_position.y,actor.global_position.z]})
		camera.global_position=actor.global_position+Vector3(3.5,2.5,4);camera.look_at(actor.global_position+Vector3.UP*.5)
		await _capture(label)

func _capture(label: String) -> void:
	game._update_hud();game.get_node("InkView").sync_dirty()
	camera.current=true
	await process_frame;await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	expect(picture!=null and not picture.is_empty(),"native image "+label)
	if picture!=null:expect(picture.save_png(output.path_join(label+".png"))==OK,"save "+label)

func finish(label: String) -> void:
	# Bot form must not change the player's established Shift/refill input path.
	Engine.time_scale=1;Engine.physics_ticks_per_second=30
	walker.global_position=Vector3(0,.05,-20);walker.reset_movement_state()
	_paint(walker.global_position,0,2)
	game._set_pointer_lock(true);game.paused=false
	key(KEY_SHIFT,true)
	var entry_ticks:=0
	while entry_ticks<30 and not (walker.squid_form and walker.grounded):
		await physics_frame
		walker._physics_process(STEP);combat.tick(STEP,false,true)
		entry_ticks+=1
	expect(walker.squid_form and walker.grounded,"native Shift enters actual grounded own-ink form before sampling")
	combat.ink_amount=35;combat.last_fire_time=0
	for i in 30:
		await physics_frame
		walker._physics_process(STEP);combat.tick(STEP,false,true)
	var squid:bool=walker.squid_form
	var gain:float=combat.ink_amount-35
	expect(squid and is_equal_approx(gain,42),"native player Shift still submerges and refills at 42/s")
	report.player_input={"input":"Shift","entry_ticks":entry_ticks,"sample_ticks":30,"squid":squid,"ink_gain":gain}
	camera.global_position=walker.global_position+Vector3(3.5,2.5,4);camera.look_at(walker.global_position+Vector3.UP*.4)
	await _capture("player-Shift-refill")
	key(KEY_SHIFT,false);await physics_frame;walker._physics_process(STEP)
	expect(not walker.squid_form,"native Shift release surfaces player")
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures.duplicate()
	var file:=FileAccess.open(output.path_join("bot-ink.json"),FileAccess.WRITE)
	if file==null:expect(false,"write native report")
	else:file.store_string(JSON.stringify(report,"\t"));file.close()
	await super.finish(label)
