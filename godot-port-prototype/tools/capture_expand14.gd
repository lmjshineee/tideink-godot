extends "res://tools/capture_unified13.gd"
const Catalog:=preload("res://map_catalog.gd")
func save(id:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://render-evidence/expand14-%s.png" % id)
func move(at:Vector2,relative:Vector2=Vector2.ZERO) -> void:
	root.warp_mouse(at)
	await frames(2)
	var e:=InputEventMouseMotion.new();e.position=at;e.global_position=at;e.relative=relative;e.button_mask=mouse_mask;root.push_input(e,true);await frames(2)
func press(at:Vector2,down:bool,button:MouseButton=MOUSE_BUTTON_LEFT) -> void:
	if button==MOUSE_BUTTON_LEFT:mouse_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=button;e.pressed=down;e.button_mask=mouse_mask;root.push_input(e,true);await frames(2)
func fresh() -> void:
	game=(load("res://tidewater_play.tscn") as PackedScene).instantiate();game.settings_path="/private/tmp/inkwave-expand14-ui.cfg";root.add_child(game);current_scene=game;await frames(15);game._layout_hud();game._update_hud();await frames(5);freeze()
func freeze() -> void:
	game.get_node("World/Walker").set_physics_process(false)
func end_strip(strip:ScrollContainer) -> void:
	await move(point(strip))
	for i in range(20):
		await press(point(strip),true,MOUSE_BUTTON_WHEEL_DOWN);await press(point(strip),false,MOUSE_BUTTON_WHEEL_DOWN)
	await frames(4)
func _run() -> void:
	if DisplayServer.get_name()=="headless":printerr("FAIL: native Metal required");quit(1);return
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	Setup.screen="home";Setup.map_id="tidewater";Setup.selected_item="bomb";Setup.selected_perk="balanced";Setup.team_size=5;Setup.random_map=false
	await fresh();await save("home")
	print("AUDIT: PLAY at ",point(game.frontend.play_button)," phase=",game.phase," size=",game.hud_root.size," scale=",game.hud_root.scale)
	await click(game.frontend.play_button)
	if not check(game.phase=="setup","PLAY opens preparation"):return
	var front:Control=game.frontend
	for ch in "稳枪专注":
		if not check((load("res://assets/fonts/NotoSansSC.ttf") as Font).has_char(ch.unicode_at(0)),"native Chinese glyph "+ch):return
	await save("stage-selection")
	for kind in ["weapon","item","perk"]:
		var strip:ScrollContainer=front.strips[kind];var before:int=strip.scroll_horizontal
		var other:int=front.strips.map.scroll_horizontal
		await move(point(strip));await press(point(strip),true,MOUSE_BUTTON_WHEEL_DOWN);await press(point(strip),false,MOUSE_BUTTON_WHEEL_DOWN)
		if not check(strip.scroll_horizontal>before and front.strips.map.scroll_horizontal==other,"wheel scrolls only hovered "+kind):return
		var previous:int=strip.scroll_horizontal
		var pan:=InputEventPanGesture.new();pan.position=point(strip);pan.delta=Vector2(2,0);root.push_input(pan,true);await frames(4)
		if not check(strip.scroll_horizontal>previous,"trackpad pan moves "+kind):return
		await end_strip(strip)
		var max_value:float=strip.get_h_scroll_bar().max_value-strip.get_h_scroll_bar().page
		if not check(absf(strip.scroll_horizontal-max_value)<2 and strip.clip_contents,"last card reached and clipped "+kind):return
		await save("scroll-"+kind)
	print("AUDIT: pre-rapid phase=",game.phase," disabled=",game.weapon_buttons.rapid.disabled," rect=",game.weapon_buttons.rapid.get_global_rect()," strip=",front.strips.weapon.get_global_rect())
	print("AUDIT: hovered=",root.gui_get_hovered_control()," mode=",Input.mouse_mode)
	game.weapon_buttons.rapid.gui_input.connect(func(e):
		if e is InputEventMouseButton:print("AUDIT: rapid gui button=",e.button_index," down=",e.pressed," local=",e.position))
	game.weapon_buttons.rapid.button_down.connect(func():print("AUDIT: rapid down"))
	game.weapon_buttons.rapid.button_up.connect(func():print("AUDIT: rapid up"))
	game.weapon_buttons.rapid.pressed.connect(func():print("AUDIT: rapid pressed"))
	front._end_hover()
	await click(game.weapon_buttons["rapid"]);await move(point(game.weapon_buttons["rapid"]));await frames(8)
	print("AUDIT: rapid selection=",game.selected_weapon," hover=",front.hover_kind,"/",front.hover_id," visible=",front.hover_panel.visible)
	if not check(game.selected_weapon=="rapid" and front.hover_panel.visible and front.hover_body.text.contains("52"),"rapid actual card and details"):return
	await save("rapid-details")
	front.strips.weapon.ensure_control_visible(game.weapon_buttons["dualie"]);await frames(3);await click(game.weapon_buttons["dualie"])
	if not check(front.model.original_weapons.dualie.visible and front.model.original_weapons.dualie_left.visible and not front.model.original_weapons.shooter.visible,"two held source-derived weapons"):return
	await click(front.pose_buttons.shoot);await frames(8);await save("dual-character")
	await click(front.item_buttons.healing);await click(front.perk_buttons.recycler)
	if not check(Setup.selected_item=="healing" and Setup.selected_perk=="recycler","last item and talent selectable"):return
	await move(point(front.perk_buttons.recycler));await frames(8);await save("recycler-details")
	# Keyboard focus must also bring the first/last card into the clipped viewport.
	front.perk_buttons.balanced.grab_focus();await frames(8)
	if not check(front.strips.perk.scroll_horizontal==0,"keyboard focus reveals first card"):return
	front.perk_buttons.recycler.grab_focus();await frames(8)
	print("AUDIT: focus last rect=",front.perk_buttons.recycler.get_global_rect()," strip=",front.strips.perk.get_global_rect()," scroll=",front.strips.perk.scroll_horizontal)
	if not check(front.strips.perk.get_global_rect().grow(1).encloses(front.perk_buttons.recycler.get_global_rect()),"keyboard focus reveals last card"):return
	var bar:HScrollBar=front.strips.perk.get_h_scroll_bar();var bar_at:=bar.get_global_rect().position+Vector2(bar.size.x-30,bar.size.y*.5)
	await move(bar_at);await press(bar_at,true);await move(bar_at-Vector2(300,0),Vector2(-300,0));await press(bar_at-Vector2(300,0),false)
	if not check(front.strips.perk.scroll_horizontal<bar.max_value-bar.page-10,"actual scrollbar thumb drag"):return
	await end_strip(front.strips.map);await click(front.map_buttons.modular_harbor);await frames(8);game=current_scene;freeze();front=game.frontend
	if not check(Setup.map_id=="modular_harbor" and Setup.random_map and game.selected_weapon=="dualie" and Setup.selected_perk=="recycler" and front.stage_preview.asset_id==Catalog.asset_id(),"modular map selection preserves loadout and actual preview"):return
	await save("harbor-selection")
	var seed_before:int=Setup.map_seed;var variant_before:int=Setup.map_variant
	await click(front.map_roll);await frames(8);game=current_scene;freeze();front=game.frontend
	if not check(Setup.map_seed!=seed_before and Setup.map_variant!=variant_before and front.stage_preview.asset_id==Catalog.asset_id(),"change layout switches module composition"):return
	await save("harbor-rerolled")
	await end_strip(front.strips.map);await click(front.map_buttons.terrace_garden);await frames(8);game=current_scene;freeze();front=game.frontend
	if not check(Setup.map_id=="terrace_garden" and front.map_roll.disabled,"layered garden selected"):return
	await save("garden-selection")
	root.size=Vector2i(960,540);root.content_scale_size=root.size;game.settings.ui_scale=1.1;game._layout_hud();game._update_hud();await frames(8)
	await save("small-selection")
	print("AUDIT: small window=",root.size," logical=",game.hud_root.size," perk=",front.strips.perk.get_global_rect())
	for kind in front.strips:
		if not check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(front.strips[kind].get_global_rect()),"small-window scroll strip inside viewport "+kind):return
	await save("small-selection")
	await end_strip(front.strips.weapon);await move(point(game.weapon_buttons.rapid));await frames(8)
	if not check(front.hover_panel.visible and Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(front.hover_panel.get_global_rect()),"small-window detail stays inside viewport"):return
	await save("small-details")
	# Actual run/jump and wheel camera input on the detailed source character.
	await click(front.pose_buttons.run);await frames(12)
	if not check(front.model.gait_weight>0,"source gait preserved"):return
	var zoom:float=front.preview.distance
	await move(point(front.preview));await press(point(front.preview),true,MOUSE_BUTTON_WHEEL_UP);await press(point(front.preview),false,MOUSE_BUTTON_WHEEL_UP)
	if not check(front.preview.distance<zoom,"character zoom independent of strips"):return
	await click(front.preview);await frames(3)
	if not check(front.preview.jump_time>=0,"character preview jump input preserved"):return
	await save("character-close")
	print("PASS: native wheel/pan/bar/focus scrolling, independent clipped rows, last-card selection, source dual wield, live details, modular reroll preserving loadout, layered garden, 960x540 / 110% and animated character")
	quit()
