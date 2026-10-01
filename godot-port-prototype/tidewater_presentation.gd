extends Control

# Original HUD visual language: ink silhouettes, roster badges, READY?/GO!,
# full-screen death tint, respawn ring and final results. Reads game state only.
const Palette := preload("res://team_palette.gd")
const Visual := preload("res://tidewater_character_visual.gd")
var game: Node3D
var display_phase := ""
var clock := 0.0
var damage_flash := 0.0
var hit_flash := 0.0
var kill_flash := false
var death_by := ""
var death_weapon := ""
var font: Font
var body_font: Font
var portraits: SubViewportContainer
var portrait_view: SubViewport
var models: Array[Node3D] = []
var roster: Array = []
var scene_kind := ""
var cinematic: Node3D
var ability_text := ""
var ability_flash := 0.0
var impact_flash := 0.0

func setup(owner_game: Node3D) -> void:
	game = owner_game
	cinematic = preload("res://tidewater_cinematic.gd").new()
	game.add_child(cinematic)
	cinematic.call("setup",game)
	mouse_filter = MOUSE_FILTER_IGNORE
	font = load("res://assets/fonts/TitanOne-latin.woff2") as Font
	body_font = ThemeDB.fallback_font
	portraits = SubViewportContainer.new()
	portraits.mouse_filter = MOUSE_FILTER_IGNORE
	portraits.stretch = true
	portraits.stretch_shrink = 1
	add_child(portraits)
	portrait_view = SubViewport.new()
	portrait_view.transparent_bg = true
	portrait_view.own_world_3d = true
	portrait_view.msaa_3d = Viewport.MSAA_2X
	portraits.add_child(portrait_view)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cad8ec")
	env.ambient_light_energy = 0.7
	env_node.environment = env
	portrait_view.add_child(env_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 1.3
	portrait_view.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0,1.8,8)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.1
	portrait_view.add_child(camera)
	camera.look_at(Vector3(0,0.8,0))
	camera.current = true
	roster = game.call("all_actors")
	roster.sort_custom(func(a: Node3D,b: Node3D): return int(game.call("actor_id",a)) < int(game.call("actor_id",b)))
	for i in roster.size():
		var model := Node3D.new()
		model.set_script(Visual)
		model.set("team",int(game.call("actor_team",roster[i])))
		model.set("style_index",int(roster[i].get_node("Body").get("style_index")))
		model.set("ornament_seed",int(roster[i].get_node("Body").get("ornament_seed")))
		model.position.x = (i - (roster.size()-1)*0.5)*1.05
		portrait_view.add_child(model)
		models.append(model)

func _process(delta: float) -> void:
	clock += delta
	damage_flash = maxf(0.0,damage_flash-delta*2.5)
	hit_flash = maxf(0.0,hit_flash-delta)
	ability_flash = maxf(0.0,ability_flash-delta)
	impact_flash = maxf(0.0,impact_flash-delta*3)
	if game != null:
		queue_redraw()

func sync() -> void:
	size = (game.get("hud_root") as Control).size
	display_phase = String(game.get("phase"))
	cinematic.call("sync")
	var show_portraits := display_phase == "intro" and float(game.get("phase_time")) < 2.9 or display_phase=="results"
	portraits.visible = show_portraits
	portrait_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show_portraits else SubViewport.UPDATE_DISABLED
	portraits.position = Vector2(size.x*0.06,size.y*0.24)
	portraits.size = Vector2(size.x*0.88,size.y*0.3)
	if display_phase=="results":
		portraits.position.y = size.y*0.18
		portraits.size.y = size.y*0.10
	for model in models:
		model.set_physics_process(show_portraits)
	if show_portraits and scene_kind != display_phase:
		scene_kind = display_phase
		for i in models.size():
			var actor: Node3D = roster[i]
			var weapon: String = game.get("selected_weapon") if actor == game.get_node("World/Walker") else actor.get("weapon_id")
			models[i].call("set_weapon",weapon)
			models[i].call("set_dance",("victory" if int(game.call("actor_team",actor)) == int(game.get("winner")) else "defeat") if display_phase == "results" else "",i % 3)
	queue_redraw()

func notify_damage() -> void:
	damage_flash = 0.8

func notify_ability(text: String, impact: float = 0.0) -> void:
	ability_text = text
	ability_flash = 2.0
	impact_flash = impact

func notify_hit(killed: bool = false) -> void:
	hit_flash = 0.32 if killed else 0.16
	kill_flash = killed

func _text(value: String, center: Vector2, px: int, color: Color = Color.WHITE, display: bool = false) -> void:
	var f := font if display else body_font
	var actual := maxi(12,roundi(px*minf(size.x/1280.0,size.y/720.0)))
	var width := f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,actual).x
	var p := center-Vector2(width*0.5,-actual*0.32)
	draw_string_outline(f,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,actual,6,Color("15121c"))
	draw_string(f,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,actual,color)

