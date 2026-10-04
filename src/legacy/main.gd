extends Node3D

# PROTOTYPE QUESTION: can INKWAVE's movement, four weapon behaviors, ground ink,
# and turf scoring be played natively in Godot before committing to a full port?
const PaintField = preload("res://src/legacy/paint_field.gd")
const GROUND_SHADER = preload("res://shaders/world/ink_ground.gdshader")
# From the exported palette, like the match scene: main.gd used to keep its own copy.
const TeamPalette := preload("res://src/core/team_palette.gd")
var orange_color := Color.WHITE
var blue_color := Color.WHITE
const UI_DARK := Color("15121c")
const UI_PANEL := Color(0.12, 0.10, 0.17, 0.93)
const RUN_SPEED := 6.0
const DRY_SQUID_SPEED := 2.9
const OWN_INK_SPEED := 11.8
const ENEMY_INK_SPEED := 1.9
const INK_REFILL_SWIM := 42.0
const INK_REFILL_KID := 9.0
const SHOOTER_INTERVAL := 0.1
const SHOOTER_COST := 0.95
const SHOOTER_SPEED := 34.0
const SHOOTER_RANGE := 12.5
const SHOOTER_RADIUS := 0.85
const SHOOTER_FIRING_SPEED := 4.6
const ROLLER_WIDTH := 1.9
const ROLLER_COST_PER_METER := 1.1
const ROLLER_SPEED := 4.4
const ROLLER_DAMAGE := 140.0
const CHARGER_CHARGE_TIME := 1.0
const CHARGER_RANGE_MIN := 11.0
const CHARGER_RANGE_MAX := 27.0
const CHARGER_DAMAGE_MIN := 40.0
const CHARGER_DAMAGE_MAX := 160.0
const CHARGER_INK_FULL := 18.0
const CHARGER_LINE_EVERY := 1.2
const CHARGER_LINE_RADIUS := 0.55
const CHARGER_FIRING_SPEED := 1.8
const BLASTER_INTERVAL := 0.78
const BLASTER_COST := 9.0
const BLASTER_SPEED := 23.0
const BLASTER_RANGE := 10.5
const BLASTER_DIRECT_DAMAGE := 125.0
const BLASTER_SPLASH_RADIUS := 2.6
const BLASTER_PAINT_RADIUS := 1.9
const BLASTER_FIRING_SPEED := 4.0
const ROUND_TIME := 90.0
const RESPAWN_TIME := 5.5

var paint = PaintField.new()
var phase := "setup"
var selected_weapon := "shooter"
var round_left := ROUND_TIME
var player_pos := Vector3(0.0, 0.0, -13.0)
var bot_pos := Vector3(0.0, 0.0, 13.0)
var bot_goal := Vector3(0.0, 0.0, 13.0)
var aim_pos := Vector3.ZERO
var player_ink := 100.0
var player_health := 100.0
var player_respawn := 0.0
var bot_health := 100.0
var bot_respawn := 0.0
var shot_cooldown := 0.0
var roller_accum := 0.0
var roller_hit_cooldown := 0.0
var charger_time := 0.0
var charger_fraction := 0.0
var charger_charging := false
var bot_paint_cooldown := 0.0
var bot_attack_cooldown := 0.0
var bot_goal_timer := 0.0
var projectiles: Array[Dictionary] = []
var beam_visuals: Array[Dictionary] = []

var camera: Camera3D
var player_model: Node3D
var bot_model: Node3D
var top_label: Label
var help_label: Label
var center_label: Label
var title_label: Label
var menu_back: Panel
var weapon_select: Control
var weapon_icon: TextureRect
var ink_bar_fill: ColorRect
var weapon_cards := {}
var weapon_textures := {}
var shown_weapon := ""


func _ready() -> void:
	orange_color = TeamPalette.color(0)
	blue_color = TeamPalette.color(1)
	Engine.max_fps = 30
	Engine.physics_ticks_per_second = 30
	weapon_textures = {
		"shooter": load("res://assets/ui/shooter.svg"),
		"roller": load("res://assets/ui/roller.svg"),
		"charger": load("res://assets/ui/charger.svg"),
		"blaster": load("res://assets/ui/blaster.svg"),
	}
	_build_arena()
	_build_actors()
	_build_camera()
	_build_hud()
	_update_hud()


