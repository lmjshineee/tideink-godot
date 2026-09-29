extends SceneTree

# Short character-acceptance capture: both teams, then the idle, walk and squid poses
# of the player alone so the poses compare the same character. A few frames only — this is not a performance or
# temperature run, and it never plays a match.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path godot-port-prototype \
#       --script res://tools/capture_character.gd
#
# The play scene's physics is suspended so the poses below are the ones asked for,
# not whatever the controller happened to be doing; the capture tool may call the
# walker's private camera update because no gameplay state is being changed.
const OUTPUT := "res://preview-character-%s.png"
const FRAME_CAP := 4000

var scene: Node3D
var walker: CharacterBody3D


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: screenshots require a graphical display")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	scene = (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in range(6):
		await RenderingServer.frame_post_draw
	scene.call("_start_round")
	scene.set_physics_process(false)
	walker = scene.get_node("World/Walker")
	walker.set_physics_process(false)
	# Both teams in frame: the blue bot stands in front of the player, facing it.
	var bot: Node3D = scene.get_node("Bot")
	bot.global_position = walker.global_position + Vector3(0.55, 0.0, 1.7)
	bot.get_node("Body").rotation.y = PI + 0.4
	# A dedicated side camera: the walker's own third-person rig sits too close and
	# crops the legs, which are exactly what these captures have to show.
	var focus := walker.global_position + Vector3(0.15, 0.85, 0.8)
	var camera := Camera3D.new()
	camera.name = "CaptureCamera"
	camera.fov = 45.0
	root.add_child(camera)
	camera.global_position = focus + Vector3(3.9, 0.55, 0.15)
	camera.look_at(focus, Vector3.UP)
	camera.current = true

	# --- both teams, three-quarter view --------------------------------------------
	await _drive(Vector3.ZERO, true, 40)
	await _save("team")

	# --- idle, player only: the bot is hidden so the two pose captures compare
	#     the same character rather than two different ones --------------------------
	bot.visible = false
	await _drive(Vector3.ZERO, true, 40)
	await _save("idle")

	# --- walk, both strides -------------------------------------------------------
	await _drive(Vector3(0.0, 0.0, -6.0), true, 40)
	var leg_l: MeshInstance3D = walker.get_node("Body/Kid/LegL")
	if not await _await_leg(leg_l, 0.55):
		quit(1)
		return
	await _save("walk")

	# --- squid --------------------------------------------------------------------
	walker.velocity = Vector3.ZERO
	walker.call("update_form", true)
	await _drive(Vector3(0.0, 0.0, -6.0), true, 30)
	await _save("squid")

	print("PASS: character captures saved next to the project")
	quit()


func _drive(velocity: Vector3, grounded: bool, frames: int) -> void:
	for i in range(frames):
		walker.velocity = velocity
		walker.set("grounded", grounded)
		await process_frame


func _await_leg(leg_l: MeshInstance3D, threshold: float) -> bool:
	for i in range(FRAME_CAP):
		walker.velocity = Vector3(0.0, 0.0, -6.0)
		walker.set("grounded", true)
		await process_frame
		if threshold > 0.0 and leg_l.rotation.x > threshold:
			return true
		if threshold < 0.0 and leg_l.rotation.x < threshold:
			return true
	printerr("FAIL: leg never reached ", threshold)
	return false


func _save(label: String) -> void:
	for i in range(3):
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := OUTPUT % label
	if image.is_empty() or image.save_png(path) != OK:
		printerr("FAIL: could not save ", path)
		quit(1)
		return
	print("saved ", ProjectSettings.globalize_path(path))
