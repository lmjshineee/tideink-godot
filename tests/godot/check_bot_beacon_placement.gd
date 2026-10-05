extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare(5,"tidewater")
	walker.global_position=Vector3(200,0,200)
	for team in range(2):
		game.deployment.beacons.clear()
		var actor:Node3D=bot if team==1 else game.extra_bots[0]
		for other in game.all_actors():
			if other==walker:continue
			if other==bot:game.bot_respawn=999 if other!=actor else 0
			else:other.respawn_time=999 if other!=actor else 0
		actor.reset();actor.ink_amount=100
		game.items.equip(actor,"beacon")
		var state:Dictionary=game.items.state(actor)
		state.cooldowns.beacon=0;state.beacon_try=0
		var base:Vector3=game.get_node("World/Map").spawn_pads[team]
		actor.global_position=base+Vector3.UP*.05
		game.paint_at_world(actor.global_position+Vector3.UP*.06,team,4,.3)
		await physics_frame
		game.items.tick(.1)
		expect(game.deployment.beacons.is_empty(),"team %d AI does not place a redundant beacon at spawn" % team)
		expect(actor.ink_amount==100 and state.cooldowns.beacon==0,"spawn rejection does not consume ink or start beacon cooldown")
		# Clear only fixture beacons so the positive case can run on old source too.
		for beacon in game.deployment.beacons:beacon.visual.queue_free()
		game.deployment.beacons.clear()
		state.cooldowns.beacon=0;state.beacon_try=0;actor.ink_amount=100
		var forward:=1.0 if team==0 else -1.0
		actor.global_position=Vector3(16,.05,base.z)
		game.paint_at_world(actor.global_position+Vector3.UP*.06,team,4,.4)
		await physics_frame
		game.items.tick(.1)
		expect(game.deployment.beacons.is_empty() and actor.ink_amount==100,"sideways movement at spawn is not a useful forward support point")
		state.beacon_try=0
		actor.global_position=Vector3(12,.05,base.z+forward*16)
		game.paint_at_world(actor.global_position+Vector3.UP*.06,team,4,.4)
		await physics_frame
		game.items.tick(.1)
		expect(game.deployment.beacons.size()==1,"team %d AI places a usable forward beacon on friendly ink" % team)
		if not game.deployment.beacons.is_empty():
			var placed:Dictionary=game.deployment.beacons[0]
			expect(placed.point.distance_to(base)>12 and placed.team==team,"forward beacon belongs to the correct team outside spawn")
			expect(actor.ink_amount==65 and state.cooldowns.beacon>17,"valid placement pays the real ink and cooldown")
			var serial:int=game.deployment.beacon_serial
			game.items.tick(18.1)
			expect(game.deployment.beacon_serial==serial,"AI preserves a usable nearby beacon after cooldown instead of repeatedly replacing it")
			for beacon in game.deployment.beacons:beacon.visual.queue_free()
			game.deployment.beacons.clear()
			# Only real observed enemy information can block a placement.
			var enemy:Node3D=walker if team==1 else bot
			enemy.global_position=actor.global_position+Vector3(0,0,3)
			if enemy==bot:game.bot_respawn=0
			game.intel.refresh()
			state.cooldowns.beacon=0;state.beacon_try=0;actor.ink_amount=100
			game.items.tick(.1)
			expect(game.deployment.beacons.is_empty() and actor.ink_amount==100,"known close enemy prevents putting a beacon in direct danger")
			enemy.global_position=Vector3(200,0,200)
			game.intel.clear_all()
		state.cooldowns.beacon=9
		game.items.on_death(actor);actor.reset();game.items.on_respawn(actor)
		state.beacon_try=0
		game.items.tick(1)
		expect(is_equal_approx(state.cooldowns.beacon,8),"respawn preserves remaining beacon cooldown even while spawn placement is rejected")
		print("AUDIT: beacon placement team=",team," base=",base)
	await finish("AI beacons: no spawn waste, forward support, no nearby duplicates and persistent cooldown")