func _build_arena() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("ink_texture", paint.texture)
	ground.material_override = material
	add_child(ground)

	# A deliberately simplified, flat Tidewater test arena. Geometry stays cheap
	# so the port answers a gameplay question rather than a scene-art question.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(side * 20.25, 0.35, 0.0), Vector3(0.5, 0.7, 40.0), Color("536778"))
		_add_box(Vector3(0.0, 0.35, side * 20.25), Vector3(40.0, 0.7, 0.5), Color("536778"))
		_add_box(Vector3(side * 8.0, 0.25, 0.0), Vector3(3.0, 0.5, 2.0), Color("a9b4bc"))
		_add_box(Vector3(side * 13.0, 0.2, side * 12.0), Vector3(2.5, 0.4, 2.5), Color("c9a27c"))
	_add_box(Vector3(0.0, 0.35, 0.0), Vector3(3.8, 0.7, 3.8), Color("d9dfe0"))
	_add_pad(Vector3(0.0, 0.015, -13.0), orange_color)
	_add_pad(Vector3(0.0, 0.015, 13.0), blue_color)


func _add_box(at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _flat_material(color)
	node.position = at
	add_child(node)


func _add_pad(at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.5
	mesh.bottom_radius = 1.5
	mesh.height = 0.03
	node.mesh = mesh
	node.material_override = _flat_material(color.darkened(0.4))
	node.position = at
	add_child(node)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _ui_style(background: Color, outline: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = outline
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _build_actors() -> void:
	player_model = _actor_model(orange_color)
	bot_model = _actor_model(blue_color)
	player_model.position = player_pos
	player_model.scale = Vector3.ONE
	bot_model.position = bot_pos


func _actor_model(color: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.45
	body.mesh = capsule
	body.material_override = _flat_material(color)
	body.position.y = 0.76
	root.add_child(body)
	var nose := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	nose.mesh = sphere
	nose.material_override = _flat_material(Color.WHITE)
	nose.position = Vector3(0.0, 0.95, -0.38)
	root.add_child(nose)
	return root


func _build_camera() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27.0
	camera.position = Vector3(0.0, 28.0, 22.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true


func _build_hud() -> void:
	var titan_font := load("res://assets/fonts/TitanOne-latin.woff2") as Font
	var rubik_font := load("res://assets/fonts/Rubik-latin.woff2") as Font
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var hud_back := Panel.new()
	hud_back.position = Vector2(8.0, 8.0)
	hud_back.size = Vector2(770.0, 136.0)
	hud_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_back.add_theme_stylebox_override("panel", _ui_style(UI_PANEL, Color(1.0, 1.0, 1.0, 0.16), 2, 18))
	root.add_child(hud_back)
	top_label = Label.new()
	top_label.position = Vector2(18.0, 14.0)
	top_label.add_theme_font_size_override("font_size", 22)
	top_label.add_theme_color_override("font_color", Color.WHITE)
	top_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	top_label.add_theme_constant_override("shadow_offset_x", 2)
	top_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(top_label)
	weapon_icon = TextureRect.new()
	weapon_icon.position = Vector2(675.0, 28.0)
	weapon_icon.size = Vector2(70.0, 70.0)
	weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(weapon_icon)
	var ink_bar_back := ColorRect.new()
	ink_bar_back.position = Vector2(20.0, 119.0)
	ink_bar_back.size = Vector2(300.0, 10.0)
	ink_bar_back.color = UI_DARK
	ink_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ink_bar_back)
	ink_bar_fill = ColorRect.new()
	ink_bar_fill.size = Vector2(300.0, 10.0)
	ink_bar_fill.color = orange_color
	ink_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink_bar_back.add_child(ink_bar_fill)
	help_label = Label.new()
	help_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help_label.offset_left = 18.0
	help_label.offset_top = -70.0
	help_label.offset_right = 1100.0
	help_label.offset_bottom = -8.0
	help_label.add_theme_font_size_override("font_size", 19)
	help_label.add_theme_color_override("font_color", Color.WHITE)
	help_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	root.add_child(help_label)
	menu_back = Panel.new()
	menu_back.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_back.offset_left = -420.0
	menu_back.offset_top = -180.0
	menu_back.offset_right = 420.0
	menu_back.offset_bottom = 180.0
	menu_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_back.add_theme_stylebox_override("panel", _ui_style(UI_PANEL, Color(1.0, 1.0, 1.0, 0.22), 3, 24))
	root.add_child(menu_back)
	title_label = Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_label.offset_left = -300.0
	title_label.offset_top = -168.0
	title_label.offset_right = 300.0
	title_label.offset_bottom = -116.0
	title_label.text = "INKWAVE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", titan_font)
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", orange_color)
	title_label.add_theme_color_override("font_shadow_color", UI_DARK)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_label)
	center_label = Label.new()
	center_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_label.offset_left = -390.0
	center_label.offset_top = -110.0
	center_label.offset_right = 390.0
	center_label.offset_bottom = 5.0
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 26)
	center_label.add_theme_color_override("font_color", Color.WHITE)
	center_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center_label)
	weapon_select = Control.new()
	weapon_select.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	weapon_select.offset_left = -375.0
	weapon_select.offset_top = 20.0
	weapon_select.offset_right = 375.0
	weapon_select.offset_bottom = 140.0
	weapon_select.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(weapon_select)
	var choices := [
		["shooter", "射手"], ["roller", "滚筒"],
		["charger", "蓄力狙"], ["blaster", "爆破枪"],
	]
	for index in range(choices.size()):
		var weapon_id: String = choices[index][0]
		var card := Panel.new()
		card.position = Vector2(index * 190.0, 0.0)
		card.size = Vector2(180.0, 118.0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weapon_select.add_child(card)
		var icon := TextureRect.new()
		icon.position = Vector2(12.0, 23.0)
		icon.size = Vector2(74.0, 74.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = weapon_textures[weapon_id] as Texture2D
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var key_label := Label.new()
		key_label.position = Vector2(102.0, 18.0)
		key_label.text = str(index + 1)
		key_label.add_theme_font_override("font", rubik_font)
		key_label.add_theme_font_size_override("font_size", 25)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(key_label)
		var name_label := Label.new()
		name_label.position = Vector2(93.0, 60.0)
		name_label.text = choices[index][1]
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_label)
		weapon_cards[weapon_id] = card


func _refresh_weapon_art() -> void:
	if shown_weapon == selected_weapon:
		return
	weapon_icon.texture = weapon_textures[selected_weapon] as Texture2D
	for weapon_id in weapon_cards:
		var active: bool = weapon_id == selected_weapon
		var card: Panel = weapon_cards[weapon_id]
		var fill := Color(0.30, 0.18, 0.08, 0.96) if active else UI_PANEL
		var outline := orange_color if active else Color(1.0, 1.0, 1.0, 0.18)
		card.add_theme_stylebox_override("panel", _ui_style(fill, outline, 3 if active else 2, 16))
	shown_weapon = selected_weapon


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			if phase == "setup" or player_respawn > 0.0:
				selected_weapon = "shooter"
		KEY_2:
			if phase == "setup" or player_respawn > 0.0:
				selected_weapon = "roller"
		KEY_3:
			if phase == "setup" or player_respawn > 0.0:
				selected_weapon = "charger"
		KEY_4:
			if phase == "setup" or player_respawn > 0.0:
				selected_weapon = "blaster"
		KEY_ENTER:
			if phase == "setup" or phase == "results":
				_start_round()
		KEY_R:
			if phase == "playing":
				_start_round()
	_update_hud()


func _start_round() -> void:
	paint = PaintField.new()
	var ground: MeshInstance3D = get_child(0)
	var material: ShaderMaterial = ground.material_override
	material.set_shader_parameter("ink_texture", paint.texture)
	for shot in projectiles:
		(shot["mesh"] as MeshInstance3D).queue_free()
	projectiles.clear()
	for beam in beam_visuals:
		(beam["mesh"] as MeshInstance3D).queue_free()
	beam_visuals.clear()
	phase = "playing"
	round_left = ROUND_TIME
	player_pos = Vector3(0.0, 0.0, -13.0)
	bot_pos = Vector3(0.0, 0.0, 13.0)
	bot_goal = bot_pos
	player_ink = 100.0
	player_health = 100.0
	player_respawn = 0.0
	bot_health = 100.0
	bot_respawn = 0.0
	shot_cooldown = 0.0
	roller_accum = 0.0
	roller_hit_cooldown = 0.0
	_reset_charger()
	bot_paint_cooldown = 0.0
	bot_attack_cooldown = 0.0
	bot_goal_timer = 0.0
	player_model.position = player_pos
	player_model.scale = Vector3.ONE
	bot_model.position = bot_pos
	player_model.visible = true
	bot_model.visible = true


func _physics_process(delta: float) -> void:
	if phase != "playing":
		return
	round_left = maxf(0.0, round_left - delta)
	if round_left <= 0.0:
		phase = "results"
		_update_hud()
		return
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	roller_hit_cooldown = maxf(0.0, roller_hit_cooldown - delta)
	_update_player(delta)
	_update_bot(delta)
	_update_projectiles(delta)
	_update_beam_visuals(delta)
	paint.flush()
	_update_hud()


func _update_player(delta: float) -> void:
	if player_respawn > 0.0:
		player_respawn -= delta
		if player_respawn <= 0.0:
			player_pos = Vector3(0.0, 0.0, -13.0)
			player_health = 100.0
			player_ink = 100.0
			player_model.position = player_pos
			player_model.scale = Vector3.ONE
			player_model.visible = true
		return
	var axis := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): axis.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): axis.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): axis.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): axis.y += 1.0
	axis = axis.normalized()
	var squid := Input.is_key_pressed(KEY_SHIFT)
	var firing := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var surface := paint.owner_at(player_pos)
	var speed := RUN_SPEED
	if squid:
		speed = OWN_INK_SPEED if surface == 0 else DRY_SQUID_SPEED
	elif surface == 1:
		speed = ENEMY_INK_SPEED
	if firing and not squid:
		match selected_weapon:
			"shooter": speed = minf(speed, SHOOTER_FIRING_SPEED)
			"roller": speed = minf(speed, ROLLER_SPEED)
			"charger": speed = minf(speed, CHARGER_FIRING_SPEED)
			"blaster": speed = minf(speed, BLASTER_FIRING_SPEED)
	var motion := Vector3(axis.x, 0.0, axis.y) * speed * delta
	player_pos += motion
	player_pos.x = clampf(player_pos.x, -19.0, 19.0)
	player_pos.z = clampf(player_pos.z, -19.0, 19.0)
	player_model.position = player_pos
	player_model.scale = Vector3(1.0, 0.45, 1.0) if squid else Vector3.ONE
	aim_pos = _mouse_on_ground()
	var aim := aim_pos - player_pos
	aim.y = 0.0
	if aim.length_squared() > 0.01:
		player_model.rotation.y = atan2(-aim.x, -aim.z)
	if squid and surface == 0:
		player_ink = minf(100.0, player_ink + INK_REFILL_SWIM * delta)
	elif not firing:
		player_ink = minf(100.0, player_ink + INK_REFILL_KID * delta)
	if selected_weapon == "charger" and charger_charging:
		if squid:
			_reset_charger()
		elif not firing:
			_fire_charger(maxf(0.12, charger_fraction))
			_reset_charger()
			shot_cooldown = 0.28
	if squid or not firing:
		return
	if selected_weapon == "shooter" and shot_cooldown <= 0.0 and player_ink >= SHOOTER_COST:
		_fire_shooter()
	elif selected_weapon == "roller" and player_ink > 0.0 and motion.length() > 0.0:
		roller_accum += motion.length()
		player_ink = maxf(0.0, player_ink - ROLLER_COST_PER_METER * motion.length())
		if roller_accum >= 0.20:
			roller_accum = 0.0
			paint.splat(player_pos + aim.normalized() * 0.45, ROLLER_WIDTH * 0.5, 0, randf())
			if bot_respawn <= 0.0 and roller_hit_cooldown <= 0.0 and player_pos.distance_to(bot_pos) < 1.25:
				_damage_bot(ROLLER_DAMAGE)
				roller_hit_cooldown = 0.5
	elif selected_weapon == "charger" and shot_cooldown <= 0.0:
		if not charger_charging and player_ink >= CHARGER_INK_FULL * 0.2:
			charger_charging = true
			charger_time = 0.0
		if charger_charging:
			charger_time = minf(CHARGER_CHARGE_TIME, charger_time + delta)
			var t := charger_time / CHARGER_CHARGE_TIME
			var curved := t * 1.25 if t < 0.2 else 0.25 + (t - 0.2) * 0.9375
			charger_fraction = minf(player_ink / CHARGER_INK_FULL, curved)
	elif selected_weapon == "blaster" and shot_cooldown <= 0.0 and player_ink >= BLASTER_COST:
		_fire_blaster()


