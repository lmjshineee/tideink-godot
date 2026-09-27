extends Node3D

# Lightweight readable stand-in for the web game's procedural squidkid rig.
# Feet are y=0, facing +Z, with source-like head height and team-colour hair.
# Visuals never own movement, collision, ink or damage state.
@export_range(0, 1) var team := 0

const TEAM_COLORS := [Color("ff8a14"), Color("2f5bff")]
const SKIN := Color("ffd9c2")
const SHIRT := Color("f4f2ec")
const DARK := Color("27304a")
const SOLE := Color("faf6eb")

var kid: Node3D
var squid: Node3D
var weapon_models: Dictionary = {}
var current_weapon := "shooter"
var is_squid := false
var _materials: Dictionary = {}


func _ready() -> void:
	kid = Node3D.new()
	kid.name = "Kid"
	add_child(kid)
	squid = Node3D.new()
	squid.name = "Squid"
	add_child(squid)
	_build_kid()
	_build_squid()
	set_weapon(current_weapon)
	set_form(false)


func set_form(value: bool) -> void:
	is_squid = value
	if kid != null:
		kid.visible = not value
		squid.visible = value


func set_weapon(weapon_id: String) -> void:
	if not weapon_models.has(weapon_id):
		return
	current_weapon = weapon_id
	for id in weapon_models:
		(weapon_models[id] as Node3D).visible = id == weapon_id


func _build_kid() -> void:
	var ink: Color = TEAM_COLORS[team]
	_sphere(kid, "Head", Vector3(0.0, 1.214, 0.012), Vector3(0.178, 0.176, 0.165), SKIN)
	_sphere(kid, "HairCap", Vector3(0.0, 1.365, -0.025), Vector3(0.182, 0.095, 0.17), ink)
	for side in [-1.0, 1.0]:
		var strand := _sphere(kid, "Tentacle", Vector3(side * 0.155, 1.155, -0.08),
			Vector3(0.065, 0.23, 0.066), ink)
		strand.rotation.z = side * -0.26
		_sphere(kid, "Eye", Vector3(side * 0.073, 1.242, 0.170), Vector3(0.052, 0.048, 0.016), Color.WHITE)
		_sphere(kid, "Pupil", Vector3(side * 0.073, 1.24, 0.187), Vector3(0.018, 0.029, 0.008), DARK)
	_box(kid, "VisorBridge", Vector3(0.0, 1.25, 0.163), Vector3(0.24, 0.025, 0.025), DARK)
	_box(kid, "Shirt", Vector3(0.0, 0.84, 0.0), Vector3(0.39, 0.39, 0.255), SHIRT)
	_box(kid, "Shorts", Vector3(0.0, 0.565, 0.0), Vector3(0.3, 0.19, 0.27), DARK)
	for side in [-1.0, 1.0]:
		var arm := _sphere(kid, "Arm", Vector3(side * 0.245, 0.79, 0.02),
			Vector3(0.075, 0.22, 0.075), SKIN)
		arm.rotation.z = side * 0.3
		_sphere(kid, "Hand", Vector3(side * 0.275, 0.57, 0.09), Vector3(0.075, 0.07, 0.07), SKIN)
		_box(kid, "Leg", Vector3(side * 0.105, 0.32, 0.0), Vector3(0.13, 0.36, 0.13), SKIN)
		_box(kid, "Shoe", Vector3(side * 0.105, 0.09, 0.09), Vector3(0.19, 0.15, 0.32), DARK)
		_box(kid, "Sole", Vector3(side * 0.105, 0.028, 0.105), Vector3(0.2, 0.05, 0.33), SOLE)
	var tank := _cylinder(kid, "InkTank", Vector3(0.0, 0.78, -0.20), 0.12, 0.43, ink)
	tank.rotation.z = 0.09
	_cylinder(kid, "TankCap", Vector3(0.0, 1.01, -0.21), 0.135, 0.06, DARK)
	_build_weapons()


