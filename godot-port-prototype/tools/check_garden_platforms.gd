extends SceneTree
const Setup:=preload("res://match_setup.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 Engine.max_fps=0;Engine.physics_ticks_per_second=240
 Setup.map_id="terrace_garden";Setup.screen="setup";Setup.random_map=false;Setup.selected_perk="balanced";Setup.team_size=5
 var game:Node3D=(load("res://tidewater_play.tscn") as PackedScene).instantiate()
 root.add_child(game);await physics_frame
 game._start_round();game.set_physics_process(false)
 var walker:CharacterBody3D=game.get_node("World/Walker");walker.set_physics_process(false)
 for team in range(2):
  walker.team=team;walker.grounded=false
  walker.global_position=game.get_node("World/Map").spawn_pads[team];walker.velocity=Vector3.ZERO
  await physics_frame
  var target:=Vector3(-7,6,-2) if team==0 else Vector3(7,6,2)
  var path:PackedVector3Array=game.navigation.route(walker.global_position,target,team)
  var index:=1
  var top:=0.0
  for step in range(900):
   if index>=path.size():break
   var offset:=path[index]-walker.global_position
   var flat:=Vector2(offset.x,offset.z)
   if flat.length()<0.55 and absf(offset.y)<0.7:
    index+=1;continue
   walker.camera_yaw=atan2(offset.x,offset.z)
   if walker.grounded and offset.y>0.4 and step%30==0:walker.jump_requested=true
   var event:=InputEventKey.new();event.keycode=KEY_W;event.physical_keycode=KEY_W;event.pressed=true
   Input.parse_input_event(event);Input.flush_buffered_events()
   walker._physics_process(1.0/30.0)
   top=maxf(top,walker.global_position.y)
   await physics_frame
  var release:=InputEventKey.new();release.keycode=KEY_W;release.physical_keycode=KEY_W;release.pressed=false
  Input.parse_input_event(release);Input.flush_buffered_events()
  print("AUDIT: garden team=",team," route nodes=",path.size()," progress=",index," position=",walker.global_position," maxY=",top)
  if walker.global_position.distance_to(target)>3 or walker.global_position.y<5.8:
   printerr("FAIL: player cannot follow live collision route to 6m garden platform");quit(1);return
 game.queue_free();await process_frame
 print("PASS: player controller climbs both garden routes from spawn to 6m upper platforms with live physics")
 quit()
