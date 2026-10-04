extends Control

signal point_selected(xz: Vector2)
var interactive := false
var show_border := true
var show_live_marks := true
var quarter_turns := 0

const TeamPalette := preload("res://src/core/team_palette.gd")
const Setup := preload("res://src/core/match_setup.gd")
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
  var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s_minimap.json" % preload("res://src/core/map_catalog.gd").asset_id()))
  var bytes := FileAccess.get_file_as_bytes("res://assets/maps/%s_minimap_lookup.bin" % preload("res://src/core/map_catalog.gd").asset_id())
  var lookup := Image.create_from_data(int(info["width"]),int(info["height"]),false,Image.FORMAT_RGBAF,bytes)
  var atlas_size := Vector2i(512,ceili(float(info["cells"])/512.0))
  var blank := Image.create(atlas_size.x,atlas_size.y,false,Image.FORMAT_R8)
  game.set_meta("minimap_atlas",{"size":atlas_size,"lookup":ImageTexture.create_from_image(lookup),"texture":ImageTexture.create_from_image(blank),"version":-1,"cells":int(info["cells"])})
 atlas = game.get_meta("minimap_atlas")
 map_image = TextureRect.new()
 map_image.texture = load("res://assets/maps/%s_minimap.png" % preload("res://src/core/map_catalog.gd").asset_id())
 map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 map_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var shader := ShaderMaterial.new()
 shader.shader = preload("res://shaders/world/turf_minimap.gdshader")
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
 var rotated := map_bounds.size if quarter_turns % 2 == 0 else Vector2(map_bounds.size.y,map_bounds.size.x)
 var extent := map_bounds.size * maxf(0.01,minf((size.x-padding)/rotated.x,(size.y-padding)/rotated.y))
 map_image.position = (size-extent)*0.5
 map_image.size = extent
 map_image.pivot_offset = extent*.5
 map_image.rotation = quarter_turns*PI*.5
 (map_image.material as ShaderMaterial).set_shader_parameter("edge_feather",Vector2.ZERO if show_border else Vector2(2.0/extent.x,2.0/extent.y))
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
 return size*.5+((Vector2.ONE-uv)*map_image.size-map_image.size*.5).rotated(quarter_turns*PI*.5)

