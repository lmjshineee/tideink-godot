extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	seed(21);await prepare(5,"viaduct");Engine.time_scale=4;Engine.physics_ticks_per_second=120
	walker.global_position=Vector3(80,40,80);bot.global_position=Vector3(2.8,.05,15)
	var target:=Vector3(2.8,0,-10)
	bot.route=game.navigation.route(bot.global_position,target,1)
	print("[DEBUG-underpass] path-end=",bot.route[-1]," target-error=",bot.route[-1].distance_to(target)," weapon=",bot.weapon_id)
	bot.route_purpose="patrol";bot.route_index=1;bot.repath_time=999;bot.team_mover.velocity=Vector3.ZERO
	var previous := "patrol"
	for i in 1300:
		await physics_frame;bot.tick(1.0/30)
		if bot.route_purpose!=previous:
			print("[DEBUG-underpass] tick=",i," purpose=",bot.route_purpose," ink=",bot.ink_amount," position=",bot.global_position," end=",bot.route[-1] if not bot.route.is_empty() else "empty");previous=bot.route_purpose
		if bot.global_position.distance_to(target)<1.2:break
		if i%120==0:print("[DEBUG-underpass] tick=",i," position=",bot.global_position," route_index=",bot.route_index," ink=",bot.ink_amount)
	expect(bot.global_position.distance_to(target)<2,"bridge underpass reaches destination")
	await finish("isolated underpass fixture")
