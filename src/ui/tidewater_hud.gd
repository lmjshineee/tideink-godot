extends RefCounted

# Builds, lays out and refreshes UI. Gameplay and score state remain on the match.
const SettingsPanel := preload("res://src/ui/tidewater_settings_panel.gd")
var game: Node3D

func _init(owner_game: Node3D) -> void:
	game = owner_game


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	game.add_child(canvas)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud_root = layer
	canvas.add_child(layer)
	game.score_panel = _hud_panel(layer, "ScorePanel")
	game.orange_score = _hud_label(game.score_panel, "OrangeScore", game.orange_color, 18)
	game.blue_score = _hud_label(game.score_panel, "BlueScore", game.blue_color.lightened(0.45), 18)
	game.timer_label = _hud_label(game.score_panel, "Timer", Color.WHITE, 34)
	game.timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var number_font := load("res://assets/fonts/TitanOne-latin.woff2") as Font
	game.timer_label.add_theme_font_override("font", number_font)
	game.timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.timer_label.add_theme_constant_override("outline_size", 3)
	game.timer_label.add_theme_color_override("font_outline_color", Color("15121c"))
	game.score_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	game.orange_bar = _hud_bar(game.score_panel, "OrangeTurf", game.orange_color)
	game.blue_bar = _hud_bar(game.score_panel, "BlueTurf", game.blue_color)
	game.vitals_panel = _hud_panel(layer, "VitalsPanel")
	game.ink_label = _hud_label(game.vitals_panel, "InkLabel", Color.WHITE, 17)
	game.health_label = _hud_label(game.vitals_panel, "HealthLabel", Color.WHITE, 17)
	game.ink_bar = _hud_bar(game.vitals_panel, "InkBar", game.orange_color)
	game.health_bar = _hud_bar(game.vitals_panel, "HealthBar", Color("fc4266"))
	game.vitals_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Values remain available to state/debug readers; presentation draws the floating HUD.
	for control in [game.ink_label, game.health_label, game.ink_bar, game.health_bar]:
		control.visible = false
	game.special_panel = _hud_panel(layer, "SpecialPanel")
	game.special_label = _hud_label(game.special_panel, "SpecialLabel", Color.WHITE, 18)
	game.turf_label = _hud_label(game.special_panel, "TurfLabel", game.orange_color.lightened(0.35), 16)
	game.turf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.special_bar = _hud_bar(game.special_panel, "SpecialBar", game.orange_color.lightened(0.35))
	game.result_panel = _hud_panel(layer, "ResultPanel")
	game.result_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	game.result_label = _hud_label(game.result_panel, "ResultLabel", Color.WHITE, 28)
	game.result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.status_panel = _hud_panel(layer, "StatusPanel")
	game.status_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	game.hud = Label.new()
	game.hud.name = "StatusLine"
	game.hud.add_theme_font_size_override("font_size", 10)
	game.hud.add_theme_color_override("font_color", Color.WHITE)
	game.hud.add_theme_color_override("font_outline_color", Color("15121c"))
	game.hud.add_theme_constant_override("outline_size", 2)
	game.hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.status_panel.add_child(game.hud)
	game.weapon_icon = TextureRect.new()
	game.weapon_icon.position = Vector2(1110.0, 20.0)
	game.weapon_icon.size = Vector2(96.0, 96.0)
	game.weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game.weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game.weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(game.weapon_icon)
	game.crosshair_layer = CenterContainer.new()
	game.crosshair_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(game.crosshair_layer)
	game.crosshair = Label.new()
	game.crosshair.text = ""
	game.crosshair.add_theme_font_size_override("font_size", 30)
	game.crosshair.add_theme_color_override("font_shadow_color", Color.BLACK)
	game.crosshair_layer.add_child(game.crosshair)
	_build_weapon_menu(layer)
	_build_team_ui(layer)
	_build_settings_ui(layer)
	game.presentation = preload("res://src/ui/tidewater_presentation.gd").new()
	layer.add_child(game.presentation)
	game.presentation.call("setup",game)
	game.tactics = preload("res://src/ui/tidewater_tactics.gd").new()
	layer.add_child(game.tactics)
	game.tactics.call("setup",game)
	game.frontend = preload("res://src/ui/tidewater_frontend.gd").new()
	layer.add_child(game.frontend)
	game.frontend.call("setup",game)
	game.deployment.setup_ui()
	# Interactive controls stay above the full-screen presentation.
	for control in [game.scoreboard_panel,game.result_panel,game.settings_panel]:
		layer.move_child(control,-1)
	# Connect through the owning Node so scene reload/free disconnects the signal.
	game.get_viewport().size_changed.connect(game._layout_hud)
	_layout_hud()


