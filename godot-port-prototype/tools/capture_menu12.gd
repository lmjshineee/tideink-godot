extends SceneTree
const Setup:=preload("res://match_setup.gd")
var game:Node3D
var mouse_mask:MouseButtonMask=0
func _initialize() -> void:call_deferred("_run")
func frames(n:int) -> void:
	for i in n:await process_frame
func save(id:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://render-evidence/menu12-%s.png" % id)
func point(control:Control) -> Vector2:return control.get_global_transform_with_canvas()*(control.size*.5)
func move(at:Vector2,relative:Vector2=Vector2.ZERO) -> void:
	var e:=InputEventMouseMotion.new();e.position=at;e.relative=relative;e.button_mask=mouse_mask;root.push_input(e,true);await frames(2)
func press(at:Vector2,down:bool,button:MouseButton=MOUSE_BUTTON_LEFT) -> void:
	if button==MOUSE_BUTTON_LEFT:mouse_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	var e:=InputEventMouseButton.new();e.position=at;e.button_index=button;e.pressed=down;e.button_mask=mouse_mask;root.push_input(e,true);await frames(2)
func click(control:Control) -> void:
	var at:=point(control);await move(at);await press(at,true);await press(at,false)
func key(code:Key,down:bool) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true);await frames(2)
func check(ok:bool,label:String) -> bool:
	if not ok:printerr("FAIL: ",label);quit(1)
	return ok
func fresh() -> void:
	game=(load("res://tidewater_play.tscn") as PackedScene).instantiate();game.settings_path="/private/tmp/inkwave-menu12-ui.cfg";root.add_child(game);current_scene=game;await frames(5);game.set_physics_process(false);game.get_node("World/Walker").set_physics_process(false)
