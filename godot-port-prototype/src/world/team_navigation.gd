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

func setup(map_id: String) -> void:
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
 var first := graph.get_closest_point(from)
 var last := graph.get_closest_point(target)
 return graph.get_point_path(first,last)

func patrol(from: Vector3, team: int, lane: int) -> PackedVector3Array:
 var graph := graphs[team]
 # Prefer the middle/opposite half and a different lateral lane for each teammate.
 for attempt in range(18):
  var id := goals[team][randi() % goals[team].size()]
  var target := graph.get_point_position(id)
  if target.distance_to(from) < 7.0 or absf(target.x - (float(lane % 3) - 1.0) * 10.0) > 12.0:
   continue
  var path := route(from,target,team)
  if path.size() > 1:
   return path
 return PackedVector3Array()

func transition(from: Vector3, target: Vector3, team: int) -> String:
 var graph := graphs[team] as SourceGraph
 var a := graph.get_closest_point(from)
 var b := graph.get_closest_point(target)
 return String(graph.edges.get(Vector2i(a,b), {}).get("type", "walk"))
