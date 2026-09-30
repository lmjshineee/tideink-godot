extends Panel

signal saved
signal closed

const TeamPalette := preload("res://team_palette.gd")
const Settings = preload("res://tidewater_settings.gd")

var model: RefCounted
var save_path := Settings.USER_PATH
var fps_button: OptionButton
var ui_scale_button: OptionButton
var sensitivity_slider: HSlider
var sensitivity_label: Label
var feedback_label: Label
var reset_button: Button
var save_button: Button
var cancel_button: Button


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
	var title := _label("设置", 26, TeamPalette.color(0))
	title.name = "Title"
	var method := String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"))
	var renderer_name := "Compatibility" if method == "gl_compatibility" else method
	var renderer := _label("渲染：%s · 切换渲染器需重启" % renderer_name, 15, Color("b5c2d9"))
	renderer.name = "RendererInfo"
	var fps_label := _label("帧率上限", 18, Color.WHITE)
	fps_label.name = "FpsLabel"
	fps_button = OptionButton.new()
	fps_button.name = "FpsChoice"
	fps_button.add_item("30 FPS · 省电", 30)
	fps_button.add_item("45 FPS", 45)
	fps_button.add_item("60 FPS", 60)
	add_child(fps_button)
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
	var hint := _label("重置只修改当前选项；点击保存后生效。", 14, Color("b5c2d9"))
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
	_update_sensitivity_label(sensitivity_slider.value)
	feedback_label.text = ""
	visible = true
	fps_button.grab_focus()


func close_panel() -> void:
	visible = false
	closed.emit()


func _on_reset_pressed() -> void:
	fps_button.select(0)
	ui_scale_button.select(1)
	sensitivity_slider.value = Settings.DEFAULT_LOOK_SENSITIVITY
	feedback_label.text = ""


func _on_save_pressed() -> void:
	if model == null:
		return
	var draft := Settings.new()
	draft.fps_cap = fps_button.get_selected_id()
	draft.ui_scale = float(ui_scale_button.get_selected_id()) / 100.0
	draft.mouse_sensitivity = sensitivity_slider.value
	if draft.save_to(save_path) != OK:
		feedback_label.text = "保存失败，请检查设置文件权限。"
		return
	model.set("fps_cap", draft.fps_cap)
	model.set("ui_scale", draft.ui_scale)
	model.set("mouse_sensitivity", draft.mouse_sensitivity)
	visible = false
	saved.emit()
	closed.emit()


func _update_sensitivity_label(value: float) -> void:
	sensitivity_label.text = "鼠标灵敏度  %.4f" % value


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
	var inner_width := size.x - 32.0
	get_node("Title").position = Vector2(16.0, 16.0)
	get_node("Title").size = Vector2(inner_width, 40.0)
	get_node("RendererInfo").position = Vector2(16.0, 58.0)
	get_node("RendererInfo").size = Vector2(inner_width, 28.0)
	get_node("FpsLabel").position = Vector2(16.0, 97.0)
	get_node("FpsLabel").size = Vector2(inner_width, 28.0)
	fps_button.position = Vector2(16.0, 124.0)
	fps_button.size = Vector2(inner_width, 38.0)
	get_node("UiScaleLabel").position = Vector2(16.0, 173.0)
	get_node("UiScaleLabel").size = Vector2(inner_width, 28.0)
	ui_scale_button.position = Vector2(16.0, 201.0)
	ui_scale_button.size = Vector2(inner_width, 38.0)
	sensitivity_label.position = Vector2(16.0, 251.0)
	sensitivity_label.size = Vector2(inner_width, 28.0)
	sensitivity_slider.position = Vector2(16.0, 282.0)
	sensitivity_slider.size = Vector2(inner_width, 22.0)
	get_node("Hint").position = Vector2(16.0, 314.0)
	get_node("Hint").size = Vector2(inner_width, 24.0)
	var button_width := (inner_width - 16.0) / 3.0
	reset_button.position = Vector2(16.0, 354.0)
	reset_button.size = Vector2(button_width, 40.0)
	save_button.position = Vector2(24.0 + button_width, 354.0)
	save_button.size = Vector2(button_width, 40.0)
	cancel_button.position = Vector2(32.0 + button_width * 2.0, 354.0)
	cancel_button.size = Vector2(button_width, 40.0)
	feedback_label.position = Vector2(16.0, 403.0)
	feedback_label.size = Vector2(inner_width, 24.0)
