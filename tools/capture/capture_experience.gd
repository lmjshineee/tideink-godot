extends "res://tests/godot/helpers/creative_fixture.gd"
const Setup:=preload("res://src/core/match_setup.gd")
const Palette:=preload("res://src/core/team_palette.gd")
var output:=""
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name()=="headless" or Engine.get_architecture_name()!="arm64":printerr("FAIL: native arm64 display required");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):printerr("FAIL: new absolute evidence directory required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	Setup.appearance_seed=731;Setup.style_index=0;Setup.randomized=true
	Palette.random_palette={};Palette.palette_index=0
	Setup.pending_loadout={"player":"shooter","settings_path":"/private/tmp/tideink-experience-unused.cfg"}
	root.size=Vector2i(1280,720)
	await prepare(5,"tidewater")
	game.paused=false
	game.show_preparation()
	await _capture("setup")
	game._start_round();walker.set_physics_process(false);game.set_physics_process(false);game.paused=false;game.phase_time=2
	walker.global_position=Vector3(0,.05,-28);walker.get_node("Body").rotation.y=0
	walker.get_node("Body").set_process(false)
	var camera:=Camera3D.new();game.add_child(camera);camera.current=true;camera.fov=43
	camera.global_position=walker.global_position+Vector3(1.15,1.40,2.45);camera.look_at(walker.global_position+Vector3.UP*.95)
	await _capture("character")
	for p in [Vector3(6,.08,-23),Vector3(8,.08,-24),Vector3(9,.08,-26)]:game.paint_at_world(p,0,2,.31)
	game.paint_at_world(Vector3(10,.08,-24),1,2.1,.63)
	game.get_node("InkView").sync_dirty()
	camera.fov=52;camera.global_position=Vector3(12,4,-19);camera.look_at(Vector3(8,.05,-24))
	await _capture("ink")
	camera.fov=60;camera.global_position=Vector3(24,17,-35);camera.look_at(Vector3(3,1,-14))
	await _capture("arena")
	var report:={"kind":"controlled native rendering and setup","architecture":Engine.get_architecture_name(),"render_scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"window":"1280x720","seed":731,"fixture_focus_pause_overridden":true,"failures":failures,"source_sha256":{}}
	for path in preload("res://tools/lib/source_inventory.gd").scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
	for path in ["res://shaders/world/surface_ink.gdshader","res://shaders/characters/character_skin.gdshader","res://shaders/characters/character_hair.gdshader","res://project.godot","res://shaders/characters/character_eyes.gdshader","res://shaders/world/tidewater_surface.gdshader","res://scenes/world/tidewater_environment.tscn","res://assets/integrity.json"]:report.source_sha256[path]=FileAccess.get_sha256(path)
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	await finish("native setup, fixed character, ink contour and arena captures")
func _capture(label:String) -> void:
	await create_timer(.15).timeout
	game.paused=false;game._update_hud();await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
