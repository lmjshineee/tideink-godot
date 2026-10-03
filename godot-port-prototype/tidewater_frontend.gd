extends Control
# Web-source menu art with a stage-first preparation screen and isolated 3D inspectors.
const Setup:=preload("res://match_setup.gd")
const Palette:=preload("res://team_palette.gd")
const Catalog:=preload("res://map_catalog.gd")
const Perks:=preload("res://tidewater_perks.gd")
const Details:=preload("res://loadout_details.gd")
const Icons:=preload("res://loadout_icons.gd")
var game:Node3D
var home:Control
var preparation:Control
var preview:SubViewportContainer
var view:SubViewport
var model:Node3D
var stage_preview:SubViewportContainer
var heading:Label
var subtitle:Label
var kit:Label
var home_stats:Label
var home_weapon:Button
var profile:Label
var random_button:Button
var play_button:Button
var settings_button:Button
var back_button:Button
var start_button:Button
var item_buttons:Dictionary={}
var perk_buttons:Dictionary={}
var map_buttons:Dictionary={}
var group_labels:Dictionary={}
var pose_buttons:Dictionary={}
var map_choice:OptionButton
var duration_choice:OptionButton
var mode_choice:OptionButton
var perk_choice:OptionButton
var perk_description:Label
var map_roll:Button
var random_map:CheckButton
var reroll:CheckButton
var footer:Label
var stage:Label
var map_blurb:Label
var map_hint:Label
var character_heading:Label
var character_hint:Label
var clock:=0.0
var logo_a:Texture2D
var logo_b:Texture2D
var hover_panel:Panel
var hover_title:Label
var hover_body:Label
var hover_kind:=""
var hover_id:=""
var hover_since:=0.0
var weapon_area:Panel
var item_area:Control
var perk_area:Control
var strips:Dictionary={}
var map_area:Control
var seen_map:=""
var seen_weapon:=""
var seen_item:=""
var seen_perk:=""

