extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for team in [0,1]:
		await prepare(5,"tidewater")
		var requester: Node3D = bot
		var ally: Node3D = walker
		for actor in game.extra_bots:
			if team==0 and actor.team==0: requester=actor;break
		if team==1:
			for actor in game.extra_bots:
				if actor.team==1: ally=actor;break
		var enemy: Node3D = bot if team==0 else walker
		var d: Node3D = game.bot_deployment
		var ground: Node3D = game.deployment
		requester.global_position=d.base_position(requester)
		ally.global_position=Vector3(0,.05,-24 if team==0 else 24)
		if ally!=walker: ally.team_mover.velocity=Vector3.ZERO
		else: walker.velocity=Vector3.ZERO
		await physics_frame
		var key := "actor:%d" % game.actor_id(ally)
		expect(ground.destination_for(requester,"actor:%d" % game.actor_id(requester)).is_empty(),"self cannot be a jump destination")
		expect(ground.destination_for(requester,"actor:%d" % game.actor_id(enemy)).is_empty(),"other team cannot be a jump destination")
		expect(d.choose(requester)==key,"team %d independently chooses a forward ally" % team)
		expect(not d.update(requester,.1) and not d.busy(requester),"initial lineup is not armed for automatic jumps")
		requester.ink_amount=10
		expect(d.choose(requester).is_empty(),"low ink leaves normal navigation in charge")
		requester.ink_amount=100
		var departure: Vector3=requester.global_position
		requester.global_position+=Vector3(8,0,0)
		expect(d.choose(requester).is_empty(),"automatic jump is restricted to the birth area")
		requester.global_position=departure
		if ally==walker: game.player_respawn=3
		else: ally.respawn_time=3
		expect(d.choose(requester).is_empty(),"dead ally rejected")
		if ally==walker: game.player_respawn=0;walker.velocity.y=3
		else: ally.respawn_time=0;ally.team_mover.velocity.y=3
		expect(d.choose(requester).is_empty(),"airborne ally rejected")
		if ally==walker: walker.velocity=Vector3.ZERO
		else: ally.team_mover.velocity=Vector3.ZERO
		var obstruction := wall(ally.global_position+Vector3.UP,Vector3(4,2,4))
		await physics_frame
		expect(d.choose(requester).is_empty(),"all occupied teammate offsets rejected")
		obstruction.queue_free();await physics_frame
		# Contact point is deliberately different from the parked enemy body.
		game.intel.contacts[team][enemy.get_instance_id()]={"actor":enemy,"point":ally.global_position,"yaw":0.0,"time":game.intel.clock,"status":"last"}
		expect(d.choose(requester).is_empty(),"known threat near destination prevents automatic jump")
		game.intel.clear_all()
		expect(d.choose(requester)==key,"unknown enemy positions are not used to veto a jump")
		d.on_respawn(requester);d.update(requester,.01)
		expect(d.busy(requester) and not d.state(requester).flying,"completed respawn starts vulnerable one-second windup")
		expect(ground.destination_for(ally,"actor:%d" % game.actor_id(requester)).is_empty(),"departing actor cannot itself be selected as a teammate")
		var at: Vector3=requester.global_position
		var time: float=d.state(requester).time
		game.paused=true;d.update(requester,2)
		expect(d.state(requester).time==time and requester.global_position==at,"pause freezes windup and position")
		game.paused=false
		expect(not game.items.use(requester) and not game.wings.begin(requester) and not game.items.recall.use(requester),"deployment excludes items, wings and recall")
		game.items.equip(requester,"refill")
		requester.ink_amount=21
		game.items.state(requester).cooldowns.beacon=9.0
		var perk: String=game.perks.choices[requester.get_instance_id()]
		if requester==bot: game.bot_invuln=0;game.bot_health=100
		else: requester.invuln=0;requester.health=100
		game.damage_actor(requester,20,1-team,enemy,"shooter")
		var hp: float=game.actor_health(requester)
		expect(hp<100 and d.busy(requester),"ordinary damage remains effective during windup")
		d.update(requester,1.01)
		var destination: Vector3=d.state(requester).target
		expect(d.state(requester).flying and d.state(requester).marker.visible,"takeoff keeps a public landing marker")
		d.update(requester,.45)
		expect(requester.global_position.y>at.y+3,"actual actor follows an elevated jump arc")
		d.update(requester,2)
		expect(not d.busy(requester) and requester.global_position.distance_to(destination)<.15,"lands at clear teammate floor")
		expect(game.actor_health(requester)==hp and requester.ink_amount==21,"landing does not restore HP or ink")
		expect(game.items.state(requester).cooldowns.beacon==9.0 and game.perks.choices[requester.get_instance_id()]==perk and game.perks.locked,"jump retains item CD and match-locked perk")
		expect(d.state(requester).cooldown>0,"landing establishes cooldown")
		requester.global_position=at;d.on_respawn(requester);d.update(requester,.01)
		expect(not d.busy(requester),"another respawn cannot bypass jump cooldown")
		d.state(requester).cooldown=0;requester.ink_amount=100
		d.on_respawn(requester);d.update(requester,.01)
		if ally==walker: game.player_respawn=3
		else: ally.respawn_time=3
		d.update(requester,.1)
		expect(not d.busy(requester) and requester.global_position.distance_to(at)<.01,"target death before takeoff cancels in place")
		if ally==walker: game.player_respawn=0
		else: ally.respawn_time=0
		d.state(requester).cooldown=0;d.on_respawn(requester);d.update(requester,.01);d.update(requester,1.01)
		if ally==walker: game.player_respawn=3
		else: ally.respawn_time=3
		d.update(requester,3)
		expect(not d.busy(requester) and requester.global_position.distance_to(d.base_position(requester))<2,"target loss in flight returns to own team base")
		if ally==walker: game.player_respawn=0
		else: ally.respawn_time=0
		requester.global_position=at;d.state(requester).cooldown=0
		d.on_respawn(requester);d.update(requester,.01)
		if requester==bot: game.bot_invuln=0
		else: requester.invuln=0
		game.damage_actor(requester,1000,1-team,enemy,"shooter")
		expect(not d.busy(requester) and not game.actor_alive(requester) and d.state(requester).marker==null,"requester death clears deployment immediately")
		d.tick(4.1)
		expect(d.state(requester).cooldown==0,"cooldown elapses during death countdown")
		if requester==bot: game._update_bot(4.1)
		else: game._update_team_actor(requester,4.1)
		expect(game.actor_alive(requester) and d.state(requester).pending,"real respawn controller arms next choice after countdown")
		expect(not game.deployment.active and not game.deployment.queued,"bot choices never select for the player")
		print("AUDIT: team ",team," self/enemy/dead/airborne/occupied/threat exclusions; respawn, windup, damage, pause, flight, cooldown, death and fallback")
		await _quiet()
		game.queue_free();await process_frame
	await _beacons_and_high_floor()
	await _quiet()
	await finish("bot respawn teammate/beacon deployment, both teams, negative destinations, vulnerable windup and lifecycle isolation")

