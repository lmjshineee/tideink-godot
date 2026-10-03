extends SceneTree
const Setup := preload("res://match_setup.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 Setup.team_size=5
 var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
 root.add_child(game)
 await physics_frame
 game.set_physics_process(false)
 var camera: Camera3D=game.get_node("World/Walker/Camera3D")
 var bot: Node3D=game.get_node("Bot")
 bot.call("_update_health_visual")
 var bar: Node3D=bot.get("health_bar")
 var toward := (camera.global_position-bar.global_position).normalized()
 var dot := bar.global_basis.z.normalized().dot(toward)
 print("AUDIT: health fill front/camera dot=",dot)
 if dot<0.99:
  printerr("FAIL: health fill is facing away from the camera");quit(1);return
 var ids := {}
 for actor in game.all_actors():
  var id: int=game.call("actor_id",actor)
  if id<=0 or ids.has(id):printerr("FAIL: actor ID missing/duplicate");quit(1);return
  ids[id]=true
  if actor==game.get_node("World/Walker"):continue
  var ornament_seed: int = actor.get_node("Body").get("ornament_seed")
  actor.set("invuln",0.0)
  game.bot_invuln=0.0
  game.phase="playing"
  var expected_damage: float = 37.0 * game.perks.incoming(actor, "")
  game.damage_actor(actor,37,1-game.actor_team(actor))
  actor.call("_update_health_visual")
  if absf(float(actor.get("health_fill").scale.x)-(game.actor_max_health(actor)-expected_damage)/game.actor_max_health(actor))>0.001:
   printerr("FAIL: actor health fill does not reflect its own health");quit(1);return
  if not String(actor.get("identity_label").text).contains("%02d" % id):
   printerr("FAIL: overhead label differs from stable actor ID");quit(1);return
  game.damage_actor(actor,200,1-game.actor_team(actor))
  if game.actor_alive(actor):printerr("FAIL: lethal damage did not hide actor");quit(1);return
  if actor==game.get_node("Bot"):game._update_bot(6.0)
  else:game._update_team_actor(actor,6.0)
  if game.actor_id(actor)!=id or absf(game.actor_health(actor)-game.actor_max_health(actor))>0.01 or int(actor.get_node("Body").get("ornament_seed"))!=ornament_seed:
   printerr("FAIL: respawn changed ID or did not restore health");quit(1);return
 for i in (game.get("presentation").get("models") as Array).size():
  var actor: Node3D = game.get("presentation").get("roster")[i]
  var model: Node3D = game.get("presentation").get("models")[i]
  if int(model.get("ornament_seed")) != int(actor.get_node("Body").get("ornament_seed")):
   printerr("FAIL: portrait ornament differs from gameplay");quit(1);return
 print("PASS: health fill faces camera, independent ally/enemy damage, stable unique IDs and overhead labels and ornament seeds across respawn/portraits")
 quit()
