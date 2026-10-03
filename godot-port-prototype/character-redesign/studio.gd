extends Node3D

const Character := preload("res://character-redesign/avatar.gd")
var model: Node3D
var camera: Camera3D
var angle := -.32
var portrait := false
var mode := "idle"
var team := 0
var capturing := false
var status: Label

func _ready() -> void:
	get_window().title = "INKWAVE · WAVE 新人物"
	get_window().size = Vector2i(1280,720)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().scaling_3d_scale = 1.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("bac6d2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dae2ee")
	environment.ambient_light_energy = .43
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35,-32,0)
	key.light_color = Color("fff1de")
	key.light_energy = .85
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 8.0
	key.shadow_blur = 2.0
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20,145,0)
	rim.light_color = Color("c5e0ff")
	rim.light_energy = .35
	add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10,0,0)
	fill.light_color = Color("e1e9ff")
	fill.light_energy = .25
	add_child(fill)
	var platform := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .49
	cylinder.bottom_radius = .49
	cylinder.height = .022
	cylinder.radial_segments = 64
	platform.mesh = cylinder
	platform.position.y = -.004
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color("8f9faf")
	platform_material.roughness = .90
	platform.material_override = platform_material
	add_child(platform)
	_build_model()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	_build_ui()
	_update_camera()
	if OS.get_cmdline_user_args().has("--capture"):
		capturing = true
		call_deferred("_capture")

func _build_model() -> void:
	if model != null:
		remove_child(model)
		model.queue_free()
	model = Character.new()
	model.team = team
	model.ornament_seed = 41
	add_child(model)
	model.set_physics_process(false)
	model.configure_animation({"runSpeed":6.0})
	_set_mode(mode)

func _process(delta: float) -> void:
	model.rotation.y = angle
	if not capturing:
		model.call("_animate",minf(delta,.05))
		if mode == "shoot" and model.action_time <= 0.0: model.set_action("shoot")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		angle += event.relative.x*.008
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.size=maxf(.50,camera.size*.92)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.size=minf(2.6,camera.size*1.08)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: _set_mode("idle")
		elif event.keycode == KEY_2: _set_mode("run")
		elif event.keycode == KEY_3: _set_mode("shoot")
		elif event.keycode == KEY_ESCAPE: get_tree().quit()

func _set_mode(value: String) -> void:
	mode = value
	model.moving = value == "run"
	model.anim_speed = 5.5 if value == "run" else 0.0
	model.set_aim(value == "shoot")
	if value == "shoot": model.set_action("shoot")
	if status != null: status.text="拖动旋转 · 滚轮缩放 · 1 待机 / 2 跑步 / 3 射击 · Esc 退出"

func _update_camera() -> void:
	var focus := Vector3(0,1.20 if portrait else .73,0)
	camera.position = focus+Vector3(0,.01 if portrait else .16,5)
	camera.look_at(focus)
	camera.size = .60 if portrait else 1.88

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansSC.ttf")
	theme.default_font_size = 16
	ui.theme = theme
	layer.add_child(ui)
	_label(ui,"WAVE / 01",Vector2(36,24),30,Color("233348"))
	_label(ui,"新头部 · 原身体与动作",Vector2(36,69),17,Color("40536b"))
	_label(ui,"重建脸型 / 眉眼 / 触须发束",Vector2(37,99),15,Color("53687f"))
	status=_label(ui,"",Vector2(36,620),15,Color("40536b"))
	var bar := HBoxContainer.new()
	bar.position = Vector2(36,659)
	bar.add_theme_constant_override("separation",10)
	ui.add_child(bar)
	for id in ["idle","run","shoot","portrait","team","reset"]:
		var button := Button.new()
		button.text={"idle":"待机","run":"跑步","shoot":"射击","portrait":"全身 / 脸部","team":"切换队色","reset":"复位"}[id]
		button.custom_minimum_size=Vector2(116,40)
		button.pressed.connect(_button.bind(id))
		bar.add_child(button)
	_set_mode(mode)

func _label(parent: Control,value: String,at: Vector2,size: int,color: Color) -> Label:
	var label := Label.new()
	label.text=value
	label.position=at
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _button(id: String) -> void:
	if id in ["idle","run","shoot"]: _set_mode(id)
	elif id == "portrait":
		portrait=not portrait
		_update_camera()
	elif id == "team":
		team=1-team
		_build_model()
	elif id == "reset":
		angle=-.32
		portrait=false
		_update_camera()
		_set_mode("idle")

func _save(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://render-evidence/redesign-"+label+".png"
	if get_viewport().get_texture().get_image().save_png(path) != OK:
		push_error("Cannot save "+path)
		get_tree().quit(1)
	print("saved ",path)

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires native graphics")
		get_tree().quit(1)
		return
	await _settle(45)
	await _save("full")
	portrait=true
	angle=0.0
	_update_camera()
	await _save("face")
	angle=-.70
	await _save("face-three-quarter")
	portrait=false
	angle=PI
	_update_camera()
	await _save("back")
	angle=-.38
	_set_mode("run")
	await _settle(24)
	await _save("run")
	_set_mode("shoot")
	await _settle(4)
	await _save("shoot")
	team=1
	_build_model()
	_set_mode("idle")
	await _settle(35)
	await _save("blue")
	print("PASS: native new-model full/face/back/run/shoot/two-team captures")
	get_tree().quit()

func _settle(frames: int) -> void:
	for i in frames:
		model.call("_animate",1.0/30.0)
		await get_tree().process_frame
