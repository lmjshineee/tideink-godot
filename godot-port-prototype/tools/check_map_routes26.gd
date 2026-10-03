extends "res://tools/creative_fixture.gd"
func _initialize() -> void:call_deferred("_run")
func reach(actor:Node3D,target:Vector3,label:String) -> void:
	actor.route=game.navigation.route(actor.global_position,target,game.actor_team(actor))
	expect(actor.route.size()>3,label+" has a navigation path")
	actor.route_index=1;actor.repath_time=999;actor.team_mover.velocity=Vector3.ZERO
	for i in 1300:
		await physics_frame
		actor.tick(1.0/30)
		if actor.global_position.distance_to(target)<1.2:break
	print("AUDIT: ",label," end=",actor.global_position," target=",target)
	expect(actor.global_position.distance_to(target)<2,label+" physically reaches destination")
func _run() -> void:
	for id in ["coral_market","viaduct"]:
		await prepare(5,id)
		walker.global_position=Vector3(80,40,80)
		var map:Node3D=game.get_node("World/Map")
		for team in 2:
			var mover:Node3D
			for actor in game.all_actors():
				if actor!=walker and game.actor_team(actor)==team:mover=actor;break
			mover.global_position=map.spawn_pads[team];mover.invuln=0
			var target:=Vector3(-13.5,3.4,-12) if id=="coral_market" else Vector3(0,6,0)
			if team==1:target=Vector3(-target.x,target.y,-target.z)
			await reach(mover,target,id+" upper route team "+str(team))
			if id=="viaduct":
				mover.global_position=Vector3(12,.05,-31) if team==0 else Vector3(-12,.05,31)
				mover.jump_time=0
				await reach(mover,Vector3(12,6,-7) if team==0 else Vector3(-12,6,7),"bridge side ramp team "+str(team))
			mover.global_position=Vector3(80+team*8,40,80)
		if id=="viaduct":
			bot.global_position=Vector3(2.8,.05,15)
			await reach(bot,Vector3(2.8,0,-10),"bridge underpass")
			var ground:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.8,1.5,0),Vector3(2.8,-1,0),1))
			expect(not ground.is_empty() and absf(ground.position.y)<.01,"underpass is hollow playable ground")
			var roof:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.8,2,0),Vector3(2.8,8,0),1))
			expect(not roof.is_empty() and absf(roof.position.y-5.5)<.01,"bridge deck blocks cross-floor attacks")
		game.queue_free();await process_frame
	if failures.is_empty():print("PASS: both teams climb new market rooftops / six-metre viaduct, physically traverse hollow underpass, deck occludes")
	quit(0 if failures.is_empty() else 1)
