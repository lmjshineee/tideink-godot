extends "res://tools/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await prepare()
	var floor_body := wall(Vector3(0,39.8,5),Vector3(40,.4,40))
	walker.global_position=Vector3(0,40.05,0)
	combat.select_weapon("canopy");combat.ink_amount=100
	await physics_frame
	var canopy:Node3D=combat.canopy
	# Typical third-person ground aim, rather than the old mid-air horizontal fixture.
	var target:=Vector3(0,40.07,8)
	for i in 30:
		canopy.update_input(walker,1.0/30,true,target)
		canopy.tick(1.0/30)
	var s:Dictionary=canopy.state(walker)
	expect(s.cover!=null and s.launched,"ground aim opens and launches cover")
	if s.cover!=null:
		var start:Vector3=s.cover.global_position
		for i in 45:
			canopy.update_input(walker,1.0/30,true,target)
			canopy.tick(1.0/30)
		expect(s.cover!=null,"launched cover survives downward aim on flat ground")
		if s.cover!=null:
			expect(s.cover.global_position.z-start.z>9,"cover advances at least nine metres")
			expect(s.cover.global_position.y>40.95,"cover stays above the floor")
		expect(combat.projectiles.size()>=18,"held trigger continues volleys after launch")
	print("AUDIT: cover=",s.cover!=null," ink=",combat.ink_amount," projectiles=",combat.projectiles.size())
	expect(combat.ink_amount>60,"opening, launch and five volleys leave a usable tank")
	canopy.clear_all()
	# A real sloping collision box rising two metres, with the face meeting the floor.
	var ramp:=wall(Vector3.ZERO,Vector3(5,.3,sqrt(68.0)))
	var landing_platform:=wall(Vector3(0,41.8,16),Vector3(5,.4,8))
	var slope_basis:=Basis(Vector3.RIGHT,Vector3(0,8,-2).normalized(),Vector3(0,2,8).normalized())
	ramp.transform=Transform3D(slope_basis,Vector3(0,41,8)-slope_basis.y*.15)
	await physics_frame
	combat.ink_amount=100
	for i in 80:
		canopy.update_input(walker,1.0/30,true,target)
		canopy.tick(1.0/30)
	s=canopy.state(walker)
	expect(s.cover!=null and s.cover.global_position.z>12 and s.cover.global_position.y>42.9,"cover climbs ramp onto a two-metre rise")
	canopy.clear_all();ramp.queue_free();landing_platform.queue_free()
	await physics_frame
	combat.ink_amount=100
	for i in 28:
		canopy.update_input(walker,1.0/30,true,target);canopy.tick(1.0/30)
	s=canopy.state(walker)
	var corner_wall:=wall(Vector3(1.05,41,3.3),Vector3(.22,2,.2))
	await physics_frame
	for i in 15:canopy.tick(1.0/30)
	expect(s.cover==null,"swept panel corners stop on a narrow wall missed by centre rays")
	corner_wall.queue_free();canopy.clear_all()
	combat.ink_amount=7
	for i in 60:
		canopy.update_input(walker,1.0/30,true,target);canopy.tick(1.0/30)
	expect(combat.ink_amount>=0,"holding with insufficient launch ink never makes tank negative")
	canopy.cancel(walker)
	canopy.clear_all();combat.ink_amount=4;combat.last_fire_time=0
	var recovered_shots:=0
	var dry_guard:=false
	for i in 90:
		var before_ink:float=combat.ink_amount
		combat.tick(1.0/30,true,false)
		if before_ink-combat.ink_amount>1:recovered_shots+=1
		dry_guard=dry_guard or canopy.holding(walker)
	expect(not dry_guard and recovered_shots>0,"nearly empty held trigger refills and resumes real shots without drain-only guard")
	floor_body.queue_free()
	await physics_frame
	await finish("ground-aim canopy advance, ramp rise, full panel corner collision, ink economy and sustained follow-up fire")
