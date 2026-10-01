extends Control

signal point_selected(xz: Vector2)
var interactive := false
var show_border := true
var show_live_marks := true

const TeamPalette := preload("res://team_palette.gd")
const Setup := preload("res://match_setup.gd")
var game: Node3D
var clock := 0.0
var map_bounds := Rect2()
var last_version := -1
var backing: StyleBoxFlat
var map_image: TextureRect
var atlas: Dictionary

func setup(owner: Node3D) -> void:
 game = owner
 map_bounds = game.get_node("World/Map").get("map_bounds")
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 backing = _backing()
 if not game.has_meta("minimap_atlas"):
  var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s_minimap.json" % preload("res://map_catalog.gd").asset_id()))
  var bytes := FileAccess.get_file_as_bytes("res://assets/maps/%s_minimap_lookup.bin" % preload("res://map_catalog.gd").asset_id())
  var lookup := Image.create_from_data(int(info["width"]),int(info["height"]),false,Image.FORMAT_RGBAF,bytes)
  var atlas_size := Vector2i(512,ceili(float(info["cells"])/512.0))
  var blank := Image.create(atlas_size.x,atlas_size.y,false,Image.FORMAT_R8)
  game.set_meta("minimap_atlas",{"size":atlas_size,"lookup":ImageTexture.create_from_image(lookup),"texture":ImageTexture.create_from_image(blank),"version":-1,"cells":int(info["cells"])})
 atlas = game.get_meta("minimap_atlas")
 map_image = TextureRect.new()
 map_image.texture = load("res://assets/maps/%s_minimap.png" % preload("res://map_catalog.gd").asset_id())
 map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 map_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var shader := ShaderMaterial.new()
 shader.shader = preload("res://turf_minimap.gdshader")
 shader.set_shader_parameter("cell_lookup",atlas["lookup"])
 shader.set_shader_parameter("ownership",atlas["texture"])
 shader.set_shader_parameter("atlas_size",Vector2(atlas["size"]))
 shader.set_shader_parameter("team_a",TeamPalette.color(0))
 shader.set_shader_parameter("team_b",TeamPalette.color(1))
 map_image.material = shader
 add_child(map_image)
 # The texture draws below the live actor/effect marks in this Control.
 map_image.show_behind_parent = true
 resized.connect(_layout)
 _layout()
 _refresh_ink()

func _layout() -> void:
 var padding := 16.0 if show_border else 0.0
 var extent := map_bounds.size * maxf(0.01,minf((size.x-padding)/map_bounds.size.x,(size.y-padding)/map_bounds.size.y))
 map_image.position = (size-extent)*0.5
 map_image.size = extent
 queue_redraw()

func _process(delta: float) -> void:
 if game == null or not is_visible_in_tree():
  return
 clock += delta
 if clock >= 1.0/6.0:
  clock = 0.0
  _refresh_ink()
 queue_redraw()

func _project(point: Vector3) -> Vector2:
 var uv := (Vector2(point.x,point.z) - map_bounds.position) / map_bounds.size
 return map_image.position + (Vector2.ONE-uv)*map_image.size

func _gui_input(event: InputEvent) -> void:
 if interactive and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Rect2(map_image.position,map_image.size).has_point(event.position):
  var uv: Vector2 = Vector2.ONE-(event.position-map_image.position)/map_image.size
  point_selected.emit(map_bounds.position+uv*map_bounds.size)
  accept_event()

func _refresh_ink() -> void:
 var ink: RefCounted = game.get("ink")
 last_version = int(ink.get("version"))
 if last_version == int(atlas["version"]):
  return
 var bytes := PackedByteArray()
 for cells in ink.get("owners"):
  bytes.append_array(cells)
 assert(bytes.size() == int(atlas["cells"]), "Minimap ownership offsets differ from the source grid")
 var dimensions: Vector2i = atlas["size"]
 bytes.resize(dimensions.x*dimensions.y)
 atlas["bytes"] = bytes
 atlas["texture"].update(Image.create_from_data(dimensions.x,dimensions.y,false,Image.FORMAT_R8,bytes))
 atlas["version"] = last_version