func _run() -> void:
	if DisplayServer.get_name()=="headless":printerr("FAIL: native Metal required");quit(1);return
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	Setup.screen="home";Setup.map_id="tidewater";Setup.selected_perk="balanced";Setup.loadout_tab="weapon";Setup.selected_item="bomb";Setup.team_size=5;Setup.random_map=false
	await fresh();await save("home-3d")
	var front:Control=game.frontend
	var old_yaw:float=front.preview.yaw;var at:=point(front.preview)
	await move(at);await press(at,true);await move(at+Vector2(130,15),Vector2(130,15));await press(at+Vector2(130,15),false)
	if not check(absf(front.preview.yaw-old_yaw)>1,"actual mouse rotates character in home"):return
	await save("character-rotated")
	await move(point(front.play_button));print("AUDIT: PLAY point=",point(front.play_button)," hovered=",root.gui_get_hovered_control())
	await click(front.play_button);print("AUDIT: after PLAY phase=",game.phase," map enabled=",front.stage_preview.enabled)
	if not check(game.phase=="setup" and front.stage_preview.enabled,"PLAY opens primary map preview"):return
	await frames(5);await save("stage-selection")
	await click(front.pose_buttons["run"]);await frames(12)
	if not check(front.model.anim_speed>1 and front.model.gait_weight>0,"preview runs source character gait"):return
	await click(front.preview)
	if not check(front.preview.jump_time>=0,"click character jumps"):return
	var old_pos:Vector3=front.preview.actor.position
	await key(KEY_W,true);await frames(6);await key(KEY_W,false)
	if not check(Vector2(front.preview.actor.position.x-old_pos.x,front.preview.actor.position.z-old_pos.z).length()>0.05,"W moves only inspection actor"):return
	var zoom:float=front.preview.distance;await press(point(front.preview),true,MOUSE_BUTTON_WHEEL_UP);await press(point(front.preview),false,MOUSE_BUTTON_WHEEL_UP)
	if not check(front.preview.distance<zoom,"wheel zooms character"):return
	await move(point(front.pose_buttons["shoot"]))
	print("AUDIT: shoot button rect=",front.pose_buttons["shoot"].get_global_rect()," point=",point(front.pose_buttons["shoot"])," hovered=",root.gui_get_hovered_control())
	await save("trial-button")
	await click(front.pose_buttons["shoot"]);await frames(8)
	print("AUDIT: trial pose=",front.preview.pose," action=",front.model.action_name," aim=",front.model.aiming)
	if not check(front.model.action_name=="shoot" and front.model.aiming,"preview trial fire animates"):return
	await move(point(game.weapon_buttons["shooter"]));await frames(8)
	if not check(front.hover_panel.visible and front.hover_body.text.contains("伤害 30") and front.hover_body.text.contains("12.5 m"),"real weapon hover shows current damage/range"):return
	await save("weapon-detail")
	await click(front.tab_buttons["item"]);await move(point(front.item_buttons["bomb"]));await frames(8)
	if not check(front.hover_panel.visible and front.hover_body.text.contains("冷却 6") and front.hover_body.text.contains("消耗 70"),"item hover shows cooldown and ink cost"):return
	await save("item-detail");await click(front.item_buttons["shield"])
	await click(front.tab_buttons["perk"]);await move(point(front.perk_buttons["adrenaline"]));await frames(8)
	print("AUDIT: perk hovered=",root.gui_get_hovered_control()," detail=",front.hover_kind,"/",front.hover_id," visible=",front.hover_panel.visible," body=",front.hover_body.text)
	await save("perk-detail")
	if not check(front.hover_panel.visible and front.hover_body.text.contains("50%") and front.hover_body.text.contains("整局"),"perk hover threshold and lock"):return
	await save("perk-detail");await click(front.perk_buttons["adrenaline"])
	await click(front.map_buttons["prism_gallery"]);await frames(6);game=current_scene;game.set_physics_process(false);game.get_node("World/Walker").set_physics_process(false);front=game.frontend
	if not check(front.stage_preview.asset_id=="prism_gallery" and game.get_node("World/Map").MAP_FILE.contains("prism_gallery") and Setup.selected_item=="shield" and Setup.selected_perk=="adrenaline","map click updates actual map/preview while preserving kit"):return
	await move(Vector2(700,80));await save("gallery-selected")
	old_yaw=front.stage_preview.yaw;at=point(front.stage_preview)
	await move(at);await press(at,true);await move(at+Vector2(70,-15),Vector2(70,-15));await press(at+Vector2(70,-15),false)
	if not check(absf(front.stage_preview.yaw-old_yaw)>0.1,"map preview rotates from actual mouse"):return
	await save("gallery-orbit")
	root.size=Vector2i(960,540);root.content_scale_size=root.size;game.settings.ui_scale=1.1;game._layout_hud();game._update_hud();await frames(5)
	for tab in ["weapon","item","perk"]:
		await click(front.tab_buttons[tab]);await move(Vector2(450,80));await frames(3);await save("small-"+tab)
		var visible_controls:Array=[front.random_button,front.start_button,front.back_button,front.settings_button,front.stage_preview,front.preview]
		visible_controls.append_array(front.map_buttons.values())
		visible_controls.append_array(front.item_buttons.values() if tab=="item" else (front.perk_buttons.values() if tab=="perk" else game.weapon_buttons.values()))
		for c in visible_controls:
			if not check(Rect2(Vector2.ZERO,Vector2(960,540)).encloses(c.get_global_rect()),"small visible control bounds "+c.name):return
		if tab=="weapon":
			for card in game.weapon_cards.values():
				print("AUDIT: small card=",card.get_global_rect()," label=",card.get_child(1).get_global_rect())
				if not check(not card.has_node("Stars") and card.get_global_rect().encloses(card.get_child(1).get_global_rect()),"small weapon cards are undivided with centered name"):return
			await move(point(game.weapon_buttons["roller"]));await frames(8);await save("small-weapon-detail")
			if not check(front.hover_panel.visible and front.hover_body.text.contains("★") and Rect2(Vector2.ZERO,Vector2(960,540)).encloses(front.hover_panel.get_global_rect()) and front.hover_panel.get_global_rect().encloses(front.hover_body.get_global_rect()),"small expanded weapon hover fits all stars and text"):return
	await move(point(front.perk_buttons["bulwark"]));await frames(8);await save("small-hover")
	if not check(Rect2(Vector2.ZERO,Vector2(960,540)).encloses(front.hover_panel.get_global_rect()),"small floating details within window"):return
	print("AUDIT: native home/prep character drag/wheel/click/W/run/shoot, weapon/item/perk hover, actual gallery selection/orbit, 960x540/110% all tabs + hover")
	game.queue_free();await frames(3)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;Setup.map_id="tidewater";Setup.screen="setup";Setup.selected_perk="balanced";Setup.selected_item="shield"
	await fresh()
	for actor in game.all_actors():game.perks.choices[actor.get_instance_id()]="balanced"
	game._start_round();game.phase_time=2;game.get_node("World/Walker").set_physics_process(false)
	var walker:Node3D=game.get_node("World/Walker");var bot:Node3D=game.get_node("Bot");walker.global_position=Vector3(-2,0.05,23);bot.global_position=Vector3(2,0.05,21)
	game.items.equip(walker,"shield");game.items.use(walker)
	var camera:=Camera3D.new();game.add_child(camera);camera.position=Vector3(8,7,33);camera.look_at(Vector3(0,1,22));camera.current=true
	game.damage_bot(30,walker,"shooter","躯干",4);game.damage_player(82,false,bot,"blaster","躯干",4)
	game._update_hud();await frames(4);await save("damage-pops")
	var fx:Node3D=game.get_node("Combat").feedback
	if not check(fx.damage_pops.size()==2,"both team damage numbers rendered"):return
	await frames(26)
	if not check(fx.damage_pops.is_empty(),"damage numbers naturally expire"):return
	await save("damage-expired")
	print("PASS: native stage-first menu and isolated interactive characters, bounded true-stat hover, selected-map reload, small UI, actual-HP palette-colored animated damage and expiry")
	game.queue_free();await frames(2);quit()