func _mouse_on_ground() -> Vector3:
	var pointer := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(pointer)
	var direction := camera.project_ray_normal(pointer)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	return hit if hit is Vector3 else player_pos + Vector3.FORWARD * 5.0


func _aim_direction() -> Vector3:
	var direction := aim_pos - player_pos
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.01 else Vector3.FORWARD


func _reset_charger() -> void:
	charger_charging = false
	charger_time = 0.0
	charger_fraction = 0.0


func _fire_charger(charge: float) -> void:
	player_ink = maxf(0.0, player_ink - CHARGER_INK_FULL * charge)
	var direction := _aim_direction()
	var length := lerpf(CHARGER_RANGE_MIN, CHARGER_RANGE_MAX, charge)
	if bot_respawn <= 0.0:
		var to_bot := bot_pos - player_pos
		var along := to_bot.dot(direction)
		var closest := player_pos + direction * along
		if along > 0.0 and along <= length and closest.distance_to(bot_pos) < 0.72:
			length = along
			var damage := CHARGER_DAMAGE_MAX if charge >= 0.999 else lerpf(CHARGER_DAMAGE_MIN, CHARGER_DAMAGE_MAX * 0.62, charge)
			_damage_bot(damage)
	var distance := 1.2
	while distance < length - 0.3:
		paint.splat(player_pos + direction * distance, CHARGER_LINE_RADIUS * (0.8 + charge * 0.4), 0, randf())
		distance += CHARGER_LINE_EVERY
	var beam := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.07 + charge * 0.07, 0.05, length)
	beam.mesh = shape
	beam.material_override = _flat_material(orange_color.lightened(0.35))
	beam.position = player_pos + direction * (length * 0.5) + Vector3.UP * 0.08
	beam.rotation.y = atan2(-direction.x, -direction.z)
	add_child(beam)
	beam_visuals.append({"mesh": beam, "life": 0.18})