func _gui_input(event: InputEvent) -> void:
 if interactive and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  var local: Vector2 = (event.position-size*.5).rotated(-quarter_turns*PI*.5)+map_image.size*.5
  if not Rect2(Vector2.ZERO,map_image.size).has_point(local): return
  var uv: Vector2 = Vector2.ONE-local/map_image.size
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
 var font: Font = preload("res://src/ui/ui_fonts.gd").font()
 for pad in game.get_node("World/Map").get("spawn_pads"):
  draw_arc(_project(pad),7.0,0.0,TAU,20,Color.WHITE,1.5,true)
 for info in actor_marks():
  var actor: Node3D = info.actor
  var ghost: bool = info.status == "last"
  var tagged: bool = info.status == "sonar"
  var team := int(game.call("actor_team",actor))
  var p := _project(info.point)
  var alive := bool(game.call("actor_alive",actor))
  var color := TeamPalette.color(team).lightened(0.3)
  if ghost: color.a = .45
  var self_actor: bool = actor == game.get_node("World/Walker")
  var radius := 7.0 if expanded else 5.0
  draw_circle(p,radius+1.5,Color("152033"))
  draw_circle(p,radius,color if alive else color.darkened(0.65))
  if ghost:
   draw_arc(p,radius+3,0,TAU,16,color,1,true)
  elif tagged:
   draw_arc(p,radius+3,0,TAU,24,Color.WHITE,2,true)
  if alive and not ghost:
   var yaw: float = info.yaw
   var forward := Vector2(sin(yaw),cos(yaw)) if not self_actor else Vector2(-sin(yaw),-cos(yaw))
   # Bots face +Z; the walker uses camera forward (-sin yaw, -cos yaw).
   if not self_actor:
    forward = -forward
   var tip := p+forward*(radius+5.0)
   var side := forward.orthogonal()*3.0
   draw_colored_polygon(PackedVector2Array([tip,p+forward*radius+side,p+forward*radius-side]),Color.WHITE if self_actor else color)
  elif not alive:
   draw_line(p-Vector2(3,3),p+Vector2(3,3),Color.WHITE,1.5,true)
   draw_line(p-Vector2(-3,3),p+Vector2(-3,3),Color.WHITE,1.5,true)
  if self_actor:
   draw_arc(p,radius+3.0,0.0,TAU,20,Color.WHITE,1.5,true)
  var label := "%02d%s" % [int(game.call("actor_id",actor))," "+String(game.call("actor_name",actor)) if expanded else ""]
  if ghost: label += " ?"
  var font_size := 12 if expanded else 10
  var at := p+Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5,-radius-5.0)
  draw_string_outline(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color("152033"))
  draw_string(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
 if game.get("deployment")!=null:
  for beacon in game.deployment.beacons:
   if int(beacon.team) != 0 and not game.intel.visible_point(beacon.point + Vector3.UP * .5, 0): continue
   var p:=_project(beacon.point);var color:=TeamPalette.color(int(beacon.team))
   draw_rect(Rect2(p-Vector2(5,5),Vector2(10,10)),color if beacon.available else color.darkened(.6))
   draw_rect(Rect2(p-Vector2(5,5),Vector2(10,10)),Color.WHITE,false,1)
   if expanded:draw_string(font,p+Vector2(7,4),"信%d" % beacon.uses,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
  if game.deployment.active and game.deployment.marker.visible:
   var p:=_project(game.deployment.target);draw_arc(p,11,0,TAU,24,Color.WHITE,2,true)
 if game.get("items") != null:
  for mark in game.items.decoys.marks_for(0):
   var p := _project(mark.point); var color := TeamPalette.color(mark.team).lightened(.3)
   if mark.status == "last": color.a = .45
   draw_circle(p,7 if expanded else 5,color)
   if mark.known:
    draw_line(p-Vector2(3,3),p+Vector2(3,3),Color.WHITE,1.5,true)
    draw_line(p-Vector2(-3,3),p+Vector2(-3,3),Color.WHITE,1.5,true)
    if expanded: draw_string(font,p+Vector2(8,4),"诱饵",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
   else:
    var forward := -Vector2(sin(mark.yaw),cos(mark.yaw))
    var side := forward.orthogonal()*3
    draw_colored_polygon(PackedVector2Array([p+forward*11,p+forward*5+side,p+forward*5-side]),color)
    var label := "%02d%s" % [mark.owner_id," "+mark.name if expanded else ""]
    draw_string(font,p+Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x*.5,-11),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
  for box in game.items.supply.boxes.values():
   if box.team != 0 and not game.intel.visible_point(box.point+Vector3.UP*.25,0): continue
   var p := _project(box.point)
   draw_rect(Rect2(p-Vector2(5,4),Vector2(10,8)),TeamPalette.color(box.team).lightened(.3))
   draw_rect(Rect2(p-Vector2(5,4),Vector2(10,8)),Color.WHITE,false,1)
   if expanded: draw_string(font,p+Vector2(8,4),"补给 %d" % box.stock,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
  for mine in game.items.mines.mines.values():
   if int(mine.team) != 0: continue
   var p := _project(mine.point)
   var color := Color.WHITE if mine.fuse >= 0 else TeamPalette.color(0).lightened(.3)
   draw_colored_polygon(PackedVector2Array([p+Vector2(0,-5),p+Vector2(5,0),p+Vector2(0,5),p+Vector2(-5,0)]),color)
   if expanded: draw_string(font,p+Vector2(8,4),"雷 %.0fs" % mine.time,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
  for station in game.items.sonar.stations.values():
   if int(station.team) != 0: continue
   var p := _project(station.point)
   draw_arc(p,6,0,TAU,24,TeamPalette.color(0),2,true)
   draw_circle(p,2,Color.WHITE)
   if float(station.radius) >= 0:
    var r: float = station.radius * map_image.size.x / map_bounds.size.x
    draw_arc(p,r,0,TAU,48,Color(TeamPalette.color(0), .65),1.5,true)
  for volume in game.items.mist.volumes:
   if int(volume.team) != 0: continue
   var p := _project(volume.point)
   var r: float = game.items.mist.RADIUS * map_image.size.x / map_bounds.size.x
   draw_circle(p,r,Color(TeamPalette.color(0),.12))
   draw_arc(p,r,0,TAU,32,Color(TeamPalette.color(0),.65),1.5,true)
   if expanded: draw_string(font,p+Vector2(r+2,4),"雾 %.0fs" % volume.time,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
  for anchor in game.items.recall.anchors.values():
   if int(anchor.team) != 0: continue
   var p := _project(anchor.point)
   draw_arc(p,8,0,TAU,24,TeamPalette.color(0),2,true)
   draw_line(p-Vector2(4,0),p+Vector2(4,0),Color.WHITE,2,true)
   draw_line(p-Vector2(0,4),p+Vector2(0,4),Color.WHITE,2,true)
   if expanded: draw_string(font,p+Vector2(10,4),"锚 %.0fs" % anchor.time,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
 var combat: Node3D = game.get_node("Combat")
 for bomb in combat.get("bombs"):
  if int(bomb.get("team",0)) != 0 and not game.intel.visible_point(bomb.position, 0): continue
  var p := _project(bomb["position"])
  draw_circle(p,3.0,Color.WHITE if sin(float(combat.get("elapsed"))*18)>0 else TeamPalette.color(int(bomb.get("team",0))))
 for cloud in combat.get("clouds"):
  if int(cloud.get("team",0)) != 0 and not game.intel.visible_point(cloud.visual.global_position, 0): continue
  var p := _project((cloud["visual"] as Node3D).global_position)
  draw_arc(p,10,0,TAU,24,TeamPalette.color(int(cloud.get("team",0))).lightened(0.3),1.5,true)

func actor_marks() -> Array[Dictionary]:
 var marks: Array[Dictionary] = []
 for actor in game.all_actors():
  var info: Dictionary = game.intel.marker(actor, 0)
  if not info.is_empty(): marks.append(info)
 return marks

func _backing() -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = Color.TRANSPARENT
 style.set_corner_radius_all(12)
 style.border_color = Color("8191ab")
 style.set_border_width_all(2)
 return style
