extends "res://tests/godot/helpers/creative_fixture.gd"
const Inventory:=preload("res://tools/lib/source_inventory.gd")
var output:=""
var camera:Camera3D
var companions:Node3D
var report:={"status":"running","method":"Controlled native scene: fixed actors, actual item E/right mouse events, physical creature ticks, real map collision; not a natural round or human balance acceptance.","cases":[]}
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or DisplayServer.get_name()=="headless" or not OS.has_feature("arm64"):
		printerr("FAIL: native arm64 and a new absolute output directory required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720);root.grab_focus()
	await prepare(5,"tidewater");companions=game.items.buddies
	report.environment={"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"display":DisplayServer.get_name(),"window":root.size,"render_scale":root.scaling_3d_scale}
	report.source_sha256={}
	var paths:Array[String]=Inventory.scripts();paths.append_array(["res://project.godot","res://assets/ui/item-ink_buddy.svg","res://tools/capture/verify_ink_buddy.gd"])
	for path in paths:report.source_sha256[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
	for actor in game.all_actors():
		if actor==walker:continue
		if actor==bot:game.bot_respawn=999
		else:actor.respawn_time=999
	game.phase="setup";game._set_pointer_lock(false);game.paused=false;game._update_hud()
	for i in range(5):await process_frame
	var button:Button=game.frontend.item_buttons.ink_buddy
	game.frontend.strips.item.ensure_control_visible(button);await process_frame
	var position:Vector2=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=position;Input.parse_input_event(motion)
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=position;click.pressed=true;Input.parse_input_event(click);Input.flush_buffered_events()
	var release:=click.duplicate();release.pressed=false;Input.parse_input_event(release);Input.flush_buffered_events();await process_frame
	expect(game.items.state(walker).kind=="ink_buddy","real native mouse selects the creature item card")
	camera=Camera3D.new();game.add_child(camera)
	await capture("setup-creature")
	root.size=Vector2i(960,540);game.settings.ui_scale=1.1;game._update_hud();await process_frame
	await capture("setup-small");root.size=Vector2i(1280,720);game.settings.ui_scale=1;game.phase="playing";game.phase_time=1
	var home:Vector3=find_corridor()
	expect(home.is_finite(),"real map has a collision-clear creature demonstration corridor")
	if not home.is_finite():await finish("native creature corridor");return
	report.fixture_home=home
	walker.global_position=home;walker.update_form(false);game.player_respawn=0;game.player_health=120;game._set_pointer_lock(true);game.paused=false
	var aim:Camera3D=walker.get_node("Camera3D");aim.global_position=home+Vector3(0,1.4,-2);aim.look_at(home+Vector3(0,0,6))
	combat.ink_amount=100;game.items.equip(walker,"ink_buddy");game.items.state(walker).cooldowns.ink_buddy=0
	# Actual right-button hold is polled by production combat input; no cast yet.
	right(true);await physics_frame;combat.tick(1.0/30,false,false,Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT));companions.tick(1.0/30)
	expect(combat.aiming_sub and companions.preview.visible and companions.buddies.is_empty(),"real right-button hold shows a read-only physical throw preview")
	camera.global_position=home+Vector3(6,6,-5);camera.look_at(home+Vector3(0,1,4));await capture("throw-preview")
	bot.global_position=home+Vector3(0,0,8);game.bot_respawn=0;game.bot_health=120;bot.health=120;game.bot_invuln=0
	right(false);await physics_frame;combat.tick(1.0/30,false,false,Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	expect(companions.buddies.size()==1 and combat.ink_amount==55,"real right-button release launches and spends 45 ink")
	if companions.buddies.is_empty():await finish("native release");return
	var b:Dictionary=companions.buddies.values()[0];var start:=Time.get_ticks_msec();var shot:=false;var hit:=false
	while Time.get_ticks_msec()-start<6000 and companions.buddies.has(b.id):
		await physics_frame;companions.tick(1.0/30);combat.feedback.advance(1.0/30)
		camera.global_position=b.body.global_position+Vector3(2.5,1.8,3);camera.look_at(b.body.global_position+Vector3.UP*.4)
		if b.mode=="chase" and not shot:shot=true;await capture("team-0-chase")
		if b.mode=="windup" and not hit:hit=true;await capture("team-0-windup")
		if game.bot_health<120:break
	expect(game.bot_health<120 and companions.bites_total>0,"native real-map creature chase causes authoritative enemy damage")
	await capture("team-0-bite");report.cases.append({"team":0,"input":"right hold/release","chase_captured":shot,"windup_captured":hit,"health_after":game.bot_health,"bites":companions.bites_total})
	# A separate controlled portrait makes the original creature's silhouette readable.
	b.body.global_position=home+Vector3(2,0,0);b.visual.rotation.y=0;b.visual.animate(.1,"search",0,0)
	walker.global_position=home-Vector3(0,0,3)
	camera.global_position=b.body.global_position+Vector3(.95,.85,1.4);camera.look_at(b.body.global_position+Vector3.UP*.4)
	await capture("creature-portrait")
	walker.global_position=home
	companions.clear_all();await physics_frame
	# The player's E quick throw is separate from the mouse release path.
	game.items.state(walker).cooldowns.ink_buddy=0;combat.ink_amount=100
	key(KEY_E,true);key(KEY_E,false);await process_frame
	expect(companions.buddies.size()==1 and combat.ink_amount==55,"actual native E quick throw works")
	companions.clear_all();await physics_frame
	walker.global_position=home+Vector3(0,0,8);bot.global_position=home;bot.ink_amount=100;game.player_health=120;game.player_invuln=0
	game.items.equip(bot,"ink_buddy");game.items.state(bot).cooldowns.ink_buddy=0;game.intel.refresh()
	expect(game.items.use(bot),"opposing creature uses real observed contact and item cast")
	b=companions.buddies.values()[0];start=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<6000 and game.player_health==120:
		await physics_frame;companions.tick(1.0/30);combat.feedback.advance(1.0/30)
		camera.global_position=b.body.global_position+Vector3(2.5,1.8,3);camera.look_at(b.body.global_position+Vector3.UP*.4)
	expect(game.player_health<120,"opposing creature deals actual player damage")
	await capture("team-1-bite");report.cases.append({"team":1,"health_after":game.player_health,"source":game.damage_history[-1].cause if not game.damage_history.is_empty() else ""})
	companions.clear_all();await physics_frame
	# Native grenade preview and release use the same production launch/bounce/fuse queries.
	walker.global_position=home;walker.velocity=Vector3.ZERO;game.player_health=120;game.player_respawn=0;game.bot_respawn=999
	bot.global_position=home+Vector3(0,0,12)
	aim.global_position=home+Vector3(0,1.4,-2);aim.look_at(home+Vector3(0,0,7))
	game.items.equip(walker,"bomb");game.items.state(walker).cooldowns.bomb=0;combat.ink_amount=100
	right(true);await physics_frame;combat.tick(1.0/30,false,false,Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT));game.items.placement_preview.tick(.1)
	var predicted:Dictionary=game.items.placement_preview.snapshot
	expect(game.items.placement_preview.visible and predicted.valid and combat.bombs.is_empty(),"native real held right button displays grenade arc, predicted bounce endpoint and blast range")
	camera.global_position=home+Vector3(6,6,-5);camera.look_at(home+Vector3(0,1,5));await capture("grenade-preview")
	right(false);await physics_frame;combat.tick(1.0/30,false,false,Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	expect(combat.bombs.size()==1,"native grenade release casts one real grenade")
	var grenade:Dictionary=combat.bombs[0]
	for i in range(180):
		await physics_frame;combat._update_bombs(1.0/30);combat.feedback.advance(1.0/30)
		if combat.bombs.is_empty():break
	expect(grenade.position.distance_to(predicted.point)<.001,"native real grenade explodes at predicted endpoint")
	report.cases.append({"item":"bomb","input":"right hold/release","predicted":predicted.point,"actual":grenade.position,"radius":predicted.radius})
	for kind in ["mine","intel_mist"]:
		game.items.equip(walker,kind);game.items.state(walker).cooldowns[kind]=0;combat.ink_amount=100;game.items.placement_preview.tick(.1)
		expect(game.items.placement_preview.visible and game.items.placement_preview.snapshot.valid,"native "+kind+" placement marker is valid")
		await capture(kind+"-placement")
		if kind=="mine":
			combat.ink_amount=0;game.items.placement_preview.tick(.1);await capture("placement-unavailable")
			combat.ink_amount=100
		key(KEY_E,true);key(KEY_E,false);await process_frame
		expect(combat.ink_amount<100,"native E places "+kind+" at its marker")
	report.status="passed" if failures.is_empty() else "failed";report.failures=failures
	var file:=FileAccess.open(output.path_join("buddy.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	companions.clear_all();await finish("native selectable creature icon, two UI sizes, actual right-button/E input, both-team real-map physical attacks, grenade explosion prediction and placement hints")
func find_corridor() -> Vector3:
	for candidate in [Vector3(12,0,-18),Vector3(0,0,-25),Vector3(8,0,-25),Vector3(-16,0,-18),Vector3(-8,0,-25),Vector3(0,0,-10),Vector3(-8,0,10)]:
		var clear:=true;var base:Vector3=candidate
		for distance in [-2,0,3,6,8]:
			var at:Vector3=candidate+Vector3(0,0,distance)
			var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*3,at-Vector3.UP*2,9)
			var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y<.8 or absf(hit.position.y)>.25:clear=false;break
			base.y=hit.position.y+.05
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=companions._shape();query.collision_mask=9;query.transform=Transform3D(Basis.IDENTITY,Vector3(at.x,base.y+.35,at.z))
			if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():clear=false;break
		if clear and companions._clear(base+Vector3.UP*.4,base+Vector3(0,.4,8)):return base
	return Vector3.INF
func right(down:bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=down;Input.parse_input_event(event);Input.flush_buffered_events()
func capture(label:String) -> void:
	game._update_hud();await process_frame
	if camera!=null and game.phase=="playing":camera.current=true
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"save native "+label)
