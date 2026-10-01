extends Node3D

# main.js _intro / cameraRig.js _path: 3.6 s mirrored sweep, 1.5 m arc;
# the remaining 0.6 s blends into the existing gameplay camera before input starts.
var game: Node3D
var camera: Camera3D
var following: Camera3D
var pad := Vector3.ZERO
var last_phase := ""

func setup(owner_game: Node3D) -> void:
	game = owner_game
	following = game.get_node("World/Walker/Camera3D")
	pad = game.get_node("World/Map").get("spawn_pads")[0]
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = following.far
	camera.fov = following.fov
	add_child(camera)

func _process(_delta: float) -> void:
	sync()

static func cubic_ease(k: float) -> float:
	return 4.0*k*k*k if k < 0.5 else 1.0-pow(-2.0*k+2.0,3.0)/2.0

func intro_pose(seconds: float) -> Transform3D:
	var e := cubic_ease(clampf(seconds/3.6,0.0,1.0))
	var from := Vector3(18,26,30)
	var to := pad+Vector3(0,2.6,-5.2)
	var position_value := from.lerp(to,e)+Vector3.UP*sin(e*PI)*1.5
	var look_value := Vector3(0,0,10).lerp(pad+Vector3(0,1.6,6),e)
	return Transform3D(Basis.IDENTITY,position_value).looking_at(look_value,Vector3.UP)

func sync() -> void:
	if game == null:
		return
	var phase := String(game.get("phase"))
	if phase == "intro":
		var seconds := float(game.get("phase_time"))
		camera.global_transform = intro_pose(seconds)
		if seconds > 3.6:
			camera.global_transform = camera.global_transform.interpolate_with(following.global_transform,cubic_ease(clampf((seconds-3.6)/0.6,0.0,1.0)))
		camera.current = true
	elif last_phase == "intro":
		following.current = true
	last_phase = phase
