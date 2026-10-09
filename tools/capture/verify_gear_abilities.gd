extends "res://tests/godot/helpers/creative_fixture.gd"
const Catalog := preload("res://src/core/gear_catalog.gd")
const Setup := preload("res://src/core/match_setup.gd")
var output := ""
var report := {"kind":"controlled native gear input", "limits":"Frozen AI/match and explicit input probes; not human balance, natural timing or thermal acceptance.", "cases":[], "clicks":[]}

func _initialize() -> void: call_deferred("_run")
func frames(count: int = 5) -> void:
	for i in count: await process_frame

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * .5)
	root.warp_mouse(point); await frames(2)
	var move := InputEventMouseMotion.new(); move.position=point;move.global_position=point
	root.push_input(move,true);await frames(2)
	var hovered := root.gui_get_hovered_control()
	var trace := {"button":control.text if control is Button else control.name,"point":point,"phase":game.phase,"locked":game.perks.locked,"disabled":control.disabled if control is BaseButton else false,"hovered":hovered.text if hovered is Button else str(hovered)}
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point;event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event,true);await frames(3)
	trace.phase_after=game.phase if is_instance_valid(game) else "scene reloaded"
	trace.editor_open=game.frontend.gear_editor.visible if is_instance_valid(game) else false
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
		root.size=pixels;root.content_scale_size=pixels;game.settings.ui_scale=1.1 if pixels.x==960 else 1.0
		await frames(10);game._layout_hud();game.frontend.sync();await frames()
		await click(game.frontend.gear_button)
		var editor: Control=game.frontend.gear_editor
		expect(editor.visible and game.phase=="setup","actual mouse opens gear without starting match")
		if not editor.visible:
			var diagnostic:=FileAccess.open(output.path_join("failed-open.json"),FileAccess.WRITE);diagnostic.store_string(JSON.stringify(report,"\t"));diagnostic.close()
			await finish("native editor open");return
		await click(editor.clear_button)
		await click(editor.slot_buttons["head:0"]);await click(editor.ability_buttons.main_saver)
		expect(game.gear.totals(walker).main_saver==10,"actual main slot gives ten points")
		await click(editor.slot_buttons["clothes:1"]);await click(editor.ability_buttons.main_saver)
		expect(game.gear.totals(walker).main_saver==13,"actual secondary slot adds three points")
		await click(editor.slot_buttons["shoes:0"]);await click(editor.ability_buttons.run_speed)
		expect(walker.player_config.runSpeed>6.3,"actual selection updates player movement configuration")
		await press(KEY_1)
		expect(game.phase=="setup","equipment editor owns numeric match shortcuts")
		editor.ability_buttons.ink_recovery.grab_focus();await press(KEY_ENTER)
		expect(game.phase=="setup" and game.gear.loadout(walker).shoes[0]=="ink_recovery","actual Enter assigns focused ability without starting match")
		game.items.state(walker).cooldowns.bomb=7;var before:Dictionary=game.gear.loadout(walker)
		await click(editor.roll_button)
		expect(game.gear.loadout(walker)!=before and game.items.state(walker).cooldowns.bomb==7,"actual gear-only ROLL changes equipment and preserves cooldown")
		for piece in Catalog.PIECES:expect(not game.gear.loadout(walker)[piece].has("none"),"ROLL fills every main/secondary slot")
		var viewport := Rect2(Vector2.ZERO,Vector2(pixels))
		for control in editor.slot_buttons.values()+editor.ability_buttons.values()+[editor.close_button,editor.roll_button,editor.clear_button]:
			expect(viewport.encloses(rect(control)),"native editor control fits scaled viewport")
			expect(not rect(control).intersects(rect(editor.summary)),"editor controls do not overlap effect summary")
		expect(editor.description.get_minimum_size().y<=editor.description.size.y and editor.summary.get_minimum_size().y<=editor.summary.size.y,"ability details and total effects fit allocated heights")
		report.cases.append({"size":[pixels.x,pixels.y],"ui_scale":game.settings.ui_scale,"gear":game.gear.loadout(walker),"points":game.gear.totals(walker),"effects":editor.summary.text})
		await snap("gear-%d"%pixels.x)
		await press(KEY_ESCAPE)
		expect(not editor.visible and game.phase=="setup","actual Esc closes only gear editor")
		before=game.gear.loadout(walker);await click(game.frontend.roll_button)
		expect(before!=game.gear.loadout(walker),"actual complete loadout ROLL includes gear")
		await snap("setup-%d"%pixels.x)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;game.settings.ui_scale=1;await frames(10);game._layout_hud()
	var saved:Dictionary=game.gear.loadout(walker)
	await click(game.frontend.rule_choice);await frames(15);bind_game()
	expect(game.gear.loadout(walker)==saved and game.area.enabled,"rule reload preserves actual gear snapshot")
	game.perks.select_player("balanced");game.gear.select_player(Catalog.empty());game.gear.select_slot("head",0,"main_saver")
	game._choose_player_weapon("shooter");game.frontend.gear_editor.open();game._begin_intro()
	expect(not game.frontend.gear_editor.visible,"native phase transition closes hidden editor input capture")
	game._start_round();game.set_physics_process(false);walker.set_physics_process(false);walker.set_process_input(false)
	walker.global_position=Vector3(0,.05,-28);combat.ink_amount=100;combat.last_fire_time=0;combat.last_fire=false;combat.cooldown=0
	var effective:float=game.perks.weapon(walker,combat.weapons.shooter).inkPerShot
	# GUI push_input routes clicks; primary combat polls global Input instead.
	mouse(true)
	var pressed_at_tick := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	combat.tick(.001,Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),false)
	expect(absf(combat.ink_amount-(100-effective))<.001,"real native mouse primary spends gear-modified ink")
	mouse(false);await frames(2)
	saved=game.gear.loadout(walker)
	expect(not game.gear.roll_player() and not game.gear.select_slot("head",0,"run_speed"),"actual started match rejects gear changes")
	game._set_pointer_lock(false);game.paused=false;await snap("playing-gear")
	report.primary={"effective_cost":effective,"ink_after":combat.ink_amount,"gear":saved,"health_max":game.actor_max_health(walker),"mouse_pressed_at_tick":pressed_at_tick}
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures
	var file:=FileAccess.open(output.path_join("gear.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	await finish("native actual mouse/Enter/Esc, three-piece primary/secondary selection, gear and full ROLL, 1280/960 at 110%, scene reload, actual modified primary cost and started-match lock")
