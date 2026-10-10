extends SceneTree
const Setup := preload("res://src/core/match_setup.gd")
const Palette := preload("res://src/core/team_palette.gd")
var output := ""
var game: Node3D
var failures: Array[String] = []
var report := {"kind":"native wardrobe/settings mouse input", "cases":[], "clicks":[], "limits":"Controlled menu/input and frozen combat; not natural match, temperature or human aesthetics."}

func _initialize() -> void:call_deferred("_run")
func frames(count: int=4) -> void:
	for i in count:await process_frame
func expect(value: bool, text: String) -> void:
	if not value:failures.append(text)
func bind_game() -> void:
	game=current_scene;game.set_physics_process(false)
	for actor in game.all_actors():actor.set_physics_process(false)
	game._set_pointer_lock(false);game.paused=false;game._layout_hud();game._update_hud()
func click(control: Control) -> void:
	root.grab_focus();await frames(3)
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	# snap() moves the system cursor off controls. Let its native motion settle
	# at this target before checking hover or injecting button input.
	root.warp_mouse(point);await frames(3)
	var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;root.push_input(move,true);await frames(2)
	var hovered:=root.gui_get_hovered_control()
	expect(hovered==control,"actual mouse reaches "+control.name)
	report.clicks.append({"button":control.name,"point":point,"hovered":str(hovered)})
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event,true)
	await frames(8)
func snap(name_text: String) -> void:
	root.gui_release_focus();root.warp_mouse(Vector2(8,8))
	var move:=InputEventMouseMotion.new();move.position=Vector2(8,8);move.global_position=move.position
	root.push_input(move,true)
	await frames(8)
	await frames();await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(name_text+".png"))==OK,"save screenshot")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64/new absolute output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	Setup.randomized=true;Setup.style_index=0;Setup.appearance_seed=27;Setup.team_size=5;Setup.screen="setup"
	Setup.pending_loadout={"settings_path":output.path_join("settings.cfg")};Palette.select(0)
	game=(load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game);current_scene=game
	await frames();bind_game();game.perks.locked=false
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=pixels;root.content_scale_size=pixels
		game.settings.ui_scale=1.1 if pixels.x==960 else 1.0;game._layout_hud();game.frontend.sync();await frames(10)
		var old_seed:=Setup.appearance_seed;var old_style:=Setup.style_index
		var colors: Array=[Palette.color(0),Palette.color(1)]
		await snap("setup-%d-before"%pixels.x)
		await click(game.frontend.random_button)
		bind_game()
		game.settings.ui_scale=1.1 if pixels.x==960 else 1.0;game._layout_hud();game.frontend.sync();await frames(6)
		expect(Setup.appearance_seed!=old_seed and Setup.style_index!=old_style,"native ROLL changes seed and body")
		expect(colors==[Palette.color(0),Palette.color(1)],"native ROLL keeps team theme")
		var body: Node3D=game.get_node("World/Walker/Body")
		expect(body.wardrobe==game.frontend.preview.model.wardrobe,"real preview matches mixed clothing")
		await snap("setup-%d-after"%pixels.x)
		var look: Dictionary=body.wardrobe.duplicate(true)
		await click(game.frontend.settings_button)
		var panel: Control=game.settings_panel
		expect(panel.visible,"native settings entry opens")
		# A real save persists only this fixture's isolated settings.
		panel.fps_button.select(0);panel.render_scale_button.select(0)
		await snap("settings-%d"%pixels.x)
		await click(panel.save_button)
		expect(not panel.visible,"real save click closes settings panel")
		expect(Engine.max_fps==30 and is_equal_approx(root.scaling_3d_scale,.75),"save applies explicit 30 FPS / 75%")
		game._start_round();game._set_pointer_lock(false);game.paused=false;game.pause_panel.hide();game.phase_time=5.0;game._update_hud()
		expect(game.get_node("World/Walker/Body").wardrobe==look,"actual combat keeps preview's clothes")
		game.randomize_appearance();expect(Setup.appearance_seed==body.ornament_seed,"combat rejects ROLL")
		await snap("combat-%d"%pixels.x)
		report.cases.append({"size":pixels,"wardrobe":look,"seed":Setup.appearance_seed,"preview_matches_combat":true,"fps":Engine.max_fps,"render_scale":root.scaling_3d_scale})
		game.perks.locked=false;game.show_preparation();game.frontend.sync();await frames()
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures
	var file:=FileAccess.open(output.path_join("native.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	game.queue_free();await frames(3)
	if failures.is_empty():print("PASS: two-size actual wardrobe ROLL/settings mouse input, retained team theme, matching preview/combat and explicit 30 FPS / 75% fixture settings")
	else:printerr("FAIL: "+str(failures))
	quit(0 if failures.is_empty() else 1)
