extends "res://tests/godot/helpers/creative_fixture.gd"

const STEP := 1.0 / 30.0

func _initialize() -> void: call_deferred("_check")


func _check() -> void:
	await prepare(1,"tidewater")
	bot.reset()
	seed(731)
	# Keep bot decisions and move_and_slide on the same 30 Hz simulated clock.
	# The former tight loop advanced AI by 0.1s but physics by 1/30s per call,
	# alongside random perks, and required the last sample to be grounded even
	# when the bot was legitimately hopping. Other navigation checks use this
	# same isolated accelerated-physics method.
	Engine.time_scale = 8
	Engine.physics_ticks_per_second = 240
	var ink: RefCounted = game.ink
	var spawn_z := bot.global_position.z
	var clearance := SphereShape3D.new()
	clearance.radius = 0.34
	var body_query := PhysicsShapeQueryParameters3D.new()
	body_query.shape = clearance
	body_query.collision_mask = 1
	var furthest_z := spawn_z
	var distance := 0.0
	var grounded_samples := 0
	var previous: Vector3 = bot.global_position
	for step in 720:
		await physics_frame
		game.call("_update_bot", STEP)
		furthest_z = minf(furthest_z, bot.global_position.z)
		distance += bot.global_position.distance_to(previous)
		previous = bot.global_position
		body_query.transform = Transform3D(Basis(), bot.global_position + Vector3.UP * 0.75)
		var overlap: Array[Dictionary] = game.get_world_3d().direct_space_state.intersect_shape(body_query, 1)
		if not overlap.is_empty():
			expect(false,"bot route intersects %s at step %d, position %s" % [overlap[0]["collider"].name, step, bot.global_position])
			await finish("bot traversal")
			return
		if bot.team_mover.is_on_floor():
			grounded_samples += 1
			if not _support_matches_feet():
				expect(false,"grounded bot must follow actual support at step %d: %s" % [step,bot.global_position])
				await finish("bot traversal")
				return
			if grounded_samples==1:
				var feet:=bot.global_position
				bot.global_position.y+=2
				expect(not _support_matches_feet(),"support gate rejects an injected floating body")
				bot.global_position=feet
	expect(distance>=12.0 and spawn_z-furthest_z>=7.0,"bot leaves spawn and advances along the map lane")
	expect(grounded_samples>=30,"route has enough actual grounded samples")
	expect(float(ink.coverage(1))>0.0,"bot route claims scoring turf")
	var stopped := bot.global_position
	var coverage := float(ink.call("coverage", 1))
	game.call("_finish_round")
	game.call("_physics_process", .5)
	expect(bot.global_position==stopped and float(ink.coverage(1))==coverage,"bot stops moving and painting at finish")
	print("AUDIT: physical traversal m=",distance," advance_z=",spawn_z-furthest_z," grounded_samples=",grounded_samples)
	Engine.time_scale = 1
	Engine.physics_ticks_per_second = 30
	await finish("opponent advances from spawn, follows grounded support, paints real turf and freezes at finish")

func _support_matches_feet() -> bool:
	# A capsule can remain supported by the deck edge after its centre crosses
	# the lip. The real floor contact is authoritative; a centre-only ray can
	# instead report the lower storey and falsely reject a valid grounded body.
	var floor_contacts:=0
	for i in bot.team_mover.get_slide_collision_count():
		var hit:KinematicCollision3D=bot.team_mover.get_slide_collision(i)
		if hit.get_normal().y<.68:continue
		floor_contacts+=1
		if absf(bot.global_position.y-hit.get_position().y)<=.6:return true
	if floor_contacts>0:return false
	# Floor snapping may not add a slide collision; sample the footprint then.
	for i in range(-1,8):
		var at:=bot.global_position
		if i>=0:at+=Vector3(cos(float(i)*PI/4),0,sin(float(i)*PI/4))*.34
		var support:Dictionary=bot._ground_at(at)
		if not support.is_empty() and float(support.normal.y)>=.68 and absf(bot.global_position.y-float(support.position.y))<=.6:return true
	return false
