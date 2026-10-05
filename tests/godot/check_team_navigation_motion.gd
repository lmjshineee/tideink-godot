extends SceneTree
const Setup := preload("res://src/core/match_setup.gd")
const Maps := preload("res://src/core/map_catalog.gd")
func _initialize() -> void:
 seed(20260930)
 call_deferred("_check")
func _check() -> void:
 var layouts := 0
 for map_id in Maps.IDS:
  for variant in Maps.variant_count(map_id):
   await _layout(map_id,variant)
   if failures: return
   layouts += 1
 Setup.map_id = "tidewater"; Setup.random_map = false; Setup.map_variant = 0
 print("PASS: all nine bots leave both spawn areas across all ",layouts," layouts in six simulated seconds using live collision queries")
 quit()

var failures := false
func _layout(map_id: String, variant: int) -> void:
  Setup.team_size = 5
  Setup.map_id = map_id
  Setup.random_map = true
  Setup.map_variant = variant
  Setup.map_seed = 20260930
  Setup.screen = "setup"
  Setup.randomized = true
  Setup.reroll_bots = false
  Setup.pending_loadout = {"settings_path":"/private/tmp/tideink-navigation-check-unused.cfg"}
  var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
  root.add_child(game)
  await physics_frame
  game.set_physics_process(false)
  game.get_node("World/Walker").set_physics_process(false)
  game.equipment_rng.seed = 20260930
  for actor in game.all_actors():
   game.perks.choices[actor.get_instance_id()] = "balanced"
   if actor != game.get_node("World/Walker"): game.randomize_bot_kit(actor)
  game.call("_start_round")
  Engine.time_scale = 4; Engine.physics_ticks_per_second = 120
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
    printerr("FAIL: stuck at spawn on ",map_id," variant=",variant," ",bot.name," ",starts[i]," -> ",bot.global_position)
    failures = true
    quit(1)
    return
  game.queue_free()
  await process_frame
