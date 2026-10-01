extends Panel

signal saved
signal closed

const TeamPalette := preload("res://team_palette.gd")
const Settings = preload("res://tidewater_settings.gd")

var model: RefCounted
var save_path := Settings.USER_PATH
var render_scale_button: OptionButton
var fps_button: OptionButton
var ui_scale_button: OptionButton
var sensitivity_slider: HSlider
var sensitivity_label: Label
var feedback_label: Label
var reset_button: Button
var save_button: Button
var cancel_button: Button
var volume_sliders: Dictionary = {}


func _ready() -> void:
	name = "SettingsPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.075, 0.98)
	style.border_color = TeamPalette.color(0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	add_theme_stylebox_override("panel", style)
	_build_theme()
	var title := _label("偏好设置", 26, Color("f1f2f7"))
	title.name = "Title"
	var renderer := _label("画面  /  界面  /  操作  /  声音", 14, Color("8d9ab2"))
	renderer.name = "RendererInfo"
	var fps_label := _label("帧率上限", 18, Color.WHITE)
	fps_label.name = "FpsLabel"
	fps_button = OptionButton.new()
	fps_button.name = "FpsChoice"
	fps_button.add_item("30 FPS · 省电", 30)
	fps_button.add_item("45 FPS", 45)
	fps_button.add_item("60 FPS", 60)
	add_child(fps_button)
	var render_label := _label("画面精度",18,Color.WHITE)
	render_label.name = "RenderScaleLabel"
	render_scale_button = OptionButton.new()
	render_scale_button.name = "RenderScaleChoice"
	render_scale_button.add_item("均衡 · 75%",75)
	render_scale_button.add_item("清晰 · 100%",100)
	add_child(render_scale_button)
	var ui_scale_label := _label("界面缩放", 18, Color.WHITE)
	ui_scale_label.name = "UiScaleLabel"
	ui_scale_button = OptionButton.new()
	ui_scale_button.name = "UiScaleChoice"
	ui_scale_button.add_item("90%", 90)
	ui_scale_button.add_item("100%", 100)
	ui_scale_button.add_item("110%", 110)
	add_child(ui_scale_button)
	sensitivity_label = _label("鼠标灵敏度", 18, Color.WHITE)
	sensitivity_label.name = "SensitivityLabel"
	sensitivity_slider = HSlider.new()
	sensitivity_slider.name = "SensitivitySlider"
	sensitivity_slider.min_value = Settings.MIN_LOOK_SENSITIVITY
	sensitivity_slider.max_value = Settings.MAX_LOOK_SENSITIVITY
	sensitivity_slider.step = 0.0001
	sensitivity_slider.value_changed.connect(_update_sensitivity_label)
	add_child(sensitivity_slider)
	for key in ["master_volume","music_volume","sfx_volume"]:
		var label := _label({"master_volume":"总音量","music_volume":"音乐","sfx_volume":"音效"}[key],17,Color.WHITE)
		label.name = key+"Label"
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		add_child(slider)
		volume_sliders[key] = slider
	var hint := _label("保存应用更改 · Esc 取消", 14, Color("b5c2d9"))
	hint.name = "Hint"
	reset_button = _button("恢复默认", "ResetButton", _on_reset_pressed)
	save_button = _button("保存并关闭", "SaveButton", _on_save_pressed)
	var save_style := StyleBoxFlat.new()
	save_style.bg_color = TeamPalette.color(0)
	save_style.set_corner_radius_all(8)
	save_button.add_theme_stylebox_override("normal", save_style)
	save_style = save_style.duplicate()
	save_style.bg_color = TeamPalette.color(0).lightened(0.25)
	save_button.add_theme_stylebox_override("hover", save_style)
	save_button.add_theme_color_override("font_color", Color("141821"))
	save_button.add_theme_color_override("font_hover_color", Color("141821"))
	cancel_button = _button("取消", "CancelButton", close_panel)
	feedback_label = _label("", 14, Color("ff7676"))
	feedback_label.name = "Feedback"
	resized.connect(_layout_controls)
	_layout_controls()


func open_with(current_model: RefCounted, path: String = Settings.USER_PATH) -> void:
	model = current_model
	save_path = path
	render_scale_button.select(0 if float(model.get("render_scale")) < 1.0 else 1)
	var selected_fps := int(model.get("fps_cap"))
	for index in fps_button.item_count:
		if fps_button.get_item_id(index) == selected_fps:
			fps_button.select(index)
			break
	var selected_scale := int(roundf(float(model.get("ui_scale")) * 100.0))
	for index in ui_scale_button.item_count:
		if ui_scale_button.get_item_id(index) == selected_scale:
			ui_scale_button.select(index)
			break
	sensitivity_slider.value = float(model.get("mouse_sensitivity"))
	for key in volume_sliders:
		volume_sliders[key].value = float(model.get(key))
	_update_sensitivity_label(sensitivity_slider.value)
	feedback_label.text = ""
	visible = true
	fps_button.grab_focus()


func close_panel() -> void:
	visible = false
	closed.emit()


func _on_reset_pressed() -> void:
	fps_button.select(0)
	render_scale_button.select(0)
	ui_scale_button.select(1)
	sensitivity_slider.value = Settings.DEFAULT_LOOK_SENSITIVITY
	for key in volume_sliders:
		volume_sliders[key].value = Settings.new().get(key)
	feedback_label.text = ""


func _on_save_pressed() -> void:
	if model == null:
		return
	var draft := Settings.new()
	draft.render_scale = float(render_scale_button.get_selected_id()) / 100.0
	draft.fps_cap = fps_button.get_selected_id()
	draft.ui_scale = float(ui_scale_button.get_selected_id()) / 100.0
	draft.mouse_sensitivity = sensitivity_slider.value
	for key in volume_sliders:
		draft.set(key,volume_sliders[key].value)
	if draft.save_to(save_path) != OK:
		feedback_label.text = "保存失败，请检查设置文件权限。"
		return
	model.set("render_scale", draft.render_scale)
	model.set("fps_cap", draft.fps_cap)
	model.set("ui_scale", draft.ui_scale)
	model.set("mouse_sensitivity", draft.mouse_sensitivity)
	for key in volume_sliders:
		model.set(key,draft.get(key))
	visible = false
	saved.emit()
	closed.emit()


func _update_sensitivity_label(value: float) -> void:
	sensitivity_label.text = "瞄准灵敏度  %d%%" % roundi(value / Settings.DEFAULT_LOOK_SENSITIVITY * 100.0)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _button(value: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = value
	button.pressed.connect(callback)
	add_child(button)
	return button


func _layout_controls() -> void:
	var pad := 24.0
	var width := size.x - pad * 2.0
	get_node("Title").position = Vector2(pad,20)
	get_node("Title").size = Vector2(width,38)
	get_node("RendererInfo").position = Vector2(pad,58)
	get_node("RendererInfo").size = Vector2(width,24)
	var labels := [get_node("FpsLabel"),get_node("RenderScaleLabel"),get_node("UiScaleLabel")]
	var choices := [fps_button,render_scale_button,ui_scale_button]
	for i in range(3):
		labels[i].position = Vector2(pad,100+i*54)
		labels[i].size = Vector2(width*0.42,36)
		choices[i].position = Vector2(pad+width*0.44,100+i*54)
		choices[i].size = Vector2(width*0.56,36)
	sensitivity_label.position = Vector2(pad,268)
	sensitivity_label.size = Vector2(width,28)
	sensitivity_slider.position = Vector2(pad,302)
	sensitivity_slider.size = Vector2(width,24)
	var row := 0
	for key in volume_sliders:
		get_node(key+"Label").position = Vector2(pad,338+row*42)
		get_node(key+"Label").size = Vector2(width*0.35,28)
		volume_sliders[key].position = Vector2(pad+width*0.38,340+row*42)
		volume_sliders[key].size = Vector2(width*0.62,24)
		row += 1
	get_node("Hint").position = Vector2(pad,466)
	get_node("Hint").size = Vector2(width,24)
	var button_width := (width-16)/3.0
	var buttons := [reset_button,cancel_button,save_button]
	for i in range(3):
		buttons[i].position = Vector2(pad+i*(button_width+8),500)
		buttons[i].size = Vector2(button_width,40)
	feedback_label.position = Vector2(pad,548)
	feedback_label.size = Vector2(width,24)
	var fit := minf(1.0,size.y/580.0)
	for control in get_children():
		if control is Control:
			control.position.y *= fit
			control.size.y *= fit


func _build_theme() -> void:
	var skin := Theme.new()
	skin.default_font_size = 16
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("243149") if state == "normal" else Color("344666")
			style.set_corner_radius_all(9)
			style.set_content_margin_all(9)
			if state == "focus":
				style.bg_color = Color.TRANSPARENT
				style.border_color = TeamPalette.color(0).lightened(0.15)
				style.set_border_width_all(2)
			skin.set_stylebox(state,type,style)
		skin.set_color("font_color",type,Color("e9edf5"))
		skin.set_color("font_hover_color",type,Color.WHITE)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("243149")
	track.set_corner_radius_all(3)
	track.set_content_margin_all(3)
	skin.set_stylebox("slider","HSlider",track)
	var fill := track.duplicate()
	fill.bg_color = TeamPalette.color(0)
	skin.set_stylebox("grabber_area","HSlider",fill)
	skin.set_stylebox("grabber_area_highlight","HSlider",fill)
	theme = skin