func _quiet() -> void:
	# Rapid simulated flights can queue 3D voices before their next audio tick.
	# Drain the fixture voices before freeing the scene / exiting the engine.
	await create_timer(.1).timeout
	for voice in game.sound.get_children():
		if voice.has_method("stop"):
			voice.stop();voice.stream=null
	await create_timer(.1).timeout

func _beacons_and_high_floor() -> void:
	await prepare(5,"prism_gallery")
	var requester: Node3D=game.extra_bots[0]
	for actor in game.extra_bots:
		if actor.team==0: requester=actor;break
	var d: Node3D=game.bot_deployment
	var ground: Node3D=game.deployment
	walker.global_position=Vector3(-8.5,6.05,-3);walker.velocity=Vector3.ZERO
	requester.global_position=d.base_position(requester)
	await physics_frame
	game.paint_at_world(walker.global_position+Vector3.UP*.06,0,4,.3)
	expect(ground.place_beacon(walker),"beacon can be placed on painted six-metre floor")
	if ground.beacons.is_empty(): return
	var beacon: Dictionary=ground.beacons[0]
	walker.global_position=Vector3(75,40,75);await physics_frame
	var key := "beacon:%d" % beacon.id
	expect(d.choose(requester)==key,"bot chooses friendly beacon when no forward ally is available")
	beacon.team=1
	expect(d.choose(requester).is_empty(),"enemy beacon rejected")
	beacon.team=0;beacon.time=0
	expect(d.choose(requester).is_empty(),"expired beacon rejected even before cleanup")
	beacon.time=45;beacon.uses=0
	expect(d.choose(requester).is_empty(),"exhausted beacon rejected")
	beacon.uses=2
	d.on_respawn(requester);d.update(requester,.01);d.update(requester,1.01);d.update(requester,3)
	expect(requester.global_position.y>5.8 and beacon.uses==1,"successful high-floor arrival consumes one beacon use")
	var competitor: Node3D
	for actor in game.extra_bots:
		if actor!=requester and actor.team==0: competitor=actor;break
	requester.global_position=d.base_position(requester)
	competitor.global_position=d.base_position(competitor)+Vector3(.8,0,0)
	requester.team_mover.velocity=Vector3.ZERO;competitor.team_mover.velocity=Vector3.ZERO
	d.state(requester).cooldown=0
	await physics_frame
	d.on_respawn(requester);d.update(requester,.01)
	d.on_respawn(competitor);d.update(competitor,.01)
	expect(d.busy(requester) and d.busy(competitor),"two bots may prepare for the last beacon use")
	d.update(requester,1.01);d.update(competitor,1.01)
	d.update(requester,3);d.update(competitor,3)
	expect(beacon.uses==0 and competitor.global_position.distance_to(d.base_position(competitor))<2,"last beacon use is consumed once; later arrival safely falls back")
	# Independent ink-loss fixture after the concurrent-arrival negative case.
	beacon.uses=1
	requester.global_position=d.base_position(requester);d.state(requester).cooldown=0;await physics_frame
	d.on_respawn(requester);d.update(requester,.01);d.update(requester,1.01)
	game.paint_at_world(beacon.point+Vector3.UP*.06,1,3,.6)
	d.update(requester,3)
	expect(requester.global_position.distance_to(d.base_position(requester))<2 and beacon.uses==1,"ink loss during flight falls back without spending beacon")
	expect(ground.destination_for(requester,key).is_empty(),"enemy-covered beacon remains disabled")
	d.on_respawn(requester)
	game._finish_round()
	expect(not d.state(requester).pending and not d.busy(requester) and d.marks_for(0).is_empty(),"finish clears pending choices and public markers")
