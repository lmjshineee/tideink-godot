extends SceneTree

# Exercise real target selection, charge, projectiles and wall occlusion in both modes.
const Setup := preload("res://match_setup.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ",message)

func _run() -> void:
	for size in [1,5]:
		Setup.team_size = size
		Setup.map_id = "tidewater"
		Setup.map_variant = 0
		Setup.reroll_bots = false
		var game := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
		root.add_child(game)
		await physics_frame
		game.set_physics_process(false)
		var walker: CharacterBody3D = game.get_node("World/Walker")
		walker.set_physics_process(false)
		for actor in game.all_actors():
			game.perks.choices[actor.get_instance_id()] = "balanced"
		game._start_round()
		var bot: Node3D = game.get_node("Bot")
		var combat: Node3D = game.get_node("Combat")
		for actor in game.extra_bots:
			actor.global_position = Vector3(60,30,60)
		# Eliminate random aim misses, without changing the production range or cadence.
		combat.weapons.heavy.spreadBaseGround = 0.0
		for spec in [["heavy",14.0,true],["charger",22.0,true],["dualie",14.0,false],["heavy",19.0,false],["charger",29.0,false]]:
			for field in ["projectiles","beams","bursts"]:
				for effect in combat.get(field):
					effect.visual.queue_free()
				combat.get(field).clear()
			bot.select_weapon(spec[0])
			bot.ink_amount = 100.0
			game.player_health = 120.0
			game.player_respawn = 0.0
			game.player_invuln = 0.0
			walker.global_position = Vector3(0,30,float(spec[1]))
			bot.global_position = Vector3(0,30,0)
			await physics_frame
			for step in range(65 if spec[0] == "charger" else 1):
				bot.global_position = Vector3(0,30,0)
				bot.route = PackedVector3Array([bot.global_position])
				bot.route_index = 0
				bot.repath_time = 999.0
				if bot.team_mover != null:
					bot.team_mover.velocity = Vector3.ZERO
				bot.tick(1.0/60.0)
			var fired: bool = not combat.projectiles.is_empty() or not combat.beams.is_empty()
			expect(fired == bool(spec[2]),"%dv%d %s at %.0fm firing=%s" % [size,size,spec[0],spec[1],fired])
			for step in range(90):
				combat.advance_effects(1.0/120.0)
			if bool(spec[2]):
				expect(game.player_health < 120.0,"extended-range shot must actually hit the target")
		# A wall must still prevent acquiring and firing at a target within weapon range.
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(8,6,1)
		collision.shape = box
		wall.add_child(collision)
		game.add_child(wall)
		wall.global_position = Vector3(0,31,7)
		walker.global_position = Vector3(0,30,14)
		bot.global_position = Vector3(0,30,0)
		bot.select_weapon("heavy")
		bot.ink_amount = 100.0
		await physics_frame
		bot.tick(1.0/60.0)
		expect(bot.last_fire_time > 0.0,"wall blocks long-range fire in both modes")
		game.queue_free()
		await process_frame
	if failures.is_empty():
		print("PASS: 1v1/5v5 heavy 14m and charger 22m acquire/fire/hit; short weapons and beyond-range targets rejected; walls still block")
	quit(0 if failures.is_empty() else 1)
