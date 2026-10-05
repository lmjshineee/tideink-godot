extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	await prepare(1,"tidewater")
	game.ai_level="standard";game.player_invuln=999
	game.items.state(bot).cooldowns.bomb=999
	wall(Vector3(0,2,-23),Vector3(5,4,3))
	walker.global_position=Vector3(0,4.05,-24.45)
	bot.global_position=Vector3(0,.05,-28);bot.team_mover.velocity=Vector3.ZERO;bot.select_weapon("shooter")
	await physics_frame
	expect(game.intel.can_see(bot,walker),"real unobstructed view to opponent at high-platform edge")
	var start:Vector3=bot.global_position;var furthest:=0.0
	for frame in range(75):
		await physics_frame;game._update_bot(1.0/30);combat.advance_effects(1.0/30);game.intel.tick(1.0/30)
		furthest=maxf(furthest,Vector2(bot.global_position.x-start.x,bot.global_position.z-start.z).length())
	expect(furthest>.8,"standard AI changes firing position under a high-ground opponent instead of standing still")
	print("AUDIT: high-ground lateral distance=",furthest," target acquired=",bot.target_actor!=null)
	await finish("visible high-ground opponent: actual collision-safe bot strafing with ordinary shooting")
