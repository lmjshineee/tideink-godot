extends Control

const Character:=preload("res://experiments/character-sculpt/avatar.gd")
const Wardrobe:=preload("res://experiments/character-sculpt/wardrobe.gd")

func _ready() -> void:
	get_window().size=Vector2i(1280,720)
	get_window().title="INKWAVE · 八款 T 恤"
	var background:=ColorRect.new()
	background.color=Color("bac6d2")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var theme:=Theme.new()
	theme.default_font=load("res://assets/fonts/NotoSansSC.ttf")
	theme.default_font_size=17
	self.theme=theme
	_label("WAVE / 8 TEE DESIGNS",Vector2(36,18),27)
	for index in Wardrobe.DESIGNS.size():_tile(index)
	if OS.get_cmdline_user_args().has("--capture"):call_deferred("_capture")

func _tile(index: int) -> void:
	var at:=Vector2(28+308*(index%4),62+326*(index/4))
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(300,280)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world:=Node3D.new()
	viewport.add_child(world)
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("afbfce")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("dae2ee")
	environment.ambient_light_energy=.55
	var settings:=WorldEnvironment.new()
	settings.environment=environment
	world.add_child(settings)
	var key:=DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-30,-25,0)
	key.light_energy=.8
	key.light_color=Color("fff1de")
	world.add_child(key)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-10,140,0)
	fill.light_energy=.3
	world.add_child(fill)
	var model:=Character.new()
	model.ornament_seed=41
	model.shirt_design=index
	world.add_child(model)
	model.set_physics_process(false)
	model.configure_animation({"runSpeed":6.0})
	model.call("_animate",.0)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=.565
	camera.position=Vector3(0,.839,5)
	world.add_child(camera)
	camera.look_at(Vector3(0,.839,0))
	camera.current=true
	var preview:=TextureRect.new()
	preview.texture=viewport.get_texture()
	preview.position=at
	preview.size=Vector2(300,280)
	add_child(preview)
	_label("%02d / %s" % [index+1,Wardrobe.DESIGNS[index].name],at+Vector2(10,286),18)

func _label(value: String,at: Vector2,size_px: int) -> void:
	var label:=Label.new()
	label.text=value
	label.position=at
	label.add_theme_font_size_override("font_size",size_px)
	label.add_theme_color_override("font_color",Color("233348"))
	add_child(label)

func _capture() -> void:
	if DisplayServer.get_name()=="headless":get_tree().quit(1);return
	for frame in 30:await get_tree().process_frame
	RenderingServer.force_draw(false)
	var path:="res://render-evidence/sculpt-v3-wardrobe.png"
	if get_viewport().get_texture().get_image().save_png(path)!=OK:get_tree().quit(1);return
	print("PASS: eight actual tee materials rendered in native Godot gallery")
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:get_tree().quit()
