extends SceneTree
const Setup := preload("res://src/core/match_setup.gd")
func _initialize() -> void:
 seed(731)
 call_deferred("_run")
func _run() -> void:
 for map_id in ["tidewater","kelpline"]:
  Setup.map_id = map_id
  Setup.team_size = 5
  var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
  root.add_child(game)
  await physics_frame
  game.set_physics_process(false)
  game.get_node("World/Walker").set_physics_process(false)
  game._start_round()
  var nav: RefCounted = game.get("navigation")
  var graph: AStar3D = nav.get("graphs")[0]
  var bot: Node3D = game.get("extra_bots")[0]
  var mover: CharacterBody3D = bot.get("team_mover")
  var passed := false
  var attempted := 0
  for node in nav.get("nodes"):
   if not graph.has_point(int(node["id"])) or int(node["zone"]) >= 0:
    continue
   for edge in node["edges"]:
    if edge["type"] != "jump" or not graph.has_point(int(edge["to"])):
     continue
    var a := graph.get_point_position(int(node["id"]))
    var b := graph.get_point_position(int(edge["to"]))
    if a.distance_to(game.get_node("World/Walker").global_position)<16.0:
     continue
    attempted += 1
    bot.global_position = a+Vector3.UP*0.05
    mover.velocity = Vector3.ZERO
    bot.set("route",PackedVector3Array([a,b]))
    bot.set("route_index",1)
    bot.set("repath_time",999.0)
    bot.set("jump_time",0.0)
    var jumps := int(bot.get("jumps_started"))
    for step in range(45):
     await physics_frame
     bot._tick_team(1.0/30.0)
     game.get_node("Combat").advance_effects(1.0/30.0)
     if int(bot.get("jumps_started")) > jumps and mover.is_on_floor() and bot.global_position.y > a.y+0.45 and Vector2(bot.global_position.x-b.x,bot.global_position.z-b.z).length()<0.4:
      passed = true
      print("AUDIT: ",map_id," jump ",node["id"]," -> ",edge["to"]," ",a," -> ",bot.global_position)
      break
    if passed or attempted>=12:
     break
   if passed or attempted>=12:
    break
  if not passed:
   printerr("FAIL: no live supported jump on ",map_id," after ",attempted," original edges");quit(1);return
  game.queue_free()
  await process_frame
 Setup.map_id = "tidewater"
 print("PASS: original jump edges launch and land on live collision surfaces on both maps")
 quit()
