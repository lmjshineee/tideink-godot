extends Control
# One click selects and queues a teammate/beacon. Countdown continues in the match.
var game:Node3D
var deployment:Node3D
var panel:Panel
var map:Control
var title:Label
var buttons:Dictionary={}
var refresh_time:=0.0
var keys:Array=[]

func setup(owner_game:Node3D,controller:Node3D) -> void:
	game=owner_game;deployment=controller;mouse_filter=MOUSE_FILTER_IGNORE;visible=false
	panel=Panel.new();panel.mouse_filter=MOUSE_FILTER_STOP;add_child(panel)
	panel.add_theme_stylebox_override("panel",game._ui_style(Color("171221"),preload("res://src/core/team_palette.gd").color(0),2,14))
	title=Label.new();title.mouse_filter=MOUSE_FILTER_IGNORE;title.add_theme_font_size_override("font_size",18);panel.add_child(title)
	map=preload("res://src/ui/turf_minimap.gd").new();panel.add_child(map);map.setup(game);map.mouse_filter=MOUSE_FILTER_STOP;map.gui_input.connect(_map_input)
	var close:=Button.new();close.name="Close";close.text="取消";close.pressed.connect(deployment.cancel_selection);panel.add_child(close)

func _process(delta:float) -> void:
	visible=game.phase=="playing" and deployment.selector_open and not deployment.flying and not game.paused
	if not visible:return
	size=game.hud_root.size;panel.position=Vector2(size.x*.09,size.y*.28);panel.size=Vector2(size.x*.82,size.y*.36)
	var u:=minf(size.x/1280.0,size.y/720.0)
	title.position=Vector2(14,10);title.text="选择复活地点 · 点击一次排队出场" if game.player_respawn>0 else "快速跳跃 · 选择队友、信标或基地"
	title.add_theme_font_size_override("font_size",maxi(12,int(18*u)))
	var close:Button=panel.get_node("Close");close.position=Vector2(panel.size.x-74,9);close.size=Vector2(62,28);close.add_theme_font_size_override("font_size",12)
	map.position=Vector2(12,42);map.size=Vector2(panel.size.x*.28,panel.size.y-54)
	refresh_time-=delta
	if refresh_time<=0:
		refresh_time=.15;_refresh_buttons()
	var index:=0
	for key in keys:
		var button:Button=buttons[key]
		var w:float=(panel.size.x*.66-12)/2;var h:float=minf(36*u,(panel.size.y-54)/5-3)
		button.position=Vector2(panel.size.x*.32+(index%2)*(w+8),42+(index/2)*(h+4));button.size=Vector2(w,h);button.add_theme_font_size_override("font_size",maxi(10,int(14*u)));index+=1

func _refresh_buttons() -> void:
	var choices:Array=deployment.destinations();var next:Array=[]
	for choice in choices:next.append(choice.key)
	if keys!=next:
		for button in buttons.values():button.queue_free()
		buttons.clear();keys=next
		for key in keys:
			var button:=Button.new();button.pressed.connect(deployment.select_destination.bind(key));panel.add_child(button);buttons[key]=button
	for choice in choices:
		var button:Button=buttons[choice.key];button.text=choice.label;button.disabled=not choice.valid
		button.tooltip_text="落点有公开预告，起跳前重新核验" if choice.valid else "队友阵亡、离地或落点无净空；信标须保持己方墨色"

func _map_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var nearest:="";var distance:=22.0
		for choice in deployment.destinations():
			if not choice.valid:continue
			var d:float=(map._project(choice.point)-event.position).length()
			if d<distance:nearest=choice.key;distance=d
		if not nearest.is_empty():deployment.select_destination(nearest)
		map.accept_event()
