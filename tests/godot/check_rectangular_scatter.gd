extends "res://tests/godot/helpers/creative_fixture.gd"
const Accuracy:=preload("res://src/core/weapon_accuracy.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	await prepare(5,"tidewater")
	seed(319)
	var half_box:=Vector2(deg_to_rad(6),deg_to_rad(3))
	var corners:=0;var average:=Vector2.ZERO
	for i in 2000:
		var direction:=Accuracy.sample(Vector3.FORWARD,half_box)
		var slope:=Vector2(direction.x/-direction.z,direction.y/-direction.z)
		expect(absf(slope.x)<=tan(half_box.x)+.0001 and absf(slope.y)<=tan(half_box.y)+.0001,"each sample stays inside the advertised rectangle")
		if pow(slope.x/tan(half_box.x),2)+pow(slope.y/tan(half_box.y),2)>1:corners+=1
		average+=slope
	expect(corners>250,"rectangle corners are reachable; scatter is not an angular disk")
	expect(average.length()/2000<.003,"box samples stay centred")
	combat.select_weapon("shooter");walker.global_position=Vector3(0,40,0);walker.camera_yaw=0;walker.camera_pitch=0;walker._update_camera();game.pointer_locked=true
	walker.grounded=true;combat.bloom=0
	var settled:Rect2=combat.reticle_box()
	combat.bloom=1;var ground:Rect2=combat.reticle_box()
	walker.grounded=false;var air:Rect2=combat.reticle_box()
	expect(settled.size.x<ground.size.x and ground.size.x<air.size.x,"HUD box matches recovered, continuous and jump fire states")
	var dual:=Accuracy.box(combat.weapons.dualie,true,1)
	var shooter:=Accuracy.box(combat.weapons.shooter,true,1)
	expect(dual.x<shooter.x and Accuracy.box(combat.weapons.dualie,true,1,true).x<dual.x,"weapon-specific accuracy and dualie roll precision")
	combat.select_weapon("dualie");combat.bloom=1;walker.grounded=true
	combat._spawn_shot_pair(combat.weapons.dualie,Vector3(0,40,0),Vector3.FORWARD,0,walker,dual)
	for shot in combat.projectiles:
		var d:Vector3=shot.velocity.normalized()
		expect(absf(d.x/-d.z)<=tan(dual.x)+.0001 and absf(d.y/-d.z)<=tan(dual.y)+.0001,"each barrel samples exactly one effective box")
	expect(not combat.projectiles[-1].velocity.is_equal_approx(combat.projectiles[-2].velocity),"dual barrels have independent RNG")
	print("AUDIT: box px settled=",settled.size," ground=",ground.size," air=",air.size," corners=",corners)
	await finish("rectangle coverage/bounds/centering, exact dynamic HUD frame and distinct independent weapon boxes")
