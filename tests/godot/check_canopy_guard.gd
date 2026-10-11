extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await prepare()
	walker.global_position = Vector3(0,40,0)
	bot.global_position = Vector3(0,40,8)
	combat.select_weapon("canopy")
	var canopy: Node3D = combat.canopy
	var target := bot.global_position + Vector3.UP
	combat.ink_amount = 6
	canopy.update_input(walker,.21,true,target)
	expect(canopy.holding(walker),"low ink still opens a defensive canopy after paying for a volley")
	canopy.clear_all()
	combat.ink_amount = 100
	canopy.update_input(walker,.21,true,target)
	canopy.state(walker).hp=150
	canopy.update_input(walker,.01,false,target)
	canopy.tick(.4)
	canopy.update_input(walker,.21,true,target)
	expect(canopy.holding(walker),"voluntary release allows prompt reopening instead of the break cooldown")
	expect(canopy.state(walker).hp==150,"quick reopening retains damage rather than granting a new full shield")
	canopy.clear_all()
	# A short obstacle at the outer edge intersects the old fixed 1.15m placement.
	var obstacle := wall(Vector3(1.05,41.05,1.15),Vector3(.25,2,.25))
	await physics_frame
	combat.ink_amount = 100
	canopy.update_input(walker,.21,true,target)
	expect(canopy.holding(walker),"near-edge obstacle permits a closer clear guard placement")
	if canopy.holding(walker):
		expect(canopy.state(walker).cover.global_position.z < 1,"guard stays on the near side of the obstacle")
	canopy.clear_all(); obstacle.queue_free()
	await physics_frame
	# A real wall across the muzzle must never allow an umbrella on its far side.
	obstacle = wall(Vector3(0,41.05,.4),Vector3(6,3,.2))
	await physics_frame
	combat.ink_amount = 100
	canopy.update_input(walker,.3,true,target)
	expect(not canopy.holding(walker),"blocked muzzle refuses a through-wall guard")
	canopy.clear_all(); obstacle.queue_free()
	await finish("low-ink guard, soft release recovery, near-obstacle fit and through-wall refusal")
