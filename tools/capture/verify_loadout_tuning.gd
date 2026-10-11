extends "res://tests/godot/helpers/creative_fixture.gd"
const Setup=preload("res://src/core/match_setup.gd")
const Kits=preload("res://src/core/loadout_rules.gd")
var output:=""
var report:Dictionary={"kind":"controlled native loadout input","limits":"Frozen match/AI and explicit CPU paint probes. Not human play, natural timing or temperature acceptance.","cases":[],"clicks":[]}

func _initialize() -> void:call_deferred("_run")
func frames(count:int=6) -> void:
	for i in count:await process_frame
func click(control:Control) -> void:
	root.grab_focus();await frames(3)
	var point:Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	# Keep the GUI sequence together. A native warp can deliver late motion
	# between button-down/up while the window is acquiring focus.
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	root.push_input(motion,true);await frames(2)
	var hovered:=root.gui_get_hovered_control()
	expect(hovered==control,"actual mouse reaches "+control.text)
	var trace:Dictionary={"button":control.text,"point":point,"hovered":hovered.text if hovered is Button else str(hovered),"mouse_mode":Input.mouse_mode,"phase":game.phase,"locked":game.perks.locked,"disabled":control.disabled if control is BaseButton else false}
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event,true)
	await frames(6)
	trace.attributes=game.attributes.loadout(walker)
	report.clicks.append(trace)
func choose(control:Button,index:int) -> void:
	var current:int=Kits.MODES.find(Setup.loadout_mode)
	if current==index:
		await click(control);await frames()
		if not is_instance_valid(control):return
	await click(control);await frames(10)

func snap(id:String) -> void:
	game.paused=false;game._update_hud();game.get_node("InkView").sync_dirty();await frames()
	game.paused=false;game._update_hud()
	await RenderingServer.frame_post_draw
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
	report.environment={"engine":Engine.get_version_info().string,"arm64":OS.has_feature("arm64"),"api":RenderingServer.get_video_adapter_api_version()}
	report.source_sha256={}
	for path in preload("res://tools/lib/source_inventory.gd").scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	Setup.pending_loadout={"settings_path":output.path_join("settings.cfg")}
	await prepare(5,"tidewater")
	current_scene=game;bind_game();game.show_preparation();game.perks.locked=false
	game.perks.select_player("balanced");game._choose_player_weapon("shooter")
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=pixels;root.content_scale_size=pixels;game.settings.ui_scale=1.1 if pixels.x==960 else 1.0
		await frames(10);game._layout_hud();game.frontend.sync();await frames(6)
		var previous: Array=[game.selected_weapon,Setup.selected_perk,Setup.selected_item]
		await click(game.frontend.roll_button)
		expect([game.selected_weapon,Setup.selected_perk,Setup.selected_item]!=previous,"actual mouse roll changes loadout")
		await choose(game.frontend.kit_mode,0)
		expect(Setup.loadout_mode=="kit" and Setup.selected_item==Kits.sub_for(game.selected_weapon),"actual fixed-kit button equips associated sub")
		game.frontend.strips.weapon.ensure_control_visible(game.weapon_buttons.bow);await frames(6)
		await click(game.weapon_buttons.bow)
		expect(game.selected_weapon=="bow" and Setup.selected_item=="intel_mist","actual main click changes kit sub")
		game.frontend.strips.item.ensure_control_visible(game.frontend.item_buttons.ink_buddy);await frames(6)
		await click(game.frontend.item_buttons.ink_buddy)
		expect(Setup.loadout_mode=="custom" and Setup.selected_item=="ink_buddy","actual independent sub click switches custom")
		game.perks.select_player("balanced");game.frontend.sync()
		var expected_caps:String="生命 %.0f · 墨量 %.0f" % [game.actor_max_health(walker),game.actor_ink_max(walker)]
		expect(game.frontend.kit.text.contains(expected_caps),"native header shows actual talent and rolled-attribute caps")
		expect(preload("res://src/core/attribute_catalog.gd").spent(game.attributes.loadout(walker))==20,"complete native ROLL assigns twenty points")
		for control in [game.frontend.kit_mode,game.frontend.roll_button]:
			expect(Rect2(Vector2.ZERO,Vector2(pixels)).encloses(Rect2(control.get_global_transform_with_canvas()*Vector2.ZERO,control.get_global_transform_with_canvas()*control.size-control.get_global_transform_with_canvas()*Vector2.ZERO)),"native new control fits viewport")
		report.cases.append({"size":[pixels.x,pixels.y],"mode":Setup.loadout_mode,"main":game.selected_weapon,"sub":Setup.selected_item,"perk":Setup.selected_perk,"attributes":game.attributes.loadout(walker),"expected_caps":expected_caps,"header":game.frontend.kit.text})
		var away:=InputEventMouseMotion.new();away.position=Vector2(20,20);root.push_input(away,true);await create_timer(.2).timeout
		await snap("loadout-%d"%pixels.x)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;game.settings.ui_scale=1;await frames(10);game._layout_hud()
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures
	var file:=FileAccess.open(output.path_join("loadout.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	await finish("native actual mouse/selector inputs, roll/kits/custom, 1280/960 at 110%, full-map turf setup")
