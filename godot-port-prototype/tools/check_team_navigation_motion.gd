extends SceneTree
const Setup := preload("res://match_setup.gd")
func _initialize() -> void:
 seed(20260930)
 call_deferred("_check")
func _check() -> void:
 for map_id in ["tidewater","kelpline"]:
  Setup.team_size = 5
  Setup.map_id = map_id
  var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
  root.add_child(game)
  await physics_frame
  game.set_physics_process(false)
  game.get_node("World/Walker").set_physics_process(false)
  game.call("_start_round")
  var bots: Array = game.get("extra_bots").duplicate()
  bots.append(game.get_node("Bot"))
  var starts: Array[Vector3] = []
  for bot in bots:
   starts.append(bot.global_position)
  var furthest: Array[float] = []
  furthest.resize(bots.size())
  furthest.fill(0.0)
  for step in range(180):
   await physics_frame
   game.call("_update_bot",1.0/30.0)
   for bot in game.get("extra_bots"):
    game.call("_update_team_actor",bot,1.0/30.0)
   game.get_node("Combat").call("advance_effects",1.0/30.0)
   for i in bots.size():
    furthest[i] = maxf(furthest[i],bots[i].global_position.distance_to(starts[i]))
  for i in range(bots.size()):
   var bot: Node3D = bots[i]
   if furthest[i] < 2.0:
    printerr("FAIL: stuck at spawn on ",map_id," ",bot.name," ",starts[i]," -> ",bot.global_position)
    quit(1)
    return
  game.queue_free()
  await process_frame
 Setup.map_id = "tidewater"
 print("PASS: all nine bots leave spawn on both maps in six simulated seconds using source navigation and live collision queries")
 quit()
