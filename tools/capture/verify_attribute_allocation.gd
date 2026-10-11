extends "res://tests/godot/helpers/creative_fixture.gd"
const Catalog := preload("res://src/core/attribute_catalog.gd")
const Setup := preload("res://src/core/match_setup.gd")
var output := ""
var report := {"kind":"controlled native attributes input", "limits":"Frozen AI/match and explicit input probes; not human balance, natural timing or thermal acceptance.", "cases":[], "clicks":[]}

func _initialize() -> void: call_deferred("_run")
func frames(count: int = 5) -> void:
	for i in count: await process_frame

func click(control: Control) -> void:
	root.grab_focus();await frames(3)
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * .5)
	# Route explicit GUI events in one sequence. OS cursor warps can enqueue late
	# motion after the button-down, especially while a scene/window is relayouting.
	var move := InputEventMouseMotion.new(); move.position=point;move.global_position=point
	root.push_input(move,true);await frames(2)
	var hovered := root.gui_get_hovered_control()
	var trace := {"button":control.text if control is Button else control.name,"point":point,"phase":game.phase,"locked":game.perks.locked,"disabled":control.disabled if control is BaseButton else false,"hovered":hovered.text if hovered is Button else str(hovered)}
	trace.control_rect=rect(control);trace.preview_rect=rect(game.frontend.preview)
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point;event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event,true)
	await frames(3)
	trace.phase_after=game.phase if is_instance_valid(game) else "scene reloaded"
	trace.editor_open=game.frontend.attribute_editor.visible if is_instance_valid(game) else false
	if is_instance_valid(game):
		trace.perk=game.perks.kind(walker);trace.allocation=game.attributes.loadout(walker)
	report.clicks.append(trace)

func press(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		root.push_input(event,true);await frames(3)

func rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	return Rect2(transform * Vector2.ZERO, transform * control.size - transform * Vector2.ZERO)

func snap(id: String) -> void:
	game.paused=false;game._update_hud();await frames();await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(id+".png"))==OK,"save "+id)

