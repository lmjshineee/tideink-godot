extends Node3D

# Real-map migration slice. Single authoritative ink state drives the HUD,
# movement, weapon impacts and the temporary 1v1 combat loop.
const SurfaceInk = preload("res://surface_ink.gd")
# Setup selects a duration from config.js MATCH.durations. The initial option is
# still 90 s / 1v1; the web defaults to 180 s / 5v5.
const MatchSetup := preload("res://match_setup.gd")
# Source match.js intro/finish and hud.js judge timings. This scene uses the
# source's optional 90 s duration while keeping the prototype's 1v1 roster.
const INTRO_SECONDS := 4.2
const FINISH_SECONDS := 2.6
const JUDGE_SECONDS := 5.1
# Weapon order and labels both come from assets/weapons.json: `weaponOrder` is
# config.js's WEAPON_ORDER, and `text.weapons` is the web's i18n table for those ids.
# This controller used to keep its own copy of both, which had drifted from the web
# (it said 射手/滚筒 where the web says 喷溅枪/滚筒刷).
var weapon_order: Array = []
# Team colours come from config.js's palette list through TeamPalette; assigned at the top
# of _ready because label colours are baked while the HUD builds. main.gd used to keep a
# second copy of the same two literals.
const TeamPalette := preload("res://team_palette.gd")
var orange_color := Color.WHITE
var blue_color := Color.WHITE
var team_names: Array[String] = []
const UI_PANEL := Color(0.035, 0.045, 0.075, 0.92)

var ink: RefCounted
var phase := "setup"
var phase_time := 0.0
var selected_weapon := "shooter"
var selected_bot_weapon := "shooter"
var round_time := 90.0
var final_countdown := 10
var round_left := 90.0
var judged_coverage := [0.0, 0.0]
var winner := -1
var player_health := 100.0
var player_respawn := 0.0
var player_invuln := 0.0
var player_last_damage := 99.0
var player_ink_damage := 0.0
var bot_health := 100.0
var bot_respawn := 0.0
var bot_invuln := 0.0
var bot_last_damage := 99.0
var bot_ink_damage := 0.0
var result := ""
# actor.js:116-125 addTurf and hud.js:482/971-985. The raw area each team has painted
# feeds the results rows; the local player's points (area * match.pointsPerM2) feed the
# HUD counter, whose shown value chases the true total instead of jumping to it.
var turf_area := [0.0, 0.0]
var turf_total := 0.0
var turf_shown := 0.0
var _points_per_m2 := 1.0
var hud: Label
var score_panel: Panel
var orange_score: Label
var blue_score: Label
var timer_label: Label
var orange_bar: ProgressBar
var blue_bar: ProgressBar
var vitals_panel: Panel
var ink_bar: ProgressBar
var health_bar: ProgressBar
var ink_label: Label
var health_label: Label
var special_panel: Panel
var special_bar: ProgressBar
var special_label: Label
var turf_label: Label
var result_panel: Panel
var result_label: Label
var status_panel: Panel
var weapon_icon: TextureRect
var crosshair: Label
var crosshair_layer: CenterContainer
var menu_panel: Panel
var menu_hint: Label
var weapon_cards := {}
var shown_weapon := ""
var pointer_locked := false
var paused := false
var setup_options: HBoxContainer
var palette_select: OptionButton
var colorblind_toggle: CheckButton
var duration_select: OptionButton
var bot_weapon_button: Button
var weapon_buttons: Dictionary = {}


