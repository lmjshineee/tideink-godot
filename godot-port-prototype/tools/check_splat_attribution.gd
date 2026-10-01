extends SceneTree
func _initialize() -> void:
 preload("res://match_setup.gd").team_size = 5
 seed(619)
 call_deferred("_run")
func _run() -> void:
 var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
 root.add_child(game)
 await physics_frame
 game.set_physics_process(false)
 game._start_round()
 var combat: Node3D = game.get_node("Combat")
 var walker: Node3D = game.get_node("World/Walker")
 walker.set_physics_process(false)
 var attacker: Node3D
 for actor in game.all_actors():
  if game.actor_id(actor) == 8:
   attacker = actor
 for kind in ["shooter","drop","charger","blaster"]:
  game.player_invuln = 0.0
  game.player_health = 1.0
  var at := walker.global_position+Vector3.UP*0.8
  var from := at+Vector3.FORWARD*1.7
  if kind == "charger":
   combat.fire_bot_charger(from,at,1.0,1,attacker)
  elif kind == "blaster":
   combat._burst_blaster(at,combat.get("weapons")["blaster"],false,1,null,attacker)
  else:
   var weapon: Dictionary = combat.get("weapons")["roller" if kind == "drop" else "shooter"]
   combat._spawn_projectile(kind,from,Vector3.BACK*34.0,weapon,1,attacker)
   # Changing a weapon after launch must not change the recorded source weapon.
   attacker.select_weapon("blaster")
   for step in range(8):
    combat._update_projectiles(0.02)
  var description: String = game.get("presentation").get("death_by")
  var weapon_id: String = "roller" if kind == "drop" else kind
  if game.player_respawn <= 0.0 or not description.contains("#08") or not description.contains(game._weapon_text(weapon_id)):
   printerr("FAIL: wrong lethal source for ",kind,": ",description);quit(1);return
  game.call("launch_respawn")
  game._update_player_respawn(6.0)
 var ally: Node3D = game.get("extra_bots")[0]
 attacker.set("invuln",0.0)
 if attacker==game.get_node("Bot"):game.bot_health=20
 else:attacker.health=20
 game.damage_actor(attacker,30.0,0,ally,"shooter")
 if not String(game.get("feed_text")).contains("#02") or not String(game.get("feed_text")).contains("#08"):
  printerr("FAIL: team kill feed loses attacker/victim IDs");quit(1);return
 game.damage_player(200.0,true)
 if String(game.get("presentation").get("death_by")) != "落入海水":
  printerr("FAIL: water death attributed to a bot");quit(1);return
 print("PASS: four lethal weapon paths preserve attacker ID and launch weapon; ally/enemy kill feed and water cause")
 quit()
