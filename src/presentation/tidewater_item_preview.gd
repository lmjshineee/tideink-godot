extends Node3D
# Read-only queries shared with actual casts. No ink, damage or deployment writes.
const PLACED:=["mine","sonar","supply_box","beacon","echo_decoy","intel_mist"]
const CAPACITY:=300
var game:Node3D
var line:MultiMeshInstance3D
var batch:MultiMesh
var ring:MeshInstance3D
var dot:MeshInstance3D
var label:Label3D
var material:StandardMaterial3D
var refresh:=0.0
var last_kind:=""
var snapshot:Dictionary={}
func setup(owner_game:Node3D) -> void:
	game=owner_game
	material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	line=MultiMeshInstance3D.new();batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D
	var mesh:=CylinderMesh.new();mesh.height=1;mesh.top_radius=1;mesh.bottom_radius=1;mesh.radial_segments=6
	batch.mesh=mesh;batch.instance_count=CAPACITY;batch.visible_instance_count=0;line.multimesh=batch;line.material_override=material;add_child(line)
	ring=MeshInstance3D.new();var circle:=TorusMesh.new();circle.inner_radius=.98;circle.outer_radius=1.02;circle.rings=64;circle.ring_segments=6
	ring.mesh=circle;ring.material_override=material;add_child(ring)
	dot=MeshInstance3D.new();var marker:=TorusMesh.new();marker.inner_radius=.19;marker.outer_radius=.25;marker.rings=32;dot.mesh=marker;dot.material_override=material;add_child(dot)
	label=Label3D.new();label.font=preload("res://src/ui/ui_fonts.gd").font();label.font_size=26;label.pixel_size=.006;label.outline_size=6;label.no_depth_test=false;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(label)
	for visual in [line,ring,dot]:visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible=false
func predict_bomb(actor:Node3D) -> Dictionary:
	var combat:Node3D=game.get_node("Combat");var config:Dictionary=combat.weapon_data.sub.bomb
	var shot:Dictionary=combat.bomb_launch(actor,config);var points:=PackedVector3Array([shot.position])
	var position:Vector3=shot.position;var velocity:Vector3=shot.velocity;var fuse:=-1.0
	var delta:=1.0/float(Engine.physics_ticks_per_second);var explosive:=false
	for i in range(mini(CAPACITY,ceili(5.0/delta))):
		var step:Dictionary=combat.bomb_step(position,velocity,delta,fuse,config)
		position=step.position;velocity=step.velocity;fuse=step.fuse;points.append(position)
		if fuse>=0:
			fuse-=delta
			if fuse<=0:explosive=true;break
		if position.y<float(combat.weapon_data.player.fallDeathY)-1.8:break
	return {"points":points,"point":position,"radius":float(config.radius),"valid":explosive,"bomb":true}
func query(actor:Node3D,kind:String) -> Dictionary:
	var items:Node3D=game.items;var checked:Dictionary={};var radius:=.55
	match kind:
		"bomb":return predict_bomb(actor)
		"mine":checked=items.mines.target(actor);radius=items.mines.TRIGGER
		"sonar","supply_box":checked=items.ground_target(actor)
		"beacon":checked=game.deployment.beacon_target(actor)
		"echo_decoy":checked=items.decoys.target(actor,game.get_node("Combat")._aim_target(actor.global_position+Vector3.UP,8))
		"intel_mist":
			var from:=actor.global_position+Vector3.UP*.85
			checked=items.mist.target(from,game.get_node("Combat")._aim_target(from,items.mist.RANGE));radius=items.mist.RADIUS
	if checked.is_empty():return {"point":actor.global_position,"valid":false,"radius":.5}
	return {"point":checked.point,"valid":true,"radius":radius}
func tick(delta:float) -> void:
	var walker:Node3D=game.get_node("World/Walker");var combat:Node3D=game.get_node("Combat")
	var kind:String=game.items.state(walker).kind
	visible=game.phase=="playing" and not game.paused and game.pointer_locked and game.actor_alive(walker) and not walker.squid_form and (kind in PLACED or (kind=="bomb" and combat.aiming_sub))
	if not visible:refresh=0;return
	refresh-=delta
	if refresh>0 and last_kind==kind:return
	refresh=.08;last_kind=kind;snapshot=query(walker,kind)
	var costs:Dictionary={"bomb":float(combat.weapon_data.sub.bomb.inkCost),"mine":game.items.mines.COST,"sonar":game.items.sonar.COST,"supply_box":game.items.supply.COST,"beacon":35.0,"echo_decoy":game.items.decoys.COST,"intel_mist":game.items.mist.COST}
	var ready:bool=game.items.state(walker).cooldowns[kind]<=0 and combat.ink_amount>=costs[kind] and not game.mobility.busy(walker) and not game.wings.busy(walker) and not game.deployment.active and combat.special_active=="" and combat.action_lock<=0
	var valid:bool=snapshot.valid and ready
	material.albedo_color=Color("fff3b0") if valid else Color("ff5c72")
	var at:Vector3=snapshot.point
	var floor_hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.1,at-Vector3.UP*.7,1))
	var surface:Vector3=floor_hit.position+floor_hit.normal*.035 if not floor_hit.is_empty() else at
	var normal:Vector3=floor_hit.normal if not floor_hit.is_empty() else Vector3.UP
	var tangent:=normal.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared()<.01:tangent=Vector3.RIGHT
	var surface_basis:=Basis(tangent,normal,tangent.cross(normal))
	ring.transform=Transform3D(surface_basis*Basis.from_scale(Vector3(snapshot.radius,.35,snapshot.radius)),surface)
	dot.transform=Transform3D(surface_basis,surface)
	ring.visible=snapshot.valid;label.position=at+Vector3.UP*.4;label.modulate=material.albedo_color
	label.text=("预计爆点 · %.1fm" % snapshot.radius if kind=="bomb" else "放置点 · E / 右键") if valid else "无法投放" if not snapshot.valid else "冷却 / 缺墨 / 动作锁"
	batch.visible_instance_count=0
	if snapshot.has("points"):
		var points:PackedVector3Array=snapshot.points;var count:=mini(CAPACITY,points.size()-1)
		for i in range(count):
			var offset:=points[i+1]-points[i];var direction:=offset.normalized();var right:=direction.cross(Vector3.UP).normalized()
			if right.length_squared()<.01:right=Vector3.RIGHT
			var basis:=Basis(right,direction,right.cross(direction).normalized())*Basis.from_scale(Vector3(.022,maxf(.001,offset.length()),.022))
			batch.set_instance_transform(i,Transform3D(basis,(points[i]+points[i+1])*.5))
		batch.visible_instance_count=count

func _process(_delta:float) -> void:
	if game!=null and (game.phase!="playing" or game.paused):visible=false
