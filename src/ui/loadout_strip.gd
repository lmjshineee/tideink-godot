extends ScrollContainer
# One clipped row per category. Wheel, trackpad pan, bar drag and keyboard focus.
func _ready() -> void:
	horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	get_h_scroll_bar().custom_minimum_size.y=8

func _gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT]:
			scroll_horizontal-=100;accept_event()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_RIGHT]:
			scroll_horizontal+=100;accept_event()
	elif event is InputEventPanGesture:
		scroll_horizontal+=roundi((event.delta.x+event.delta.y)*45);accept_event()
