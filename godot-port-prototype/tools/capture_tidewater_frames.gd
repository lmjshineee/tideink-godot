extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await RenderingServer.frame_post_draw
	if not _save("/private/tmp/inkwave-setup.png"):
		quit(1)
		return
	scene.call("_start_round")
	await RenderingServer.frame_post_draw
	if not _save("/private/tmp/inkwave-playing.png"):
		quit(1)
		return
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	var bot: Node3D = scene.get_node("Bot")
	bot.global_position = walker.global_position + Vector3(0.0, 0.0, 4.0)
	bot.get_node("Body").rotation.y = PI
	scene.call("damage_bot", 25.0)
	bot.call("_update_health_visual")
	bot.call("_show_attack")
	scene.call("paint_at_world", bot.global_position + Vector3.UP * 0.2, 1, 1.6, 0.5)
	scene.get_node("InkView").call("sync_dirty")
	scene.call("_update_hud")
	await RenderingServer.frame_post_draw
	if not _save("/private/tmp/inkwave-combat.png"):
		quit(1)
		return
	print("PASS: setup, playing and combat frames saved")
	quit()


func _save(path: String) -> bool:
	var image := root.get_texture().get_image()
	if image.is_empty() or image.save_png(path) != OK:
		printerr("FAIL: could not save ", path)
		return false
	return true
