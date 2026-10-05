extends "res://tests/godot/helpers/creative_fixture.gd"

const TARGETS := {
	# The central roof is disconnected in the existing graph; the broad side
	# platform is the current bot-accessible firing position on this stage.
	"tidewater":Vector3(-14.5,1.6,-.5),
	"kelpline":Vector3(-.5,2.8,-2.5),
	"coral_market":Vector3(-9.5,3.4,-6.5),
	"prism_gallery":Vector3(-2.5,6,-.5),
	"viaduct":Vector3(-.5,6,-.5),
	"modular_harbor":Vector3(-.5,1.2,-.5),
	"terrace_garden":Vector3(-.5,6,-.5),
}
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for map_id in TARGETS:
		await prepare(1,map_id)
		walker.global_position=Vector3(200,0,200)
		bot.select_weapon("shooter")
		Engine.time_scale=8;Engine.physics_ticks_per_second=240
		for team in range(2):
			bot.team=team;bot.reset();bot.global_position.y+=.05
			bot.team_mover.velocity=Vector3.ZERO
			var target:Vector3=TARGETS[map_id]
			if team==1: target=Vector3(-target.x,target.y,-target.z)
			bot.route=game.navigation.route(bot.global_position,target,team)
			expect(bot.route.size()>1,"platform path exists: %s team %d" % [map_id,team])
			if bot.route.size()<2:continue
			bot.route_index=1;bot.route_purpose="patrol";bot.repath_time=999
			var closest:=bot.global_position.distance_to(target)
			for frame in range(900):
				await physics_frame
				game._update_bot(1.0/30)
				closest=minf(closest,bot.global_position.distance_to(target))
				if closest<.7:break
			expect(closest<.7,"bot reaches actual high platform: %s team %d closest %.2fm" % [map_id,team,closest])
			print("AUDIT: ",map_id," team=",team," platform=",target," closest_m=",closest)
		for voice in game.sound.get_children():
			if voice.has_method("stop"):voice.stop();voice.stream=null
		game.queue_free();await process_frame;await process_frame
	if failures.is_empty(): print("PASS: both teams physically reach selected platforms across seven maps")
	quit(0 if failures.is_empty() else 1)