func _splat(center: Vector2, radius: float, color: Color, seed: int = 1) -> void:
	var points := PackedVector2Array()
	for i in range(72):
		var angle := TAU * i / 72.0
		var r := radius*(0.79+0.15*sin(angle*9+seed)+0.08*sin(angle*5-seed))
		points.append(center+Vector2(cos(angle),sin(angle))*r)
	draw_colored_polygon(points,color)
	for i in range(8):
		var angle := i*TAU/8.0+seed
		draw_circle(center+Vector2(cos(angle),sin(angle))*radius*1.17,radius*0.045*(1+i%3),color)

func _backdrop(color: Color, opacity: float) -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("15121c")*Color(1,1,1,opacity))
	for i in range(8):
		var x := float(i)*size.x/7.0
		_splat(Vector2(x,0),size.y*(0.22+0.04*sin(i)),Color(color,0.32),i)
		_splat(Vector2(size.x-x,size.y),size.y*(0.18+0.04*sin(i)),Color(color,0.25),i+11)

func _draw() -> void:
	if game == null:
		return
	var team := Palette.color(0)
	var enemy := Palette.color(1)
	var center := size*0.5
	var phase_time: float = game.get("phase_time")
	var dead: float = game.get("player_respawn")
	match display_phase:
		"setup":
			_splat(Vector2(size.x*0.12,size.y*0.07),92,Color(team,0.7),11)
			_text("INKWAVE",Vector2(size.x*0.14,size.y*0.075),38,Color.WHITE,true)
		"intro":
			_backdrop(team,0.46 if phase_time < 2.9 else 0.18)
			if phase_time < 2.9:
				_text("TURF WAR",Vector2(center.x,size.y*0.11),48,Color.WHITE,true)
				_text("涂满地面，为队伍争取更多领地",Vector2(center.x,size.y*0.19),22)
				_text(String(game.get("team_names")[0]),Vector2(size.x*0.25,size.y*0.57),30,team.lightened(0.2))
				_text("VS",Vector2(center.x,size.y*0.57),40,Color.WHITE,true)
				_text(String(game.get("team_names")[1]),Vector2(size.x*0.75,size.y*0.57),30,enemy.lightened(0.3))
				var slots := [0,0]
				for actor in roster:
					var side: int = game.call("actor_team",actor)
					var weapon: String = game.get("selected_weapon") if actor == game.get_node("World/Walker") else actor.get("weapon_id")
					var label: String = game.call("_actor_name",actor)
					_text(label+"  ·  "+String(game.call("_weapon_text",weapon)),Vector2(size.x*(0.25 if side==0 else 0.75),size.y*(0.66+slots[side]*0.047)),18,team if side==0 else enemy.lightened(0.3))
					slots[side] += 1
			else:
				_splat(center, size.y*0.26,team,21)
				_text("READY?",center,116,Color.WHITE,true)
				_text(str(maxi(1,int(ceil(4.2-phase_time)))),center+Vector2(0,size.y*0.18),48,Color.WHITE,true)
		"playing":
			if dead>0.0:
				_text("SQUID SPAWN",Vector2(center.x,size.y*0.10),40,Color.WHITE,true)
				var wait := "跳跃中" if game.deployment.flying else ("出场就绪" if bool(game.get("respawn_ready")) else "%.1f 秒" % dead)
				_text("被击倒 · "+death_by,Vector2(center.x,size.y*0.17),22)
				_text(wait,Vector2(size.x*0.85,size.y*0.12),36,team.lightened(0.4))
				_text(game.call("damage_summary"),Vector2(center.x,size.y*0.225),14)
				var weapon: String = game.get("selected_weapon")
				var item: String = game.get("items").LABELS[preload("res://match_setup.gd").selected_item]
				var perk: String = game.perks.LABELS[game.perks.kind(game.get_node("World/Walker"))]
				draw_style_box(game.call("_ui_style",Color(0.05,0.04,0.1,0.85),team,2,14),Rect2(size.x*0.25,size.y*0.65,size.x*0.5,size.y*0.115))
				_text("当前配装  "+game.call("_weapon_text",weapon)+"  /  "+item,Vector2(center.x,size.y*0.686),22)
				_text("天赋 "+perk+" · 整局锁定",Vector2(center.x,size.y*0.73),17,team.lightened(0.5))
				var queued: bool = game.get("deployment").get("queued")
				_text("点队友 / 信标排队 · J 查看地图 · Esc 回基地 · R 重摇",Vector2(center.x,size.y*0.80),22)
				_text("正在飞向："+game.deployment.selected_label() if game.deployment.flying else ("已准备："+game.deployment.selected_label()+" · 倒计时结束发射" if queued and not bool(game.get("respawn_ready")) else "左键 / 空格 出场 · 可在倒计时期间提前准备"),Vector2(center.x,size.y*0.86),21)
			elif not bool(game.get("paused")):
				if Time.get_ticks_msec()<int(game.get("last_damage_until")):
					_text(game.get("last_damage_text"),Vector2(center.x,size.y*0.75),17,Color("ffb4cb"))
				_draw_roster(team,enemy)
				if bool(game.get("pointer_locked")):
					_draw_reticle(team)
				if phase_time < 0.9:
					_splat(center,size.y*0.22*(1+phase_time*0.25),Color(team,1-phase_time/0.9),21)
					_text("GO!",center,140,Color(1,1,1,1-phase_time/0.9),true)
				if damage_flash > 0:
					for i in range(6):
						_splat(Vector2(i*size.x/5.0,size.y),size.y*0.19,Color(enemy,damage_flash*0.45),i)
				if ability_flash>0.0:
					_text(ability_text,Vector2(center.x,size.y*0.20),27,team.lightened(0.4))
				if impact_flash>0.0:
					draw_arc(center,size.y*(0.25+0.2*(1-impact_flash)),0,TAU,64,Color(team,impact_flash),12,true)
				var seconds := int(ceil(float(game.get("round_left"))))
				if seconds <= int(game.get("final_countdown")):
					_text(str(seconds),Vector2(center.x,size.y*0.25),58,Color("ffe27a"),true)
		"finish":
			_backdrop(team,0.76)
			_splat(center-Vector2(size.y*0.12,0),size.y*0.29,enemy,8)
			_splat(center+Vector2(size.y*0.12,0),size.y*0.29,team,13)
			_text("TIME'S UP!",center,100,Color.WHITE,true)
		"results":
			_backdrop(team if int(game.get("winner"))==0 else enemy,0.96)
			var result_color := team if int(game.get("winner"))==0 else enemy
			_text("VICTORY!" if int(game.get("winner"))==0 else "DEFEAT",Vector2(center.x,size.y*0.14),80,result_color.lightened(0.3),true)

