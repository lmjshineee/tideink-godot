extends SceneTree
const Setup = preload("res://src/core/match_setup.gd")
func _initialize() -> void:
 call_deferred("_check")
func _check() -> void:
 seed(20260930)
 if Engine.max_fps != 30:
  _fail("startup cap must already be active before the match scene loads"); return
 for map_id in ["tidewater","kelpline"]:
  Setup.map_id = map_id
  Setup.team_size = 5
  var scene := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
  scene.settings_path = "/tmp/inkwave-feedback-no-settings.cfg"
  root.add_child(scene)
  await physics_frame
  var walker: CharacterBody3D = scene.get_node("World/Walker")
  walker.active = false
  walker.grounded = true
  var visual: Node3D = walker.get_node("Body")
  visual.set_physics_process(false)
  var sk: Skeleton3D = visual.skeleton
  visual._animate(1.0/30.0)
  var hip := sk.find_bone("hips")
  if sk.get_bone_pose_position(hip).y < 0.59 or sk.get_bone_global_pose(sk.find_bone("footL")).origin.y < -0.04:
   _fail("rig hips/feet sank into the ground on "+map_id); return
  walker.update_intent(0.1,false,true,false)
  if walker.squid_form:
   _fail("Shift entered squid on dry spawn deck"); return
  scene.paint_at_world(walker.global_position+Vector3.UP*0.02,0,1.5,0.5)
  if not walker.can_dive():
   _fail("own painted deck did not allow diving"); return
  walker.update_intent(0.1,false,false,false)
  walker.update_intent(0.1,false,true,false)
  if not walker.squid_form:
   _fail("Shift did not enter squid on own ink"); return
  scene.paint_at_world(walker.global_position+Vector3.UP*0.02,1,2.0,0.5)
  walker.update_intent(0.1,false,true,false)
  if walker.squid_form:
   _fail("grounded squid remained submerged on enemy ink"); return
  # Constant aim must converge without sustained ringing at either frame rate.
  for hz in [30,60]:
   walker.aim_yaw=0.8
   walker.firing_pose=true
   walker.body_yaw=0.0
   walker.yaw_velocity=0.0
   var maximum := 0.0
   for i in range(hz*3):
    var before: float = walker.body_yaw
    walker._face(1.0/hz,false,Vector2.ZERO,false)
    if i>hz*2: maximum=maxf(maximum,absf(walker.body_yaw-before))
   if maximum>0.005 or absf(walker.body_yaw-0.8)>0.005:
    _fail("constant aim rings at "+str(hz)+" Hz; steady step="+str(maximum)); return
  var max_jump := 0.0
  for id in ["shooter","charger","roller","blaster"]:
   visual.set_weapon(id)
   visual.set_aim(true)
   visual.set_weapon_pose(0.0,id=="roller")
   for i in range(45): visual._animate(1.0/30.0)
   var hand := sk.find_bone("handR")
   var before := sk.get_bone_global_pose(hand)
   visual.set_action("flick" if id=="roller" else "shoot")
   for i in range(25):
    visual._animate(1.0/30.0)
    var after := sk.get_bone_global_pose(hand)
    max_jump = maxf(max_jump,before.origin.distance_to(after.origin))
    if not after.is_finite() or before.origin.distance_to(after.origin)>0.32:
     _fail("weapon hand teleported during "+id); return
    before=after
  var map: Node3D = scene.get_node("World/Map")
  var tested := 0
  for face in map.surfaces:
   if not face.paintable or float(face.n[1])<0.68: continue
   var grid: Dictionary = face.grid
   # Pick a valid cell; includes hard bridge/ramp decks even when its centre is buried.
   var dead: PackedByteArray = scene.ink.buried[int(face.id)]
   var selected := -1
   for cell in dead.size():
    if dead[cell]==0: selected=cell; break
   if selected<0: continue
   var u := (selected % int(grid.nu)+0.5)*float(grid.cu)
   var v := (selected / int(grid.nu)+0.5)*float(grid.cv)
   var point := Vector3(face.origin[0],face.origin[1],face.origin[2])+Vector3(face.u[0],face.u[1],face.u[2])*u+Vector3(face.v[0],face.v[1],face.v[2])*v
   var normal := Vector3(face.n[0],face.n[1],face.n[2])
   if map.find_surface(point,normal,int(face.block)).is_empty():
    _fail("hard deck cannot resolve paint surface "+str(face.id)); return
   scene.ink.splat_face(int(face.id),u,v,0.8,0,0.4)
   if scene.ink.owner_at(int(face.id),u,v)!=0:
    _fail("valid hard deck cell cannot be painted "+str(face.id)); return
   tested+=1
  if tested<30:
   _fail("too few hard deck surfaces audited"); return
  scene.get_node("InkView").sync_dirty()
  for block in map.get_children():
   if block is StaticBody3D and int(block.get_meta("pattern",0))==12 and block.collision_layer!=8:
    _fail("grate must be separate from solid inkable decks"); return
  if map_id=="kelpline":
   for block in map.get_children():
    if block is StaticBody3D and block.collision_layer==8:
     var saved_position:=walker.global_position
     walker.global_position=block.global_position+Vector3.DOWN*0.6
     walker.update_form(true)
     if not walker.update_form(false):
      _fail("squid stood up inside a grate");return
     walker.global_position=saved_position
     walker.update_form(false)
     break
  var panel: Panel = scene.settings_panel
  panel.open_with(scene.settings,scene.settings_path)
  panel.render_scale_button.select(1)
  panel._on_save_pressed()
  if absf(root.scaling_3d_scale-1.0)>0.001:
   _fail("render scale setting did not apply"); return
  DirAccess.remove_absolute(scene.settings_path)
  print("AUDIT: ",map_id," hard deck faces=",tested," maximum weapon hand step=",max_jump," hips=",sk.get_bone_pose_position(hip).y)
  scene.queue_free()
  await process_frame
 Setup.map_id="tidewater"
 print("PASS: startup frame cap; visible feet; original weapon IK/action continuity; own-ink-only Shift; dual-map hard deck paint; grate separation; render-scale settings")
 quit()
func _fail(message: String) -> void:
 printerr("FAIL: ",message)
 quit(1)
