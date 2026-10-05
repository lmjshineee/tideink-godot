extends Node3D

# Original rounded creature. Visual animation never writes combat or ink state.
var mantle:Node3D
var feet:Array[Node3D]=[]
var eyes:Array[Node3D]=[]
var mouth:Node3D
var clock:=0.0

func configure(team:int) -> void:
	var tint:Color=preload("res://src/core/team_palette.gd").color(team)
	var ink:=_material(tint,.22)
	ink.clearcoat_enabled=true;ink.clearcoat=.7;ink.clearcoat_roughness=.2
	var pale:=_material(Color("fff4df"),.4)
	var dark:=_material(Color("1e1837"),.3)
	mantle=Node3D.new();add_child(mantle)
	_ball(mantle,Vector3(0,.44,0),Vector3(.37,.4,.31),ink)
	_ball(mantle,Vector3(0,.24,.13),Vector3(.27,.2,.24),pale)
	for side in [-1,1]:
		var fin:=_ball(mantle,Vector3(side*.34,.47,-.05),Vector3(.22,.09,.17),ink)
		fin.rotation.z=side*.35
		var eye:=Node3D.new();mantle.add_child(eye);eye.position=Vector3(side*.145,.53,.255);eyes.append(eye)
		_ball(eye,Vector3.ZERO,Vector3(.125,.15,.07),pale)
		_ball(eye,Vector3(side*.01,-.006,.055),Vector3(.052,.072,.035),dark)
		_ball(eye,Vector3(side*.005,.025,.084),Vector3(.017,.02,.01),pale)
		_ball(mantle,Vector3(side*.24,.34,.225),Vector3(.07,.032,.018),_material(tint.lightened(.5),.32))
	mouth=_ball(mantle,Vector3(0,.31,.315),Vector3(.072,.034,.022),dark)
	# A swept crest and four soft appendages give it a readable squid silhouette.
	for i in range(3):
		var crest:=_ball(mantle,Vector3(0,.73+i*.055,-.09-i*.07),Vector3(.11-i*.024,.13-i*.024,.16-i*.028),ink)
		crest.rotation.x=-.35
	for i in range(4):
		var foot:=Node3D.new();mantle.add_child(foot);foot.position=Vector3((i%2*2-1)*.21,.11,(i/2*2-1)*.14)
		_ball(foot,Vector3(0,0,.045),Vector3(.13,.095,.2),ink);feet.append(foot)

func animate(delta:float,mode:String,speed:float,windup:float) -> void:
	clock+=delta
	var moving:=speed>.3
	var bounce:=absf(sin(clock*15))*.08 if moving else sin(clock*3)*.018
	mantle.position.y=bounce
	mantle.rotation.z=sin(clock*8)*.07 if moving else sin(clock*2)*.025
	mantle.rotation.x=-.16 if moving else 0
	mantle.scale=Vector3.ONE
	if mode=="flying":mantle.rotation.x=-clock*5;mantle.position.y=0
	elif mode=="windup":
		mantle.scale=Vector3(1.15,.78,1.08);mantle.rotation.x=-.2;mouth.scale.y=.034*1.4
	elif mode=="bite":
		mantle.position.y=.13;mantle.rotation.x=.3;mantle.scale=Vector3(.9,1.1,1.08);mouth.scale.y=.034*2
	else:mouth.scale.y=.034
	for i in feet.size():feet[i].rotation.x=sin(clock*15+i*PI)*.4 if moving else 0
	var blinking:=fmod(clock,3.4)<.12
	for eye in eyes:eye.scale.y=.12 if blinking else 1

func _material(color:Color,roughness:float) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=roughness
	return material

func _ball(parent:Node3D,at:Vector3,size:Vector3,material:Material) -> MeshInstance3D:
	var mesh:=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=24;mesh.rings=12
	var part:=MeshInstance3D.new();part.mesh=mesh;part.material_override=material;part.position=at;part.scale=size;parent.add_child(part)
	return part
