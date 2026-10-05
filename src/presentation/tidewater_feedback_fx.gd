extends Node3D

# Two bounded draw calls for transient droplets. Gameplay never reads these particles.
const Palette := preload("res://src/core/team_palette.gd")
const CAPACITY := 48
var pools: Array[MultiMesh] = []
var particles: Array[Dictionary] = []
var cursor := [0,0]
var events := {"hit":0,"splat":0,"dive":0,"jump":0,"muzzle":0}

func _ready() -> void:
 var mesh := SphereMesh.new()
 mesh.radius = 0.07
 mesh.height = 0.14
 mesh.radial_segments = 6
 mesh.rings = 3
 for team in range(2):
  var batch := MultiMesh.new()
  batch.transform_format = MultiMesh.TRANSFORM_3D
  batch.mesh = mesh
  batch.instance_count = CAPACITY
  var visual := MultiMeshInstance3D.new()
  visual.multimesh = batch
  visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var material := StandardMaterial3D.new()
  material.albedo_color = Palette.color(team).lightened(0.12)
  material.roughness = 0.22
  visual.material_override = material
  add_child(visual)
  pools.append(batch)
  for slot in range(CAPACITY):
   particles.append({"life":0.0})
   batch.set_instance_transform(slot,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.001),Vector3(0,-1000,0)))

func emit(kind: String, at: Vector3, team: int, normal: Vector3 = Vector3.UP) -> void:
 events[kind] = int(events.get(kind,0))+1
 var count := 18 if kind == "splat" else (3 if kind == "muzzle" else 6)
 var power := 4.0 if kind == "splat" else (1.8 if kind == "muzzle" else 2.6)
 for n in range(count):
  var slot: int = cursor[team]
  cursor[team] = (slot+1)%CAPACITY
  var velocity := (Vector3(randf_range(-1,1),randf_range(0.1,1.0),randf_range(-1,1))+normal*0.7).normalized()*power*randf_range(0.6,1.0)
  var life := randf_range(0.24,0.48)
  particles[team*CAPACITY+slot] = {"p":at,"v":velocity,"life":life,"total":life}

func advance(delta: float) -> void:
 advance_trails(delta)
 advance_warnings(delta)
 for i in range(particles.size()):
  var particle := particles[i]
  if float(particle["life"]) <= 0.0:
   continue
  particle["life"] = maxf(0.0,float(particle["life"])-delta)
  var slot := i%CAPACITY
  var batch := pools[i/CAPACITY]
  if float(particle["life"]) <= 0.0:
   batch.set_instance_transform(slot,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.001),Vector3(0,-1000,0)))
   continue
  particle["v"] = (particle["v"] as Vector3)-Vector3.UP*10.0*delta
  particle["p"] = (particle["p"] as Vector3)+(particle["v"] as Vector3)*delta
  var scale_factor := float(particle["life"])/float(particle["total"])
  batch.set_instance_transform(slot,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_factor),particle["p"]))

# A separate bounded label pool. Numbers use HP actually lost after shield absorption.
const DAMAGE_CAPACITY := 24
var damage_pops: Array[Dictionary] = []
var damage_labels: Array[Label3D] = []
var damage_cursor := 0

func pop_damage(victim: Node3D, amount: float, team: int, region: String = "") -> void:
 if amount<=0:return
 var id:=victim.get_instance_id()
 for pop in damage_pops:
  if pop["victim"]==id and pop["team"]==team and float(pop["age"])<0.22:
   pop["value"]+=amount
   _damage_text(pop)
   return
 var label: Label3D
 if damage_labels.size()<DAMAGE_CAPACITY:
  label=Label3D.new();label.font=load("res://assets/fonts/TitanOne-latin.woff2");label.pixel_size=0.016;label.outline_size=9;label.outline_modulate=Color("100c1b");label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=false;label.visibility_range_end=38;add_child(label);damage_labels.append(label)
 else:
  label=damage_labels[damage_cursor%DAMAGE_CAPACITY]
  for i in range(damage_pops.size()-1,-1,-1):
   if damage_pops[i]["label"]==label:damage_pops.remove_at(i)
 damage_cursor+=1
 var camera:=get_viewport().get_camera_3d()
 var right:Vector3=camera.global_basis.x if camera!=null else Vector3.RIGHT
 var side:float=[-0.4,-0.15,0.15,0.4][damage_cursor%4]
 var pop:Dictionary={"victim":id,"value":amount,"team":clampi(team,0,1),"age":0.0,"label":label,"origin":victim.global_position+Vector3.UP*2.1+right*side}
 label.visible=true;label.font_size=48 if region=="头部" else 42;label.global_position=pop["origin"];label.modulate=Palette.color(team)
 damage_pops.append(pop);_damage_text(pop)

func _damage_text(pop: Dictionary) -> void:
 var label:Label3D=pop["label"]
 label.text="−%.1f" % pop["value"] if float(pop["value"])<10 else "−%.0f" % pop["value"]