func _ready() -> void:
	var loadout := MatchSetup.take_loadout()
	selected_weapon = String(loadout.get("player", "shooter"))
	selected_bot_weapon = String(loadout.get("bot", "shooter"))
	orange_color = TeamPalette.color(0)
	blue_color = TeamPalette.color(1)
	team_names = [TeamPalette.display_name(0), TeamPalette.display_name(1)]
	_set_pointer_lock(false)
	Engine.max_fps = 30
	Engine.physics_ticks_per_second = 30
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater_surfaces.json"))
	ink = SurfaceInk.new(data)
	$InkView.call("setup", ink)
	$World/Walker.set("ink", ink)
	$World/Walker.set("active", false)
	$World/Walker.set("auto_respawn", false)
	$Combat.call("setup", self, $World/Walker)
	var match_config: Dictionary = $Combat.get("weapon_data")["match"]
	round_time = MatchSetup.duration(match_config)
	final_countdown = int(match_config["finalCountdown"])
	var weapon_data: Dictionary = $Combat.get("weapon_data")
	weapon_order = weapon_data.get("weaponOrder", [])
	if weapon_order.is_empty():
		push_error("assets/weapons.json carries no weaponOrder; falling back to the weapons block order")
		weapon_order = (weapon_data.get("weapons", {}) as Dictionary).keys()
	if not weapon_order.has(selected_weapon):
		selected_weapon = String(weapon_order[0])
	if not weapon_order.has(selected_bot_weapon):
		selected_bot_weapon = String(weapon_order[0])
	$Combat.call("select_weapon", selected_weapon)
	# hud.js uses `MATCH.pointsPerM2 || 1`, so a missing or zero value means one point per
	# square metre rather than a score of zero.
	_points_per_m2 = float(match_config.get("pointsPerM2", 1.0))
	if _points_per_m2 <= 0.0:
		_points_per_m2 = 1.0
	round_left = round_time
	$Bot.call("setup", self, $World/Walker, $World/Map)
	$Bot.call("select_weapon", selected_bot_weapon)
	player_health = float($Combat.get("weapon_data")["player"]["hp"])
	bot_health = player_health
	_build_hud()
	_update_hud()


# Chinese label for a weapon id, from the export's text block. The English brand name
# (weapons.<id>.name in the JSON) is not needed to reach it, and the id is returned as a
# last resort so a missing translation shows up as an id rather than an empty label.
func _weapon_text(weapon_id: String) -> String:
	var text_block: Dictionary = $Combat.get("weapon_data").get("text", {})
	var weapons_text: Dictionary = text_block.get("weapons", {})
	return String(weapons_text.get(weapon_id, weapon_id))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and phase == "playing" and player_respawn <= 0.0 and not pointer_locked:
		_set_pointer_lock(true)
		_update_hud()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			# Explicit type: event is statically an InputEvent, so keycode is dynamic and
			# `:=` cannot infer (this is what broke the whole suite once).
			var slot: int = event.keycode - KEY_1
			if slot < weapon_order.size() and (phase == "setup" or (phase == "playing" and player_respawn > 0.0)):
				_choose_player_weapon(String(weapon_order[slot]))
		KEY_B:
			_cycle_bot_weapon()
		KEY_ENTER:
			if phase == "setup":
				_begin_intro()
			elif phase == "results":
				get_tree().reload_current_scene()
		KEY_R:
			get_tree().reload_current_scene()
		KEY_F, KEY_Q:
			if phase == "playing" and not paused and pointer_locked and player_respawn <= 0.0:
				$Combat.call("try_special")
		KEY_ESCAPE:
			if phase == "playing":
				_set_pointer_lock(false)
	_update_hud()


func _choose_player_weapon(id: String) -> void:
	if not (phase == "setup" or (phase == "playing" and player_respawn > 0.0)) or not weapon_order.has(id):
		return
	selected_weapon = id
	$Combat.call("select_weapon", id)
	_update_hud()


func _cycle_bot_weapon() -> void:
	if phase != "setup":
		return
	selected_bot_weapon = weapon_order[(weapon_order.find(selected_bot_weapon) + 1) % weapon_order.size()]
	$Bot.call("select_weapon", selected_bot_weapon)
	_update_hud()


func _change_palette(index: int) -> void:
	if phase != "setup" or index == TeamPalette.palette_index:
		return
	TeamPalette.select(index)
	_reload_setup()


func _change_colorblind(enabled: bool) -> void:
	if phase != "setup" or enabled == TeamPalette.use_colorblind:
		return
	TeamPalette.set_colorblind(enabled)
	_reload_setup()


func _reload_setup() -> void:
	MatchSetup.pending_loadout = {"player": selected_weapon, "bot": selected_bot_weapon}
	get_tree().reload_current_scene()


func _change_duration(index: int) -> void:
	var config: Dictionary = $Combat.get("weapon_data")["match"]
	var options: Array = config.get("durations", [])
	if phase != "setup" or index < 0 or index >= options.size():
		return
	MatchSetup.duration_index = index
	round_time = MatchSetup.duration(config)
	round_left = round_time
	_update_hud()


