extends SceneTree

const Setup := preload("res://match_setup.gd")
var failed := false

func _initialize() -> void:
 call_deferred("_check")

func _check() -> void:
 for map_id in ["tidewater", "kelpline"]:
  Setup.team_size = 5
  Setup.map_id = map_id
  var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
  root.add_child(game)
  await process_frame
  game.set_physics_process(false)
  var actors: Array = game.call("all_actors")
  _expect(actors.size() == 10, "5v5 must spawn ten distinct actors on " + map_id)
  var count := [0,0]
  for actor in actors:
   count[int(game.call("actor_team", actor))] += 1
   var visual: Node3D = actor.get_node("Body")
   _expect(visual.get("skeleton") != null, "original skeleton missing")
   var skeleton: Skeleton3D = visual.get("skeleton")
   _expect(skeleton.get_bone_count() == 87, "source skin/rig bone count differs")
   _expect((visual.get("original_weapons") as Dictionary).size() == 4, "source weapons missing from skin attachment")
  _expect(count == [5,5], "unbalanced roster")
  _expect(game.get_node("World/Map").get("block_count") == (145 if map_id == "tidewater" else 141), "wrong map collision export")
  var ink: RefCounted = game.get("ink")
  _expect(int(ink.get("turf_total")) > 50000, "missing original scoring denominator")
  game.call("_start_round")
  var walker: CharacterBody3D = game.get_node("World/Walker")
  walker.set_physics_process(false)
  var combat: Node3D = game.get_node("Combat")
  var bots: Array = game.get("extra_bots")
  var ally: Node3D = bots[0]
  var rival: Node3D = bots[4]
  var rival2: Node3D = bots[5]
  # Put the targets in isolated air: rule fixture, not a navigation/performance run.
  for actor in actors:
   actor.global_position = Vector3(60,30,60)
  walker.global_position = Vector3(0,30,0)
  ally.global_position = Vector3(0,30,2)
  rival.global_position = Vector3(0,30,4)
  rival2.global_position = Vector3(0,30,6)
  var hit: Dictionary = combat.call("_segment_team_hit",Vector3(0,31,0),Vector3(0,31,10),0.15,0)
  _expect(hit.get("actor") == rival, "friendly shield or nearest rival selection failed")
  game.call("damage_actor",ally,1000.0,0)
  _expect(float(ally.get("health")) == 100.0, "friendly fire is enabled")
  var bomb: Dictionary = combat.get("weapon_data")["sub"]["bomb"]
  combat.call("_explode_bomb", Vector3(0,30.6,4),bomb)
  _expect(not bool(game.call("actor_alive",rival)), "bomb failed to hit extra rival")
  _expect(float(rival2.get("health")) < 100.0, "area damage only affects one rival")
  _expect(float(ally.get("health")) == 100.0, "area damage hit friendly actor")
  game.call("_update_team_actor",rival,10.0)
  _expect(bool(game.call("actor_alive",rival)) and rival.visible and float(rival.get("health")) == 100.0, "per-actor respawn failed")
  _expect(float(rival.get("invuln")) > 0.0, "respawn protection missing")
  rival.set("invuln",0.0)
  rival.global_position = Vector3(0,30,4)
  rival2.global_position = Vector3(60,30,60)
  # Bots choose opponents on the opposite team, including other bots.
  ally.call("tick",0.3)
  _expect(ally.get("target_actor") == rival, "ally bot does not target rival bot")
  var shots: Array = combat.get("projectiles")
  _expect(not shots.is_empty() and int(shots.back()["team"]) == 0, "ally cannot fire a team-correct projectile")
  var nav: RefCounted = game.get("navigation")
  var graphs: Array = nav.get("graphs")
  for team in range(2):
   var graph: AStar3D = graphs[team]
   _expect(graph.get_point_count() > 3000, "original navigation graph not loaded")
   var pad: Vector3 = game.get_node("World/Map").get("spawn_pads")[team]
   var path: PackedVector3Array = nav.call("patrol",pad,team,1)
   _expect(path.size() > 1, "spawn has no reachable patrol route on " + map_id)
  # Aim/weapon action really affects the imported skeleton, not just old adapters.
  var visual: Node3D = walker.get_node("Body")
  var skeleton: Skeleton3D = visual.get("skeleton")
  visual.call("set_aim",true)
  visual.call("_animate",0.1)
  var before := skeleton.get_bone_pose_rotation(skeleton.find_bone("uArmR"))
  visual.call("set_action","flick")
  visual.call("_animate",0.15)
  var after := skeleton.get_bone_pose_rotation(skeleton.find_bone("uArmR"))
  _expect(not before.is_equal_approx(after), "source bone action layer did not move")
  _expect(game.get("minimap") != null and game.get("map_select") != null and game.get("start_button") != null,"new HUD/menu not connected")
  game.get("minimap").call("_refresh_ink")
  # Bot-owned projectiles retain their identity when advanced outside bot.tick.
  game.set("bot_painting", true)
  combat.call("spawn_bot_shot",Vector3(0,30,0),Vector3(5,30,0),"shooter",0)
  game.set("bot_painting", false)
  var projectiles: Array = combat.get("projectiles")
  _expect(not bool(projectiles.back()["local_credit"]), "ally shot is credited to local player")
  combat.call("_update_projectiles",0.01)
  _expect(not bool(game.get("bot_painting")), "projectile credit guard leaked between actors")
  _expect((game.get("roster_rows") as Array).size() == 10, "team status rows are incomplete")
  game.call("_finish_round")
  game.call("_judge_round")
  _expect(game.get("judged_coverage") == [float(ink.call("coverage",0)),float(ink.call("coverage",1))],"team judge must use authoritative ink")
  game.queue_free()
  await process_frame
 Setup.map_id = "tidewater"
 Setup.team_size = 5
 if failed:
  quit(1)
 else:
  print("PASS: both source maps, ten skinned actors, 5+5 roster, nearest enemy/friendly fire, group damage, individual protected respawn, bot-vs-bot weapons, source navigation and team judge")
  quit()

func _expect(ok: bool,message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ",message)
