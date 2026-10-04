extends SceneTree
const Setup := preload("res://src/core/match_setup.gd")
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 for id in ["tidewater","kelpline"]:
  Setup.map_id = id
  var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
  root.add_child(game)
  await process_frame
  game.set_physics_process(false)
  var ink: RefCounted = game.get("ink")
  var map: Control = game.get("minimap")
  var expanded: Control = game.get("expanded_map")
  for team in range(2):
   game.paint_at_world(game.get_node("World/Map").get("spawn_pads")[team]+Vector3.UP*0.1,team,1.2,0.5)
  map._refresh_ink()
  expanded._refresh_ink()
  var atlas: Dictionary = game.get_meta("minimap_atlas")
  var bytes: PackedByteArray = atlas["bytes"]
  var offset := 0
  for cells in ink.get("owners"):
   for i in range(cells.size()):
    if bytes[offset+i] != cells[i]:
     printerr("FAIL: minimap ownership differs from authoritative grid");quit(1);return
   offset += cells.size()
  if int(atlas["version"]) != int(ink.get("version")):
   printerr("FAIL: minimap stale after paint");quit(1);return
  var self_p: Vector2 = map._project(game.get_node("World/Map").get("spawn_pads")[0])
  var enemy_p: Vector2 = map._project(game.get_node("World/Map").get("spawn_pads")[1])
  if self_p.y <= enemy_p.y:
   printerr("FAIL: own spawn is not at bottom");quit(1);return
  var view := preload("res://src/world/surface_ink_view.gd")
  for face in ink.get("surfaces"):
   if bool(face["paintable"]) and absf(float(face["n"][1])) < 0.45:
    var mesh: ArrayMesh = view._face_mesh(face)
    var origin := Vector3(face["origin"][0],face["origin"][1],face["origin"][2])
    var normal := Vector3(face["n"][0],face["n"][1],face["n"][2])
    var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    if (vertices[0]-origin).dot(normal)<0.022:
     printerr("FAIL: ink competes with the 12 mm warning decal");quit(1);return
  var fx: Node3D = game.get_node("Combat").get("feedback")
  for kind in ["hit","splat","dive","jump","muzzle"]:
   fx.emit(kind,Vector3.ZERO,0)
   fx.emit(kind,Vector3.ZERO,1)
  fx.advance(1.0)
  for particle in fx.get("particles"):
   if float(particle["life"]) > 0.0:
    printerr("FAIL: transient effects do not expire");quit(1);return
  if (fx.get("particles") as Array).size() != 96:
   printerr("FAIL: unbounded feedback pool");quit(1);return
  game.queue_free()
  await process_frame
 Setup.map_id = "tidewater"
 print("PASS: both source minimaps read exact ownership, own spawn projection, decal depth separation and bounded expiring feedback")
 quit()
