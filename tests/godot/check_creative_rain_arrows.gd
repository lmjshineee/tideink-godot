extends "res://tests/godot/helpers/creative_fixture.gd"
var rain: Node3D
var home: Vector3
func _initialize() -> void: call_deferred("_run")
func clear() -> void:
	rain.clear_all(); combat.special_active = ""; game.bot_health = 120; bot.health = 120; game.bot_invuln = 0
func simulate(seconds: float) -> void:
	for i in ceili(seconds/.01): rain.tick(.01)
func _run() -> void:
	await prepare(); rain = combat.rain_arrows
	walker.global_position = Vector3(0,.05,-20); walker.update_form(false); walker.grounded = true
	bot.global_position = Vector3(0,.05,-14); bot.set_meta("enemy_swimming",false); await physics_frame
	home = walker.global_position
	combat.select_weapon("bow"); combat.special_points = 170; combat.ink_amount = 20
	var camera: Camera3D = walker.get_node("Camera3D"); camera.current = true
	camera.global_position = home+Vector3(0,2,-3); camera.look_at(home+Vector3(0,40,6))
	game.pointer_locked = true
	combat.charging = true; combat.charge_time = .5; combat.charge_fraction = .5
	expect(not combat.try_special() and combat.special_points == 170 and combat.ink_amount == 20,"invalid sky target preserves meter and resources")
	expect(combat.charging and combat.charge_fraction == .5,"refused special target does not cancel existing primary charge")
	camera.look_at(bot.global_position + Vector3.UP*.2)
	key(KEY_F,true); key(KEY_F,false)
	expect(rain.busy(walker) and combat.special_active == "rain_arrows" and combat.special_points == 0 and combat.ink_amount == 100,"actual F input spends bow's own meter on rain arrows")
	if not rain.busy(walker): await finish("rain arrows actual input"); return
	var s: Dictionary = rain.casts[walker.get_instance_id()]
	var locked: Vector3 = s.point
	expect(combat.is_busy() and s.wave == 0,"announced target and form/action lock start before firing")
	walker.update_intent(.01,false,true,combat.is_busy()); expect(not walker.squid_form,"rain windup cannot dive")
	game.items.equip(walker,"mine"); expect(not game.items.use(walker),"special locks item use")
	combat.tick(.1,true,false); expect(combat.bow.arrows.is_empty() and combat.ink_amount == 100,"primary trigger cannot charge or spend ink during special")
	rain.tick(.49); expect(rain.arrows.is_empty(),"full 0.6s prewarning")
	rain.tick(.02); expect(rain.arrows.size() == 9 and s.wave == 1 and s.point == locked,"first nine arrows fly from real bow towards fixed target")
	expect(rain.arrows[0].visual.global_position.distance_to(home) < 2,"no rain spawns above or behind target")
	var volley: Dictionary = rain.arrows[0].budget
	for a in rain.arrows: expect(a.budget == volley and a.velocity.y > 0,"wave shares damage budget and initial upward trajectory")
	simulate(.9)
	expect(not rain.busy(walker) and rain.volleys_total == 3,"three timed volleys release then primary lock ends")
	simulate(2)
	expect(rain.arrows.is_empty() and game.bot_health < 120,"real descending arrows/splash damage actual enemy")
	expect(combat.special_points == 0 and game._attacker_description(walker,"rain_arrows").contains("雨箭"),"special paint does not recharge itself and damage source remains readable")
	clear(); bot.global_position = Vector3(0,.05,-14); await physics_frame
	expect(rain.begin(walker,bot.global_position+Vector3.UP*.2),"same-height floor target validated")
	s = rain.casts[walker.get_instance_id()]; s.next = .01
	rain.tick(.02); rain.cancel(walker)
	simulate(2)
	expect(game.bot_health >= 75 and game.bot_health < 120,"one actual wave stays below 45 outgoing damage")
	clear(); game.perks.choices[walker.get_instance_id()] = "adrenaline"; game.player_health = 120
	var a := {"owner":walker,"team":0,"budget":{"hits":{}}}
	rain._damage(a,bot,28); game.player_health = 50; rain._damage(a,bot,28)
	expect(is_equal_approx(game.bot_health,75),"changing outgoing perk mid-flight cannot exceed per-wave cap")
	game.perks.choices[walker.get_instance_id()] = "balanced"; game.player_health = 120
	clear(); bot.global_position = Vector3(0,.05,-14)
	var roof := wall(Vector3(0,2.4,-17),Vector3(10,.12,12)); await physics_frame
	expect(rain.begin(walker,bot.global_position+Vector3.UP*.2),"floor visible under roof remains valid tactical choice")
	simulate(3); expect(game.bot_health == 120,"real arc collides with thin overhead roof instead of teleporting arrows")
	roof.queue_free(); await physics_frame; clear()
	var barrier := wall(Vector3(0,1,-17),Vector3(10,5,.12)); await physics_frame
	expect(not rain.begin(walker,bot.global_position+Vector3.UP*.2),"target behind wall is refused")
	barrier.queue_free(); await physics_frame
	# Controlled high platform: lower target is within spherical splash range but
	# must remain protected by the .12m slab under every impact.
	clear(); var deck := wall(Vector3(0,2,-14),Vector3(8,.12,8)); await physics_frame
	walker.global_position = Vector3(0,2.11,-17)
	bot.global_position = Vector3(0,.4,-14)
	expect(rain.begin(walker,Vector3(0,2.2,-14)),"upper-floor target independently validated")
	simulate(3); expect(game.bot_health == 120,"higher impacts cannot damage lower enemy through thin floor")
	deck.queue_free(); walker.global_position = home; await physics_frame; clear()
	bot.global_position = Vector3(0,.05,-14); await physics_frame
	expect(rain.begin(walker,bot.global_position),"death fixture begins special")
	rain.tick(.61); var fired: int = rain.volleys_total
	game.player_respawn = 3; combat.on_death(); simulate(2)
	expect(not rain.busy(walker) and rain.volleys_total == fired and rain.arrows.is_empty() and game.bot_health < 120,"death cancels future waves but fired arrows remain actual attacks")
	game.player_respawn = 0; clear(); game.intel.clear_all()
	bot.select_weapon("bow"); bot.global_position = Vector3(0,.05,-20); walker.global_position = Vector3(0,.05,-14)
	var bs: Dictionary = game.bot_specials.state(bot); bs.points = 170; bs.cooldown = 0; await physics_frame
	barrier = wall(Vector3(0,1,-17),Vector3(10,5,.12)); await physics_frame
	game.bot_specials.tick(.01); expect(bs.points == 170 and not rain.busy(bot),"AI requires actual visibility and valid target before spending meter")
	barrier.queue_free(); await physics_frame; game.intel.refresh(); game.bot_specials.tick(.01)
	expect(bs.active and bs.kind == "rain_arrows" and bs.points == 0 and rain.busy(bot),"AI dispatches same ballistic special from actual bow meter")
	simulate(3); game.bot_specials.tick(.01)
	expect(not bs.active and game.player_health < 120 and game.bot_health == 120,"AI real rain hits opposing player, no self/team damage")
	expect(game.last_damage_text.contains("雨箭"),"actual hostile rain is attributed by readable special name")
	clear(); rain.cancel(bot); bs.active = false; bs.cooldown = 0; bs.points = 170
	bot.global_position = Vector3(0,2,-20); walker.global_position = Vector3(0,.05,-14); await physics_frame
	game.intel.refresh(); game.bot_specials.tick(.01)
	var height: float = bot.global_position.y
	game._update_bot(.033)
	expect(bs.active and bot.global_position.y < height and combat.bow.arrows.is_empty(),"casting AI keeps actual gravity/body movement while primary stays locked")
	# Kill spray uses the general damage path, so verify it cannot refill either
	# side's rain meter after the casting lock has already ended.
	rain.clear_all(); combat.special_active = ""; combat.special_points = 0
	game.bot_health = 120; bot.health = 120; bot.global_position = Vector3(12,.05,-23); game.bot_invuln = 0
	var turf_before := float(walker.get_meta("match_stats").turf)
	for wave in 3:
		rain._damage({"owner":walker,"team":0,"budget":{"hits":{}}},bot,90)
	expect(game.bot_respawn > 0 and float(walker.get_meta("match_stats").turf) > turf_before and combat.special_points == 0,"actual lethal rain credits player kill spray turf without charging next meter")
	game.bot_respawn = 0; game.bot_health = 120; bot.health = 120
	bs.active = false; bs.points = 0
	walker.global_position = Vector3(-12,.05,-23); game.player_health = 20; game.player_invuln = 0
	turf_before = float(bot.get_meta("match_stats").turf)
	rain._damage({"owner":bot,"team":1,"budget":{"hits":{}}},walker,28)
	expect(game.player_respawn > 0 and float(bot.get_meta("match_stats").turf) > turf_before and bs.points == 0,"actual enemy rain kill spray credits bot turf without charging its next meter")
	# Complete the weapon -> authoritative ink -> meter -> real F path as well.
	# Resources/positions are controlled; all ink is produced by actual primary arrows.
	rain.clear_all(); combat.special_active = ""; combat.special_points = 0
	game.player_health = 120; game.player_respawn = 0; walker.active = true; walker.visible = true; walker.update_form(false); game.deployment.clear()
	bot.global_position = Vector3(70,40,70); game.perks.choices[walker.get_instance_id()] = "balanced"
	var rounds := 0
	for x in range(-21,22,3):
		for z in range(-24,25,3):
			if combat.special_ready(): break
			var floor_hit := game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,12,z),Vector3(x,-1,z),1))
			if floor_hit.is_empty() or floor_hit.normal.y < .68: continue
			walker.global_position = floor_hit.position+Vector3.UP*.05; combat.ink_amount = 100
			combat.bow.fire(walker,walker.global_position+Vector3(0,0,4),1)
			for i in 215: combat.bow.tick(.01)
			rounds += 1
		if combat.special_ready(): break
	expect(combat.special_ready() and combat.special_points == 170,"actual primary arrows/explosions on fresh turf fill 170-point rain meter")
	print("AUDIT: rain charged by ",rounds," actual bow volleys / controlled positions and ink")
	walker.global_position = home; await physics_frame
	camera.global_position = home+Vector3(0,2,-3); camera.look_at(home+Vector3(0,0,6))
	key(KEY_F,true); key(KEY_F,false)
	expect(rain.busy(walker) and combat.special_points == 0,"real F consumes legitimately paint-charged bow meter")
	game._finish_round(); expect(rain.casts.is_empty() and rain.arrows.is_empty(),"round end clears pending/flying rain arrows")
	await finish("rain arrows F input/target validity/cost, announced ballistic volleys, action locks, actual impacts/45 cap/perk change, roof/wall/thin-deck occlusion, death projectile ownership, AI dispatch and cleanup")
