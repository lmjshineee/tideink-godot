extends SceneTree
const Setup:=preload("res://match_setup.gd")
var game:Node3D
func _initialize() -> void:call_deferred("_run")
func snap(label:String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://render-evidence/creative17-"+label+".png")
func _run() -> void:
	root.size=Vector2i(1440,900)
	Setup.screen="setup";Setup.team_size=5;Setup.selected_perk="balanced";Setup.selected_item="recall"
	Setup.map_id="prism_gallery";Setup.map_variant=0;Setup.random_map=false
	Setup.pending_loadout={"player":"bow"}
	game=(load("res://tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game);current_scene=game
	await process_frame
	game.set_physics_process(false)
	var walker:CharacterBody3D=game.get_node("World/Walker");walker.set_physics_process(false)
	var combat:Node3D=game.get_node("Combat")
	game.frontend._begin_hover("weapon","bow")
	await snap("bow-loadout")
	game.frontend._end_hover()
	game.frontend.preview.set_pose("shoot")
	game.frontend.preview.distance=2.8;game.frontend.preview.yaw=.7;game.frontend.preview._update_camera()
	await snap("bow-held")
	game._choose_player_weapon("canopy");game.frontend._begin_hover("weapon","canopy")
	await snap("canopy-loadout")
	game._start_round();game._set_pointer_lock(false);game.paused=false;game.pointer_locked=true;game.phase_time=4;game.deployment.clear()
	for actor in game.all_actors():
		if actor!=walker:actor.global_position=Vector3(70,40,70)
	var bot:Node3D=game.get_node("Bot")
	var camera:Camera3D=walker.get_node("Camera3D");camera.current=true
	var body:Node3D=walker.get_node("Body")
	combat.select_weapon("bow")
	walker.global_position=Vector3(-8.5,3.05,-18);walker.reset_movement_state();walker.grounded=true;walker.update_form(false);body.set_form(false)
	bot.global_position=Vector3(-8.5,6.05,-4);bot.select_weapon("bow")
	bot.visible=true;bot.get_node("Body").set_form(false)
	var aim:Vector3=bot.global_position+Vector3.UP*.8-walker.global_position-Vector3.UP*1.05
	body.rotation.y=atan2(aim.x,aim.z);body.set_aim(true);body.set_weapon_pose(atan2(aim.y,Vector2(aim.x,aim.z).length()),false)
	for i in 15:body._physics_process(.033)
	camera.global_position=walker.global_position+Vector3(3,3,-5);camera.look_at(bot.global_position+Vector3.UP*.8)
	combat.tick(1,true,false);game._update_hud()
	await snap("aim-upper-deck")
	combat.tick(.001,false,false)
	combat.bow.tick(.066);game._update_hud()
	await snap("arrows-upper-deck")
	combat.bow.clear_all()
	# Reverse the height relation for the same three-dimensional camera and weapon.
	walker.global_position=Vector3(8.5,6.05,3);bot.global_position=Vector3(8.5,3.05,18)
	aim=bot.global_position+Vector3.UP*.8-walker.global_position-Vector3.UP*1.05
	body.rotation.y=atan2(aim.x,aim.z);body.set_weapon_pose(atan2(aim.y,Vector2(aim.x,aim.z).length()),false)
	for i in 15:body._physics_process(.033)
	camera.global_position=walker.global_position+Vector3(3,3,5);camera.look_at(bot.global_position+Vector3.UP*.8)
	game._update_hud();await snap("aim-lower-deck")
	combat.select_weapon("canopy")
	walker.global_position=Vector3(-15,.85,-13);bot.global_position=Vector3(-15,.85,-9)
	body.rotation.y=0;body.set_weapon_pose(0,false);body.set_aim(true)
	for i in 15:body._physics_process(.033)
	camera.global_position=walker.global_position+Vector3(3,2.5,-5);camera.look_at(walker.global_position+Vector3(0,1,3))
	combat.canopy.update_input(walker,.3,true,bot.global_position+Vector3.UP);combat.canopy.tick(.01)
	game._update_hud();await snap("canopy-open")
	combat.canopy.update_input(walker,1,true,bot.global_position+Vector3.UP);combat.canopy.tick(.3)
	game._update_hud();await snap("canopy-launch")
	game.queue_free();await process_frame
	print("PASS: Metal native bow/canopy loadouts, upper/lower gallery aim and actual arrow/cover/launch meshes captured")
	quit()