func _pill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	return style

func _draw_roster(team: Color, enemy: Color) -> void:
	var slots := [0,0]
	for actor in roster:
		var side: int = game.call("actor_team",actor)
		var position_x: float = size.x*0.5+(-102.0-slots[side]*45.0 if side==0 else 102.0+slots[side]*45.0)*minf(size.x/1280.0,1)
		var p := Vector2(position_x,39)
		var alive: bool = game.call("actor_alive",actor)
		_splat(p,17,(team if side==0 else enemy) if alive else Color("49424e"),slots[side])
		var weapon: String = game.get("selected_weapon") if actor==game.get_node("World/Walker") else actor.get("weapon_id")
		var icon := load("res://assets/ui/%s.svg" % weapon) as Texture2D
		draw_texture_rect(icon,Rect2(p-Vector2(12,12),Vector2(24,24)),false,Color.WHITE if alive else Color(0.5,0.5,0.5))
		if not alive: _text("X",p,24,Color.WHITE,true)
		_text("%02d" % int(game.call("actor_id",actor)),p+Vector2(0,26),12,Color.WHITE,true)
		_text(String(game.call("actor_name",actor)).left(6),p+Vector2(0,40),10,Color.WHITE,true)
		slots[side] += 1
	var combat := game.get_node("Combat")
	var fraction: float = combat.call("special_fraction")
	var orb := Vector2(size.x-82,86)
	draw_circle(orb,49,Color("15121c"))
	draw_arc(orb,42,-PI*0.5,-PI*0.5+TAU*maxf(0.001,fraction),64,team,9,true)
	_text("%d%%" % int(fraction*100),orb,25,Color.WHITE,true)
	_text("F / Q" if fraction >= 1 else "SPECIAL",orb+Vector2(0,58),15,team.lightened(0.3),true)
	_text("%d p" % int(float(game.get("turf_shown"))),orb+Vector2(0,90),26,Color.WHITE,true)

func _draw_reticle(team: Color) -> void:
	var combat := game.get_node("Combat")
	var center := size*0.5
	var weapon: String = game.get("selected_weapon")
	var radius := 9.0+float(combat.get("bloom"))*8.0
	if weapon == "charger":
		draw_arc(center,21,0,TAU,48,Color(1,1,1,0.28),2,true)
		draw_arc(center,21,-PI*0.5,-PI*0.5+TAU*maxf(0.001,float(combat.get("charge_fraction"))),48,team,4,true)
	elif weapon == "blaster":
		draw_arc(center,16,0,TAU,32,Color.WHITE,2,true)
	for side in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(center+side*radius,center+side*(radius+6),Color("15121c"),5,true)
		draw_line(center+side*radius,center+side*(radius+6),Color.WHITE,2,true)
	draw_circle(center,2,Color.WHITE)
	if hit_flash > 0:
		for x in [-1,1]:
			for y in [-1,1]:
				var v := Vector2(x,y)
				draw_line(center+v*5,center+v*15,team if kill_flash else Color.WHITE,4,true)
	var max_ink: float = combat.get("weapon_data")["player"]["inkMax"]
	var level := clampf(float(combat.get("ink_amount"))/max_ink,0,1)
	draw_style_box(_pill(Color("15121c")),Rect2(center+Vector2(38,-25),Vector2(11,54)))
	draw_style_box(_pill(team if level > 0.2 else Color("ff4266")),Rect2(center+Vector2(40,27-50*level),Vector2(7,50*level)))
