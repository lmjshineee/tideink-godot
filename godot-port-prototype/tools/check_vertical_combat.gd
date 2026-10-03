extends "res://tools/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280, 720)
	await prepare()
	game.pointer_locked = true
	var camera: Camera3D = walker.get_node("Camera3D")
	# Actual crosshair ray, player weapon dispatch and enemy capsule: no aim override.
	for height in [-3.0, 0.0, 3.0, 6.0]:
		walker.global_position = Vector3(0, 40, 0)
		bot.global_position = Vector3(0, 40 + height, 8)
		game.bot_health = 120
		bot.health = 120
		game.bot_respawn = 0
		game.bot_invuln = 0
		camera.global_position = walker.global_position + Vector3(4, 4, -6)
		camera.look_at(bot.global_position + Vector3.UP * 0.8)
		combat.select_weapon("charger")
		var muzzle := walker.global_position + Vector3.UP * 1.05
		var target: Vector3 = combat._aim_target(muzzle, 27)
		combat._fire_charger(combat.weapons.charger, 1)
		print("AUDIT: reticle height=", height, " target=", target, " remainingHP=", game.bot_health)
		expect(game.bot_health < 120, "crosshair on body must hit at height " + str(height))
	# Real camera convergence for projectile weapons and returning discs.
	for id in ["shooter","blaster","disc","canopy"]:
		for height in [-3.0,0.0,3.0]:
			walker.global_position=Vector3(0,40,0)
			walker.grounded=true
			bot.global_position=Vector3(0,40+height,4.5)
			game.bot_health=120;bot.health=120;game.bot_respawn=0;game.bot_invuln=0
			combat.ink_amount=100
			combat.select_weapon(id)
			camera.global_position=walker.global_position+Vector3(4,4,-6)
			camera.look_at(bot.global_position+Vector3.UP*.8)
			if id=="shooter":
				var accurate:Dictionary=combat.weapons.shooter.duplicate(true)
				accurate.spreadBaseGround=0
				combat._spawn_shot(accurate)
			elif id=="blaster":
				var accurate:Dictionary=combat.weapons.blaster.duplicate(true)
				accurate.spreadBaseGround=0
				combat._spawn_shot(accurate)
			else:combat.tick(.01,true,false)
			for i in 50:combat.advance_effects(1.0/30)
			combat.tick(.001,false,false)
			print("AUDIT: ",id," height=",height," remainingHP=",game.bot_health)
			expect(game.bot_health<120,"actual "+id+" reticle hits elevated/lowered capsule "+str(height))
	# A thin raised deck must interrupt the shot between actor and target.
	var deck:=wall(Vector3(0,42,3),Vector3(16,.25,12))
	await physics_frame
	for id in ["shooter","blaster","charger","disc","bow","canopy"]:
		walker.global_position=Vector3(0,40,0)
		bot.global_position=Vector3(0,43,4)
		game.bot_health=120;bot.health=120;game.bot_respawn=0;game.bot_invuln=0
		combat.ink_amount=100;combat.select_weapon(id)
		var target:=bot.global_position+Vector3.UP*.8
		if id=="charger":combat._fire_charger(combat.weapons.charger,1,(target-walker.global_position-Vector3.UP*1.05).normalized())
		elif id=="disc":combat.discs.throw_primary(walker,target)
		elif id=="bow":combat.bow.fire(walker,target,1)
		elif id=="canopy":combat.canopy.update_input(walker,.01,true,target)
		else:combat.spawn_bot_shot(walker.global_position+Vector3.UP*1.05,target,id,0,walker)
		for i in 80:combat.advance_effects(1.0/30)
		combat.canopy.cancel(walker)
		expect(game.bot_health==120,"thin deck blocks actual "+id+" attack from lower floor")
	deck.queue_free()
	await physics_frame
	# Roller flick must respect an upwards/downwards aim before adding its arc.
	var pitches: Array[float] = []
	for pitch in [-0.5, 0.5]:
		for shot in combat.projectiles: shot.visual.queue_free()
		combat.projectiles.clear()
		combat.spawn_bot_flick(Vector3(0, 50, 0), Vector3(0, 50 + tan(pitch) * 6, 6), 1, bot)
		var velocity: Vector3 = combat.projectiles[combat.projectiles.size() / 2].velocity
		pitches.append(atan2(velocity.y, Vector2(velocity.x, velocity.z).length()))
	print("AUDIT: downward/upward roller launch pitches ", pitches)
	expect(pitches[1] - pitches[0] > 0.7, "roller fan must retain vertical aim")
	walker.global_position = Vector3(0, 45, 8)
	bot.global_position = Vector3(0, 40, 0)
	bot.select_weapon("charger")
	bot.tick(0.033)
	print("AUDIT: bot gun pose pitch ", bot.get_node("Body").aim_pitch)
	expect(bot.get_node("Body").aim_pitch > 0.3, "bot visibly aims its weapon towards upper target")
	await finish("crosshair body convergence through real weapon dispatch at four heights, pitched roller arc and bot upper/lower weapon pose")