func _process(delta: float) -> void:
 advance_damage(delta)

func advance_damage(delta: float) -> void:
 for i in range(damage_pops.size()-1,-1,-1):
  var pop:=damage_pops[i];pop["age"]=float(pop["age"])+delta
  var age:float=pop["age"];var label:Label3D=pop["label"]
  if age>=0.8:label.visible=false;damage_pops.remove_at(i);continue
  label.global_position=pop["origin"]+Vector3.UP*(age*0.75+sin(age/0.8*PI)*0.18)
  label.scale=Vector3.ONE*(1+0.24*exp(-age*16))
  label.modulate=Color(Palette.color(int(pop["team"])),clampf((0.8-age)/0.25,0,1))

# Actual swept movement only, with depth testing. Two bounded batches per team
# give bright cores a dark silhouette against both ink and pale architecture.
const TRAIL_CAPACITY := 96
var trail_pools: Array[MultiMesh] = []
var trail_states: Array[Dictionary] = []
var trail_cursor := [0,0]
func _prepare_trails() -> void:
 if not trail_pools.is_empty():return
 var mesh:=CylinderMesh.new();mesh.top_radius=1;mesh.bottom_radius=1;mesh.height=1;mesh.radial_segments=6
 for team in range(2):
  for core in range(2):
   var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=mesh;batch.instance_count=TRAIL_CAPACITY
   var visual:=MultiMeshInstance3D.new();visual.multimesh=batch;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   mat.albedo_color=Palette.color(team).darkened(.6) if core==0 else Palette.color(team).lightened(.65)
   if core==0:mat.cull_mode=BaseMaterial3D.CULL_FRONT
   visual.material_override=mat;add_child(visual);trail_pools.append(batch)
   for slot in range(TRAIL_CAPACITY):batch.set_instance_transform(slot,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.001),Vector3(0,-1000,0)))
 for i in range(2*TRAIL_CAPACITY):trail_states.append({"life":0.0})
func trail(from:Vector3, to:Vector3, team:int, width:float=.045) -> void:
 if from.distance_to(to)<.01:return
 _prepare_trails();team=clampi(team,0,1)
 var slot:int=trail_cursor[team];trail_cursor[team]=(slot+1)%TRAIL_CAPACITY
 var direction:Vector3=(to-from).normalized();var right:=direction.cross(Vector3.UP).normalized()
 if right.length_squared()<.01:right=Vector3.RIGHT
 var basis:=Basis(right,direction,right.cross(direction).normalized())
 var center:Vector3=(from+to)*.5
 for core in range(2):
  var radius:float=width*(.45 if core==1 else .75)
  trail_pools[team*2+core].set_instance_transform(slot,Transform3D(basis*Basis.from_scale(Vector3(radius,from.distance_to(to),radius)),center))
 trail_states[team*TRAIL_CAPACITY+slot]={"life":.22,"from":from,"to":to}
func advance_trails(delta:float) -> void:
 for i in range(trail_states.size()):
  if float(trail_states[i].life)<=0:continue
  trail_states[i].life-=delta
  if trail_states[i].life<=0:
   for core in range(2):trail_pools[(i/TRAIL_CAPACITY)*2+core].set_instance_transform(i%TRAIL_CAPACITY,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.001),Vector3(0,-1000,0)))

# Only confirmed contact surfaces receive blast outlines. They expire unless
# refreshed by the real fuse, use depth testing, and never predict through walls.
const WARNING_CAPACITY := 32
var warnings: Dictionary = {}
func warning(key:int, at:Vector3, normal:Vector3, radius:float, fuse:float, team:int) -> void:
 if not warnings.has(key):
  if warnings.size()>=WARNING_CAPACITY:remove_warning(warnings.keys()[0])
  var visual:=MeshInstance3D.new();var mesh:=TorusMesh.new()
  mesh.inner_radius=.98;mesh.outer_radius=1.02;mesh.rings=48;mesh.ring_segments=6;visual.mesh=mesh
  var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  visual.material_override=mat;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(visual);warnings[key]={"visual":visual,"life":.12}
 var state:Dictionary=warnings[key];state.life=.12
 var y:Vector3=normal.normalized();var x:=y.cross(Vector3.FORWARD).normalized()
 if x.length_squared()<.01:x=Vector3.RIGHT
 state.visual.global_transform=Transform3D(Basis(x,y,x.cross(y))*Basis.from_scale(Vector3(radius,.4,radius)),at+y*.045)
 state.visual.material_override.albedo_color=Palette.color(clampi(team,0,1)).lightened(.35+.45*(.5+.5*sin(fuse*28)))
func remove_warning(key:int) -> void:
 if warnings.has(key):warnings[key].visual.queue_free();warnings.erase(key)
func advance_warnings(delta:float) -> void:
 for key in warnings.keys():
  warnings[key].life-=delta
  if warnings[key].life<=0:remove_warning(key)
