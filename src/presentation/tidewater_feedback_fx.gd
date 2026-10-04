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
