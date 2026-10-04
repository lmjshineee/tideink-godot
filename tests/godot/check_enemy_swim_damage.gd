extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await prepare(5,"modular_harbor")
	game.perks.choices[walker.get_instance_id()]="enemy_swim"
	game.perks.apply_movement()
	walker.global_position=Vector3(0,.05,-20); walker.reset_movement_state(); walker.grounded=true
	game.paint_at_world(walker.global_position+Vector3.UP*.1,1,3,0)
	walker.ink_owner=walker._floor_ink_owner()
	expect(walker.ink_owner==1 and walker.can_dive(),"actual enemy ink permits selected swim talent")
	for hz in [30,60,120]:
		game.player_health=120; game.player_ink_damage=0; game.player_invuln=0; game.player_last_damage=99
		for i in hz: game._update_player_vitals(1.0/hz)
		print("AUDIT: ",hz," Hz enemy ink loss/s=",120-game.player_health)
		expect(absf(game.player_health-114)<.01,"enemy ink drains six HP per second independently of tick rate")
		for i in hz*10: game._update_player_vitals(1.0/hz)
		print("AUDIT: sustained enemy ink health=",game.player_health," accumulated=",game.player_ink_damage)
		expect(absf(game.player_health-100)<.01 and absf(game.player_ink_damage-20)<.01,"talent enemy ink loss caps at twenty with no in-ink regeneration")
	game.player_health=120; game.player_respawn=0; game.player_invuln=0
	walker.global_position=Vector3(0,20,36); walker.squid_form=false; walker.get_node("Body").set_form(false)
	var from: Vector3=walker.global_position+Vector3(0,.9,-4)
	combat.fire_bot_charger(from,walker.global_position+Vector3.UP*.9,1,1,bot)
	print("AUDIT: real full charger torso hit health=",game.player_health," respawn=",game.player_respawn)
	expect(game.player_respawn<=0 and absf(game.player_health-10)<.01,"one normal torso charge cannot one-shot the full-health talent")
	game.player_health=120; game.player_respawn=0; game.player_invuln=0
	game.damage_player(30,false,bot,"shooter")
	expect(absf(game.player_health-87)<.01,"enemy attacks retain ten percent extra damage")
	game.perks.choices[bot.get_instance_id()]="adrenaline"; game.bot_health=50
	game.player_health=120
	game.damage_player(108,false,bot,"charger","头部",4)
	expect(game.player_respawn<=0 and absf(game.player_health-5)<.01,"normal shot limit applies after attacker and defender modifiers")
	game.damage_player(10,false,bot,"shooter")
	expect(game.player_respawn>0,"ordinary follow-up damage remains lethal")
	game.player_respawn=0; game.player_health=3; game.player_ink_damage=0; walker.grounded=true; walker.ink_owner=1
	game._update_player_vitals(1)
	expect(game.player_health==1 and game.player_respawn==0,"enemy ink alone never kills a low-health actor")
	game.player_health=120; game.player_ink_damage=0; game.player_invuln=1
	game._update_player_vitals(.1)
	expect(game.player_health==120 and game.player_ink_damage==0,"spawn protection prevents environment loss")
	game.player_invuln=0; walker.grounded=false; game.player_last_damage=0
	game._update_player_vitals(.1)
	expect(game.player_health==120 and game.player_ink_damage==0,"airborne feet do not take ground-ink damage")
	game.perks.choices[walker.get_instance_id()]="balanced"; walker.grounded=true; walker.ink_owner=1
	game.player_health=120; game.player_ink_damage=0
	game._update_player_vitals(1)
	expect(game.player_health==100,"ordinary enemy-ink DPS remains twenty")
	game._update_player_vitals(9)
	expect(game.player_health==80 and game.player_ink_damage==40,"ordinary enemy-ink damage cap remains forty")
	# Both production bot-vitals paths use the same talent limit.
	var home := Vector3(0,.05,-20)
	bot.global_position=home; bot.team_mover.position=Vector3.ZERO
	game.paint_at_world(home+Vector3.UP*.1,0,3,0)
	game.perks.choices[bot.get_instance_id()]="enemy_swim"; game.bot_health=120; game.bot_ink_damage=0; game.bot_invuln=0
	expect(bot.floor_ink_owner()==0,"primary opponent stands on actual hostile ink")
	game._update_bot_vitals(1)
	expect(absf(game.bot_health-114)<.01,"primary opponent shares six HP/s")
	game._update_bot_vitals(9)
	expect(absf(game.bot_health-100)<.01 and game.bot_ink_damage==20,"primary opponent shares twenty-HP cap")
	var ally: Node3D=game.extra_bots[0]
	bot.global_position=Vector3(70,40,70); walker.global_position=Vector3(90,40,90)
	game.perks.choices[ally.get_instance_id()]="enemy_swim"; ally.health=120; ally.ink_damage=0; ally.invuln=0; ally.respawn_time=0
	game.paint_at_world(home+Vector3.UP*.1,1,3,0)
	ally.global_position=home; ally.team_mover.global_position=home
	for i in 3:
		ally.team_mover.velocity=Vector3.DOWN; ally.team_mover.move_and_slide()
	ally.global_position=ally.team_mover.global_position; ally.team_mover.position=Vector3.ZERO
	game.perks.bot_form(ally,false)
	expect(ally.get_meta("enemy_swimming",false),"team actor is physically grounded before environment trial")
	for i in 120:
		ally.global_position=home; ally.team_mover.position=Vector3.ZERO
		game._update_team_actor(ally,1.0/30)
		if i==29:
			print("AUDIT: team actor HP/s=",120-ally.health," ink budget=",ally.ink_damage)
			expect(absf(ally.health-114)<.01,"team actor shares six HP/s")
	expect(absf(ally.health-100)<.01 and ally.ink_damage==20,"team actor shares twenty-HP cap")
	await finish("enemy-swim six HP/s and twenty-HP cap at three tick rates; actual charge ray, attack disadvantage and final normal-shot ceiling")
