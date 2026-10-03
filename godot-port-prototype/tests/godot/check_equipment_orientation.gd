extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare()
	walker.global_position=Vector3(0,40,0)
	walker.grounded=true
	var body:Node3D=walker.get_node("Body")
	body.set_physics_process(false)
	body.rotation.y=0
	body.set_form(false)
	body.set_aim(true)
	for id in ["bow","canopy"]:
		body.set_weapon(id)
		body.set_weapon_pose(0,false)
		for i in 25:
			body._physics_process(.033)
			await process_frame
		var model:Node3D=body.original_weapons[id]
		var forward:Vector3=model.global_basis.z.normalized()
		var reference:Node3D=body.original_weapons["charger" if id=="bow" else "shooter"]
		print("AUDIT: ",id," visible tip axis=",forward," imported mesh axis=",(reference.get_child(0) as Node3D).global_basis.z.normalized()," actor forward=",body.global_basis.z.normalized())
		expect(forward.dot(body.global_basis.z.normalized())>.8,"held "+id+" points forwards along firing direction")
	# Same imported grip basis must remain valid across yaw and upper/lower aim poses.
	for id in ["bow","canopy"]:
		body.set_weapon(id)
		for pitch in [-.6,0.0,.6]:
			body.rotation.y=1.1
			body.set_weapon_pose(pitch,false)
			for i in 25:body._physics_process(.033)
			await process_frame;await process_frame
			var model:Node3D=body.original_weapons[id]
			var reference:Node3D=body.original_weapons["charger" if id=="bow" else "shooter"]
			expect(model.global_basis.z.normalized().dot((reference.get_child(0) as Node3D).global_basis.z.normalized())>.999,"grip conversion retains yaw and pitch for "+id)
	var bow:Node3D=body.original_weapons.bow
	var strings:Node3D=bow.get_node("BowString")
	var arrows:Node3D=bow.get_node("LoadedArrows")
	expect((strings.get_child(0) as Node3D).position.z<0 and (arrows.get_child(0) as Node3D).position.z+.27>0,"bowstring behind grip and arrow tip ahead")
	preload("res://src/combat/ink_equipment_mesh.gd").set_bow_charge(bow,0)
	var rear:float=(strings.get_child(0) as Node3D).position.z
	var rest:float=arrows.position.z
	body.set_weapon("bow");body.set_weapon_charge(1)
	expect((strings.get_child(0) as Node3D).position.z<rear-.08 and arrows.position.z<rest-.17,"charging draws string and arrow nocks backwards")
	var loaded: Node3D = arrows.get_child(0)
	var tip_z: float = arrows.position.z + loaded.position.z + .27 * loaded.scale.z
	var nock_z: float = arrows.position.z + loaded.position.z - .25 * loaded.scale.z
	var string_knot: float = (strings.get_child(0) as Node3D).position.z * 2 + .16
	expect(tip_z > .22 and absf(nock_z - string_knot) < .001,"fully drawn arrow tip clears rest and nock stays on string")
	body.set_weapon_charge(0)
	expect(is_equal_approx(arrows.position.z,rest),"release resets loaded arrows")
	await finish("held procedural bow/canopy arrows and tip align with actor aim, pitched/yawed grip, rear bowstring and charge draw")