func _fire_shooter() -> void:
	shot_cooldown = SHOOTER_INTERVAL
	player_ink -= SHOOTER_COST
	var horizontal := _aim_direction()
	var target := player_pos + horizontal * minf(SHOOTER_RANGE, player_pos.distance_to(aim_pos))
	var origin := player_pos + horizontal * 0.55 + Vector3.UP * 1.05
	var velocity := (target - origin).normalized() * SHOOTER_SPEED
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	node.mesh = mesh
	node.material_override = _flat_material(orange_color)
	node.position = origin
	add_child(node)
	projectiles.append({"mesh": node, "velocity": velocity, "travel": 0.0, "kind": "shooter", "max_travel": SHOOTER_RANGE + 1.0})


func _fire_blaster() -> void:
	shot_cooldown = BLASTER_INTERVAL
	player_ink -= BLASTER_COST
	var direction := _aim_direction()
	var origin := player_pos + direction * 0.55 + Vector3.UP * 1.05
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	node.mesh = mesh
	node.material_override = _flat_material(orange_color)
	node.position = origin
	add_child(node)
	projectiles.append({"mesh": node, "velocity": direction * BLASTER_SPEED, "travel": 0.0, "kind": "blaster", "max_travel": BLASTER_RANGE})


func _burst_blaster(at: Vector3, direct_hit: bool) -> void:
	paint.splat(at, BLASTER_PAINT_RADIUS, 0, randf())
	if bot_respawn > 0.0:
		return
	if direct_hit:
		_damage_bot(BLASTER_DIRECT_DAMAGE)
		return
	var distance := Vector2(at.x - bot_pos.x, at.z - bot_pos.z).length()
	if distance <= BLASTER_SPLASH_RADIUS:
		_damage_bot(lerpf(70.0, 30.0, distance / BLASTER_SPLASH_RADIUS))