func _set_pointer_lock(locked: bool) -> void:
	pointer_locked = locked
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if locked else Input.MOUSE_MODE_VISIBLE
	$World/Walker.set("look_enabled", locked)
	if phase == "playing":
		paused = not locked
		$World/Walker.set("active", locked and player_respawn <= 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "playing" and pointer_locked:
		_set_pointer_lock(false)
		if hud != null:
			_update_hud()


func _begin_intro() -> void:
	phase = "intro"
	phase_time = 0.0
	round_left = round_time
	result = ""
	winner = -1
	$World/Walker.set("active", false)
	_update_hud()


func _start_round() -> void:
	phase = "playing"
	paused = false
	phase_time = 0.0
	round_left = round_time
	player_respawn = 0.0
	bot_respawn = 0.0
	var player_config: Dictionary = $Combat.get("weapon_data")["player"]
	player_health = float(player_config["hp"])
	# Source match.setup() removes spawn protection for the initial lineup.
	player_invuln = 0.0
	player_last_damage = 99.0
	player_ink_damage = 0.0
	bot_health = player_health
	bot_invuln = 0.0
	bot_last_damage = 99.0
	bot_ink_damage = 0.0
	$Bot.call("reset")
	$Bot.call("select_weapon", selected_bot_weapon)
	$World/Walker.set("active", true)
	$World/Walker.visible = true
	$Combat.call("select_weapon", selected_weapon)
	_set_pointer_lock(true)
	_update_hud()


func _physics_process(delta: float) -> void:
	_update_turf_display(delta)
	match phase:
		"intro":
			phase_time += delta
			if phase_time >= INTRO_SECONDS:
				_start_round()
			_update_hud()
			return
		"finish":
			phase_time += delta
			if phase_time >= FINISH_SECONDS:
				_judge_round()
			_update_hud()
			return
		"judge":
			phase_time += delta
			if phase_time >= JUDGE_SECONDS:
				phase = "results"
				phase_time = 0.0
			_update_hud()
			return
		"playing":
			pass
		_:
			return
	if paused:
		return
	round_left = maxf(0.0, round_left - delta)
	if round_left <= 0.0:
		_finish_round()
		_update_hud()
		return
	var firing := pointer_locked and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var throwing := pointer_locked and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var walker: CharacterBody3D = $World/Walker
	var alive := player_respawn <= 0.0
	# The walker owns the squid/fire rule ("most recent press wins") and the buffered
	# pop-out shot, so the controller only feeds it raw key state. Holding squid and
	# pressing fire used to be silently ignored, and a tap just before surfacing was lost.
	var firing_pose := bool($Combat.get("rolling")) or float($Combat.get("firing_time")) > 0.0
	walker.call("update_intent", delta, alive and firing, alive and Input.is_key_pressed(KEY_SHIFT),
		bool($Combat.call("is_busy")), firing_pose, alive and throwing)
	var squid := bool(walker.get("squid_form"))
	var weapon_fire := bool(walker.get("weapon_fire"))
	_update_player_respawn(delta)
	if player_respawn <= 0.0:
		_update_player_vitals(delta)
		$Combat.call("tick", delta, weapon_fire, squid, throwing)
	else:
		$Combat.call("advance_effects", delta)
	_update_bot(delta)
	$InkView.call("sync_dirty")
	_update_hud()


func _finish_round() -> void:
	phase = "finish"
	phase_time = 0.0
	$World/Walker.set("active", false)
	$Bot.call("clear_attack_visual")
	_set_pointer_lock(false)
	_update_hud()


func _judge_round() -> void:
	judged_coverage = [float(ink.call("coverage", 0)), float(ink.call("coverage", 1))]
	winner = randi_range(0, 1) if judged_coverage[0] == judged_coverage[1] else (0 if judged_coverage[0] > judged_coverage[1] else 1)
	result = "%s胜利" % team_names[winner]
	phase = "judge"
	phase_time = 0.0
	_update_hud()


func paint_at_world(center: Vector3, team: int, radius: float, seed: float,
		stretch: Vector3 = Vector3.ZERO, stretch_amount: float = 0.0) -> float:
	var area := float(ink.call("splat_world", center, radius, team, seed, stretch, stretch_amount))
	# actor.js:116-125 credits turf to whoever painted it. Every stroke in the port funnels
	# through here — the bot's own paint calls this directly rather than going through the
	# weapon script — so this is the one place that can account for both teams without
	# touching the bot. Raw area always counts (actor stats.turf); the local player's
	# points only while alive, which is the `_live()` guard hud.js applies.
	var slot := clampi(team, 0, turf_area.size() - 1)
	turf_area[slot] = float(turf_area[slot]) + area
	if slot == 0 and player_respawn <= 0.0:
		turf_total += area * _points_per_m2
	return area


# hud.js:983-985: the shown number climbs toward the true total by 6 points per second or
# seven times the remaining gap, whichever is larger. The floating "+n p" pops drawn on
# top of it are an animation the port has no framework for, so only the chase is ported —
# the number itself is the same.
func _update_turf_display(delta: float) -> void:
	if turf_shown < turf_total:
		turf_shown = minf(turf_total, turf_shown + maxf(6.0, (turf_total - turf_shown) * 7.0) * delta)


func damage_bot(amount: float) -> void:
	if phase != "playing" or bot_respawn > 0.0 or amount <= 0.0 or bot_invuln > 0.0:
		return
	bot_last_damage = 0.0
	bot_health = maxf(0.0, bot_health - amount)
	if bot_health <= 0.0:
		$Combat.call("_paint_player", $Bot.global_position + Vector3.UP * 0.35, 1.7, randf())
		bot_respawn = float($Combat.get("weapon_data")["player"]["respawnTime"])
		$Bot.visible = false
		$Bot.call("clear_attack_visual")


func damage_player(amount: float, bypass_invuln: bool = false) -> void:
	if phase != "playing" or player_respawn > 0.0 or amount <= 0.0 or (player_invuln > 0.0 and not bypass_invuln):
		return
	if not bypass_invuln and String($Combat.get("special_active")) == "slam":
		amount *= 0.25
	player_last_damage = 0.0
	player_health = maxf(0.0, player_health - amount)
	if player_health <= 0.0:
		if not bypass_invuln:
			paint_at_world($World/Walker.global_position + Vector3.UP * 0.35, 1, 1.7, randf())
		player_respawn = float($Combat.get("weapon_data")["player"]["respawnTime"])
		$World/Walker.set("active", false)
		$World/Walker.visible = false
		$Combat.call("on_death")


func _update_player_vitals(delta: float) -> void:
	if phase != "playing" or player_respawn > 0.0:
		return
	var player_config: Dictionary = $Combat.get("weapon_data")["player"]
	var walker: CharacterBody3D = $World/Walker
	player_invuln = maxf(0.0, player_invuln - delta)
	player_last_damage += delta
	# Ground contact comes from the walker's foot probe. The engine's is_on_floor() is
	# no longer usable here: the squid body is lifted by squidBodyLift (physics.js:201),
	# so in squid form the collision shape never touches the floor and reading
	# is_on_floor() silently disabled enemy-ink damage and the swim regen.
	var grounded_now := bool(walker.get("grounded"))
	var on_enemy := grounded_now and int(walker.get("ink_owner")) == 1
	var submerged := grounded_now and bool(walker.get("squid_form")) and int(walker.get("ink_owner")) == 0
	if on_enemy:
		if player_ink_damage < float(player_config["enemyInkDamageCap"]) and player_invuln <= 0.0:
			var damage := minf(float(player_config["enemyInkDps"]) * delta, float(player_config["enemyInkDamageCap"]) - player_ink_damage)
			player_ink_damage += damage
			player_health = maxf(1.0, player_health - damage)
		player_last_damage = minf(player_last_damage, 0.4)
	else:
		player_ink_damage = maxf(0.0, player_ink_damage - delta * 30.0)
	if player_last_damage > float(player_config["regenDelay"]) and player_health < float(player_config["hp"]):
		var rate := float(player_config["regenRateSwim"]) if submerged else float(player_config["regenRate"])
		player_health = minf(float(player_config["hp"]), player_health + rate * delta)


func _update_player_respawn(delta: float) -> void:
	var walker: CharacterBody3D = $World/Walker
	if player_respawn <= 0.0:
		var fall_y := float($Combat.get("weapon_data")["player"]["fallDeathY"])
		if walker.global_position.y < fall_y:
			damage_player(player_health, true)
		return
	player_respawn = maxf(0.0, player_respawn - delta)
	if player_respawn > 0.0:
		return
	var pads: Array = $World/Map.get("spawn_pads")
	walker.global_position = (pads[0] as Vector3) + Vector3.UP * 0.05
	walker.call("reset_movement_state")
	walker.set("ink_owner", -1)
	walker.set("active", true)
	walker.visible = true
	player_health = float($Combat.get("weapon_data")["player"]["hp"])
	player_invuln = float($Combat.get("weapon_data")["player"]["spawnInvuln"])
	player_last_damage = 99.0
	player_ink_damage = 0.0
	$Combat.set("ink_amount", float($Combat.get("weapon_data")["player"]["inkMax"]))
	$Combat.call("select_weapon", selected_weapon)


func _update_bot(delta: float) -> void:
	var bot: Node3D = $Bot
	if bot_respawn > 0.0:
		bot_respawn = maxf(0.0, bot_respawn - delta)
		if bot_respawn <= 0.0:
			var player_config: Dictionary = $Combat.get("weapon_data")["player"]
			bot_health = float(player_config["hp"])
			bot_invuln = float(player_config["spawnInvuln"])
			bot_last_damage = 99.0
			bot_ink_damage = 0.0
			bot.call("reset")
		return
	_update_bot_vitals(delta)
	bot.call("tick", delta)


func _update_bot_vitals(delta: float) -> void:
	if phase != "playing" or bot_respawn > 0.0:
		return
	var player_config: Dictionary = $Combat.get("weapon_data")["player"]
	bot_invuln = maxf(0.0, bot_invuln - delta)
	bot_last_damage += delta
	var on_enemy := int($Bot.call("floor_ink_owner")) == 0
	if on_enemy:
		if bot_ink_damage < float(player_config["enemyInkDamageCap"]) and bot_invuln <= 0.0:
			var damage := minf(float(player_config["enemyInkDps"]) * delta, float(player_config["enemyInkDamageCap"]) - bot_ink_damage)
			bot_ink_damage += damage
			bot_health = maxf(1.0, bot_health - damage)
		bot_last_damage = minf(bot_last_damage, 0.4)
	else:
		bot_ink_damage = maxf(0.0, bot_ink_damage - delta * 30.0)
	if bot_last_damage > float(player_config["regenDelay"]) and bot_health < float(player_config["hp"]):
		bot_health = minf(float(player_config["hp"]), bot_health + float(player_config["regenRate"]) * delta)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	score_panel = _hud_panel(layer, "ScorePanel")
	orange_score = _hud_label(score_panel, "OrangeScore", orange_color, 18)
	blue_score = _hud_label(score_panel, "BlueScore", blue_color.lightened(0.45), 18)
	timer_label = _hud_label(score_panel, "Timer", Color.WHITE, 34)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var number_font := load("res://assets/fonts/TitanOne-latin.woff2") as Font
	timer_label.add_theme_font_override("font", number_font)
	orange_bar = _hud_bar(score_panel, "OrangeTurf", orange_color)
	blue_bar = _hud_bar(score_panel, "BlueTurf", blue_color)
	vitals_panel = _hud_panel(layer, "VitalsPanel")
	ink_label = _hud_label(vitals_panel, "InkLabel", Color.WHITE, 17)
	health_label = _hud_label(vitals_panel, "HealthLabel", Color.WHITE, 17)
	ink_bar = _hud_bar(vitals_panel, "InkBar", orange_color)
	health_bar = _hud_bar(vitals_panel, "HealthBar", Color("fc4266"))
	special_panel = _hud_panel(layer, "SpecialPanel")
	special_label = _hud_label(special_panel, "SpecialLabel", Color.WHITE, 18)
	turf_label = _hud_label(special_panel, "TurfLabel", orange_color.lightened(0.35), 16)
	turf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	special_bar = _hud_bar(special_panel, "SpecialBar", orange_color.lightened(0.35))
	result_panel = _hud_panel(layer, "ResultPanel")
	result_label = _hud_label(result_panel, "ResultLabel", Color.WHITE, 28)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_panel = _hud_panel(layer, "StatusPanel")
	hud = Label.new()
	hud.name = "StatusLine"
	hud.add_theme_font_size_override("font_size", 17)
	hud.add_theme_color_override("font_color", Color.WHITE)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(hud)
	weapon_icon = TextureRect.new()
	weapon_icon.position = Vector2(1110.0, 20.0)
	weapon_icon.size = Vector2(96.0, 96.0)
	weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(weapon_icon)
	crosshair_layer = CenterContainer.new()
	crosshair_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(crosshair_layer)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 30)
	crosshair.add_theme_color_override("font_shadow_color", Color.BLACK)
	crosshair_layer.add_child(crosshair)
	_build_weapon_menu(layer)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()


