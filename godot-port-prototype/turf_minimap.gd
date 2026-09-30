extends Control

const TeamPalette := preload("res://team_palette.gd")
var game: Node3D
var clock := 0.0
var ink_marks: Array = []
var map_bounds := Rect2()
var last_version := -1

func setup(owner: Node3D) -> void:
 game = owner
 map_bounds = game.get_node("World/Map").get("map_bounds")
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
 if game == null or not visible:
  return
 clock += delta
 if clock >= 0.25:
  clock = 0.0
  _refresh_ink()
  queue_redraw()

func _project(point: Vector3) -> Vector2:
 var uv := (Vector2(point.x,point.z) - map_bounds.position) / map_bounds.size
 return Vector2(8.0,8.0) + uv * (size - Vector2(16.0,16.0))

func _refresh_ink() -> void:
 var ink: RefCounted = game.get("ink")
 if int(ink.get("version")) == last_version:
  return
 last_version = int(ink.get("version"))
 ink_marks.clear()
 for face in ink.get("surfaces"):
  if not bool(face["turf"]) or not face["grid"] is Dictionary:
   continue
  var grid: Dictionary = face["grid"]
  var origin := _vector(face["origin"])
  var u := _vector(face["u"])
  var v := _vector(face["v"])
  # Four source cells per sample (about one metre). Display only; never changes score.
  for j in range(0,int(grid["nv"]),4):
   for i in range(0,int(grid["nu"]),4):
    var owner := int(ink.call("owner_at", int(face["id"]), (i + 0.5) * float(grid["cu"]), (j + 0.5) * float(grid["cv"])))
    if owner >= 0:
     var p := origin + u * (i + 0.5) * float(grid["cu"]) + v * (j + 0.5) * float(grid["cv"])
     ink_marks.append({"p":_project(p),"team":owner})

func _draw() -> void:
 if game == null:
  return
 draw_style_box(_backing(), Rect2(Vector2.ZERO,size))
 var ink: RefCounted = game.get("ink")
 for face in ink.get("surfaces"):
  if not bool(face["turf"]) or not face["grid"] is Dictionary:
   continue
  var origin := _vector(face["origin"])
  var u := _vector(face["u"]) * float(face["su"])
  var v := _vector(face["v"]) * float(face["sv"])
  draw_colored_polygon(PackedVector2Array([_project(origin),_project(origin+u),_project(origin+u+v),_project(origin+v)]),Color("354053"))
 var dot_size := (size - Vector2(16.0,16.0)) / map_bounds.size * 1.1
 for mark in ink_marks:
  draw_rect(Rect2(mark["p"],dot_size), TeamPalette.color(int(mark["team"])))
 for actor in game.call("all_actors"):
  if not bool(game.call("actor_alive",actor)):
   continue
  var team := int(game.call("actor_team",actor))
  var p := _project(actor.global_position)
  draw_circle(p,4.0,Color("152033"))
  draw_circle(p,2.6,TeamPalette.color(team).lightened(0.4))
  if actor == game.get_node("World/Walker"):
   draw_arc(p,6.0,0.0,TAU,16,Color.WHITE,1.5,true)

func _backing() -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.035,0.045,0.075,0.92)
 style.set_corner_radius_all(12)
 style.border_color = Color("8191ab")
 style.set_border_width_all(1)
 return style

static func _vector(values: Array) -> Vector3:
 return Vector3(values[0],values[1],values[2])