func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot := projectiles[index]
		var node: MeshInstance3D = shot["mesh"]
		var travel: float = shot["travel"]
		var step: Vector3 = shot["velocity"] * delta
		var previous := node.position
		node.position += step
		travel += step.length()
		shot["travel"] = travel
		var hit_bot := false
		var impact := node.position
		if bot_respawn <= 0.0 and step.length_squared() > 0.0:
			var toward_bot := bot_pos + Vector3.UP * 0.8 - previous
			var fraction := clampf(toward_bot.dot(step) / step.length_squared(), 0.0, 1.0)
			impact = previous + step * fraction
			hit_bot = impact.distance_to(bot_pos + Vector3.UP * 0.8) < 0.65
		if shot["kind"] == "blaster":
			if hit_bot or travel >= shot["max_travel"]:
				_burst_blaster(impact if hit_bot else node.position, hit_bot)
				node.queue_free()
				projectiles.remove_at(index)
		elif hit_bot or node.position.y <= 0.0 or travel >= shot["max_travel"]:
			if hit_bot:
				_damage_bot(36.0)
				paint.splat(bot_pos, SHOOTER_RADIUS, 0, randf())
			else:
				paint.splat(node.position, SHOOTER_RADIUS, 0, randf())
			node.queue_free()
			projectiles.remove_at(index)


