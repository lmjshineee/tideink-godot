extends SubViewportContainer
# Actual selected map geometry in its own world; no ink grids, AI or match camera.
var view: SubViewport
var map: Node3D
var camera: Camera3D
var yaw := 1.02
var pitch := 0.38
var span := 120.0
var zoom := 1.0
var dragging := false
var enabled := false
var asset_id := ""
var refresh_frames := 0

func setup() -> void:
	stretch=true;mouse_filter=MOUSE_FILTER_STOP;gui_input.connect(_inspect_input)
	view=SubViewport.new();view.size=Vector2i(960,300);view.own_world_3d=true;view.gui_disable_input=true;add_child(view)
	resized.connect(_request_refresh);view.size_changed.connect(_request_refresh)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("b7d7e2")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("deedff");environment.environment.ambient_light_energy=0.72;view.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);light.light_energy=1.35;light.shadow_enabled=true;light.directional_shadow_max_distance=250;view.add_child(light)
	asset_id=preload("res://src/core/map_catalog.gd").asset_id()
	map=preload("res://src/world/tidewater_map.gd").new()
	var scenery:=preload("res://src/world/tidewater_scenery.gd").new();map.add_child(scenery);view.add_child(map)
	span=maxf(map.map_bounds.size.x,map.map_bounds.size.y)*1.55
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.current=true;camera.far=1200;view.add_child(camera);_update_camera()

func set_enabled(value: bool) -> void:
	if enabled!=value:
		enabled=value
		if value:_request_refresh()
		else:view.render_target_update_mode=SubViewport.UPDATE_DISABLED;refresh_frames=0
	if not value:dragging=false

func _inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom=clampf(zoom+(-0.08 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.08),0.7,1.45);_update_camera()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		yaw-=event.relative.x*0.006;pitch=clampf(pitch+event.relative.y*0.005,0.18,0.75);_update_camera();accept_event()

func _update_camera() -> void:
	camera.size=span*zoom
	var target:=Vector3(0,2.4,0)
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*span*1.4
	camera.look_at(target);_request_refresh()

func _request_refresh() -> void:
	if enabled:
		# Resize reallocates the render target. Draw several frames before caching it.
		refresh_frames=3;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func _process(_delta:float) -> void:
	if refresh_frames>0:
		refresh_frames-=1
		if refresh_frames==0:view.render_target_update_mode=SubViewport.UPDATE_ONCE