func bind_game() -> void:
	game=current_scene;walker=game.get_node("World/Walker");combat=game.get_node("Combat");bot=game.get_node("Bot")
	game.set_physics_process(false);walker.set_physics_process(false);walker.set_process_input(false)
	game._set_pointer_lock(false);game.paused=false;game._layout_hud();game._update_hud()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64/new absolute output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	report.environment={"engine":Engine.get_version_info().string,"arm64":OS.has_feature("arm64"),"api":RenderingServer.get_video_adapter_api_version(),"adapter":RenderingServer.get_video_adapter_name()}
	report.source_sha256={}
	for path in preload("res://tools/lib/source_inventory.gd").scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	Setup.pending_loadout={"settings_path":output.path_join("settings.cfg")}
	await prepare(5,"tidewater");current_scene=game;bind_game();game.show_preparation();game.perks.locked=false
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		game.perks.select_player("balanced") # Calibrate each size after the prior full-loadout ROLL.
		root.size=pixels;root.content_scale_size=pixels;game.settings.ui_scale=1.1 if pixels.x==960 else 1.0
		await frames(10);game._layout_hud();game.frontend.sync();await frames()
		await click(game.frontend.attribute_button)
		var editor: Control=game.frontend.attribute_editor
		expect(editor.visible and game.phase=="setup","actual mouse opens attributes without starting match")
		if not editor.visible:
			var diagnostic:=FileAccess.open(output.path_join("failed-open.json"),FileAccess.WRITE);diagnostic.store_string(JSON.stringify(report,"\t"));diagnostic.close()
			await finish("native editor open");return
		await click(editor.clear_button)
		await click(editor.plus_buttons.main_saver);await click(editor.plus_buttons.main_saver)
		expect(game.attributes.totals(walker).main_saver==2,"actual plus buys one rank per click")
		await click(editor.minus_buttons.main_saver)
		expect(game.attributes.totals(walker).main_saver==1,"actual minus refunds one point")
		await click(editor.plus_buttons.run_speed)
		expect(walker.player_config.runSpeed>6.3,"point purchase changes actual movement")
		await click(editor.plus_buttons.health);await click(editor.plus_buttons.ink_capacity)
		expect(game.actor_max_health(walker)>132 and game.actor_ink_max(walker)>110,"native health and capacity purchase changes actual caps")
		await press(KEY_1);expect(game.phase=="setup","point editor owns numeric match shortcuts")
		editor.plus_buttons.ink_recovery.grab_focus();await press(KEY_ENTER)
		expect(game.phase=="setup" and game.attributes.loadout(walker).ink_recovery==1,"actual Enter buys focused rank without starting")
		game.items.state(walker).cooldowns.bomb=7;var before:Dictionary=game.attributes.loadout(walker)
		await click(editor.roll_button)
		expect(game.attributes.loadout(walker)!=before and game.items.state(walker).cooldowns.bomb==7,"point-only ROLL preserves cooldown")
		expect(Catalog.spent(game.attributes.loadout(walker))==20,"native random allocation spends twenty points")
		for control in editor.plus_buttons.values():expect(control.disabled,"full budget disables extra purchases")
		var viewport := Rect2(Vector2.ZERO,Vector2(pixels))
		for control in editor.plus_buttons.values()+editor.minus_buttons.values()+[editor.close_button,editor.roll_button,editor.clear_button]:
			expect(viewport.encloses(rect(control)),"native editor control fits scaled viewport")
			expect(not rect(control).intersects(rect(editor.summary)),"editor controls do not overlap effect summary")
		expect(editor.description.get_minimum_size().y<=editor.description.size.y and editor.summary.get_minimum_size().y<=editor.summary.size.y,"ability details and total effects fit allocated heights")
		report.cases.append({"size":[pixels.x,pixels.y],"ui_scale":game.settings.ui_scale,"attributes":game.attributes.loadout(walker),"points":game.attributes.totals(walker),"effects":editor.summary.text})
		await snap("attributes-%d"%pixels.x)
		await press(KEY_ESCAPE)
		expect(not editor.visible and game.phase=="setup","actual Esc closes only attributes editor")
		before=game.attributes.loadout(walker);await click(game.frontend.roll_button)
		expect(before!=game.attributes.loadout(walker),"actual complete loadout ROLL includes attributes")
		await snap("setup-%d"%pixels.x)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;game.settings.ui_scale=1;await frames(10);game._layout_hud()
	var saved:Dictionary=game.attributes.loadout(walker)
	var style_before:int=Setup.style_index
	expect(not rect(game.frontend.preview).intersects(rect(game.frontend.appearance_choice)),"appearance selector stays outside the drag-consuming preview")
	await click(game.frontend.appearance_choice);await frames(15);bind_game()
	expect(Setup.style_index!=style_before,"actual native appearance selector changes archetype")
	expect(game.attributes.loadout(walker)==saved,"appearance reload retains point allocation")
	expect(walker.get_node("Body").get_meta("archetype")==preload("res://src/actors/character_archetypes.gd").IDS[Setup.style_index],"gameplay and preview use chosen real model")
	style_before=Setup.style_index;game.frontend.appearance_choice.grab_focus();await press(KEY_ENTER);await frames(15);bind_game()
	expect(game.phase=="setup" and Setup.style_index!=style_before,"Enter selects focused appearance without starting the round")
	expect(game.attributes.loadout(walker)==saved,"keyboard appearance change preserves points")
	game.perks.select_player("balanced");game.attributes.select_player(Catalog.empty());game.attributes.adjust("main_saver",1)
	game._choose_player_weapon("shooter");game.frontend.attribute_editor.open();game._begin_intro()
	expect(not game.frontend.attribute_editor.visible,"native phase transition closes hidden editor input capture")
	game._start_round();game.set_physics_process(false);walker.set_physics_process(false);walker.set_process_input(false)
	walker.global_position=Vector3(0,.05,-28);combat.ink_amount=100;combat.last_fire_time=0;combat.last_fire=false;combat.cooldown=0
	var effective:float=game.perks.weapon(walker,combat.weapons.shooter).inkPerShot
	# GUI push_input routes clicks; primary combat polls global Input instead.
	mouse(true)
	var pressed_at_tick := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	combat.tick(.001,Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),false)
	expect(absf(combat.ink_amount-(100-effective))<.001,"real native mouse primary spends attributes-modified ink")
	mouse(false);await frames(2)
	saved=game.attributes.loadout(walker)
	expect(not game.attributes.roll_player() and not game.attributes.adjust("run_speed",1),"actual started match rejects attributes changes")
	game._set_pointer_lock(false);game.paused=false;await snap("playing-attributes")
	report.primary={"effective_cost":effective,"ink_after":combat.ink_amount,"attributes":saved,"health_max":game.actor_max_health(walker),"mouse_pressed_at_tick":pressed_at_tick}
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures
	var file:=FileAccess.open(output.path_join("attributes.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	await finish("native actual mouse/Enter/Esc, eight-attribute plus/minus purchases, attributes and full ROLL, 1280/960 at 110%, scene reload, actual modified primary cost and started-match lock")
