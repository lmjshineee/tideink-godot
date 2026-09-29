extends SceneTree

# spawnBarrier (actor.js:522-533). The map exporter has emitted `spawnBarrier: 4.2` since
# it was written and nothing consumed it until now. The rule: any actor inside the enemy
# spawn radius is pushed out to exactly that radius, velocity still heading inward is
# reflected with a 1.6 factor, and the whole check is skipped below `pad.y - 1.0`.
#
# The walk scene's pads are spawnPads[0] at z = -39.2 (team 0, where the walker spawns)
# and spawnPads[1] at z = +39.2 (team 1), so the barrier for the default team 0 sits far
# from the spawn point and cannot interfere with the other movement checks.
var scene: Node3D
var walker: CharacterBody3D


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	scene = (load("res://tidewater_walk.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	walker = scene.get_node("Walker")
	for i in range(12):
		await physics_frame
	var pads: Array = scene.get_node("Map").get("spawn_pads")
	var radius := float(walker.get("spawn_barrier"))
	if pads.size() != 2 or absf(radius - 4.2) > 0.001:
		_fail("spawnBarrier was not read from the map export: radius=%s pads=%d" % [
			walker.get("spawn_barrier"), pads.size()])
		return
	var own_pad: Vector3 = pads[0]
	var enemy_pad: Vector3 = pads[1]

	# 1. an intruder inside the enemy radius is pushed out to exactly the radius.
	await _step(Vector3(enemy_pad.x + 1.0, enemy_pad.y + 0.5, enemy_pad.z), Vector3.ZERO)
	var pushed := _planar_distance(walker.global_position, enemy_pad)
	if absf(pushed - radius) > 0.01:
		_fail("intruder was not pushed to the barrier radius: %.3f (want %.2f)" % [pushed, radius])
		return

	# 2. outside the radius nothing happens.
	var outside := Vector3(enemy_pad.x + radius + 0.8, enemy_pad.y + 0.5, enemy_pad.z)
	await _step(outside, Vector3.ZERO)
	if _planar_distance(walker.global_position, outside) > 0.01:
		_fail("walker outside the barrier was moved: " + str(walker.global_position))
		return

	# 3. velocity that is still heading inward comes back outward.
	await _step(Vector3(enemy_pad.x + 1.0, enemy_pad.y + 0.5, enemy_pad.z), Vector3(-4.0, 0.0, 0.0))
	if walker.velocity.x <= 0.1:
		_fail("inward velocity was not reflected: vx=%.3f" % walker.velocity.x)
		return

	# 4. the barred pad follows the team: team 1 is kept out of the other pad.
	walker.set("team", 1)
	await _step(Vector3(own_pad.x + 1.0, own_pad.y + 0.5, own_pad.z), Vector3.ZERO)
	var own_distance := _planar_distance(walker.global_position, own_pad)
	if absf(own_distance - radius) > 0.01:
		_fail("team 1 was not barred from the other pad: %.3f" % own_distance)
		return
	walker.set("team", 0)

	# 5. a walker exactly on the pad centre is pushed out instead of producing a NaN.
	await _step(Vector3(enemy_pad.x, enemy_pad.y + 0.5, enemy_pad.z), Vector3.ZERO)
	if not is_finite(walker.global_position.x) or _planar_distance(walker.global_position, enemy_pad) < radius - 0.01:
		_fail("barrier did not survive a walker exactly on the pad centre: " + str(walker.global_position))
		return

	# 6. below the pad line the barrier is skipped (actor.js:527). Tidewater cannot
	#    provide this case naturally: both pad platforms are solid down to the deck, so
	#    anywhere within 4.2 m of a pad is either on it or inside it (the engine lifts an
	#    intruder out of the block, which lands it above the line again). The scenario is
	#    therefore isolated by pointing the barrier at a pad one and a half metres above
	#    the walker's feet: same 1.0 m planar overlap as case 1, but below the line.
	var standing := walker.global_position
	walker.set("_spawn_pads", [
		Vector3(standing.x, standing.y + 1.5, standing.z),
		Vector3(standing.x, standing.y + 1.5, standing.z),
	])
	await _step(Vector3(standing.x + 1.0, standing.y, standing.z), Vector3.ZERO)
	if absf(walker.global_position.x - (standing.x + 1.0)) > 0.01:
		_fail("barrier applied below the pad line: " + str(walker.global_position))
		return

	# Parenthesised: % binds tighter than +, so the specifier and the argument have to be
	# in the same expression (an earlier version formatted only the second half and failed
	# at runtime with "not all arguments converted").
	print(("PASS: spawn barrier pushes to %.1f m, reflects inward velocity, follows team, "
		+ "survives the pad centre, skips below the pad line") % radius)
	quit()


# Places the walker, gives it a velocity and advances one physics frame. `grounded` is set
# so no gravity accumulates, and the feet resolve before the barrier runs — the source's
# order (integrate and collide, then barrier).
func _step(at: Vector3, velocity: Vector3) -> void:
	walker.global_position = at
	walker.velocity = velocity
	walker.set("grounded", true)
	await physics_frame


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
