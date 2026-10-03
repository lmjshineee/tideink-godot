extends SceneTree
const Setup:=preload("res://match_setup.gd")
var suffix:="after"
func _initialize() -> void: call_deferred("_run")
func snap(label:String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://render-evidence/canopy26-%s-%s.png" % [label,suffix])
func _run() -> void:
	if OS.get_cmdline_user_args().has("before"):suffix="before"
	if OS.get_cmdline_user_args().has("gl"):suffix="after-gl"
	root.size=Vector2i(1440,900)
	Setup.randomized=true;Setup.style_index=0;Setup.appearance_seed=1709
	preload("res://team_palette.gd").select(0)
	for id in ["coral_market","viaduct"]:
		Setup.map_id=id;Setup.screen="setup";Setup.random_map=false;Setup.map_seed=1;Setup.team_size=5
		Setup.selected_perk="balanced";Setup.pending_loadout={"player":"canopy"}
		var game:Node3D=(load("res://tidewater_play.tscn") as PackedScene).instantiate()
		root.add_child(game);current_scene=game
		await physics_frame
		game._start_round();game._set_pointer_lock(false);game.paused=false
		game.hud_root.visible=false;game.set_physics_process(false)
		var walker:Node3D=game.get_node("World/Walker");walker.set_physics_process(false)
		for actor in game.all_actors():actor.visible=false
		var camera:=Camera3D.new();game.add_child(camera)
		camera.position=Vector3(31,34,-43) if id=="coral_market" else Vector3(29,33,-46)
		camera.look_at(Vector3(0,2,0));camera.current=true;camera.fov=68
		await snap(id+"-overview")
		# Identical real paint events on a clear lane for before/after material comparison.
		var combat:Node3D=game.get_node("Combat")
		for z in 9:
			combat._paint_team(Vector3(-5+sin(z)*.5,.08,-27+z*.65),0,1.25,.37,Vector3.ZERO,0,walker)
		for z in 5:combat._paint_team(Vector3(-2+sin(z)*.3,.08,-22+z*.7),1,1.05,.61,Vector3.ZERO,0,walker)
		game.get_node("InkView").sync_dirty()
		camera.position=Vector3(-9,3.3,-28);camera.look_at(Vector3(-3,.1,-22));camera.fov=58
		await snap(id+"-wet")
		if id=="coral_market":
			var owners_before:String=JSON.stringify(game.ink.owners)
			var coverage_before:Array=[game.ink.coverage(0),game.ink.coverage(1)]
			camera.position=Vector3(-3,5.6,-27);camera.look_at(Vector3(-5,.08,-23));camera.fov=54
			await snap("ink-reflection")
			var ink_view:Node3D=game.get_node("InkView")
			var materials:Array=[]
			var baseline:=load("res://render-evidence/canopy26-baseline.gdshader") as Shader
			for face in ink_view.get_children():
				materials.append([face.material_override,face.material_override.shader])
				face.material_override.shader=baseline
			var environment:Environment=game.get_node("World/Map/Lighting/WorldEnvironment").environment
			environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
			await snap("ink-reflection-baseline")
			environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
			for entry in materials:entry[0].shader=entry[1]
			if owners_before!=JSON.stringify(game.ink.owners) or coverage_before!=[game.ink.coverage(0),game.ink.coverage(1)]:
				printerr("FAIL: material comparison changed ownership or coverage");quit(1);return
			camera.position=Vector3(-8,3.5,-27);camera.look_at(Vector3(-4,1,-19));camera.fov=66
			walker.visible=true;walker.global_position=Vector3(-4,.05,-24)
			combat.select_weapon("canopy");combat.ink_amount=100
			var target:=Vector3(-4,.08,-12)
			for i in 8:
				combat.canopy.update_input(walker,1.0/30,true,target);combat.canopy.tick(1.0/30)
			await physics_frame
			var state:Dictionary=combat.canopy.state(walker)
			if state.cover==null or state.launched or state.hp!=220:
				printerr("FAIL: native real cover did not open");quit(1);return
			var cover_start:Vector3=state.cover.global_position
			await snap("canopy-guard")
			for i in 42:
				combat.canopy.update_input(walker,1.0/30,true,target);combat.canopy.tick(1.0/30)
			game.get_node("InkView").sync_dirty()
			if state.cover==null or not state.launched or state.cover.global_position.distance_to(cover_start)<4:
				printerr("FAIL: native ground-aim canopy failed to push");quit(1);return
			print("AUDIT: native cover advance=",state.cover.global_position.distance_to(cover_start)," ink=",combat.ink_amount," pellets=",combat.projectiles.size())
			await snap("canopy-push")
		game.queue_free();await process_frame
	print("PASS: actual market/viaduct geometry and same-seed paint captured ",suffix)
	quit()
