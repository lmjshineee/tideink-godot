extends Control

const Palette := preload("res://team_palette.gd")
const HEADERS := ["玩家","武器","击倒","阵亡","伤害","涂地 m²"]
const WIDTHS := [0.28,0.20,0.10,0.10,0.15,0.17]
const MUTED := Color("9caec5")
const GOLD := Color("ffe28a")

var game: Node3D
var panel: Panel
var map: Control
var hint: Label
var item_label: Label
var coverage_labels: Array[Label] = []
var team_labels: Array[Label] = []
var team_panels: Array[Panel] = []
var header_cells: Array[Label] = []
var row_panels: Array[Panel] = []
var row_cells: Array = []
var roster: Array = []
var last_layout_size := Vector2.ZERO

func setup(owner_game: Node3D) -> void:
	game = owner_game
	mouse_filter = MOUSE_FILTER_IGNORE
	# Standalone map: no outline, opaque letterbox area or live actor clutter.
	map = preload("res://turf_minimap.gd").new()
	map.show_border = false
	map.show_live_marks = false
	add_child(map)
	map.setup(game)
	for team in range(2):
		coverage_labels.append(_label(self,28))
	hint = _label(self,12)
	panel = Panel.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",game._ui_style(Color("111a29"),Color("34445e"),1,16))
	add_child(panel)
	for text in HEADERS:
		var label := _label(panel,12)
		label.text = text
		label.add_theme_color_override("font_color",MUTED)
		header_cells.append(label)
	for team in range(2):
		var team_panel := Panel.new()
		team_panel.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(team_panel)
		team_panels.append(team_panel)
		team_labels.append(_label(team_panel,14))
	roster = game.all_actors()
	roster.sort_custom(func(a,b): return game.actor_id(a)<game.actor_id(b))
	for actor in roster:
		var row := Panel.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(row)
		row_panels.append(row)
		var cells: Array[Label] = []
		for column in range(HEADERS.size()):
			var cell := _label(row,14)
			cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.clip_text = true
			cells.append(cell)
		row_cells.append(cells)
	item_label = _label(self,15)
	item_label.add_theme_color_override("font_outline_color",Color.BLACK)
	item_label.add_theme_constant_override("outline_size",6)

func _label(parent: Node, px: int) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",px)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _columns(cells: Array, width: float, height: float, font_size: int) -> void:
	var x := 10.0
	for column in range(cells.size()):
		var label: Label = cells[column]
		var cell_width: float = (width-20.0)*WIDTHS[column]
		label.add_theme_font_size_override("font_size",font_size)
		label.position = Vector2(x,0)
		label.size = Vector2(cell_width-8,height)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if column<2 else HORIZONTAL_ALIGNMENT_RIGHT
		x += cell_width

func _process(_delta: float) -> void:
	if game == null:
		return
	size = game.hud_root.size
	var results: bool = game.phase == "results"
	var was_visible := panel.visible
	panel.visible = results
	map.visible = results
	hint.visible = results
	for label in coverage_labels:
		label.visible = results
	item_label.visible = game.phase == "playing" and game.player_respawn<=0.0 and not game.paused
	item_label.position = Vector2(16,size.y-192)
	item_label.text = game.items.hud_text()
	if results and (not was_visible or last_layout_size != size):
		_layout_results()
		last_layout_size = size

func _layout_results() -> void:
	var compact := size.y < 600.0
	var font_size := 12 if compact else 16
	var team_height := 22.0 if compact else 28.0
	var header_height := 22.0 if compact else 28.0
	panel.position = Vector2(size.x*0.35,size.y*0.30)
	panel.size = Vector2(size.x*0.60,size.y*0.54)
	map.position = Vector2(size.x*0.045,size.y*0.315)
	map.size = Vector2(size.x*0.285,size.y*0.55)
	for team in range(2):
		var label := coverage_labels[team]
		label.position = Vector2(size.x*(0.065+team*0.145),size.y*0.27)
		label.size = Vector2(size.x*0.145,size.y*0.045)
		label.add_theme_font_size_override("font_size",20 if compact else 28)
		label.add_theme_color_override("font_color",Palette.color(team).lightened(0.35))
		label.text = "%s  %.1f%%" % [game.team_names[team],float(game.judged_coverage[team])*100]
	hint.position = Vector2(size.x*0.065,size.y*0.865)
	hint.size = Vector2(size.x*0.265,20)
	hint.text = "你的涂地  %.0f p" % game.turf_total
	hint.add_theme_color_override("font_color",MUTED)
	var inner_width := panel.size.x-20.0
	var row_height: float = maxf(18.0,(panel.size.y-20.0-header_height-2*team_height)/maxi(1,roster.size()))
	_columns(header_cells,inner_width,header_height,font_size)
	for label in header_cells:
		label.position += Vector2(10,8)
	var maxima := {"kills":0,"turf":0.0}
	for actor in roster:
		var stats: Dictionary = actor.get_meta("match_stats",{})
		maxima.kills = maxi(maxima.kills,int(stats.get("kills",0)))
		maxima.turf = maxf(maxima.turf,float(stats.get("turf",0.0)))
	var y := 8.0+header_height
	var index := 0
	for team in range(2):
		var color := Palette.color(team).lightened(0.18)
		var team_panel := team_panels[team]
		team_panel.position = Vector2(10,y)
		team_panel.size = Vector2(inner_width,team_height)
		team_panel.add_theme_stylebox_override("panel",game._ui_style(Color(color,0.13),Color.TRANSPARENT,0,5))
		var label := team_labels[team]
		label.position = Vector2(10,0)
		label.size = Vector2(inner_width-20,team_height)
		label.add_theme_font_size_override("font_size",12 if compact else 15)
		label.add_theme_color_override("font_color",color.lightened(0.25))
		label.text = game.team_names[team]+("  /  胜利" if game.winner == team else "")
		y += team_height
		for actor in roster:
			if game.actor_team(actor) != team:
				continue
			var row := row_panels[index]
			var cells: Array = row_cells[index]
			var local: bool = actor == game.get_node("World/Walker")
			row.position = Vector2(10,y)
			row.size = Vector2(inner_width,row_height)
			var fill := Color(color,0.18) if local else Color("192335") if index%2==0 else Color("141e2e")
			row.add_theme_stylebox_override("panel",game._ui_style(fill,Color(color,0.65) if local else Color.TRANSPARENT,1 if local else 0,5))
			_columns(cells,inner_width,row_height,font_size)
			var stats: Dictionary = actor.get_meta("match_stats",{})
			var weapon: String = game.selected_weapon if local else actor.weapon_id
			cells[0].text = "%02d  %s%s" % [game.actor_id(actor),game.actor_name(actor)," · 你" if local else ""]
			cells[0].add_theme_color_override("font_color",Color.WHITE if local else Color("d8e2ee"))
			cells[1].text = game._weapon_text(weapon)
			cells[1].add_theme_color_override("font_color",MUTED)
			cells[2].text = str(int(stats.get("kills",0)))
			cells[3].text = str(int(stats.get("deaths",0)))
			cells[3].add_theme_color_override("font_color",MUTED)
			cells[4].text = "%.0f" % float(stats.get("damage",0))
			cells[5].text = "%.0f" % float(stats.get("turf",0))
			cells[2].add_theme_color_override("font_color",GOLD if maxima.kills>0 and int(stats.get("kills",0))==maxima.kills else Color.WHITE)
			cells[5].add_theme_color_override("font_color",GOLD if maxima.turf>0 and is_equal_approx(float(stats.get("turf",0)),maxima.turf) else color.lightened(0.4))
			index += 1
			y += row_height
