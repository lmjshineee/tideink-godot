extends SceneTree
const Setup:=preload("res://match_setup.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 root.size=Vector2i(1280,720)
 for id in ["coral_market","prism_gallery","viaduct"]:
  Setup.map_id=id;Setup.screen="setup";Setup.random_map=false;Setup.map_seed=1;Setup.selected_perk="balanced"
  var game:Node3D=(load("res://tidewater_play.tscn") as PackedScene).instantiate()
  root.add_child(game);current_scene=game
  await physics_frame
  game._start_round();game.hud_root.visible=false;game.set_physics_process(false);game.get_node("World/Walker").set_physics_process(false)
  var camera:=Camera3D.new();game.add_child(camera)
  camera.position=Vector3(27,27,-37) if id!="viaduct" else Vector3(25,28,-43)
  camera.look_at(Vector3(0,2,0));camera.current=true;camera.fov=68
  for i in range(8):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://render-evidence/balance11-%s-overview.png" % id)
  game.queue_free();await process_frame
 print("PASS: three native stage overviews from actual playable geometry")
 quit()
