extends Node3D

const Character := preload("res://character-sculpt/avatar.gd")
const Wardrobe := preload("res://character-sculpt/wardrobe.gd")
var model: Node3D
var camera: Camera3D
var angle := -.32
var portrait := false
var mode := "idle"
var team := 0
var capturing := false
var status: Label
var wardrobe_label: Label
var shirt_design := 0
var wardrobe_rng:=RandomNumberGenerator.new()

func _ready() -> void:
	get_window().title = "INKWAVE · WAVE 人物与随机 T 恤"
	wardrobe_rng.randomize()
	shirt_design=0 if OS.get_cmdline_user_args().has("--capture") else wardrobe_rng.randi_range(0,Wardrobe.DESIGNS.size()-1)
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
	model.shirt_design=shirt_design
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
		elif event.keycode == KEY_R: _random_shirt()
		elif event.keycode == KEY_ESCAPE: get_tree().quit()

func _set_mode(value: String) -> void:
	mode = value
	model.moving = value == "run"
	model.anim_speed = 5.5 if value == "run" else 0.0
	model.set_aim(value == "shoot")
	if value == "shoot": model.set_action("shoot")
	if status != null: status.text="拖动旋转 · 滚轮缩放 · 1 待机 / 2 跑步 / 3 射击 · R 随机 T 恤 · Esc 退出"

func _update_camera() -> void:
	var focus := Vector3(0,1.155 if portrait else .71,0)
	camera.position = focus+Vector3(0,.01 if portrait else .16,5)
	camera.look_at(focus)
	camera.size = .49 if portrait else 1.83

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
	_label(ui,"WAVE / SCULPT 03",Vector2(36,24),30,Color("233348"))
	_label(ui,"新头部 · 原身体与动作",Vector2(36,69),17,Color("40536b"))
	_label(ui,"小头比例 / 闭口微笑 / 分层细发",Vector2(37,99),15,Color("53687f"))
	wardrobe_label=_label(ui,"",Vector2(37,130),15,Color("40536b"))
	_update_wardrobe_label()
	status=_label(ui,"",Vector2(36,620),15,Color("40536b"))
	var bar := HBoxContainer.new()
	bar.position = Vector2(36,659)
	bar.add_theme_constant_override("separation",10)
	ui.add_child(bar)
	for id in ["idle","run","shoot","portrait","team","random_shirt","next_shirt","reset"]:
		var button := Button.new()
		button.text={"idle":"待机","run":"跑步","shoot":"射击","portrait":"全身 / 脸部","team":"切换队色","random_shirt":"随机 T 恤","next_shirt":"下一款 T 恤","reset":"复位"}[id]
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
	elif id == "random_shirt":_random_shirt()
	elif id == "next_shirt":_set_shirt(shirt_design+1)
	elif id == "reset":
		angle=-.32
		portrait=false
		_update_camera()
		_set_mode("idle")

func _set_shirt(index: int) -> void:
	shirt_design=posmod(index,Wardrobe.DESIGNS.size())
	model.set_shirt_design(shirt_design)
	_update_wardrobe_label()

func _random_shirt() -> void:
	_set_shirt(shirt_design+wardrobe_rng.randi_range(1,Wardrobe.DESIGNS.size()-1))

func _update_wardrobe_label() -> void:
	if wardrobe_label!=null:wardrobe_label.text="T 恤 %02d / %s" % [shirt_design+1,Wardrobe.DESIGNS[shirt_design].name]

func _save(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var path := "res://render-evidence/sculpt-v3-"+label+".png"
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
	model.head_visual.set_clay(true)
	await _save("clay")
	model.head_visual.set_clay(false)
	angle=-PI/2
	await _save("profile")
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
	team=0
	_build_model()
	for index in Wardrobe.DESIGNS.size():
		_set_shirt(index)
		await _save("tee-%02d" % [index+1])
	if not await _verify_controls():
		get_tree().quit(1)
		return
	print("PASS: native new-model full/face/back/run/shoot/two-team captures")
	get_tree().quit()

func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position=at
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	get_viewport().push_input(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.position=at
	up.button_index=MOUSE_BUTTON_LEFT
	up.pressed=false
	get_viewport().push_input(up)
	await get_tree().process_frame

func _verify_controls() -> bool:
	await _click(Vector2(220,679))
	if mode!="run": push_error("Run button did not respond");return false
	await _click(Vector2(346,679))
	if mode!="shoot": push_error("Shoot button did not respond");return false
	await _click(Vector2(472,679))
	if not portrait: push_error("Portrait button did not respond");return false
	await _click(Vector2(598,679))
	if team!=1 or not portrait or not is_equal_approx(camera.size,.49):
		push_error("Team change lost portrait framing");return false
	var previous_model:=model
	var previous_shirt:=shirt_design
	await _click(Vector2(724,679))
	if shirt_design==previous_shirt or model!=previous_model or not portrait:
		push_error("Random tee failed or reset the model/framing");return false
	previous_shirt=shirt_design
	await _click(Vector2(850,679))
	if shirt_design!=posmod(previous_shirt+1,Wardrobe.DESIGNS.size()):
		push_error("Next tee button failed");return false
	await _click(Vector2(976,679))
	if portrait or mode!="idle": push_error("Reset button did not respond");return false
	var motion := InputEventMouseMotion.new()
	motion.position=Vector2(630,360)
	motion.relative=Vector2(70,0)
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	var before := angle
	get_viewport().push_input(motion)
	if is_equal_approx(before,angle): push_error("Drag rotation did not respond");return false
	var wheel := InputEventMouseButton.new()
	wheel.position=Vector2(630,360)
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	before=camera.size
	get_viewport().push_input(wheel)
	if camera.size>=before: push_error("Wheel zoom did not respond");return false
	for key in [KEY_1,KEY_2,KEY_3]:
		var input := InputEventKey.new()
		input.keycode=key
		input.pressed=true
		get_viewport().push_input(input)
		await get_tree().process_frame
		if mode!={KEY_1:"idle",KEY_2:"run",KEY_3:"shoot"}[key]:
			push_error("Action keyboard shortcut did not respond");return false
	previous_shirt=shirt_design
	var random_input:=InputEventKey.new()
	random_input.keycode=KEY_R
	random_input.pressed=true
	get_viewport().push_input(random_input)
	await get_tree().process_frame
	if shirt_design==previous_shirt:push_error("Random tee keyboard shortcut failed");return false
	_button("reset")
	print("PASS: viewport buttons, random/next tee, preserved portrait, R/1/2/3 keyboard, drag and wheel")
	return true

func _settle(frames: int) -> void:
	for i in frames:
		model.call("_animate",1.0/30.0)
		await get_tree().process_frame
