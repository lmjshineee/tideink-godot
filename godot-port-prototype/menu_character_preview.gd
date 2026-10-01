extends SubViewportContainer
# Isolated inspection stage. Preview input and animation never reach match actors.
class StageActor extends CharacterBody3D:
	var grounded := true

var view: SubViewport
var actor: StageActor
var model: Node3D
var camera: Camera3D
var enabled := false
var pose := "idle"
var yaw := 0.18
var pitch := 0.08
var distance := 3.5
var dragging := false
var drag_travel := 0.0
var jump_time := -1.0
var fire_time := 0.0
var held := {}

func setup(game: Node3D) -> void:
	stretch=true;mouse_filter=MOUSE_FILTER_STOP;focus_mode=FOCUS_ALL
	gui_input.connect(_inspect_input);focus_exited.connect(func():held.clear())
	view=SubViewport.new();view.transparent_bg=true;view.own_world_3d=true;view.size=Vector2i(420,520)
	view.gui_disable_input=true;add_child(view)
	view.msaa_3d=Viewport.MSAA_4X
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("d7e6ff");environment.environment.ambient_light_energy=0.65
	view.add_child(environment)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-35,0);key.light_energy=1.6;key.shadow_enabled=true;key.directional_shadow_max_distance=8;view.add_child(key)
	var rim:=OmniLight3D.new();rim.position=Vector3(-2,2,-2);rim.light_color=preload("res://team_palette.gd").color(1).lightened(0.4);rim.light_energy=0.8;rim.omni_range=5;view.add_child(rim)
	var plinth:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=0.72;cylinder.bottom_radius=0.8;cylinder.height=0.12;plinth.mesh=cylinder;plinth.position.y=-0.07
	var material:=StandardMaterial3D.new();material.albedo_color=preload("res://team_palette.gd").color(0).darkened(0.45);material.roughness=0.55;plinth.material_override=material;view.add_child(plinth)
	actor=StageActor.new();actor.collision_layer=0;actor.collision_mask=0;view.add_child(actor)
	model=preload("res://tidewater_character_visual.gd").new()
	model.style_index=preload("res://match_setup.gd").style_index;model.ornament_seed=game.get_node("World/Walker/Body").ornament_seed
	actor.add_child(model);model.configure_animation(game.get_node("Combat").weapon_data["player"]);model.set_weapon(game.selected_weapon)
	camera=Camera3D.new();camera.fov=38;camera.current=true;view.add_child(camera);_update_camera()

func set_enabled(value: bool) -> void:
	enabled=value;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	model.set_physics_process(value)
	if not value:dragging=false;held.clear();actor.velocity=Vector3.ZERO

func set_weapon(id: String) -> void:
	if model.current_weapon!=id:model.set_weapon(id)

func set_pose(id: String) -> void:
	pose=id;fire_time=0;model.set_aim(id=="shoot")

func jump() -> void:
	if jump_time<0:jump_time=0

func _inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:grab_focus();dragging=true;drag_travel=0
			else:
				if dragging and drag_travel<6:jump()
				dragging=false
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance=clampf(distance+(-0.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.25),2.65,4.8);_update_camera()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		drag_travel+=event.relative.length();yaw-=event.relative.x*0.012;pitch=clampf(pitch+event.relative.y*0.008,-0.16,0.42);_update_camera();accept_event()
	elif event is InputEventKey and event.keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE]:
		if event.keycode==KEY_SPACE and event.pressed:jump()
		else:held[event.keycode]=event.pressed
		accept_event()

func _update_camera() -> void:
	var target:=Vector3(0,0.88,0)
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func _process(delta: float) -> void:
	if not enabled:return
	var input:=Vector2(float(held.get(KEY_D,false))-float(held.get(KEY_A,false)),float(held.get(KEY_S,false))-float(held.get(KEY_W,false)))
	var motion:=Vector3(input.x,0,input.y).limit_length()
	actor.position+=motion*delta*0.7
	var flat:=Vector2(actor.position.x,actor.position.z).limit_length(0.4);actor.position.x=flat.x;actor.position.z=flat.y
	actor.velocity=motion*4.2 if motion.length()>0 else (Vector3(0,0,4.2) if pose=="run" else Vector3.ZERO)
	if motion.length()>0:model.rotation.y=atan2(motion.x,motion.z)
	elif pose!="run":model.rotation.y=move_toward(model.rotation.y,0,delta*2)
	actor.grounded=jump_time<0
	if jump_time>=0:
		jump_time+=delta
		actor.position.y=sin(minf(jump_time/0.65,1)*PI)*0.35
		actor.velocity.y=cos(minf(jump_time/0.65,1)*PI)*0.35*PI/0.65
		if jump_time>=0.65:jump_time=-1;actor.position.y=0;actor.grounded=true
	if pose=="shoot":
		fire_time-=delta
		if fire_time<=0:model.set_action("shoot");fire_time=0.35
