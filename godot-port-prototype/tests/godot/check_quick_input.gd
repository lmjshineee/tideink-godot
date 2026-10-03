extends SceneTree
func _initialize() -> void:
 preload("res://src/core/match_setup.gd").team_size = 1
 call_deferred("_run")
func _run() -> void:
 var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
 root.add_child(game)
 await physics_frame
 game.set_physics_process(false)
 game._start_round()
 var combat: Node3D = game.get_node("Combat")
 var walker: CharacterBody3D = game.get_node("World/Walker")
 walker.set_physics_process(false)
 for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
  for pressed in [true,false]:
   var event := InputEventMouseButton.new()
   event.button_index = button
   event.pressed = pressed
   Input.parse_input_event(event)
   Input.flush_buffered_events()
  game._physics_process(1.0/30.0)
  if button == MOUSE_BUTTON_LEFT and (combat.get("projectiles") as Array).is_empty():
   printerr("FAIL: sub-tick mouse tap was lost");quit(1);return
  game._physics_process(1.0/30.0)
 if (combat.get("bombs") as Array).is_empty():
  printerr("FAIL: sub-tick bomb tap was lost");quit(1);return
 var key := InputEventKey.new()
 key.physical_keycode = KEY_SPACE
 key.pressed = true
 Input.parse_input_event(key)
 Input.flush_buffered_events()
 if not bool(walker.get("jump_requested")):
  printerr("FAIL: physical Space ignored");quit(1);return
 key = key.duplicate()
 key.pressed = false
 Input.parse_input_event(key)
 Input.flush_buffered_events()
 combat.select_weapon("shooter")
 combat.set("ink_amount",1000.0)
 var used := 0.0
 for i in range(90):
  var before := float(combat.get("ink_amount"))
  combat.tick(1.0/30.0,true,false)
  used += maxf(0,before-float(combat.get("ink_amount")))
 var weapon: Dictionary = combat.get("weapons")["shooter"]
 var shots := roundi(used/float(weapon["inkPerShot"]))
 var expected := ceili(3.0/float(weapon["fireInterval"]))
 if absi(shots-expected)>1:
  printerr("FAIL: firing cadence quantized: ",shots," expected ",expected);quit(1);return
 print("PASS: sub-tick fire/bomb taps, physical jump key and 30 Hz firing cadence (",shots," shots)")
 quit()