func _hud_panel(parent: Node, name_text: String) -> Panel:
	var panel := Panel.new()
	panel.name = name_text
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _ui_style(game.UI_PANEL, Color(1.0, 1.0, 1.0, 0.22), 2, 16))
	parent.add_child(panel)
	return panel


func _hud_label(parent: Control, name_text: String, color: Color, size_px: int) -> Label:
	var label := Label.new()
	label.name = name_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _hud_bar(parent: Control, name_text: String, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = name_text
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.add_theme_stylebox_override("background", _ui_style(Color(0.18, 0.2, 0.27, 0.9), Color.TRANSPARENT, 0, 6))
	bar.add_theme_stylebox_override("fill", _ui_style(fill, Color.TRANSPARENT, 0, 6))
	parent.add_child(bar)
	return bar


static func _ui_style(background: Color, outline: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = outline
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _build_weapon_menu(layer: Node) -> void:
	game.menu_panel = Panel.new()
	game.menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.menu_panel.add_theme_stylebox_override("panel", _ui_style(game.UI_PANEL, Color(1.0, 1.0, 1.0, 0.22), 3, 22))
	layer.add_child(game.menu_panel)
	var title := Label.new()
	title.text = "INKWAVE"
	title.position = Vector2(0.0, 17.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/fonts/TitanOne-latin.woff2") as Font)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", game.orange_color)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.menu_panel.add_child(title)
	game.menu_hint = Label.new()
	game.menu_hint.position = Vector2(0.0, 83.0)
	game.menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.menu_hint.add_theme_font_size_override("font_size", 18)
	game.menu_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.menu_panel.add_child(game.menu_hint)
	for index in game.weapon_order.size():
		var weapon_id: String = game.weapon_order[index]
		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.menu_panel.add_child(card)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load("res://assets/ui/%s.svg" % weapon_id) as Texture2D
		icon.size = Vector2(60.0, 60.0)
		icon.position.y = 9.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var name_label := Label.new()
		name_label.text = "%d  %s" % [index + 1, game._weapon_text(weapon_id)]
		name_label.position.y = 74.0
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_label)
		game.weapon_cards[weapon_id] = card
		var button := Button.new()
		button.name = "SelectWeapon"
		button.flat = true
		button.tooltip_text = game._weapon_text(weapon_id)
		card.add_child(button)
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.pressed.connect(game._choose_player_weapon.bind(weapon_id))
		game.weapon_buttons[weapon_id] = button


func _refresh_weapon_cards() -> void:
	for weapon_id in game.weapon_order:
		var card: Panel = game.weapon_cards[weapon_id]
		var selected: bool = weapon_id == game.selected_weapon
		card.add_theme_stylebox_override("panel", _ui_style(
			Color(0.18, 0.11, 0.07, 0.98) if selected else Color(0.07, 0.09, 0.14, 0.96),
			game.orange_color if selected else Color(1.0, 1.0, 1.0, 0.2), 3 if selected else 1, 14))


func _layout_hud() -> void:
	var size := game.get_viewport().get_visible_rect().size / float(game.settings.get("ui_scale"))
	game.hud_root.scale = Vector2.ONE * float(game.settings.get("ui_scale"))
	game.hud_root.size = size
	var score_width := minf(400.0, size.x - 24.0)
	game.score_panel.position = Vector2((size.x - score_width) * 0.5, 12.0)
	game.score_panel.size = Vector2(score_width, 86.0)
	game.orange_score.position = Vector2(16.0, 10.0)
	game.orange_score.size = Vector2(140.0, 38.0)
	game.blue_score.position = Vector2(score_width - 156.0, 10.0)
	game.blue_score.size = Vector2(140.0, 38.0)
	game.blue_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	game.timer_label.position = Vector2((score_width - 90.0) * 0.5, 2.0)
	game.timer_label.size = Vector2(90.0, 49.0)
	game.orange_bar.position = Vector2(16.0, 62.0)
	game.orange_bar.size = Vector2((score_width - 42.0) * 0.5, 12.0)
	game.blue_bar.position = Vector2((score_width + 10.0) * 0.5, 62.0)
	game.blue_bar.size = game.orange_bar.size
	game.vitals_panel.position = Vector2(16.0, maxf(104.0, size.y - 162.0))
	game.vitals_panel.size = Vector2(275.0, 112.0)
	game.ink_label.position = Vector2(16.0, 8.0)
	game.ink_label.size = Vector2(240.0, 27.0)
	game.ink_bar.position = Vector2(16.0, 36.0)
	game.ink_bar.size = Vector2(243.0, 13.0)
	game.health_label.position = Vector2(16.0, 55.0)
	game.health_label.size = Vector2(240.0, 27.0)
	game.health_bar.position = Vector2(16.0, 83.0)
	game.health_bar.size = Vector2(243.0, 13.0)
	game.special_panel.position = Vector2(maxf(16.0, size.x - 226.0), 124.0)
	game.special_panel.size = Vector2(210.0, 108.0)
	game.turf_label.position = Vector2(0.0, 78.0)
	game.turf_label.size = Vector2(210.0, 24.0)
	game.special_label.position = Vector2(13.0, 7.0)
	game.special_label.size = Vector2(184.0, 35.0)
	game.special_bar.position = Vector2(13.0, 53.0)
	game.special_bar.size = Vector2(184.0, 15.0)
	var result_width := minf(520.0, size.x - 24.0)
	game.result_panel.size = Vector2(result_width, 230.0)
	game.result_panel.position = (size - game.result_panel.size) * 0.5
	game.result_label.position = Vector2(12.0, 19.0)
	game.result_label.size = Vector2(result_width - 24.0, 140.0)
	game.status_panel.position = Vector2(16.0, maxf(277.0, size.y - 43.0))
	game.status_panel.size = Vector2(size.x - 32.0, 31.0)
	game.hud.position = Vector2(10.0, 4.0)
	game.hud.size = Vector2(game.status_panel.size.x - 20.0, 24.0)
	game.crosshair_layer.position = Vector2.ZERO
	game.crosshair_layer.size = size
	game.weapon_icon.position = Vector2(maxf(18.0, size.x - 114.0), 20.0)
	_layout_team_ui(size)
	var layout := compact_hud_layout()
	game.score_panel.size = layout.timer.size
	game.score_panel.position = layout.timer.position
	game.timer_label.position = Vector2(0,0)
	game.timer_label.add_theme_font_size_override("font_size", 32 if game.hud_root.size.x >= 1100 else 30)
	game.timer_label.size = game.score_panel.size
	# Result buttons have their own responsive position inside the existing panel.
	game.result_panel.position.y = game.hud_root.size.y*0.67
	game.result_panel.size.y = game.hud_root.size.y*0.28
	game.result_actions.position.y = game.result_panel.size.y-48
	if game.frontend!=null:game.frontend.sync()


func _update_hud() -> void:
	if not game.is_inside_tree():
		return
	game.crosshair.visible = game.phase == "playing" and game.player_respawn <= 0.0 and game.pointer_locked and not game.deployment.live_jump and not game.deployment.selector_open
	game.menu_panel.visible = game.phase=="setup" and not game.settings_panel.visible
	_update_team_ui()
	for button in game.weapon_buttons.values():
		(button as Button).disabled = not game.menu_panel.visible
	if game.frontend!=null:
		game.frontend.call("sync")
	if game.shown_weapon != game.selected_weapon:
		game.weapon_icon.texture = load("res://assets/ui/%s.svg" % game.selected_weapon) as Texture2D
		game.shown_weapon = game.selected_weapon
		_refresh_weapon_cards()
	var combat: Node3D = game.get_node("Combat")
	var orange_percent := float(game.ink.call("coverage", 0)) * 100.0
	var blue_percent := float(game.ink.call("coverage", 1)) * 100.0
	game.orange_score.text = "%s %.1f%%" % [game.team_names[0], orange_percent]
	game.blue_score.text = "%s %.1f%%" % [game.team_names[1], blue_percent]
	game.orange_bar.value = orange_percent
	game.blue_bar.value = blue_percent
	var seconds := int(ceil(game.round_left))
	game.timer_label.text = "%d:%02d" % [int(seconds / 60), seconds % 60]
	game.timer_label.add_theme_color_override("font_color", Color("ffe27a") if game.phase == "playing" and seconds <= game.final_countdown else Color.WHITE)
	game.vitals_panel.visible = game.phase == "playing" and game.player_respawn <= 0.0
	game.special_panel.visible = game.phase == "playing" and game.player_respawn <= 0.0
	game.turf_label.visible = game.special_panel.visible
	var max_health: float = game.actor_max_health(game.get_node("World/Walker"))
	var max_ink: float = game.actor_ink_max(game.get_node("World/Walker"))
	game.ink_label.text = "墨量  %d / %d" % [int(ceil(float(combat.get("ink_amount")))), int(max_ink)]
	game.health_label.text = "生命  %d / %d" % [int(ceil(game.player_health)), int(max_health)]
	game.ink_bar.value = float(combat.get("ink_amount")) / max_ink * 100.0
	game.health_bar.value = game.player_health / max_health * 100.0
	var ready := bool(combat.call("special_ready"))
	var special_percent := int(round(float(combat.call("special_fraction")) * 100.0))
	game.special_bar.value = special_percent
	game.special_label.text = "大招就绪 · F/Q" if ready else "大招  %d%%" % special_percent
	if combat.counter.busy(game.get_node("World/Walker")):
		var intake: Dictionary = combat.counter.intakes[game.get_node("World/Walker").get_instance_id()]
		game.special_label.text = "吸墨 %.0f / 100 · %.1fs" % [intake.charge,intake.time] if intake.phase == "intake" else "反击蓄势 · %.1fs" % intake.time
	game.special_label.add_theme_color_override("font_color", game.orange_color.lightened(0.45) if ready else Color.WHITE)
	# Hud.js prints the local player's turf points next to the special gauge; the results
	# screen prints the raw area instead, and the web labels both "p" (they differ by
	# pointsPerM2, which the shipped config sets to 1).
	game.turf_label.text = "涂地  %d p" % int(floor(game.turf_shown))
	game.result_panel.visible = game.phase == "finish" or game.phase == "results"
	if game.phase == "finish":
		game.result_label.text = "时间到\n等待裁判统计"
	elif game.phase == "results":
		game.result_label.text = "%s\n%s %.1f%%   %s %.1f%%\n涂地 %s %.1f m²   %s %.1f m²" % [
			game.result, game.team_names[0], game.judged_coverage[0] * 100.0, game.team_names[1], game.judged_coverage[1] * 100.0,
			game.team_names[0], game.turf_area[0], game.team_names[1], game.turf_area[1]]
	if game.phase == "setup":
		game.hud.text = "赛前按 1–8 选%s武器 · B 切换%s武器 · Enter 开始" % game.team_names
	elif game.phase == "intro":
		game.hud.text = "准备开战 · %d" % int(ceil(maxf(0.0, game.INTRO_SECONDS - game.phase_time)))
	elif game.phase == "finish":
		game.hud.text = "时间到 · 等待裁判统计"
	elif game.phase == "results":
		game.hud.text = "Enter 再开一局 · R 重开"
	elif game.player_respawn > 0.0:
		game.hud.text = "被击倒 · %.1f 秒后重生 · 可按 1–8 更换武器" % game.player_respawn
	elif game.paused:
		game.hud.text = "已暂停 · 点击画面继续 · R 重开"
	else:
		var charge := float(combat.get("charge_fraction"))
		var charge_text := "  蓄力 %d%%" % int(charge * 100.0) if bool(combat.get("charging")) else ""
		if combat.selected_id=="bow" and combat.charging:
			charge_text="  "+("精准三箭" if charge>=.999 else "爆裂箭就绪" if charge>=.5 else "快速箭")
		var controls := "Tab 地图 · J 跳跃 · Esc 暂停"
		var cover_text := ""
		if combat.counter.busy(game.get_node("World/Walker")):
			cover_text = "  转向瞄准 · 吸墨结束后自动反击"
		elif combat.selected_id=="canopy":
			var cover:Dictionary=combat.canopy.state(game.get_node("World/Walker"))
			cover_text="  伞面 %.0f HP%s" % [cover.hp," · 推进中" if cover.launched else " · 持伞"] if cover.cover!=null else ("  伞恢复 %.1fs" % cover.cooldown if cover.cooldown>0 else "  按住开伞 / 推出")
		game.hud.text = ("最后 %d 秒 · " % seconds if seconds <= game.final_countdown else "") + ("点击画面继续 · " if not game.pointer_locked else "") + controls + charge_text + cover_text
	_update_presentation()


func _update_presentation() -> void:
	if game.presentation == null:
		return
	var cinematic: bool = game.phase in ["intro","finish","results"] or game.player_respawn > 0.0
	game.score_panel.visible = game.phase=="playing" and not cinematic
	game.orange_score.visible = false
	game.blue_score.visible = false
	game.orange_bar.visible = false
	game.blue_bar.visible = false
	game.weapon_icon.visible = false
	game.special_panel.visible = false
	game.status_panel.visible = game.phase == "playing" and not cinematic
	game.roster_label.visible = false
	game.result_label.visible = false
	game.result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.presentation.call("sync")


func _build_team_ui(layer: Node) -> void:
	game.minimap = Control.new()
	game.minimap.name = "TurfMinimap"
	game.minimap.set_script(preload("res://src/ui/turf_minimap.gd"))
	layer.add_child(game.minimap)
	game.minimap.call("setup", game)
	game.roster_label = Label.new()
	game.roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.roster_label.add_theme_font_size_override("font_size", 16)
	game.roster_label.add_theme_color_override("font_outline_color", Color("17203a"))
	game.roster_label.add_theme_constant_override("outline_size", 5)
	game.roster_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(game.roster_label)
	game.feed_label = Label.new()
	game.feed_label.add_theme_font_size_override("font_size", 12)
	game.feed_label.add_theme_color_override("font_outline_color", Color("17203a"))
	game.feed_label.add_theme_constant_override("outline_size", 2)
	game.feed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(game.feed_label)
	game.pause_panel = _hud_panel(layer, "PausePanel")
	var rows := VBoxContainer.new()
	rows.position = Vector2(24.0,16.0)
	rows.size = Vector2(280.0,195.0)
	rows.add_theme_constant_override("separation",12)
	game.pause_panel.add_child(rows)
	var heading := Label.new()
	heading.text = "对局已暂停"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",24)
	rows.add_child(heading)
	var resume := Button.new()
	game.pause_resume_button = resume
	resume.text = "继续对局"
	resume.pressed.connect(func(): game._set_pointer_lock(true); _update_hud())
	rows.add_child(resume)
	game.pause_settings_button = Button.new()
	game.pause_settings_button.text = "设置"
	game.pause_settings_button.pressed.connect(_open_settings)
	rows.add_child(game.pause_settings_button)
	var back := Button.new()
	back.text = "返回主菜单"
	back.pressed.connect(game._reload_setup)
	rows.add_child(back)
	game.scoreboard_panel = _hud_panel(layer, "TeamRoster")
	var header := _hud_label(game.scoreboard_panel, "TeamHeader", Color.WHITE, 22)
	header.text = "战术地图 · 松开 Tab 返回"
	header.position = Vector2(20,16)
	game.expanded_map = Control.new()
	game.expanded_map.set_script(preload("res://src/ui/turf_minimap.gd"))
	game.expanded_map.name = "ExpandedMap"
	game.scoreboard_panel.add_child(game.expanded_map)
	game.expanded_map.call("setup",game)
	for team in range(2):
		for slot in range(5):
			var row := _hud_label(game.scoreboard_panel, "Roster_%d_%d" % [team,slot], game.TeamPalette.color(team).lightened(0.4), 16)
			game.roster_rows.append(row)
	game.result_actions = HBoxContainer.new()
	game.result_actions.add_theme_constant_override("separation",12)
	game.result_panel.add_child(game.result_actions)
	for text in ["返回主菜单", "退出游戏"]:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size = Vector2(140,38)
		if text == "返回主菜单":
			button.pressed.connect(game._reload_setup)
		else:
			button.pressed.connect(game.get_tree().quit)
		game.result_actions.add_child(button)


func compact_hud_layout() -> Dictionary:
	return preload("res://src/ui/tidewater_hud_layout.gd").measure(game.hud_root.size,game.minimap.map_bounds.size,game.MatchSetup.team_size)

func _layout_team_ui(view_size: Vector2) -> void:
	var layout := preload("res://src/ui/tidewater_hud_layout.gd").measure(view_size,game.minimap.map_bounds.size,game.MatchSetup.team_size)
	game.minimap.position = layout.map.position
	game.minimap.show_border = false
	game.minimap.size = layout.map.size
	game.minimap._layout()
	game.roster_label.position = Vector2((view_size.x - 460.0) * 0.5,102.0)
	game.roster_label.size = Vector2(460,30)
	game.feed_label.position = Vector2(16,game.minimap.get_rect().end.y+12)
	game.feed_label.size = Vector2(300,28)
	game.pause_panel.size = Vector2(328,245)
	game.pause_panel.position = (view_size - game.pause_panel.size) * 0.5
	game.scoreboard_panel.size = Vector2(minf(900.0,view_size.x-32.0),minf(460.0,view_size.y-32.0))
	game.scoreboard_panel.position = (view_size-game.scoreboard_panel.size)*0.5
	game.expanded_map.position = Vector2(20,58)
	game.expanded_map.size = Vector2(game.scoreboard_panel.size.x*0.37,game.scoreboard_panel.size.y-76.0)
	var roster_x: float = game.expanded_map.position.x + game.expanded_map.size.x + 16.0
	var row_width: float = game.scoreboard_panel.size.x-roster_x-20.0
	for index in game.roster_rows.size():
		game.roster_rows[index].position = Vector2(roster_x,58.0+index*(game.scoreboard_panel.size.y-78.0)/10.0)
		game.roster_rows[index].size = Vector2(row_width,30.0)
	game.settings_panel.size = Vector2(minf(540.0, view_size.x - 24.0), minf(580.0,view_size.y-24.0))
	game.settings_panel.position = (view_size - game.settings_panel.size) * 0.5
	game.result_actions.position = Vector2((game.result_panel.size.x - 292.0) * 0.5,game.result_panel.size.y - 45.0)


func _update_team_ui() -> void:
	game.minimap.visible = game.phase == "playing" and not game.paused and game.player_respawn <= 0.0 and not Input.is_key_pressed(KEY_TAB)
	game.roster_label.visible = game.phase == "playing" or game.phase == "intro"
	var live := [0,0]
	for actor in game.all_actors():
		if game.actor_alive(actor):
			live[game.actor_team(actor)] += 1
	game.roster_label.text = "%s  %d/%d   ·   %s  %d/%d" % [game.team_names[0],live[0],game.MatchSetup.team_size,game.team_names[1],live[1],game.MatchSetup.team_size]
	game.feed_label.visible = game.phase == "playing" and game.feed_time > 0.0
	game.feed_label.text = game.feed_text
	game.pause_panel.visible = game.phase == "playing" and game.paused and game.player_respawn <= 0.0 and not game.settings_panel.visible
	game.result_actions.visible = game.phase == "results"
	game.scoreboard_panel.visible = game.phase == "playing" and Input.is_key_pressed(KEY_TAB) and not game.settings_panel.visible and not game.paused
	game.scoreboard_panel.visible = game.scoreboard_panel.visible and game.player_respawn<=0.0
	if not game.scoreboard_panel.visible:
		return
	var roster := [[],[]]
	for actor in game.all_actors():
		roster[game.actor_team(actor)].append(actor)
	for team in range(2):
		for slot in range(5):
			var row: Label = game.roster_rows[team * 5 + slot]
			row.visible = slot < roster[team].size()
			if not row.visible:
				continue
			var actor: Node3D = roster[team][slot]
			var weapon: String = game.selected_weapon if actor == game.get_node("World/Walker") else String(actor.get("weapon_id"))
			var info: Dictionary = game.intel.marker(actor, 0)
			var status := "等待重生"
			if game.actor_alive(actor):
				status = "生命 %d" % int(game.actor_health(actor)) if team == 0 or (not info.is_empty() and info.status == "seen") else ("声呐标记" if not info.is_empty() and info.status == "sonar" else "最后发现" if not info.is_empty() else "位置未知")
			row.text = "%s · %s · %s" % [game._actor_name(actor), game._weapon_text(weapon), status]


func _build_settings_ui(parent: Node) -> void:
	game.settings_panel = Panel.new()
	game.settings_panel.set_script(SettingsPanel)
	parent.add_child(game.settings_panel)
	game.settings_panel.connect("saved", game._on_settings_saved)
	game.settings_panel.connect("closed", _update_hud)


func _open_settings() -> void:
	if game.phase not in ["home","setup"] and not (game.phase == "playing" and game.paused and game.player_respawn <= 0.0):
		return
	game.settings_panel.call("open_with", game.settings, game.settings_path)
	_update_hud()
