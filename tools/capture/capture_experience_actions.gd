extends "res://tests/godot/helpers/creative_fixture.gd"
const Setup:=preload("res://src/core/match_setup.gd")
var output:=""
var report:={"kind":"controlled native input, high-ground AI and eight specials","ai_selection_injected":true,"fixture_focus_pause_overridden":true,"audit":[],"failures":[],"source_sha256":{}}
func _initialize() -> void:call_deferred("_run")
func click(control:Control) -> void:
	var point:=control.get_global_rect().get_center()
	root.notify_mouse_entered()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	root.push_input(motion,true);await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=down
		root.push_input(event,true);await process_frame
func capture(label:String) -> void:
	game.paused=false;game._update_hud();await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func _run() -> void:
	if DisplayServer.get_name()=="headless" or Engine.get_architecture_name()!="arm64":printerr("FAIL: native arm64 window required");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):printerr("FAIL: new absolute output directory required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	Setup.appearance_seed=731;Setup.randomized=true;Setup.pending_loadout={"player":"shooter","settings_path":"/private/tmp/tideink-experience-unused.cfg"}
	preload("res://src/core/team_palette.gd").random_palette={};preload("res://src/core/team_palette.gd").palette_index=0
	root.gui_embed_subwindows=true # Fixture routes injected keys to the embedded popup; production is unchanged.
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	await prepare(1,"tidewater")
	game.settings.ui_scale=1.1;game.show_preparation();game._layout_hud();await process_frame
	await click(game.frontend.item_buttons.shield)
	expect(Setup.selected_item=="shield" and game.items.state(walker).kind=="shield","native mouse selects actual shield loadout")
	# Configure difficulty through the same GUI selection signal as the rule
	# regression. Native OS popup input is not claimed by this controlled fixture.
	game.frontend.ai_choice.select(2);game.frontend.ai_choice.item_selected.emit(2)
	expect(game.ai_level=="veteran" and game.phase=="setup","controlled GUI difficulty reaches setup state")
	await capture("setup-960-shield-veteran")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	game._start_round();game.set_physics_process(false);walker.set_physics_process(false);game.paused=false;game.phase_time=2
	game._set_pointer_lock(false);game.paused=false
	var platform:=wall(Vector3(0,2,-23),Vector3(5,4,3));await physics_frame
	var camera:=Camera3D.new();game.add_child(camera);camera.current=true;camera.global_position=Vector3(10,9,-34);camera.look_at(Vector3(0,2,-25))
	for level in preload("res://src/core/bot_difficulty.gd").IDS:
		game.ai_level=level;game.player_invuln=999;game.items.state(bot).cooldowns.bomb=999
		combat.weapon_specials.clear();game.bot_specials.on_death(bot);game.bot_specials.state(bot).points=0
		walker.global_position=Vector3(0,4.05,-24.45);bot.global_position=Vector3(0,.05,-28);bot.team_mover.velocity=Vector3.ZERO
		bot.select_weapon("shooter");bot.reaction_target=null;bot.reaction_time=0;bot.strafe_time=0;bot.recovery_time=0;bot.last_fire_time=0;bot.ink_amount=100
		await physics_frame
		var from:Vector3=bot.global_position;var furthest:=0.0;var first_shot:=-1;var shots:=0
		for frame in range(75):
			await physics_frame;var count:int=combat.projectiles.size();game._update_bot(1.0/30)
			if combat.projectiles.size()>count:
				shots+=combat.projectiles.size()-count
				if first_shot<0:first_shot=frame
			combat.advance_effects(1.0/30);game.intel.tick(1.0/30)
			furthest=maxf(furthest,Vector2(bot.global_position.x-from.x,bot.global_position.z-from.z).length())
		expect(furthest>.4 and shots>0,"high-ground "+level+" moves and fires with actual collision/vision")
		report.audit.append({"ai":level,"distance":furthest,"shots":shots,"first_shot_frame":first_shot})
		await capture("high-ground-"+level)
	platform.queue_free();await physics_frame
	camera.current=false
	bot.global_position=Vector3(80,40,80);walker.global_position=Vector3(0,.05,-28);walker.reset_movement_state();walker.grounded=true;walker.ink_owner=0
	game.player_invuln=0;game.player_health=120;game.pointer_locked=true;game.paused=false
	var aim:Camera3D=walker.get_node("Camera3D");aim.current=true;aim.global_position=walker.global_position+Vector3(3,3,4);aim.look_at(walker.global_position+Vector3(0,.1,6))
	key(KEY_E,true);key(KEY_E,false);combat.tick(.01,false,false)
	expect(game.items.state(walker).armor==60,"native E activates selected shield")
	game.damage_player(82,false,bot,"blaster");expect(game.player_health==98,"real shield damage loses only 22 HP")
	# Controlled grant is disclosed: these captures validate input and visuals, not charging pace.
	for id in game.weapon_order:
		combat.on_death();walker.cancel_slam();combat.weapon_specials.clear();combat.counter.cancel(walker);combat.rain_arrows.cancel(walker)
		walker.global_position=Vector3(0,.05,-28);walker.update_form(false);walker.grounded=true;walker.active=true
		game.selected_weapon=id;combat.select_weapon(id);combat.special_points=combat.special_cost();game.paused=false;game.pointer_locked=true
		aim.global_position=walker.global_position+Vector3(3,3,4);aim.look_at(walker.global_position+Vector3(0,.1,6));await physics_frame
		key(KEY_F,true);key(KEY_F,false)
		expect(combat.special_points==0 and combat.special_active==String(combat.weapons[id].special),"actual F activates "+id)
		combat.advance_effects(.32);game.get_node("InkView").sync_dirty();await capture("special-"+id)
		report.audit.append({"weapon":id,"special":combat.weapons[id].special,"cost":combat.special_cost(),"meter_granted":true})
	report.architecture=Engine.get_architecture_name();report.failures=failures
	for path in preload("res://tools/lib/source_inventory.gd").scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	await finish("native mouse shield, controlled AI menu, all levels high-ground move/fire and actual F for eight specials")
