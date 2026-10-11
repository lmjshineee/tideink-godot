extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await prepare(5,"tidewater")
	walker.global_position=Vector3(0,40,0);bot.global_position=Vector3(0,40,12)
	var from:=walker.global_position+Vector3.UP*.9
	var w:Dictionary=combat.weapons.charger
	combat.fire_bot_charger(from,bot.global_position+Vector3.UP*.9,1,0,walker)
	expect(game.actor_alive(bot) and is_equal_approx(game.bot_health,17),"healthy default build survives one full precision shot with 17 HP")
	print("AUDIT: full shot HP=",game.bot_health)
	game.bot_health=132;bot.health=132;game.bot_respawn=0;bot.respawn_time=0
	var near_miss:=from+Vector3.RIGHT*.44
	combat._fire_charger_ray(w,1,near_miss,Vector3.BACK,0,walker)
	expect(is_equal_approx(game.bot_health,132),"ray 44 cm from capsule axis is a genuine miss")
	print("AUDIT: near miss HP=",game.bot_health)
	game.bot_health=120;bot.health=120;game.perks.choices[walker.get_instance_id()]="adrenaline";game.player_health=50
	game.perks.choices[bot.get_instance_id()]="enemy_swim"
	combat.fire_bot_charger(from,bot.global_position+Vector3.UP*.9,1,0,walker)
	expect(game.bot_health>=1.99,"boosted damage and vulnerability cannot bypass the finite 118 final damage cap")
	game.perks.choices[walker.get_instance_id()]="balanced";game.perks.choices[bot.get_instance_id()]="balanced"
	bot.select_weapon("charger");walker.global_position=Vector3(0,.05,-28);bot.global_position=Vector3(0,.05,-16)
	bot.team_mover.global_position=bot.global_position;game.player_health=132;game.player_invuln=0
	bot.ink_amount=110;bot.attack_cooldown=0;bot.charge_time=float(w.chargeTime)-.22;bot.reaction_target=walker;bot.reaction_time=0
	await physics_frame
	bot._tick_team(.01)
	var committed:Vector3=bot.charger_aim
	expect(committed!=Vector3.ZERO,"real bot tick commits aim before the shot")
	walker.global_position.x=3
	bot._tick_team(.23)
	expect(game.player_health==132 and bot.attack_cooldown>0,"side-step during the final window dodges a real released bot shot")
	print("AUDIT: committed aim=",committed," sidestep HP=",game.player_health)
	await finish("charger survival and strict ray counterplay")
