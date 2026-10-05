extends RefCounted

# Read source NavGraph nodes/edges, use Godot AStar for the team patrol routes.
# Source costs favour walk routes; jump/drop transitions keep their original penalty.
class SourceGraph extends AStar3D:
 var edges: Dictionary = {}
 func _compute_cost(a: int, b: int) -> float:
  return float(edges[Vector2i(a,b)]["cost"])
 func _estimate_cost(a: int, b: int) -> float:
  var delta := get_point_position(a)-get_point_position(b)
  return Vector2(delta.x,delta.z).length()

var graphs: Array[AStar3D] = []
var nodes: Array = []
var goals: Array[PackedInt64Array] = []
var terrain: Node3D
var clearance := PhysicsShapeQueryParameters3D.new()
var clear_nodes: Dictionary = {}

func setup(map_id: String, map_node: Node3D = null, body_height: float = 1.45) -> void:
 graphs.clear(); goals.clear(); clear_nodes.clear()
 terrain = map_node
 var body := CapsuleShape3D.new()
 body.radius = .34
 # Ignore the feet's small ramp/step tolerance, but keep the real head height.
 body.height = body_height - .2
 clearance.shape = body
 clearance.collision_mask = 9 # Static terrain and grates, never live actors.
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s_nav.json" % map_id))
 nodes = data["nodes"]
 for team in range(2):
  var graph := SourceGraph.new()
  var candidates := PackedInt64Array()
  for node in nodes:
   if int(node["zone"]) == 1 - team:
    continue
   var p: Array = node["p"]
   graph.add_point(int(node["id"]), Vector3(p[0],p[1],p[2]))
   if int(node["zone"]) < 0:
    candidates.append(int(node["id"]))
  for node in nodes:
   var id := int(node["id"])
   if not graph.has_point(id):
    continue
   for edge in node["edges"]:
    var to := int(edge["to"])
    if graph.has_point(to):
     graph.edges[Vector2i(id,to)] = edge
     graph.connect_points(id,to,false)
  graphs.append(graph)
  goals.append(candidates)

func route(from: Vector3, target: Vector3, team: int) -> PackedVector3Array:
 var graph := graphs[team]
 # Source nodes describe surface positions. Some ground nodes below inclined
 # ramps have no room for a standing body. Lazily reject these in real physics
 # and cache the static result; a route must never force a bot into the ceiling.
 for attempt in range(16):
  var first := graph.get_closest_point(from)
  var last := graph.get_closest_point(target)
  if first < 0 or last < 0: return PackedVector3Array()
  var ids := graph.get_id_path(first,last)
  if ids.is_empty(): return PackedVector3Array()
  var blocked := false
  for id in ids:
   if not _standing_clear(id,graph.get_point_position(id)):
    graph.set_point_disabled(id)
    blocked = true
  if not blocked: return graph.get_point_path(first,last)
 return PackedVector3Array()

func _standing_clear(id: int, point: Vector3) -> bool:
 if terrain == null: return true # Graph-only inspection has no physics world.
 if not clear_nodes.has(id):
  clearance.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*(.25+clearance.shape.height*.5))
  clear_nodes[id] = terrain.get_world_3d().direct_space_state.intersect_shape(clearance,1).is_empty()
 return bool(clear_nodes[id])

func patrol(from: Vector3, team: int, lane: int) -> PackedVector3Array:
 var graph := graphs[team]
 # Prefer the middle/opposite half and a different lateral lane for each teammate.
 for attempt in range(18):
  var id := goals[team][randi() % goals[team].size()]
  if graph.is_point_disabled(id): continue
  var target := graph.get_point_position(id)
  if target.distance_to(from) < 7.0 or absf(target.x - (float(lane % 3) - 1.0) * 10.0) > 12.0:
   continue
  var path := route(from,target,team)
  if path.size() > 1:
   return path
 # Random lane preference must not turn into an idle interval.
 for id in goals[team]:
  if graph.is_point_disabled(id): continue
  if graph.get_point_position(id).distance_to(from) < 3: continue
  var fallback := route(from,graph.get_point_position(id),team)
  if fallback.size() > 1: return fallback
 return PackedVector3Array()

func transition(from: Vector3, target: Vector3, team: int) -> String:
 var graph := graphs[team] as SourceGraph
 var a := graph.get_closest_point(from)
 var b := graph.get_closest_point(target)
 return String(graph.edges.get(Vector2i(a,b), {}).get("type", "walk"))
