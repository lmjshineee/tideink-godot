extends RefCounted

# The settings panel can edit this small, validated model without knowing how the
# scene applies frame limits or mouse look. Renderer choice remains a build setting.
const USER_PATH := "user://inkwave_settings.cfg"
const FPS_OPTIONS := [30, 45, 60]
const DEFAULT_FPS := 30
const UI_SCALE_OPTIONS := [0.9, 1.0, 1.1]
const DEFAULT_UI_SCALE := 1.0
const DEFAULT_LOOK_SENSITIVITY := 0.0021
const MIN_LOOK_SENSITIVITY := 0.0005
const MAX_LOOK_SENSITIVITY := 0.006

var fps_cap := DEFAULT_FPS
var ui_scale := DEFAULT_UI_SCALE
var mouse_sensitivity := DEFAULT_LOOK_SENSITIVITY


func load_from(path: String = USER_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	var saved_fps: Variant = config.get_value("display", "fps_cap", DEFAULT_FPS)
	fps_cap = int(saved_fps) if saved_fps is int and FPS_OPTIONS.has(int(saved_fps)) else DEFAULT_FPS
	var saved_scale: Variant = config.get_value("display", "ui_scale", DEFAULT_UI_SCALE)
	ui_scale = float(saved_scale) if (saved_scale is float or saved_scale is int) and UI_SCALE_OPTIONS.has(float(saved_scale)) else DEFAULT_UI_SCALE
	var saved_sensitivity: Variant = config.get_value("controls", "mouse_sensitivity", DEFAULT_LOOK_SENSITIVITY)
	mouse_sensitivity = clampf(float(saved_sensitivity), MIN_LOOK_SENSITIVITY, MAX_LOOK_SENSITIVITY) \
		if saved_sensitivity is float or saved_sensitivity is int else DEFAULT_LOOK_SENSITIVITY
	return true


func save_to(path: String = USER_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("display", "fps_cap", fps_cap)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	return config.save(path)


func apply_to(walker: Node) -> void:
	Engine.max_fps = fps_cap
	walker.set("look_sensitivity", mouse_sensitivity)
