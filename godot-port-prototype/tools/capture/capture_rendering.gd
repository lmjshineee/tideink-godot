extends SceneTree

const TeamPalette := preload("res://src/core/team_palette.gd")

var capture_failed := false

# Bounded visual smoke test, not a sustained performance/temperature benchmark.
# -- --label=baseline gives reproducible before/after files in .godot/.
func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: screenshots require a graphical display")
		quit(1)
		return
	seed(20260929)
	var label := "forward"
	var minimal := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			label = argument.trim_prefix("--label=").validate_filename()
		elif argument.begins_with("--palette="):
			TeamPalette.select(int(argument.trim_prefix("--palette=")))
		elif argument == "--colorblind":
			TeamPalette.set_colorblind(true)
		elif argument == "--minimal":
			minimal = true
	root.size = Vector2i(1280, 720)
	var scene := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for i in range(8):
		await RenderingServer.frame_post_draw
	_save(label + "-menu")
	scene.call("_start_round")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	var bot: Node3D = scene.get_node("Bot")
	bot.global_position = walker.global_position + Vector3(1.6, 0.0, 4.0)
	bot.get_node("Body").rotation.y = PI
	scene.call("paint_at_world", walker.global_position + Vector3(0, 0.2, 3), 0, 2.4, 0.5)
	scene.call("paint_at_world", bot.global_position + Vector3.UP * 0.2, 1, 1.4, 0.5)
	var ink: RefCounted = scene.get("ink")
	var view: Node = scene.get_node("InkView")
	view.call("sync_dirty")
	scene.call("_update_hud")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i in range(20):
		await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in range(30):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	_save(label + "-combat")
	if minimal:
		if capture_failed:
			quit(1)
			return
		print("PASS: selected palette menu/combat capture")
		quit()
		return
	var camera: Camera3D = walker.get_node("Camera3D")
	camera.global_position = Vector3(34, 43, -54)
	camera.look_at(Vector3(0, 0, 0))
	for i in range(8):
		await RenderingServer.frame_post_draw
	_save(label + "-overview")
	root.size = Vector2i(960, 540)
	for i in range(8):
		await RenderingServer.frame_post_draw
	_save(label + "-small")
	samples.sort()
	cpu.sort()
	gpu.sort()
	var report := {
		"engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"size": "1280x720", "fps_cap": Engine.max_fps, "samples": samples.size(),
		"frame_median_ms": samples[15], "frame_p95_ms": samples[28],
		"render_cpu_median_ms": cpu[15], "render_gpu_median_ms": gpu[15],
		"coverage_orange": ink.call("coverage", 0), "coverage_blue": ink.call("coverage", 1),
		"ink_faces": view.get("face_mesh_count"),
		"note": "Short frozen-scene smoke sample; excludes startup; not thermal or full-round evidence. Zero GPU time means unavailable."
	}
	var file := FileAccess.open("res://.godot/render-" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	# Extra closeups follow measurement, so coverage is identical in comparisons.
	root.size = Vector2i(1280, 720)
	for kind in ["wall", "ramp"]:
		for face in ink.surfaces:
			if not bool(face["paintable"]):
				continue
			var normal := Vector3(face["n"][0], face["n"][1], face["n"][2])
			var origin := Vector3(face["origin"][0], face["origin"][1], face["origin"][2])
			if absf(origin.z) > 15.0 or float(face["sv"]) < 1.5:
				continue
			if (kind == "wall" and not bool(face["wall"])) or (kind == "ramp" and not (normal.y > 0.2 and normal.y < 0.99)):
				continue
			var u := float(face["su"]) * 0.5
			var v := float(face["sv"]) * 0.5
			if ink.call("splat_face", int(face["id"]), u, v, 1.3, 0, 0.5) <= 0.0:
				continue
			ink.call("splat_face", int(face["id"]), u + 0.6, v, 0.6, 1, 0.5)
			view.call("sync_dirty")
			var point := origin + Vector3(face["u"][0], face["u"][1], face["u"][2]) * u + Vector3(face["v"][0], face["v"][1], face["v"][2]) * v
			camera.global_position = point + normal * 5.0 + Vector3.UP * 0.5
			camera.look_at(point)
			for i in range(8):
				await RenderingServer.frame_post_draw
			_save(label + "-" + kind)
			break
	if capture_failed:
		quit(1)
		return
	# Inspect the original wall art and street furniture from playable-height views.
	if scene.has_node("World/Map/Scenery"):
		for shot in [
			["spawn",Vector3(0,5.5,-30),Vector3(0,3.8,-43)],
			["kiosk",Vector3(11,4.5,-30),Vector3(19,1.5,-37)],
		]:
			camera.global_position = shot[1]
			camera.look_at(shot[2])
			for i in range(8):
				await RenderingServer.frame_post_draw
			_save(label + "-" + shot[0])
	if capture_failed:
		quit(1)
		return
	print("PASS: bounded render capture ", JSON.stringify(report))
	quit()


func _save(label: String) -> void:
	var image := root.get_texture().get_image()
	if image.is_empty() or image.save_png("res://.godot/render-" + label + ".png") != OK:
		printerr("FAIL: render capture ", label)
		capture_failed = true
