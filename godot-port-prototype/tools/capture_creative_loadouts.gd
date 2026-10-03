extends SceneTree
const Setup := preload("res://match_setup.gd")
var game: Node3D
func _initialize() -> void: call_deferred("_run")
func snap(name: String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://render-evidence/creative16-"+name+".png")
func _run() -> void:
 root.size=Vector2i(1440,900)
 Setup.screen="setup";Setup.map_id="modular_harbor";Setup.random_map=false;Setup.map_variant=6;Setup.team_size=5
 Setup.selected_perk="enemy_swim";Setup.selected_item="recall"
 Setup.pending_loadout={"player":"disc"}
 game=(load("res://tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game);current_scene=game
 await process_frame
 game.set_physics_process(false)
 var walker:CharacterBody3D=game.get_node("World/Walker");walker.set_physics_process(false)
 var combat:Node3D=game.get_node("Combat")
 game.frontend._begin_hover("weapon","disc")
 await snap("loadout")
 game._start_round();game._set_pointer_lock(false);game.paused=false;game.pointer_locked=true;game.phase_time=4;game.deployment.clear()
 for actor in game.all_actors():
  if actor!=walker: actor.global_position=Vector3(70,40,70)
 walker.global_position=Vector3(0,.05,-20);walker.reset_movement_state();walker.grounded=true
 walker.camera_yaw=0;walker.camera_pitch=-.15;walker._update_camera();walker.get_node("Camera3D").current=true
 game.items.use(walker)
 combat.special_points=180;combat.try_special()
 for i in 13:combat.advance_effects(.033)
 game._update_hud()
 await snap("twins")
 for i in 80:combat.advance_effects(.033)
 combat.special_active="";combat.discs.throw_primary(walker,walker.global_position+Vector3(0,1.05,12))
 for i in 5:combat.advance_effects(.033)
 game._update_hud()
 await snap("disc-anchor")
 game.queue_free();await process_frame
 print("PASS: Metal native setup, held/flying disc, twin special and recall marker captured")
 quit()
