extends "res://tools/creative_fixture.gd"
var suffix:="metal"
func _initialize() -> void:call_deferred("_run")
func input_tick(delta:float,pressed:bool) -> void:
	# Desktop focus may change while saving frames. Resume this controlled
	# fixture before injecting the next input; production focus pause stays intact.
	if game.paused:print("AUDIT: screenshot fixture resumes after desktop focus pause")
	game.paused=false;game.pointer_locked=true
	mouse(pressed);combat.tick(delta,Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),false)
func snap(label:String) -> void:
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://render-evidence/bow27-%s-%s.png" % [label,suffix])
func pose(target:Vector3) -> void:
	var body:Node3D=walker.get_node("Body")
	var aim:Vector3=target-walker.global_position-Vector3.UP*1.05
	body.set_form(false);body.set_weapon("bow");body.rotation.y=atan2(aim.x,aim.z)
	body.set_aim(true);body.set_weapon_pose(atan2(aim.y,Vector2(aim.x,aim.z).length()),false)
	body.set_weapon_charge(combat.charge_fraction)
	for i in 12:body._physics_process(1.0/30)
func _run() -> void:
	if OS.get_cmdline_user_args().has("gl"):suffix="gl"
	root.size=Vector2i(1440,900)
	preload("res://match_setup.gd").pending_loadout={"player":"bow"}
	await prepare(5,"prism_gallery")
	expect(game.selected_weapon=="bow" and combat.selected_id=="bow","normal pending loadout initializes bow HUD and primary together")
	game.phase_time=8;game.deployment.clear()
	var camera:Camera3D=walker.get_node("Camera3D");camera.current=true
	walker.global_position=Vector3(-20,.05,-24);walker.grounded=true;walker.visible=true
	bot.global_position=Vector3(-20,.05,-8);bot.visible=true;bot.get_node("Body").set_form(false)
	var target:Vector3=bot.global_position+Vector3.UP*.8
	camera.global_position=walker.global_position+Vector3(3,3,-5);camera.look_at(target)
	game.pointer_locked=true;game._update_hud()
	input_tick(.8,true)
	pose(target);game._update_hud()
	expect(combat.charge_fraction==1 and game.hud.text.contains("精准三箭"),"native full draw has actual compact readiness hint")
	await snap("full-draw")
	input_tick(.001,false)
	for i in 35:combat.bow.tick(1.0/30)
	expect(is_equal_approx(game.bot_health,12) and is_equal_approx(combat.ink_amount,93),"native 16m physical three-arrow release hits 108 and costs 7")
	print("AUDIT: native full draw 16m damage=",120-game.bot_health," ink left=",combat.ink_amount)
	game._update_hud();await snap("full-hit")
	bot.global_position=Vector3(70,40,70);bot.visible=false
	walker.global_position=Vector3(-4,.05,-24);target=Vector3(-4,1.1,-8)
	camera.global_position=walker.global_position+Vector3(3,3,-1);camera.look_at(target)
	combat.ink_amount=100;combat.cooldown=0
	input_tick(.4,true)
	pose(target);game._update_hud()
	expect(is_equal_approx(combat.charge_fraction,.5) and game.hud.text.contains("爆裂箭就绪"),"native half draw exposes explosive readiness")
	await snap("half-draw")
	input_tick(.001,false)
	for i in 12:combat.bow.tick(1.0/30)
	expect(combat.bow.planted.size()==3 and is_equal_approx(combat.ink_amount,95),"native half-draw embeds on actual gallery terrain and costs 5")
	game.get_node("InkView").sync_dirty();game._update_hud();await snap("planted")
	for i in 24:combat.bow.tick(1.0/30)
	expect(combat.bow.planted.is_empty(),"native terrain explosions expire")
	game.get_node("InkView").sync_dirty();await snap("exploded")
	root.size=Vector2i(960,540);combat.cooldown=0;combat.ink_amount=100
	input_tick(.4,true)
	pose(target);game._update_hud();await snap("half-small")
	mouse(false);combat.tick(.001,false,false);combat.bow.clear_all()
	game.show_preparation();game._choose_player_weapon("bow")
	for i in 12:await process_frame
	game.frontend.strips.weapon.ensure_control_visible(game.weapon_buttons.bow)
	for i in 12:await process_frame
	DisplayServer.warp_mouse(game.weapon_buttons.bow.get_global_rect().get_center())
	for i in 12:await process_frame
	game.frontend._begin_hover("weapon","bow")
	await create_timer(.25).timeout
	await snap("loadout-small")
	expect(game.frontend.hover_panel.visible and game.frontend.hover_body.text.contains("满蓄 0.8 秒") and game.frontend.hover_body.text.contains("三箭满蓄 108"),"visible native loadout reads current bow tuning")
	await finish("native mouse hold/release, full 16m hit, half-draw actual terrain/fuse, compact readiness and current loadout at two sizes / "+suffix)
