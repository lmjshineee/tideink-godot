extends "res://tests/godot/helpers/creative_fixture.gd"
var output := "res://render-evidence/art-direction-2026-10-10/bold-ink-native"
var report := {"kind":"controlled CPU ink on actual convex and stacked surfaces", "human_aesthetic_acceptance":false,"cases":[]}
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64 and new output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	report.environment={"engine":Engine.get_version_info().string,"api":RenderingServer.get_video_adapter_api_version(),"arm64":OS.has_feature("arm64")}
	report.source_sha256={}
	for path in preload("res://tools/lib/source_inventory.gd").scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
	for id in ["sunset_park","lantern_depot"]:
		await prepare(5,id)
		game._start_round();game._set_pointer_lock(false);game.hud_root.visible=false
		walker.global_position=Vector3(80,40,80)
		var added := 0.0
		if id=="sunset_park":
			for sign in [-1,1]:
				for z in [-3.0,0.0,3.0]:added+=game.ink.splat_world(Vector3(sign*14.7,2.2,z),2.4,0 if sign<0 else 1,.5)
				added+=game.ink.splat_world(Vector3(sign*2.0,1.6,0),2.3,0 if sign<0 else 1,.5)
		else:
			added+=game.ink.splat_world(Vector3(-1.7,3.4,0),2.0,0,.5)
			added+=game.ink.splat_world(Vector3(1.7,3.4,0),2.0,1,.5)
			added+=game.ink.splat_world(Vector3(0,0,-1.5),2.3,0,.5)
			added+=game.ink.splat_world(Vector3(0,0,1.5),2.3,1,.5)
		var synced: int=game.get_node("InkView").sync_dirty()
		expect(added>0 and synced>0,"real CPU grid generates visible wet convex surfaces")
		var camera:=Camera3D.new();game.add_child(camera);camera.position=Vector3(15,10,-21);camera.look_at(Vector3(0,1,0));camera.current=true
		await snap(id+"-ink")
		if id=="lantern_depot":
			camera.position=Vector3(6,1.5,-7);camera.look_at(Vector3(0,1.2,0));await snap(id+"-underpass-ink")
		report.cases.append({"map":id,"credited_area":added,"wet_faces":synced})
		game.queue_free();await process_frame;await create_timer(.2).timeout
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures
	var file:=FileAccess.open(output.path_join("ink.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
func snap(name_text: String) -> void:
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(name_text+".png"))==OK,"native wet screenshot saved")