func _hud_panel(parent: CanvasLayer, name_text: String) -> Panel:
	var panel := Panel.new()
	panel.name = name_text
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _ui_style(UI_PANEL, Color(1.0, 1.0, 1.0, 0.22), 2, 16))
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


func _ui_style(background: Color, outline: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = outline
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _build_weapon_menu(layer: CanvasLayer) -> void:
	menu_panel = Panel.new()
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_theme_stylebox_override("panel", _ui_style(UI_PANEL, Color(1.0, 1.0, 1.0, 0.22), 3, 22))
	layer.add_child(menu_panel)
	var title := Label.new()
	title.text = "INKWAVE"
	title.position = Vector2(0.0, 17.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/fonts/TitanOne-latin.woff2") as Font)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", orange_color)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(title)
	menu_hint = Label.new()
	menu_hint.position = Vector2(0.0, 83.0)
	menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_hint.add_theme_font_size_override("font_size", 22)
	menu_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(menu_hint)
	for index in weapon_order.size():
		var weapon_id: String = weapon_order[index]
		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_panel.add_child(card)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load("res://assets/ui/%s.svg" % weapon_id) as Texture2D
		icon.size = Vector2(60.0, 60.0)
		icon.position.y = 9.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var name_label := Label.new()
		name_label.text = "%d  %s" % [index + 1, _weapon_text(weapon_id)]
		name_label.position.y = 74.0
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_label)
		weapon_cards[weapon_id] = card
		var button := Button.new()
		button.name = "SelectWeapon"
		button.flat = true
		button.tooltip_text = _weapon_text(weapon_id)
		card.add_child(button)
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.pressed.connect(_choose_player_weapon.bind(weapon_id))
		weapon_buttons[weapon_id] = button
	setup_options = HBoxContainer.new()
	setup_options.add_theme_constant_override("separation", 12)
	menu_panel.add_child(setup_options)
	palette_select = OptionButton.new()
	palette_select.custom_minimum_size.x = 200
	palette_select.add_theme_font_size_override("font_size", 16)
	var palettes := TeamPalette.palettes()
	var labels: Dictionary = $Combat.get("weapon_data")["text"]["teams"]
	for palette in palettes:
		var names: Array = labels.get(String(palette["id"]), palette["names"])
		palette_select.add_item("%s / %s" % names)
	palette_select.select(TeamPalette.palette_index)
	palette_select.item_selected.connect(_change_palette)
	setup_options.add_child(palette_select)
	colorblind_toggle = CheckButton.new()
	colorblind_toggle.text = "色盲配色"
	colorblind_toggle.add_theme_font_size_override("font_size", 16)
	colorblind_toggle.set_pressed_no_signal(TeamPalette.use_colorblind)
	colorblind_toggle.toggled.connect(_change_colorblind)
	setup_options.add_child(colorblind_toggle)
	duration_select = OptionButton.new()
	duration_select.custom_minimum_size.x = 100
	duration_select.add_theme_font_size_override("font_size", 16)
	var durations: Array = $Combat.get("weapon_data")["match"].get("durations", [])
	for duration in durations:
		duration_select.add_item("%d 秒" % int(duration))
	if not durations.is_empty():
		duration_select.select(clampi(MatchSetup.duration_index, 0, durations.size() - 1))
	duration_select.item_selected.connect(_change_duration)
	setup_options.add_child(duration_select)
	bot_weapon_button = Button.new()
	bot_weapon_button.add_theme_font_size_override("font_size", 16)
	bot_weapon_button.pressed.connect(_cycle_bot_weapon)
	setup_options.add_child(bot_weapon_button)


