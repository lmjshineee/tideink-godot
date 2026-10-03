extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare()
	walker.global_position=Vector3(0,40,0)
	bot.global_position=Vector3(0,40,7)
	combat.select_weapon("canopy")
	combat.ink_amount=100
	var canopy:Node3D=combat.canopy
	var target:=bot.global_position+Vector3.UP
	canopy.update_input(walker,.01,true,target)
	expect(combat.projectiles.size()==6 and combat.ink_amount==95,"tap emits six pellets and pays once")
	for i in 10:combat._update_projectiles(1.0/30)
	expect(game.bot_health<120 and game.bot_health>0,"actual pellets damage while leaving reaction HP")
	canopy.update_input(walker,.12,true,target)
	expect(not canopy.holding(walker),"open waits 0.20 seconds")
	canopy.update_input(walker,.08,true,target)
	expect(canopy.holding(walker),"hold opens real cover")
	await physics_frame
	var s:Dictionary=canopy.state(walker)
	var before:float=combat.ink_amount
	canopy.tick(.2)
	expect(is_equal_approx(before-combat.ink_amount,.28) and combat.is_busy(),"holding drains ink and prevents passive refill/dive")
	game.player_health=120
	combat.fire_bot_charger(bot.global_position+Vector3.UP,walker.global_position+Vector3.UP,1,1,bot)
	expect(game.player_health==120 and is_equal_approx(s.hp,120),"enemy full charge hits cover rather than owner")
	# A teammate behind the cover can shoot forwards through it.
	game.bot_health=120;bot.health=120
	combat._fire_charger_ray(combat.weapons.charger,1,walker.global_position+Vector3.UP,Vector3(0,0,1),0,walker)
	expect(game.bot_health<120 and is_equal_approx(s.hp,120),"friendly ray passes cover without damaging it")
	combat.fire_bot_charger(bot.global_position+Vector3.UP,walker.global_position+Vector3.UP,1,1,bot)
	expect(s.cover!=null and s.hp==20,"two full charges leave twenty cover HP")
	combat.fire_bot_charger(bot.global_position+Vector3.UP,walker.global_position+Vector3.UP,1,1,bot)
	expect(s.cover==null and s.cooldown==4.5 and game.player_health==120,"third hit breaks cover and begins cooldown; breaking shot stays blocked")
	canopy.cancel(walker)
	game.randomize_player_kit()
	combat.select_weapon("canopy")
	expect(s.cooldown==4.5,"reroll keeps cover cooldown")
	canopy.tick(4.5)
	canopy.update_input(walker,.3,true,target)
	await physics_frame
	expect(canopy.holding(walker),"cover returns after cooldown")
	# A side attack bypasses the finite panel.
	combat.fire_bot_charger(walker.global_position+Vector3(5,1,0),walker.global_position+Vector3.UP,1,1,bot)
	expect(game.player_health<120 and s.hp==220,"side ray hits exposed actor rather than an omnidirectional shield")
	game.player_health=120
	var start:Vector3=s.cover.global_position
	var ink_before:float=combat.ink_amount
	canopy.update_input(walker,1,true,target)
	expect(s.launched and is_equal_approx(ink_before-combat.ink_amount,8),"hold to 0.85 seconds launches with extra ink")
	canopy.tick(.5)
	expect(s.cover.global_position.distance_to(start)>2.9,"released cover advances in 3D")
	var barrier:=wall(s.cover.global_position+Vector3(0,0,1),Vector3(8,8,.3))
	await physics_frame
	for i in 10:canopy.tick(1.0/30)
	expect(s.cover==null and s.cooldown>3.6,"wall stops advancing cover")
	barrier.queue_free()
	canopy.cancel(walker);canopy.tick(4.5)
	combat.ink_amount=100
	canopy.update_input(walker,.3,true,walker.global_position+Vector3(0,5,7))
	await physics_frame
	canopy.tick(.01)
	expect(canopy.holding(walker) and s.cover.basis.z.y>.4,"cover tilts towards elevated aim")
	game.player_respawn=2
	canopy.tick(.01)
	expect(s.cover==null and s.cooldown>4.4,"death closes held cover without clearing cooldown")
	game.player_respawn=0
	bot.select_weapon("canopy")
	bot.ink_amount=100
	game.bot_respawn=0;game.bot_health=120;bot.health=120;game.bot_invuln=0
	game.damage_bot(10,walker,"shooter")
	for i in 11:bot.tick(1.0/30)
	expect(canopy.holding(bot) and bot.ink_amount<=95,"bot uses real cover under fire")
	canopy.clear_all()
	await finish("canopy real pellet volley, windup/ink, hostile blocking and break, friendly passage, exposed flank, cooldown retention, launch/wall, pitched cover and bot defense")
