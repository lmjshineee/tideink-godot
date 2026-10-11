extends "res://tests/godot/helpers/creative_fixture.gd"
var output:=""
var report:={"cases":[]}
func _initialize() -> void:call_deferred("_run")
func snap(label:String) -> void:
	game._update_hud();game.get_node("InkView").sync_dirty()
	await process_frame;await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	expect(picture!=null and not picture.is_empty(),"native image "+label)
	if picture!=null:expect(picture.save_png(output.path_join(label+".png"))==OK,"save "+label)
func input_tick() -> void:
	game.paused=false;game.pointer_locked=true;walker.active=true
	walker.update_intent(1.0/30,Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),Input.is_physical_key_pressed(KEY_SHIFT),combat.is_busy())
	combat.tick(1.0/30,walker.weapon_fire,walker.squid_form)
	walker._physics_process(1.0/30)
func home(id:String="shooter") -> void:
	mouse(false);key(KEY_SPACE,false);key(KEY_SHIFT,false);key(KEY_W,false);key(KEY_S,false)
	combat.on_death();game.wings.cancel(walker);walker.reset_movement_state()
	game.player_health=132;game.player_respawn=0;game.player_invuln=0
	game.selected_weapon=id;combat.select_weapon(id)
	walker.global_position=Vector3(0,.05,-28);walker.grounded=true
	walker.camera_yaw=0;walker.camera_pitch=-.08;walker._update_camera()
	game.paused=false;game.pointer_locked=true;walker.active=true
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64 and a fresh absolute output directory required");quit(1);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:quit(1);return
	root.size=Vector2i(1280,720)
	preload("res://src/core/match_setup.gd").pending_loadout={"settings_path":output.path_join("isolated-settings.cfg")}
	await prepare(1,"tidewater")
	game.phase_time=2.5;DisplayServer.window_move_to_foreground();root.grab_focus()
	report.environment={"engine":Engine.get_version_info().string,"arch":"arm64","display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"window":[1280,720]}
	report.source_sha256={}
	for path in preload("res://tools/lib/source_inventory.gd").scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
	report.source_sha256["res://tools/capture/verify_accuracy_items.gd"]=FileAccess.get_sha256("res://tools/capture/verify_accuracy_items.gd")
	walker.set_process_input(false);game._set_pointer_lock(true);home()
	bot.global_position=Vector3(70,40,70)
	combat.ink_amount=110;combat.bloom=0
	await snap("01-settled-box")
	var small:Rect2=combat.reticle_box();mouse(true)
	for i in 22:await physics_frame;input_tick()
	var ground:Rect2=combat.reticle_box()
	expect(combat.bloom>.9 and ground.size.x>small.size.x+20,"actual held mouse expands shot box")
	await snap("02-continuous-box")
	walker.set_process_input(true);key(KEY_SPACE,true);key(KEY_SPACE,false);walker.set_process_input(false)
	await physics_frame;input_tick()
	var air:Rect2=combat.reticle_box()
	expect(not walker.grounded and air.size.x>ground.size.x*1.5,"actual Space jump enlarges the accuracy box")
	report.cases.append({"case":"mouse-Space-scatter","settled_px":small.size,"ground_px":ground.size,"air_px":air.size})
	await snap("03-jump-box")
	home();combat.ink_amount=1;combat.special_points=combat.special_cost()
	key(KEY_F,true);key(KEY_F,false)
	report.cases.append({"case":"F-immediate","active":combat.special_active,"guard":game.player_invuln,"tank":combat.ink_amount,"max_tank":game.actor_ink_max(walker)})
	expect(combat.special_active=="overdrive","actual F starts the shooter's special")
	expect(is_equal_approx(game.player_invuln,1.0),"actual F grants one second of real protection")
	expect(combat.ink_amount==game.actor_ink_max(walker),"actual F refills the actor's effective tank")
	game.damage_player(200,false,bot,"charger");expect(game.player_health==132,"native startup blocks actual lethal hit")
	await snap("04-special-guard")
	game.player_last_damage=0;game._update_player_vitals(.85);combat.special_guard.tick(.85)
	game.damage_player(80,false,bot,"blaster");expect(game.player_health==132,"native guard lasts through 850ms")
	report.cases.append({"case":"F-real-guard","hp":game.player_health,"remaining":game.player_invuln,"tank":combat.ink_amount})
	await snap("05-guard-remains")
	# Each pressure shot reads a new actual mouse aim direction.
	home("blaster");combat.ink_amount=1;combat.special_points=combat.special_cost();key(KEY_F,true);key(KEY_F,false)
	combat.weapon_specials.tick(.26)
	var first:Vector3=combat.weapon_specials.states[walker.get_instance_id()].direction
	walker.apply_look_delta(Vector2(160,0));combat.weapon_specials.tick(.40)
	var second:Vector3=combat.weapon_specials.states[walker.get_instance_id()].direction
	expect(first.dot(second)<.98,"native pressure volley responds to changed mouse aim")
	report.cases.append({"case":"pressure-steer","first":first,"second":second,"guard":game.player_invuln})
	await snap("06-steered-pressure")
	home();combat.ink_amount=110;game.items.equip(walker,"ink_wings");game.items.state(walker).cooldowns.ink_wings=0
	key(KEY_E,true);key(KEY_E,false)
	expect(game.wings.busy(walker) and combat.ink_amount==85,"actual E opens economical wings")
	expect(game.wings.vertical(walker)==0,"wings wait for direct rise input")
	var start:float=walker.global_position.y;key(KEY_SPACE,true)
	await physics_frame;input_tick()
	expect(walker.velocity.y>8.9,"first held Space frame immediately ascends at 9m/s")
	for i in 9:await physics_frame;input_tick()
	expect(walker.global_position.y>start+2.9,"native flight rises three metres in one third of a second")
	key(KEY_SPACE,false);var y:float=walker.global_position.y
	await physics_frame;input_tick();expect(absf(walker.global_position.y-y)<.02,"release immediately hovers")
	report.cases.append({"case":"E-Space-wings","rise":y-start,"cooldown":game.items.state(walker).cooldowns.ink_wings,"cost":game.wings.COST,"flap_rotation":game.wings.flights[walker.get_instance_id()].visual.rotation.z})
	await snap("07-direct-rise-wings")
	key(KEY_SHIFT,true);await physics_frame;input_tick();key(KEY_SHIFT,false)
	expect(walker.velocity.y<-6.9,"Shift immediately descends at 7m/s")
	home();walker.global_position=Vector3(5.5,.1,0);walker.camera_yaw=-PI/2;walker._update_camera()
	game.ink.splat_face(5,5,1.4,3,0,.5)
	key(KEY_SHIFT,true);key(KEY_W,true)
	await physics_frame;input_tick();expect(walker.climbing,"real Shift-W attaches to owned wall")
	key(KEY_W,false);key(KEY_S,true)
	walker.set_process_input(true);key(KEY_SPACE,true);key(KEY_SPACE,false);walker.set_process_input(false)
	await physics_frame;input_tick()
	expect(not walker.climbing and walker.velocity.x>10 and walker.velocity.y>8,"real away+Space produces wall kick")
	report.cases.append({"case":"wall-kick","velocity":walker.velocity,"guard":walker.squid_roll_guard})
	await snap("08-wall-kick")
	home();bot.global_position=Vector3(70,40,70)
	for shot in combat.projectiles:shot.visual.queue_free()
	combat.projectiles.clear()
	var at:=walker.global_position+Vector3(0,1.5,6)
	combat._spawn_projectile("shooter",at-Vector3.BACK,Vector3.BACK*34,combat.weapons.shooter,0,walker)
	combat._spawn_projectile("shooter",at+Vector3.BACK,Vector3.FORWARD*34,combat.weapons.shooter,1,bot)
	var collisions:int=combat.ink_clash.total
	combat._update_projectiles(.033);combat.feedback.advance(.016)
	expect(combat.ink_clash.total==collisions+1 and combat.projectiles.is_empty(),"native swept ink collision removes both real projectiles")
	await snap("09-ink-clash")
	report.cases.append({"case":"ink-clash","point":combat.ink_clash.last_point,"pairs":combat.ink_clash.total-collisions})
	home();game._set_pointer_lock(false)
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures.duplicate()
	report.limits="Controlled native input with frozen AI/match and forced resources; no human feel, natural full-match balance, temperature or App export acceptance."
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	await finish("native mouse/jump boxes, F protection/refill, pressure aim, E/direct wings, wall kick and ink collision")
