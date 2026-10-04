extends SceneTree
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 root.size = Vector2i(960,540)
 preload("res://src/core/match_setup.gd").team_size = 1
 var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 var walker: CharacterBody3D = game.get_node("World/Walker")
 walker.set_physics_process(false)
 var camera: Camera3D = walker.get_node("Camera3D")
 var at := Vector3(-9.8,1.7,-43.4)
 camera.current = true
 camera.global_position = at+Vector3(0,0,2.1)
 camera.look_at(at)
 game.get("hud_root").visible = false
 for i in range(6):
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://render-evidence/feedback8-warning-unpainted.png")
 game.paint_at_world(at+Vector3.BACK*0.05,0,0.52,0.5)
 game.get_node("InkView").sync_dirty()
 for angle in [-0.45,0.0,0.45]:
  camera.global_position = at+Vector3(sin(angle)*2.1,0,cos(angle)*2.1)
  camera.look_at(at)
  for frame in range(8):
   await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://render-evidence/feedback8-warning-painted-%s.png" % angle)
 var bar: Node3D = game.get_node("Bot").get("health_bar")
 game.get("hud_root").visible = true
 game._start_round()
 game.phase_time = 2.0
 game.get_node("Bot").global_position = Vector3(-9.4,0,-41.2)
 game.bot_invuln = 0.0
 game.damage_bot(37)
 camera.global_position = Vector3(-9.4,2.0,-37.8)
 camera.look_at(Vector3(-9.4,1.2,-41.2))
 game.get_node("Bot")._update_health_visual()
 for i in range(8):
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://render-evidence/feedback8-health-63.png")
 game._finish_round()
 game._judge_round()
 game.phase = "results"
 game._update_hud()
 for i in range(12):
  await process_frame
 var button: Button = game.get("result_actions").get_child(0)
 var pos := button.get_global_transform_with_canvas()*(button.size*0.5)
 var motion := InputEventMouseMotion.new()
 motion.position = pos
 motion.relative = Vector2(1,1)
 root.push_input(motion,true)
 await process_frame
 if root.gui_get_hovered_control() != button:
  printerr("FAIL: result button not reachable via mouse; hover=",root.gui_get_hovered_control());quit(1);return
 print("PASS: wall warning paint at three view angles, 63 HP health face and result button mouse reachability")
 quit()
