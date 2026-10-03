extends Node3D

const Original := preload("res://src/actors/tidewater_character_visual.gd")
const Candidate := preload("res://experiments/character-sample/visual.gd")
var models: Array[Node3D] = []
var camera: Camera3D
var angle := -0.28
var mode := "idle"
var portrait := false
var team := 0
var capturing := false
var status: Label

func _ready() -> void:
	get_window().title = "INKWAVE · 人物造型样板"
	get_window().size = Vector2i(1280,720)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("141b2b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5dfee")
	environment.ambient_light_energy = .48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32,-32,0)
	key.light_color = Color("ffefdc")
	key.light_energy = 1.05
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25,140,0)
	rim.light_color = Color("96c9ef")
	rim.light_energy = .45
	add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	for x in [-.58,.58]:
		var floor_mesh := CylinderMesh.new()
		floor_mesh.top_radius = .44
		floor_mesh.bottom_radius = .44
		floor_mesh.height = .028
		floor_mesh.radial_segments = 64
		var floor_node := MeshInstance3D.new()
		floor_node.mesh = floor_mesh
		floor_node.position = Vector3(x,-.014,0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("28344b")
		material.roughness = .85
		floor_node.material_override = material
		add_child(floor_node)
	_build_models()
	_build_ui()
	_update_camera()
	if OS.get_cmdline_user_args().has("--capture"):
		capturing = true
		call_deferred("_capture")

func _build_models() -> void:
	for model in models:
		remove_child(model)
		model.queue_free()
	models.clear()
	for i in 2:
		var model: Node3D = Original.new() if i == 0 else Candidate.new()
		model.team = team
		model.style_index = 0
		model.ornament_seed = 41
		model.position.x = -.58 if i == 0 else .58
		add_child(model)
		model.set_physics_process(false)
		model.configure_animation({"runSpeed":6.0})
		model.set("_blink_remaining",8.0)
		models.append(model)
	_set_mode(mode)
	_update_camera()

func _process(delta: float) -> void:
	if capturing:
		return
	for model in models:
		model.rotation.y = angle
		model.call("_animate",minf(delta,.05))
		if mode == "shoot" and model.action_time <= 0.0:
			model.set_action("shoot")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		angle += event.relative.x * .008
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(.55,camera.size*.92)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(2.8,camera.size*1.08)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:_set_mode("idle")
		elif event.keycode == KEY_2:_set_mode("run")
		elif event.keycode == KEY_3:_set_mode("shoot")
		elif event.keycode == KEY_ESCAPE:get_tree().quit()

func _set_mode(next: String) -> void:
	mode = next
	for model in models:
		model.moving = mode == "run"
		model.anim_speed = 5.5 if mode == "run" else 0.0
		model.set_aim(mode == "shoot")
		if mode == "shoot":model.set_action("shoot")
	if status != null:
		status.text = "同一灯光 · 同一动作 · 拖动旋转 / 滚轮缩放 · 1 待机  2 跑步  3 射击"

func _update_camera() -> void:
	for i in models.size():
		models[i].position.x = (-1.0 if i == 0 else 1.0)*(.29 if portrait else .58)
	var focus := Vector3(0,1.135 if portrait else .70,0)
	camera.position = focus + Vector3(0,.025 if portrait else .13,5)
	camera.look_at(focus)
	camera.size = .82 if portrait else 2.05

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
	_label(ui,"INKWAVE / CHARACTER STUDY",Vector2(36,24),28,Color("e8eef9"))
	_label(ui,"人物候选 A · 肩颈比例 / 眉眼 / 五束触须 / 哑光服装",Vector2(37,64),16,Color("a6b4ca"))
	_label(ui,"当前角色",Vector2(305,96),20,Color("aab9d0"))
	_label(ui,"WAVE · 候选样板",Vector2(811,96),20,Color("ffd270"))
	status = _label(ui,"",Vector2(36,623),15,Color("93a6c1"))
	var bar := HBoxContainer.new()
	bar.position = Vector2(36,659)
	bar.add_theme_constant_override("separation",10)
	ui.add_child(bar)
	for id in ["idle","run","shoot","portrait","team","reset"]:
		var button := Button.new()
		button.text = {"idle":"待机","run":"跑步","shoot":"射击","portrait":"全身 / 脸部","team":"切换队色","reset":"复位"}[id]
		button.custom_minimum_size = Vector2(116,40)
		button.pressed.connect(_button.bind(id))
		bar.add_child(button)
	_set_mode(mode)

func _label(parent: Control,text: String,at: Vector2,size: int,color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _button(id: String) -> void:
	if id in ["idle","run","shoot"]:_set_mode(id)
	elif id == "portrait":
		portrait = not portrait
		_update_camera()
	elif id == "team":
		team = 1-team
		_build_models()
	elif id == "reset":
		angle = -.28
		portrait = false
		_update_camera()
		_set_mode("idle")

func _settle(frames: int) -> void:
	for i in frames:
		for model in models:
			model.rotation.y = angle
			model.call("_animate",1.0/30.0)
		await get_tree().process_frame

func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://render-evidence/sample-"+label+".png"
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
	await _save("comparison")
	portrait = true
	angle = 0.0
	_update_camera()
	await _settle(3)
	await _save("face")
	portrait = false
	angle = PI
	_update_camera()
	await _settle(3)
	await _save("back")
	angle = -.42
	_set_mode("run")
	await _settle(24)
	await _save("running")
	_set_mode("shoot")
	await _settle(35)
	for model in models:model.set_action("shoot")
	await _settle(3)
	await _save("shooting")
	team = 1
	_build_models()
	_set_mode("idle")
	await _settle(35)
	await _save("blue")
	if not await _verify_controls():
		get_tree().quit(1)
		return
	print("PASS: original/candidate same-light full/face/back/run/shoot/two-team native captures; sample only")
	get_tree().quit()

func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = at
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	get_viewport().push_input(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.position = at
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	get_viewport().push_input(up)
	await get_tree().process_frame

func _verify_controls() -> bool:
	await _click(Vector2(210,679))
	if mode != "run":push_error("Run button did not respond");return false
	await _click(Vector2(338,679))
	if mode != "shoot":push_error("Shoot button did not respond");return false
	await _click(Vector2(463,679))
	if not portrait:push_error("Portrait button did not respond");return false
	await _click(Vector2(590,679))
	if team != 0 or not is_equal_approx(models[1].position.x,.29):
		push_error("Team change lost portrait framing");return false
	await _click(Vector2(717,679))
	if portrait or mode != "idle":push_error("Reset button did not respond");return false
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(630,360)
	motion.relative = Vector2(70,0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	var before := angle
	get_viewport().push_input(motion)
	if is_equal_approx(before,angle):push_error("Drag rotation did not respond");return false
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(630,360)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	before = camera.size
	get_viewport().push_input(wheel)
	if camera.size >= before:push_error("Wheel zoom did not respond");return false
	_button("reset")
	print("PASS: viewport mouse input reached run/shoot/portrait/team/reset buttons; portrait framing retained, drag and wheel responded")
	return true
