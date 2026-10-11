extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	Engine.time_scale=4;Engine.physics_ticks_per_second=120
	for id in ["sunset_park","lantern_depot"]:
		await prepare(5,id)
		Engine.time_scale=4;Engine.physics_ticks_per_second=120
		var map:Node3D=game.get_node("World/Map")
		expect(map.get_node("Scenery").find_children("*","CollisionObject3D",true,false).is_empty(),"dressing cannot duplicate collision")
		walker.global_position=Vector3(80,40,80)
		for team in 2:
			var actor:Node3D
			for candidate in game.all_actors():
				if candidate!=walker and game.actor_team(candidate)==team:actor=candidate;break
			var targets: Array=[Vector3(15,2.2,0)] if id=="sunset_park" else [Vector3(0,3.4,0),Vector3(0,0,0)]
			for value in targets:
				var target: Vector3=value
				if team==1:target.x=-target.x
				actor.global_position=map.spawn_pads[team];actor.invuln=0
				actor.route=game.navigation.route(actor.global_position,target,team)
				expect(actor.route.size()>10,id+" both bases reach level "+str(target))
				actor.route_purpose="patrol";actor.route_index=1;actor.repath_time=999;actor.team_mover.velocity=Vector3.ZERO
				for i in 800:
					await physics_frame;actor.tick(1.0/30)
					if actor.global_position.distance_to(target)<1.2:break
				print("AUDIT: ",id," team=",team," end=",actor.global_position," target=",target)
				expect(actor.global_position.distance_to(target)<2.0,id+" physical collision route team "+str(team)+" level "+str(target))
			actor.global_position=Vector3(80+team*10,40,80)
		if id=="lantern_depot":
			for height in [2.5,8.0]:
				var stacked:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,height,0),Vector3(0,-1,0),1))
				expect(not stacked.is_empty(),"both station layers have collision")
				if not stacked.is_empty():
					var level: float=0.0 if height<3 else 3.4
					expect(absf(stacked.position.y-level)<.01,"ray reaches the intended bridge / underpass level")
					var source: Dictionary=map.find_surface(stacked.position,stacked.normal,int(stacked.collider.get_meta("source_id")))
					expect(not source.is_empty() and source.turf,"both actual levels resolve distinct CPU surfaces")
					expect(game.ink.splat_world(stacked.position,.8,0,.5)>0,"both layers contribute actual ink")
			var junction: Dictionary={}
			for face in map.surfaces:
				if face.has("polygon") and face.n[1]>.9 and face.polygon.size()==24:junction=face;break
			var outside: Vector3=map._vector(junction.origin)+map._vector(junction.u)*.001+map._vector(junction.v)*.001
			expect(map.find_surface(outside,Vector3.UP,int(junction.block)).is_empty(),"circle bounding rectangle cannot become phantom paint surface")
			var clipped: ArrayMesh=preload("res://src/world/surface_ink_view.gd")._face_mesh(junction)
			expect(clipped.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==24,"wet ink uses the actual polygon rather than its bounding rectangle")
		# A actual ramp hit resolves a paintable face; buried floor stays uncredited.
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(0,8,-18),Vector3(0,-2,-18),1)
		var hit:=game.get_world_3d().direct_space_state.intersect_ray(ray)
		expect(not hit.is_empty(),"spawn ramp has real collision")
		if not hit.is_empty():
			var face:Dictionary=map.find_surface(hit.position,hit.normal,int(hit.collider.get_meta("source_id")))
			expect(not face.is_empty() and face.turf,"collision and CPU scoring identify the same ramp")
			var added:float=game.ink.splat_world(hit.position,1.4,0,.5)
			expect(added>0 and game.ink.coverage(0)>0,"actual slope paint contributes to full-map coverage")
		game.set_process(false);game.set_physics_process(false)
		for voice in game.sound.get_children():
			if voice.has_method("stop"):voice.stop();voice.stream=null
		await create_timer(.15).timeout
		game.queue_free();await process_frame
		await create_timer(.15).timeout
	if failures.is_empty():print("PASS: two curated maps, both teams physically reach curved highlines and both station levels, polygon/ray/collision/ink agree, dressing adds no collision")
	quit(0 if failures.is_empty() else 1)