func _refresh_weapon_cards() -> void:
	for weapon_id in weapon_order:
		var card: Panel = weapon_cards[weapon_id]
		var selected: bool = weapon_id == selected_weapon
		card.add_theme_stylebox_override("panel", _ui_style(
			Color(0.18, 0.11, 0.07, 0.98) if selected else Color(0.07, 0.09, 0.14, 0.96),
			orange_color if selected else Color(1.0, 1.0, 1.0, 0.2), 3 if selected else 1, 14))


func _layout_hud() -> void:
	var size := get_viewport().get_visible_rect().size
	var score_width := minf(400.0, size.x - 24.0)
	score_panel.position = Vector2((size.x - score_width) * 0.5, 12.0)
	score_panel.size = Vector2(score_width, 86.0)
	orange_score.position = Vector2(16.0, 10.0)
	orange_score.size = Vector2(140.0, 38.0)
	blue_score.position = Vector2(score_width - 156.0, 10.0)
	blue_score.size = Vector2(140.0, 38.0)
	blue_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.position = Vector2((score_width - 90.0) * 0.5, 2.0)
	timer_label.size = Vector2(90.0, 49.0)
	orange_bar.position = Vector2(16.0, 62.0)
	orange_bar.size = Vector2((score_width - 42.0) * 0.5, 12.0)
	blue_bar.position = Vector2((score_width + 10.0) * 0.5, 62.0)
	blue_bar.size = orange_bar.size
	vitals_panel.position = Vector2(16.0, maxf(104.0, size.y - 162.0))
	vitals_panel.size = Vector2(275.0, 112.0)
	ink_label.position = Vector2(16.0, 8.0)
	ink_label.size = Vector2(240.0, 27.0)
	ink_bar.position = Vector2(16.0, 36.0)
	ink_bar.size = Vector2(243.0, 13.0)
	health_label.position = Vector2(16.0, 55.0)
	health_label.size = Vector2(240.0, 27.0)
	health_bar.position = Vector2(16.0, 83.0)
	health_bar.size = Vector2(243.0, 13.0)
	special_panel.position = Vector2(maxf(16.0, size.x - 226.0), 124.0)
	special_panel.size = Vector2(210.0, 108.0)
	turf_label.position = Vector2(0.0, 78.0)
	turf_label.size = Vector2(210.0, 24.0)
	special_label.position = Vector2(13.0, 7.0)
	special_label.size = Vector2(184.0, 35.0)
	special_bar.position = Vector2(13.0, 53.0)
	special_bar.size = Vector2(184.0, 15.0)
	var result_width := minf(520.0, size.x - 24.0)
	result_panel.size = Vector2(result_width, 176.0)
	result_panel.position = (size - result_panel.size) * 0.5
	result_label.position = Vector2(12.0, 19.0)
	result_label.size = Vector2(result_width - 24.0, 140.0)
	status_panel.position = Vector2(16.0, maxf(277.0, size.y - 43.0))
	status_panel.size = Vector2(size.x - 32.0, 31.0)
	hud.position = Vector2(10.0, 4.0)
	hud.size = Vector2(status_panel.size.x - 20.0, 24.0)
	crosshair_layer.position = Vector2.ZERO
	crosshair_layer.size = size
	weapon_icon.position = Vector2(maxf(18.0, size.x - 114.0), 20.0)
	var width := minf(850.0, size.x - 24.0)
	menu_panel.size = Vector2(width, 330.0)
	menu_panel.position = (size - menu_panel.size) * 0.5
	var title: Label = menu_panel.get_child(0)
	title.size = Vector2(width, 58.0)
	menu_hint.size = Vector2(width, 36.0)
	setup_options.position = Vector2(24.0, 260.0)
	setup_options.size = Vector2(width - 48.0, 44.0)
	var card_width := (width - 70.0) * 0.25
	for index in weapon_order.size():
		var card: Panel = weapon_cards[weapon_order[index]]
		card.position = Vector2(20.0 + float(index) * (card_width + 10.0), 137.0)
		card.size = Vector2(card_width, 106.0)
		var icon: TextureRect = card.get_child(0)
		icon.position.x = (card_width - 60.0) * 0.5
		var name_label: Label = card.get_child(1)
		name_label.size = Vector2(card_width, 28.0)


