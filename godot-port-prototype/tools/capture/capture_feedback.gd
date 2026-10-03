extends SceneTree

const Setup := preload("res://src/core/match_setup.gd")
var game: Node3D
var mouse_notified := false

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 if DisplayServer.get_name() == "headless":
  printerr("FAIL: native display required")
  quit(1)
  return
 DirAccess.remove_absolute("/private/tmp/inkwave-feedback-gui-settings.cfg")
 root.size = Vector2i(1280,720)
 Setup.team_size = 5
 for id in ([] if OS.get_cmdline_user_args().has("--rig-only") else ["tidewater","kelpline"]):
  Setup.map_id = id
  game = (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
  game.set("settings_path", "/private/tmp/inkwave-feedback-gui-settings.cfg")
  root.add_child(game)
  current_scene = game
  await _frames(3)
  (game.get("map_select") as OptionButton).get_popup().index_pressed.emit(0 if id == "tidewater" else 1)
  await _frames(4)
  game = current_scene
  if Setup.map_id != id:
   printerr("FAIL: map selector did not rebuild the selected source map")
   quit(1)
   return
  await _frames(2)
  await _save("feedback-" + id + "-menu")
  if id == "tidewater":
   await _click_control(game.get("setup_settings_button"))
   await _frames(2)
   await _save("feedback-settings")
   var panel: Panel = game.get("settings_panel")
   (panel.get("ui_scale_button") as OptionButton).select(2)
   (panel.get("sensitivity_slider") as HSlider).value = 0.003
   await _click_control(panel.get("save_button"))
   if not is_equal_approx((game.get("hud_root") as Control).scale.x,1.1):
    printerr("FAIL: native settings save did not apply UI scale")
    quit(1)
    return
  root.size = Vector2i(960,540)
  await _frames(3)
  for control in [game.get("frontend").get("random_button"),game.get("frontend").get("back_button")]:
   if not Rect2(Vector2.ZERO,Vector2(root.size)).encloses(control.get_global_rect()):
    printerr("FAIL: small menu overflow ",control.name)
    quit(1)
    return
  await _save("feedback-" + id + "-small")
  root.size = Vector2i(1280,720)
  game.call("show_preparation")
  await _frames(2)
  await _click_control(game.get("frontend").get("preparation").get_node("Actions").get_child(1))
  if game.get("phase") != "intro":
   printerr("FAIL: native start button did not enter intro")
   quit(1)
   return
  game.call("_physics_process",4.2)
  # Bounded gameplay at actual ten-actor load. Move from spawn to source nav's
  # clear central ground only as a capture fixture, not as a manual traversal claim.
  var nav: RefCounted = game.get("navigation")
  var graphs: Array = nav.get("graphs")
  var index := 0
  for actor in game.call("all_actors"):
   var team := int(game.call("actor_team",actor))
   var graph: AStar3D = graphs[team]
   var marker := Vector3((float(index % 5)-2.0)*3.5,2.0, -4.0 if team == 0 else 4.0)
   actor.global_position = graph.get_point_position(graph.get_closest_point(marker)) + Vector3.UP * 0.05
   if actor == game.get_node("World/Walker"):
    game.set("player_invuln",5.0)
   elif actor == game.get_node("Bot"):
    game.set("bot_invuln",5.0)
   else:
    actor.set("invuln",5.0)
   index += 1
  var walker: CharacterBody3D = game.get_node("World/Walker")
  walker.set_physics_process(false)
  # Keep player out of the scripted battle so bots visibly target other bots.
  var camera: Camera3D = walker.get_node("Camera3D")
  camera.global_position = Vector3(8,6,-12)
  camera.look_at(Vector3(0,1.2,0))
  game.set("phase_time",2.0)
  await _frames(12)
  await _save("feedback-" + id + "-battle")
  var tab := InputEventKey.new()
  tab.keycode = KEY_TAB
  tab.pressed = true
  Input.parse_input_event(tab)
  await _frames(2)
  await _save("feedback-" + id + "-roster")
  tab.pressed = false
  Input.parse_input_event(tab)
  await _frames(1)
  game.call("_finish_round")
  game.call("_judge_round")
  game.set("phase","results")
  game.call("_update_hud")
  # Forced phase changes need the responsive containers to settle before input.
  await _frames(12)
  await _save("feedback-" + id + "-results")
  await _click_control((game.get("result_actions") as HBoxContainer).get_child(0))
  await _frames(3)
  game = current_scene
  if game.get("phase") != "setup" or Setup.map_id != id:
   printerr("FAIL: result replay did not preserve selected map")
   quit(1)
   return
  game.queue_free()
  await _frames(2)
 DirAccess.remove_absolute("/private/tmp/inkwave-feedback-gui-settings.cfg")
 # Close-up of the four default original web variants and their held weapons.
 var stage := Node3D.new()
 root.add_child(stage)
 stage.add_child((load("res://scenes/world/tidewater_environment.tscn") as PackedScene).instantiate())
 var camera := Camera3D.new()
 stage.add_child(camera)
 camera.current = true
 camera.position = Vector3(0,1.6,4.0)
 camera.look_at(Vector3(0,0.8,0))
 var ground := MeshInstance3D.new()
 ground.mesh = PlaneMesh.new()
 ground.mesh.size = Vector2(14,14)
 var ground_material := StandardMaterial3D.new()
 ground_material.albedo_color=Color("bfc5cc")
 ground.material_override=ground_material
 ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 stage.add_child(ground)
 var weapons := ["shooter","roller","charger","blaster"]
 for style in range(4):
  var visual := Node3D.new()
  visual.set_script(preload("res://src/actors/tidewater_character_visual.gd"))
  visual.set("team", style % 2)
  visual.set("style_index",style)
  visual.position.x = (style - 1.5) * 1.0
  stage.add_child(visual)
  visual.call("set_weapon",weapons[style])
  visual.call("set_aim",true)
  visual.call("set_weapon_pose",0.0,weapons[style]=="roller")
 await _frames(12)
 await _save("feedback-characters")
 print("PASS: default character legs/weapon holds and ground shadows captured" if OS.get_cmdline_user_args().has("--rig-only") else "PASS: bounded native 5v5 on both maps, Tab map, setup/settings at 1280/960, battle/results, default character legs/holds; fixtures used, not full-duration gameplay")
 quit()

func _frames(count: int) -> void:
 for i in range(count):
  await process_frame

func _save(label: String) -> void:
 await RenderingServer.frame_post_draw
 var capture_label := label.replace("feedback-","feedback8-") if OS.get_cmdline_user_args().has("--feedback8") else label.replace("feedback-","clean-") if OS.get_cmdline_user_args().has("--clean") else label.replace("feedback-","restored-") if OS.get_cmdline_user_args().has("--restored") else label.replace("feedback-","original-") if OS.get_cmdline_user_args().has("--original") else label
 var result := root.get_texture().get_image().save_png("res://render-evidence/" + capture_label + ".png")
 if result != OK:
  printerr("FAIL: screenshot save ", label)
  quit(1)


func _click_control(control: Control) -> void:
 var position := control.get_global_transform_with_canvas()*(control.size*0.5)
 var motion := InputEventMouseMotion.new()
 motion.position = position
 root.push_input(motion,true)
 await _frames(2)
 for pressed in [true,false]:
  var event := InputEventMouseButton.new()
  event.position = position
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed
  root.push_input(event,true)
  await _frames(1)