func setup(owner_game:Node3D) -> void:
	game=owner_game;mouse_filter=MOUSE_FILTER_IGNORE
	home=Control.new();preparation=Control.new();home.mouse_filter=MOUSE_FILTER_IGNORE;preparation.mouse_filter=MOUSE_FILTER_IGNORE;add_child(home);add_child(preparation)
	logo_a=load("res://assets/ui/logo-a.svg");logo_b=load("res://assets/ui/logo-b.svg")
	heading=_label(self,"INKWAVE",66,true);heading.rotation=-0.045
	heading.add_theme_constant_override("outline_size",8);heading.add_theme_color_override("font_outline_color",Color("15121c"));heading.add_theme_color_override("font_shadow_color",Color.BLACK);heading.add_theme_constant_override("shadow_offset_y",4)
	subtitle=_label(self,"TURF RIOT / 涂地争夺战",16)
	footer=_label(self,"Enter 开战 · Esc 返回",13)
	var nav:=VBoxContainer.new();nav.name="MainNavigation";nav.add_theme_constant_override("separation",14);home.add_child(nav)
	play_button=_button(nav,"PLAY\n开始涂地争夺战",func():game.show_preparation());play_button.custom_minimum_size=Vector2(320,96);play_button.add_theme_font_size_override("font_size",30);play_button.icon=load("res://assets/ui/nav-play.svg");play_button.add_theme_constant_override("icon_max_width",42)
	_button(nav,"LOADOUT 配装",func():game.show_preparation()).icon=load("res://assets/ui/shooter.svg")
	_button(nav,"SETTINGS 设置",func():game._open_settings()).icon=load("res://assets/ui/nav-gear.svg")
	_button(nav,"QUIT 退出",func():game.get_tree().quit())
	profile=_label(home,"",19,true);home_stats=_label(home,"",16);kit=_label(self,"",17);kit.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	home_weapon=_button(home,"",func():game.show_preparation())
	home_weapon.mouse_entered.connect(func():_begin_hover("weapon",game.selected_weapon));home_weapon.mouse_exited.connect(_end_hover)
	home_weapon.focus_entered.connect(func():_begin_hover("weapon",game.selected_weapon));home_weapon.focus_exited.connect(_end_hover)
	preview=preload("res://menu_character_preview.gd").new();add_child(preview);preview.setup(game);view=preview.view;model=preview.model
	stage_preview=preload("res://menu_stage_preview.gd").new();preparation.add_child(stage_preview);stage_preview.setup()
	stage=_label(preparation,"",24,true);map_blurb=_label(preparation,"",13);map_hint=_label(preparation,"拖动查看地形 · 滚轮缩放",12)
	character_heading=_label(preparation,"YOU / #01 "+Setup.player_name,16,true)
	character_hint=_label(self,"拖动旋转 · 滚轮缩放 · 点按跳跃",12)
	for id in ["idle","run","shoot"]:
		pose_buttons[id]=_button(self,{"idle":"待机","run":"跑动","shoot":"试射"}[id],_select_pose.bind(id))
	random_button=_button(self,"RANDOM 随机形象",func():game.randomize_appearance())
	map_area=Control.new();map_area.mouse_filter=MOUSE_FILTER_IGNORE;preparation.add_child(map_area)
	for i in Catalog.IDS.size():
		var id:String=Catalog.IDS[i]
		var button:=_button(map_area,Catalog.NAMES[i],_select_map.bind(i));button.icon=load("res://assets/maps/%s_minimap.png" % id);button.add_theme_constant_override("icon_max_width",30);map_buttons[id]=button
	weapon_area=game.menu_panel;weapon_area.reparent(preparation);weapon_area.get_child(0).visible=false;game.menu_hint.visible=false
	weapon_area.add_theme_stylebox_override("panel",game._ui_style(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
	for id in game.weapon_order:
		_bind_hover(game.weapon_buttons[id],"weapon",id)
	item_area=Control.new();item_area.mouse_filter=MOUSE_FILTER_IGNORE;preparation.add_child(item_area)
	for id in game.items.KINDS:
		var button:=_button(item_area,"%s\nCD %.0fs · %s" % [game.items.LABELS[id],game.items.COOLDOWNS[id],game.items.BLURBS[id]],_select_item.bind(id));item_buttons[id]=button;_bind_hover(button,"item",id)
		button.icon=Icons.icon("item",id)
	perk_area=Control.new();perk_area.mouse_filter=MOUSE_FILTER_IGNORE;preparation.add_child(perk_area)
	for id in Perks.ORDER:
		var button:=_button(perk_area,Perks.LABELS[id],_select_perk.bind(Perks.ORDER.find(id)));perk_buttons[id]=button;_bind_hover(button,"perk",id)
		button.icon=Icons.icon("perk",id)
	for pair in [["weapon","主武器"],["item","道具"],["perk","天赋"]]:
		group_labels[pair[0]]=_label(preparation,pair[1],15)
	for pair in [["map",map_area],["weapon",weapon_area],["item",item_area],["perk",perk_area]]:
		var strip:=preload("res://loadout_strip.gd").new();preparation.add_child(strip);pair[1].reparent(strip);strips[pair[0]]=strip
		strip.get_h_scroll_bar().value_changed.connect(func(_value):_end_hover())
	# Retain the selection adapters for setup injection, without small drop-downs in the UI.
	map_choice=OptionButton.new();map_choice.visible=false;preparation.add_child(map_choice)
	for name in Catalog.NAMES:map_choice.add_item(name)
	map_choice.select(Catalog.IDS.find(Setup.map_id));map_choice.item_selected.connect(_select_map)
	perk_choice=OptionButton.new();perk_choice.visible=false;preparation.add_child(perk_choice)
	for id in Perks.ORDER:perk_choice.add_item(Perks.LABELS[id])
	perk_choice.select(Perks.ORDER.find(Setup.selected_perk));perk_choice.item_selected.connect(_select_perk)
	perk_description=_label(preparation,"",13);perk_description.visible=false
	duration_choice=OptionButton.new();preparation.add_child(duration_choice)
	for duration in game.get_node("Combat").weapon_data["match"]["durations"]:duration_choice.add_item("%d 秒" % int(duration))
	duration_choice.select(Setup.duration_index);duration_choice.item_selected.connect(func(i):game._change_duration(i))
	mode_choice=OptionButton.new();mode_choice.add_item("5 对 5");mode_choice.add_item("1 对 1");preparation.add_child(mode_choice);mode_choice.select(0 if Setup.team_size==5 else 1);mode_choice.item_selected.connect(_select_mode)
	random_map=CheckButton.new();random_map.text="地图随机布置";preparation.add_child(random_map);random_map.disabled=not Catalog.supports_random(Setup.map_id);random_map.set_pressed_no_signal(Setup.random_map);random_map.toggled.connect(_toggle_random_map)
	map_roll=_button(preparation,"换图",func():Catalog.reroll();_reload_preparation())
	reroll=CheckButton.new();reroll.text="机器人复活重摇装备";preparation.add_child(reroll);reroll.set_pressed_no_signal(Setup.reroll_bots);reroll.toggled.connect(func(value):Setup.reroll_bots=value)
	back_button=_button(preparation,"返回",func():game.show_home());settings_button=_button(preparation,"设置",func():game._open_settings());start_button=_button(preparation,"LET'S GO! 开战",func():game._begin_intro())
	_build_hover();sync()

func _label(parent:Node,text:String,px:int,display:bool=false) -> Label:
	var label:=Label.new();label.text=text;label.mouse_filter=MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",px);label.add_theme_color_override("font_color",Color("f5f0fb"))
	label.add_theme_font_override("font",preload("res://ui_fonts.gd").font(display))
	parent.add_child(label);return label

func _button(parent:Node,text:String,action:Callable) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2.ZERO;button.add_theme_font_size_override("font_size",20);button.add_theme_font_override("font",preload("res://ui_fonts.gd").font(true));button.add_theme_color_override("font_color",Color.WHITE)
	button.add_theme_stylebox_override("normal",game._ui_style(Color("241c32"),Color("4a405b"),2,12));button.add_theme_stylebox_override("hover",game._ui_style(Palette.color(0).darkened(0.55),Color.WHITE,2,12));button.add_theme_stylebox_override("focus",game._ui_style(Color.TRANSPARENT,Palette.color(0),3,12));button.add_theme_stylebox_override("pressed",game._ui_style(Palette.color(0).darkened(0.7),Color.WHITE,2,12));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",26);button.pressed.connect(action);parent.add_child(button);return button

func _bind_hover(control:Control,kind:String,id:String) -> void:
	control.tooltip_text="";control.mouse_entered.connect(_begin_hover.bind(kind,id));control.mouse_exited.connect(_end_hover);control.focus_entered.connect(_begin_hover.bind(kind,id));control.focus_exited.connect(_end_hover)

func _build_hover() -> void:
	hover_panel=Panel.new();hover_panel.mouse_filter=MOUSE_FILTER_IGNORE;hover_panel.z_index=100;add_child(hover_panel);hover_panel.visible=false
	hover_panel.add_theme_stylebox_override("panel",game._ui_style(Color("171221"),Palette.color(0),2,14))
	hover_title=_label(hover_panel,"",18,true);hover_body=_label(hover_panel,"",14);hover_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hover_body.add_theme_constant_override("line_spacing",1)

func _begin_hover(kind:String,id:String) -> void:
	hover_kind=kind;hover_id=id;hover_since=clock;_refresh_hover()
func _end_hover() -> void:
	hover_kind="";hover_panel.visible=false
func _refresh_hover() -> void:
	if hover_kind.is_empty():return
	var info:Dictionary=Details.weapon(game,hover_id) if hover_kind=="weapon" else (Details.item(game,hover_id) if hover_kind=="item" else Details.perk(hover_id))
	hover_title.text=info.title;hover_body.text=info.body
func _layout_hover() -> void:
	if hover_kind.is_empty() or not visible:hover_panel.visible=false;return
	hover_panel.visible=clock-hover_since>=0.15
	var u:=clampf(minf(size.x/1280.0,size.y/720.0),0.60,1.4)
	var width:=minf(410,size.x*0.62)
	hover_title.position=Vector2(16,12);hover_title.size=Vector2(width-32,28);hover_title.add_theme_font_size_override("font_size",17)
	hover_body.add_theme_font_size_override("font_size",maxi(11,int(14*u)))
	hover_body.position=Vector2(16,48);hover_body.size=Vector2(width-32,1)
	hover_panel.size=Vector2(width,minf(size.y-24,hover_body.get_minimum_size().y+64))
	var point:=get_local_mouse_position()+Vector2(18,18)
	if point.y+hover_panel.size.y>size.y-12:point.y=get_local_mouse_position().y-hover_panel.size.y-18
	hover_panel.position=Vector2(clampf(point.x,12,size.x-width-12),clampf(point.y,12,size.y-hover_panel.size.y-12))

func _select_pose(id:String) -> void:
	preview.set_pose(id);sync()
func _select_item(id:String) -> void:
	Setup.selected_item=id;game.items.equip(game.get_node("World/Walker"),id);sync()
func _select_perk(index:int) -> void:
	if game.perks.select_player(Perks.ORDER[index]):perk_choice.select(index);sync()
func _select_map(index:int) -> void:
	if Setup.map_id==Catalog.IDS[index]:return
	Setup.map_id=Catalog.IDS[index];Setup.random_map=Setup.random_map or Setup.map_id=="modular_harbor";Catalog.roll();_reload_preparation()
func _select_mode(index:int) -> void:
	Setup.team_size=5 if index==0 else 1;_reload_preparation()
func _toggle_random_map(enabled:bool) -> void:
	Setup.random_map=enabled;Catalog.roll();_reload_preparation()
func _reload_preparation() -> void:
	Setup.screen="setup";Setup.pending_loadout={"player":game.selected_weapon,"settings_path":game.settings_path};game.get_tree().reload_current_scene()

func _place(control:Control,at:Vector2,extent:Vector2,px:int=14) -> void:
	control.add_theme_font_size_override("font_size",px);control.position=at;control.size=extent
func _selected(button:Button,selected:bool) -> void:
	button.add_theme_stylebox_override("normal",game._ui_style(Palette.color(0).darkened(0.65) if selected else Color("241c32"),Palette.color(0) if selected else Color("4a405b"),3 if selected else 1,12))

func sync() -> void:
	if not game.is_inside_tree():return
	var screen:String=game.phase
	game.get_viewport().disable_3d=screen in ["home","setup"]
	visible=screen in ["home","setup"] and not game.settings_panel.visible
	home.visible=screen=="home";preparation.visible=screen=="setup"
	preview.visible=visible;preview.set_enabled(visible);stage_preview.set_enabled(visible and preparation.visible)
	if not visible:_end_hover();return
	size=game.hud_root.size;home.size=size;preparation.size=size
	var u:=clampf(minf(size.x/1280.0,size.y/720.0),0.60,1.4)
	var preparing:=screen=="setup"
	_place(heading,Vector2(size.x*.04,size.y*.03),Vector2(330*u,70*u),int((42 if preparing else 64)*u))
	_place(subtitle,Vector2(size.x*.045,size.y*(.115 if preparing else .145)),Vector2(380*u,28*u),maxi(12,int(15*u)))
	subtitle.text="STAGE SELECT / 战场与配装" if preparing else "TURF RIOT / 涂地争夺战"
	footer.visible=preparing;_place(footer,Vector2(size.x*.32,size.y*.943),Vector2(size.x*.39,30*u),maxi(10,int(13*u)))
	footer.text="滚轮 / 双指滑动选择 · 悬停详情 · Enter 开战"
	play_button.add_theme_stylebox_override("normal",game._ui_style(Palette.color(0),Palette.color(0).lightened(.25),2,14));play_button.add_theme_color_override("font_color",Color("15121c"))
	var nav:Control=home.get_node("MainNavigation");nav.position=Vector2(size.x*.05,size.y*.33);nav.scale=Vector2.ONE*u
	for i in nav.get_child_count():
		var button:Button=nav.get_child(i);button.custom_minimum_size.x=320;button.pivot_offset=button.size*.5;button.rotation=deg_to_rad([-2.2,1.4,-1.1,1.6][i])
	character_heading.visible=preparing
	character_hint.visible=visible
	preview.position=Vector2(size.x*(.742 if preparing else .36),size.y*(.207 if preparing else .21));preview.size=Vector2(size.x*(.226 if preparing else .31),size.y*(.37 if preparing else .65))
	_place(character_hint,Vector2(size.x*(.75 if preparing else .36),size.y*(.585 if preparing else .865)),Vector2(size.x*.28,24*u),maxi(10,int(12*u)))
	character_hint.text="拖动旋转 · 滚轮缩放 · 点按跳跃"
	for i in pose_buttons.size():
		var button:Button=pose_buttons[["idle","run","shoot"][i]];button.visible=preparing
		_place(button,Vector2(size.x*.747+i*size.x*.075,size.y*.617),Vector2(size.x*.068,28*u),maxi(11,int(13*u)));_selected(button,preview.pose==["idle","run","shoot"][i])
	_place(random_button,Vector2(size.x*(.74 if preparing else .37),size.y*(.664 if preparing else .91)),Vector2(size.x*(.23 if preparing else .28),40*u),maxi(12,int(17*u)))
	_place(profile,Vector2(size.x*.715,size.y*.19),Vector2(size.x*.245,size.y*.19),int(20*u));profile.text="#01 "+Setup.player_name+"\nTURF WAR · "+("5 v 5" if Setup.team_size==5 else "1 v 1")
	_place(kit,Vector2(size.x*(.37 if preparing else .715),size.y*(.058 if preparing else .435)),Vector2(size.x*(.60 if preparing else .235),size.y*.13),maxi(12,int(16*u)))
	kit.text=("当前配装  " if preparing else "CURRENT LOADOUT\n")+game._weapon_text(game.selected_weapon)+" / "+game.items.LABELS[Setup.selected_item]+"\n天赋 "+Perks.LABELS[Setup.selected_perk]+(" · 整局锁定" if preparing else "")
	_place(home_stats,Vector2(size.x*.715,size.y*.595),Vector2(size.x*.24,30*u),int(14*u));home_stats.text="悬停查看星级与数值 · 点击进入配装"
	_place(home_weapon,Vector2(size.x*.715,size.y*.65),Vector2(size.x*.23,62*u),int(19*u));home_weapon.text=game._weapon_text(game.selected_weapon);home_weapon.icon=load("res://assets/ui/%s.svg" % game.selected_weapon)
	preview.set_weapon(game.selected_weapon)
	if preparing:_layout_preparation(u)
	_refresh_hover();_layout_hover();queue_redraw()

func _layout_preparation(u:float) -> void:
	_place(stage,Vector2(size.x*.047,size.y*.185),Vector2(size.x*.35,36*u),maxi(16,int(25*u)));stage.text=Catalog.title()
	_place(map_blurb,Vector2(size.x*.047,size.y*.235),Vector2(size.x*.60,28*u),maxi(11,int(13*u)));map_blurb.text=Catalog.BLURBS[Catalog.IDS.find(Setup.map_id)]+" · "+Catalog.layout_name()
	stage_preview.position=Vector2(size.x*.037,size.y*.267);stage_preview.size=Vector2(size.x*.666,size.y*.239)
	_place(map_hint,Vector2(size.x*.047,size.y*.508),Vector2(size.x*.60,24*u),maxi(10,int(12*u)))
	_place(character_heading,Vector2(size.x*.752,size.y*.178),Vector2(size.x*.21,30*u),maxi(12,int(16*u)))
	strips.map.position=Vector2(size.x*.03,size.y*.55);strips.map.size=Vector2(size.x*.68,46*u)
	var map_width:float=160*u
	map_area.custom_minimum_size=Vector2(Catalog.IDS.size()*(map_width+6*u),36*u)
	for i in Catalog.IDS.size():
		var id:String=Catalog.IDS[i];var button:Button=map_buttons[id]
		_place(button,Vector2(i*(map_width+6*u),0),Vector2(map_width,36*u),maxi(11,int(14*u)));_selected(button,id==Setup.map_id)
	if seen_map!=Setup.map_id:
		seen_map=Setup.map_id;strips.map.call_deferred("ensure_control_visible",map_buttons[seen_map])
	var row_width:float=size.x*.58
	for pair in [["weapon",.627],["item",.714],["perk",.802]]:
		var key:String=pair[0];var strip:ScrollContainer=strips[key]
		strip.position=Vector2(size.x*.13,size.y*pair[1])
		_place(group_labels[key],Vector2(size.x*.033,size.y*pair[1]+3*u),Vector2(size.x*.088,45*u),maxi(11,int(14*u)))
	group_labels.weapon.text="主武器\n%d · 滚动" % game.weapon_order.size()
	group_labels.item.text="道具\n%d · 滚动" % item_buttons.size()
	group_labels.perk.text="天赋\n%d · 滚动" % Perks.ORDER.size()
	var width:float=178*u
	weapon_area.custom_minimum_size=Vector2(game.weapon_order.size()*(width+8*u),46*u);weapon_area.visible=true
	item_area.custom_minimum_size=Vector2(item_buttons.size()*(width+8*u),46*u);item_area.visible=true
	perk_area.custom_minimum_size=Vector2(Perks.ORDER.size()*(width+8*u),46*u);perk_area.visible=true
	for i in game.weapon_order.size():
		var card:Panel=game.weapon_cards[game.weapon_order[i]]
		card.position=Vector2(i*(width+8*u),0);card.size=Vector2(width,46*u)
		var icon:TextureRect=card.get_child(0);icon.position=Vector2(8,9)*u;icon.size=Vector2(28,28)*u
		var label:Label=card.get_child(1);_place(label,Vector2(40*u,9*u),Vector2(width-46*u,28*u),maxi(11,int(15*u)))
	for i in item_buttons.size():
		var id:String=game.items.KINDS[i]
		item_buttons[id].text="%s\n冷却 %.0fs" % [game.items.LABELS[id],game.perks.item_cooldown(game.get_node("World/Walker"),game.items.COOLDOWNS[id])]
		item_buttons[id].add_theme_constant_override("icon_max_width",maxi(18,int(26*u)))
		_place(item_buttons[id],Vector2(i*(width+8*u),0),Vector2(width,46*u),maxi(11,int(14*u)));_selected(item_buttons[id],Setup.selected_item==id)
	for i in Perks.ORDER.size():
		var id:String=Perks.ORDER[i]
		perk_buttons[id].add_theme_constant_override("icon_max_width",maxi(18,int(26*u)))
		_place(perk_buttons[id],Vector2(i*(width+8*u),0),Vector2(width,46*u),maxi(11,int(15*u)));_selected(perk_buttons[id],Setup.selected_perk==id)
	# Set content minimums before the container extent; otherwise resize clamps
	# to the previous row height and leaves stale overlap in smaller windows.
	for key in ["weapon","item","perk"]:strips[key].size=Vector2(row_width,58*u)
	if seen_weapon!=game.selected_weapon:
		seen_weapon=game.selected_weapon;strips.weapon.call_deferred("ensure_control_visible",game.weapon_buttons[seen_weapon])
	if seen_item!=Setup.selected_item:
		seen_item=Setup.selected_item
		if item_buttons.has(seen_item): strips.item.call_deferred("ensure_control_visible",item_buttons[seen_item])
	if seen_perk!=Setup.selected_perk:
		seen_perk=Setup.selected_perk
		if perk_buttons.has(seen_perk): strips.perk.call_deferred("ensure_control_visible",perk_buttons[seen_perk])
	_place(duration_choice,Vector2(size.x*.75,size.y*.741),Vector2(size.x*.09,30*u),maxi(11,int(14*u)))
	_place(mode_choice,Vector2(size.x*.857,size.y*.741),Vector2(size.x*.10,30*u),maxi(11,int(14*u)))
	_place(random_map,Vector2(size.x*.746,size.y*.805),Vector2(size.x*.165,28*u),maxi(11,int(13*u)))
	map_roll.disabled=not Setup.random_map or not Catalog.supports_random(Setup.map_id)
	_place(map_roll,Vector2(size.x*.92,size.y*.803),Vector2(size.x*.052,30*u),maxi(11,int(13*u)))
	_place(reroll,Vector2(size.x*.746,size.y*.862),Vector2(size.x*.225,28*u),maxi(10,int(12*u)))
	_place(back_button,Vector2(size.x*.03,size.y*.932),Vector2(96*u,40*u),maxi(12,int(17*u)))
	_place(settings_button,Vector2(size.x*.115,size.y*.932),Vector2(96*u,40*u),maxi(12,int(17*u)))
	_place(start_button,Vector2(size.x*.74,size.y*.932),Vector2(size.x*.23,40*u),maxi(13,int(18*u)))
	start_button.add_theme_stylebox_override("normal",game._ui_style(Palette.color(0),Palette.color(0).lightened(.25),2,14));start_button.add_theme_color_override("font_color",Color("15121c"))

func _process(delta:float) -> void:
	if not visible:return
	clock+=delta
	# Scrolling may clear the old hover without a new mouse_entered event. Resolve
	# the actual clipped control again so a stationary pointer regains its detail.
	if hover_kind.is_empty():
		var hovered:=get_viewport().gui_get_hovered_control()
		for pair in [["weapon",game.weapon_buttons],["item",item_buttons],["perk",perk_buttons]]:
			for id in pair[1]:
				if hovered==pair[1][id]:_begin_hover(pair[0],id)
	_layout_hover()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("100c1b"))
	for i in range(25):
		var x:float=float(i)*size.x/15-size.y*.4;draw_line(Vector2(x,0),Vector2(x+size.y*.45,size.y),Color(.16,.12,.23,.28),18)
	var preparing:bool=game.phase=="setup"
	var logo:=Rect2(size.x*.005,-size.y*.03,size.x*(.29 if preparing else .43),size.y*(.18 if preparing else .25))
	draw_texture_rect(logo_b,logo,false,Palette.color(1));draw_texture_rect(logo_a,logo,false,Palette.color(0))
	if preparing:
		draw_style_box(game._ui_style(Color("211b30"),Palette.color(0).darkened(.3),2,18),Rect2(size.x*.03,size.y*.167,size.x*.68,size.y*.371))
		draw_style_box(game._ui_style(Color("211b30"),Color("4a405b"),2,18),Rect2(size.x*.74,size.y*.167,size.x*.23,size.y*.482))
		draw_style_box(game._ui_style(Color("211b30"),Color("4a405b"),1,14),Rect2(size.x*.74,size.y*.73,size.x*.23,size.y*.169))
	else:
		var blob:=Rect2(size.x*.335,size.y*.32,size.x*.36,size.y*.43);draw_texture_rect(logo_b,blob,false,Color(Palette.color(1),.65));draw_texture_rect(logo_a,Rect2(blob.position+Vector2(0,22),blob.size),false,Color(Palette.color(0),.45))
		draw_style_box(game._ui_style(Color("241c32"),Color("4a405b"),2,18),Rect2(size.x*.69,size.y*.155,size.x*.28,size.y*.22))
		draw_style_box(game._ui_style(Color("241c32"),Palette.color(0).darkened(.35),2,18),Rect2(size.x*.69,size.y*.40,size.x*.28,size.y*.41))