func _update_hud() -> void:
	crosshair.visible = phase == "playing" and player_respawn <= 0.0 and pointer_locked
	menu_panel.visible = phase == "setup" or (phase == "playing" and player_respawn > 0.0)
	setup_options.visible = phase == "setup"
	palette_select.disabled = phase != "setup"
	colorblind_toggle.disabled = phase != "setup"
	duration_select.disabled = phase != "setup"
	bot_weapon_button.disabled = phase != "setup"
	bot_weapon_button.text = "机器人：%s · B" % _weapon_text(selected_bot_weapon)
	for button in weapon_buttons.values():
		(button as Button).disabled = not menu_panel.visible
	if menu_panel.visible:
		menu_hint.text = ("%s 1–4 · %s B：%s · Enter 开始" % [team_names[0], team_names[1], _weapon_text(selected_bot_weapon)]) if phase == "setup" else "等待重生 · 按 1–4 更换武器"
	if shown_weapon != selected_weapon:
		weapon_icon.texture = load("res://assets/ui/%s.svg" % selected_weapon) as Texture2D
		shown_weapon = selected_weapon
		_refresh_weapon_cards()
	var combat: Node3D = $Combat
	var orange_percent := float(ink.call("coverage", 0)) * 100.0
	var blue_percent := float(ink.call("coverage", 1)) * 100.0
	orange_score.text = "%s %.1f%%" % [team_names[0], orange_percent]
	blue_score.text = "%s %.1f%%" % [team_names[1], blue_percent]
	orange_bar.value = orange_percent
	blue_bar.value = blue_percent
	var seconds := int(ceil(round_left))
	timer_label.text = "%d:%02d" % [int(seconds / 60), seconds % 60]
	timer_label.add_theme_color_override("font_color", Color("ffe27a") if phase == "playing" and seconds <= final_countdown else Color.WHITE)
	vitals_panel.visible = phase == "playing" and player_respawn <= 0.0
	special_panel.visible = phase == "playing" and player_respawn <= 0.0
	turf_label.visible = special_panel.visible
	var max_health := float(combat.get("weapon_data")["player"]["hp"])
	var max_ink := float(combat.get("weapon_data")["player"]["inkMax"])
	ink_label.text = "墨量  %d / %d" % [int(ceil(float(combat.get("ink_amount")))), int(max_ink)]
	health_label.text = "生命  %d / %d" % [int(ceil(player_health)), int(max_health)]
	ink_bar.value = float(combat.get("ink_amount")) / max_ink * 100.0
	health_bar.value = player_health / max_health * 100.0
	var ready := bool(combat.call("special_ready"))
	var special_percent := int(round(float(combat.call("special_fraction")) * 100.0))
	special_bar.value = special_percent
	special_label.text = "大招就绪 · F/Q" if ready else "大招  %d%%" % special_percent
	special_label.add_theme_color_override("font_color", orange_color.lightened(0.45) if ready else Color.WHITE)
	# Hud.js prints the local player's turf points next to the special gauge; the results
	# screen prints the raw area instead, and the web labels both "p" (they differ by
	# pointsPerM2, which the shipped config sets to 1).
	turf_label.text = "涂地  %d p" % int(floor(turf_shown))
	result_panel.visible = phase == "finish" or phase == "judge" or phase == "results"
	if phase == "finish":
		result_label.text = "时间到\n等待裁判统计"
	elif phase == "judge" or phase == "results":
		result_label.text = "%s\n%s %.1f%%   %s %.1f%%\n涂地 %s %.1f m²   %s %.1f m²" % [
			result, team_names[0], judged_coverage[0] * 100.0, team_names[1], judged_coverage[1] * 100.0,
			team_names[0], turf_area[0], team_names[1], turf_area[1]]
	if phase == "setup":
		hud.text = "赛前按 1–4 选%s武器 · B 切换%s武器 · Enter 开始" % team_names
	elif phase == "intro":
		hud.text = "准备开战 · %d" % int(ceil(maxf(0.0, INTRO_SECONDS - phase_time)))
	elif phase == "finish":
		hud.text = "时间到 · 等待裁判统计"
	elif phase == "judge":
		hud.text = "裁判计分中"
	elif phase == "results":
		hud.text = "Enter 再开一局 · R 重开"
	elif player_respawn > 0.0:
		hud.text = "被击倒 · %.1f 秒后重生 · 可按 1–4 更换武器" % player_respawn
	elif paused:
		hud.text = "已暂停 · 点击画面继续 · R 重开"
	else:
		var charge := float(combat.get("charge_fraction"))
		var charge_text := "  蓄力 %d%%" % int(charge * 100.0) if bool(combat.get("charging")) else ""
		var controls := "WASD 移动 · 鼠标瞄准 · 空格跳跃 · Shift 潜墨 · 左键射击 · 右键炸弹 · F/Q 大招 · Esc 暂停"
		hud.text = ("最后 %d 秒 · " % seconds if seconds <= final_countdown else "") + ("点击画面继续 · " if not pointer_locked else "") + controls + charge_text
