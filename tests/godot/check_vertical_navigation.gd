extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 for size in [1, 5]:
  await prepare(size, "prism_gallery")
  expect(bot.team_mover != null, "all match sizes use a physical 3D mover")
  if bot.team_mover != null:
   bot.global_position = game.get_node("World/Map").spawn_pads[1]
   bot.team_mover.velocity = Vector3.ZERO
   var destination := Vector3(8.5, 6, 3)
   bot.route = game.navigation.route(bot.global_position, destination, 1)
   bot.route_index = 1
   bot.repath_time = 999
   walker.global_position = Vector3(70, 40, 70)
   var peak := 0.0
   for step in 1000:
    bot.tick(1.0 / 30)
    peak = maxf(peak, bot.global_position.y)
    if bot.global_position.distance_to(destination) < 1.3: break
   print("AUDIT: ",size,"v",size," bot peak=",peak," position=",bot.global_position)
   expect(bot.global_position.y > 5.8 and bot.global_position.distance_to(destination) < 2, "bot reaches real six-metre platform in " + str(size) + "v" + str(size))
  game.queue_free();await process_frame
 if failures.is_empty(): print("PASS: 1v1 and 5v5 use the same collision/gravity/navigation and reach upper gallery via real ramps")
 quit(0 if failures.is_empty() else 1)