func _draw() -> void:
 if game == null:
  return
 # Only draw the border here: a filled parent would cover its behind-parent map.
 if show_border:draw_style_box(backing, Rect2(Vector2.ZERO,size))
 if not show_live_marks:return
 var expanded := size.y > 230.0
 var font: Font = ThemeDB.fallback_font
 for pad in game.get_node("World/Map").get("spawn_pads"):
  draw_arc(_project(pad),7.0,0.0,TAU,20,Color.WHITE,1.5,true)
 for actor in game.call("all_actors"):
  var team := int(game.call("actor_team",actor))
  var p := _project(actor.global_position)
  var alive := bool(game.call("actor_alive",actor))
  var color := TeamPalette.color(team).lightened(0.3)
  var self_actor: bool = actor == game.get_node("World/Walker")
  var radius := 7.0 if expanded else 5.0
  draw_circle(p,radius+1.5,Color("152033"))
  draw_circle(p,radius,color if alive else color.darkened(0.65))
  if alive:
   var yaw: float = actor.get("camera_yaw") if self_actor else actor.get_node("Body").rotation.y
   var forward := Vector2(sin(yaw),cos(yaw)) if not self_actor else Vector2(-sin(yaw),-cos(yaw))
   # Bots face +Z; the walker uses camera forward (-sin yaw, -cos yaw).
   if not self_actor:
    forward = -forward
   var tip := p+forward*(radius+5.0)
   var side := forward.orthogonal()*3.0
   draw_colored_polygon(PackedVector2Array([tip,p+forward*radius+side,p+forward*radius-side]),Color.WHITE if self_actor else color)
  else:
   draw_line(p-Vector2(3,3),p+Vector2(3,3),Color.WHITE,1.5,true)
   draw_line(p-Vector2(-3,3),p+Vector2(-3,3),Color.WHITE,1.5,true)
  if self_actor:
   draw_arc(p,radius+3.0,0.0,TAU,20,Color.WHITE,1.5,true)
  var label := "%02d%s" % [int(game.call("actor_id",actor))," "+String(game.call("actor_name",actor)) if expanded else ""]
  var font_size := 12 if expanded else 10
  var at := p+Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5,-radius-5.0)
  draw_string_outline(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color("152033"))
  draw_string(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
 if game.get("deployment")!=null:
  for beacon in game.deployment.beacons:
   var p:=_project(beacon.point);var color:=TeamPalette.color(int(beacon.team))
   draw_rect(Rect2(p-Vector2(5,5),Vector2(10,10)),color if beacon.available else color.darkened(.6))
   draw_rect(Rect2(p-Vector2(5,5),Vector2(10,10)),Color.WHITE,false,1)
   if expanded:draw_string(font,p+Vector2(7,4),"信%d" % beacon.uses,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
  if game.deployment.active and game.deployment.marker.visible:
   var p:=_project(game.deployment.target);draw_arc(p,11,0,TAU,24,Color.WHITE,2,true)
 var combat: Node3D = game.get_node("Combat")
 for bomb in combat.get("bombs"):
  var p := _project(bomb["position"])
  draw_circle(p,3.0,Color.WHITE if sin(float(combat.get("elapsed"))*18)>0 else TeamPalette.color(int(bomb.get("team",0))))
 for cloud in combat.get("clouds"):
  var p := _project((cloud["visual"] as Node3D).global_position)
  draw_arc(p,10,0,TAU,24,TeamPalette.color(int(cloud.get("team",0))).lightened(0.3),1.5,true)

func _backing() -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = Color.TRANSPARENT
 style.set_corner_radius_all(12)
 style.border_color = Color("8191ab")
 style.set_border_width_all(2)
 return style