func _update_beam_visuals(delta: float) -> void:
	for index in range(beam_visuals.size() - 1, -1, -1):
		var beam := beam_visuals[index]
		beam["life"] = float(beam["life"]) - delta
		if beam["life"] <= 0.0:
			(beam["mesh"] as MeshInstance3D).queue_free()
			beam_visuals.remove_at(index)


func _update_bot(delta: float) -> void:
	if bot_respawn > 0.0:
		bot_respawn -= delta
		if bot_respawn <= 0.0:
			bot_pos = Vector3(0.0, 0.0, 13.0)
			bot_health = 100.0
			bot_model.position = bot_pos
			bot_model.visible = true
		return
	bot_goal_timer -= delta
	if bot_goal_timer <= 0.0 or bot_pos.distance_to(bot_goal) < 1.0:
		bot_goal = Vector3(randf_range(-16.0, 16.0), 0.0, randf_range(-16.0, 16.0))
		bot_goal_timer = 3.5
	bot_pos = bot_pos.move_toward(bot_goal, 3.5 * delta)
	bot_model.position = bot_pos
	var toward := bot_goal - bot_pos
	if toward.length_squared() > 0.01:
		bot_model.rotation.y = atan2(-toward.x, -toward.z)
	bot_paint_cooldown -= delta
	if bot_paint_cooldown <= 0.0:
		bot_paint_cooldown = 0.22
		paint.splat(bot_pos + toward.normalized() * 1.2, 0.7, 1, randf())
	bot_attack_cooldown -= delta
	if player_respawn <= 0.0 and bot_pos.distance_to(player_pos) < 5.0 and bot_attack_cooldown <= 0.0:
		bot_attack_cooldown = 1.2
		player_health -= 18.0
		paint.splat(player_pos, 0.8, 1, randf())
		if player_health <= 0.0:
			player_respawn = RESPAWN_TIME
			_reset_charger()
			player_model.visible = false


func _damage_bot(amount: float) -> void:
	bot_health -= amount
	if bot_health <= 0.0:
		bot_respawn = 4.0
		bot_model.visible = false


func _update_hud() -> void:
	_refresh_weapon_art()
	ink_bar_fill.size.x = 300.0 * clampf(player_ink / 100.0, 0.0, 1.0)
	var selection_visible := phase == "setup" or (phase == "playing" and player_respawn > 0.0)
	menu_back.visible = phase != "playing" or selection_visible
	title_label.visible = menu_back.visible
	weapon_select.visible = selection_visible
	center_label.offset_top = -90.0 if phase == "results" else -110.0
	center_label.offset_bottom = 90.0 if phase == "results" else 5.0
	var weapon_names := {"shooter": "射手", "roller": "滚筒", "charger": "蓄力狙", "blaster": "爆破枪"}
	var weapon_name: String = weapon_names[selected_weapon]
	var charge_text := "    蓄力 %d%%" % int(charger_fraction * 100.0) if charger_charging else ""
	top_label.text = "INKWAVE · Godot 迁移样机    FPS %d\n橙队 %.1f%%    蓝队 %.1f%%    剩余 %ds\n武器 %s    墨量 %d    生命 %d%s" % [Engine.get_frames_per_second(), paint.coverage(0), paint.coverage(1), int(ceil(round_left)), weapon_name, int(player_ink), int(maxf(player_health, 0.0)), charge_text]
	if phase == "setup":
		center_label.text = "Godot 原生迁移样机\n按 1–4 选武器，Enter 开始对局"
		help_label.text = "移植范围：移动 / 潜墨加速与回墨 / 四种武器 / 双方涂墨计分"
	elif phase == "results":
		var orange_score := paint.coverage(0)
		var blue_score := paint.coverage(1)
		var result := "平局"
		if orange_score > blue_score:
			result = "橙队胜利"
		elif blue_score > orange_score:
			result = "蓝队胜利"
		center_label.text = "%s\n橙 %.1f%%  :  蓝 %.1f%%\n按 Enter 重开" % [result, orange_score, blue_score]
		help_label.text = ""
	elif player_respawn > 0.0:
		center_label.text = "被击倒 · %.1f 秒后重生\n可按 1–4 更换武器" % player_respawn
		help_label.text = "WASD 移动 · 鼠标瞄准 · 左键使用武器 · Shift 潜墨"
	else:
		center_label.text = ""
		help_label.text = "WASD 移动 · 鼠标瞄准 · 左键使用武器（蓄力狙松开发射）· Shift 潜墨 · R 重开"
