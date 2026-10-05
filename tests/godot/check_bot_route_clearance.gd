extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare(1,"viaduct")
	walker.global_position=Vector3(200,0,200)
	bot.select_weapon("shooter")
	bot.global_position=Vector3(-6,.05,31)
	bot.team_mover.velocity=Vector3.ZERO
	bot.route=game.navigation.route(bot.global_position,Vector3(6,0,25),1)
	bot.route_index=1;bot.repath_time=999;bot.route_purpose="patrol"
	var goal:Vector3=bot.route[-1]
	var closest:=bot.global_position.distance_to(goal)
	var arrived:=false
	var hit_ceiling:=false
	Engine.time_scale=4;Engine.physics_ticks_per_second=120
	for frame in range(450):
		await physics_frame
		game._update_bot(1.0/30)
		closest=minf(closest,bot.global_position.distance_to(goal))
		for i in bot.team_mover.get_slide_collision_count():
			var collision:KinematicCollision3D=bot.team_mover.get_slide_collision(i)
			if collision.get_normal().y < -.68: hit_ceiling=true
		if closest < .6:
			arrived=true;break
	expect(arrived,"bot crosses the low-ramp area using a route with actual standing clearance")
	expect(not hit_ceiling,"ground route avoids wedging the actor's head into a ramp underside")
	print("AUDIT: low-ramp goal=",goal," nearest_m=",closest," ceiling_contact=",hit_ceiling)
	await finish("physical bot route respects low-ramp headroom")