func _build_squid() -> void:
	var ink: Color = TEAM_COLORS[team]
	_sphere(squid, "Mantle", Vector3(0.0, 0.24, 0.0), Vector3(0.35, 0.20, 0.40), ink)
	for side in [-1.0, 1.0]:
		_sphere(squid, "SquidEye", Vector3(side * 0.12, 0.28, 0.355),
			Vector3(0.060, 0.073, 0.025), Color.WHITE)
		_sphere(squid, "SquidPupil", Vector3(side * 0.12, 0.28, 0.382),
			Vector3(0.025, 0.045, 0.012), DARK)
		var fin := _sphere(squid, "Fin", Vector3(side * 0.26, 0.13, -0.27),
			Vector3(0.095, 0.10, 0.22), ink.darkened(0.15))
		fin.rotation.y = side * 0.35


func _build_weapons() -> void:
	for id in ["shooter", "roller", "charger", "blaster"]:
		var model := Node3D.new()
		model.name = "Weapon_" + id
		model.position = Vector3(-0.27, 0.68, 0.26)
		kid.add_child(model)
		weapon_models[id] = model
		match id:
			"shooter":
				_box(model, "Receiver", Vector3(0.0, 0.1, 0.12), Vector3(0.20, 0.17, 0.42), SHIRT)
				_box(model, "InkSpine", Vector3(0.0, 0.20, 0.10), Vector3(0.13, 0.04, 0.30), TEAM_COLORS[team])
				var barrel := _cylinder(model, "Barrel", Vector3(0.0, 0.10, 0.40), 0.065, 0.23, DARK)
				barrel.rotation.x = PI * 0.5
			"roller":
				_box(model, "Handle", Vector3(0.0, 0.01, 0.28), Vector3(0.07, 0.07, 0.48), DARK)
				var drum := _cylinder(model, "Drum", Vector3(0.0, -0.20, 0.56), 0.18, 0.70, TEAM_COLORS[team])
				drum.rotation.z = PI * 0.5
				_box(model, "DrumFork", Vector3(0.0, -0.12, 0.50), Vector3(0.65, 0.035, 0.06), SHIRT)
			"charger":
				_box(model, "Rail", Vector3(0.0, 0.10, 0.29), Vector3(0.12, 0.12, 0.82), SHIRT)
				_box(model, "Coil", Vector3(0.0, 0.19, 0.18), Vector3(0.08, 0.08, 0.35), TEAM_COLORS[team])
				var nozzle := _cylinder(model, "Nozzle", Vector3(0.0, 0.10, 0.78), 0.045, 0.25, DARK)
				nozzle.rotation.x = PI * 0.5
			"blaster":
				_sphere(model, "Chamber", Vector3(0.0, 0.10, 0.15), Vector3(0.19, 0.19, 0.22), TEAM_COLORS[team])
				var muzzle := _cylinder(model, "Muzzle", Vector3(0.0, 0.10, 0.40), 0.14, 0.25, DARK)
				muzzle.rotation.x = PI * 0.5
				_box(model, "Guard", Vector3(0.0, -0.07, 0.04), Vector3(0.14, 0.15, 0.12), SHIRT)


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = material
	return _materials[key] as StandardMaterial3D


func _sphere(parent: Node3D, name_text: String, at: Vector3, radii: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var part := MeshInstance3D.new()
	part.name = name_text
	part.mesh = mesh
	part.position = at
	part.scale = radii
	part.material_override = _material(color)
	parent.add_child(part)
	return part


func _box(parent: Node3D, name_text: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = name_text
	part.mesh = mesh
	part.position = at
	part.material_override = _material(color)
	parent.add_child(part)
	return part


func _cylinder(parent: Node3D, name_text: String, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var part := MeshInstance3D.new()
	part.name = name_text
	part.mesh = mesh
	part.position = at
	part.material_override = _material(color)
	parent.add_child(part)
	return part
