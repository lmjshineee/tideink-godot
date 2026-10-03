extends "res://tools/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	await prepare()
	var intel: Node3D = game.intel
	walker.global_position = Vector3(0,40,0); walker.update_form(false)
	bot.global_position = Vector3(0,40,8)
	intel.refresh()
	expect(intel.marker(bot,0).status == "seen" and intel.marker(walker,1).status == "seen", "both teams observe through actual 3D sight")
	var last: Vector3 = intel.marker(bot,0).point
	var barrier := wall(Vector3(0,41,4),Vector3(20,6,.25))
	await physics_frame
	bot.global_position.x = 3
	intel.tick(.2)
	var stale: Dictionary = intel.marker(bot,0)
	expect(stale.status == "last" and stale.point == last, "lost contact freezes last observed transform")
	expect(not intel.can_see(walker,bot) and not bot.health_bar.visible, "opaque wall blocks vision and enemy nameplate")
	var small: Array = game.minimap.actor_marks()
	var large: Array = game.expanded_map.actor_marks()
	expect(small == large, "small and expanded maps use same observations")
	intel.tick(1.6)
	expect(intel.marker(bot,0).is_empty(), "last contact expires instead of tracking hidden opponent")
	intel.tag(bot,0); intel.refresh()
	expect(intel.marker(bot,0).status == "sonar" and intel.labels[bot.get_instance_id()].visible, "sonar grants temporary team/world marker")
	expect(not bot._visible_actor(walker), "information tag does not enable shooting through walls")
	game.items.on_death(bot)
	expect(intel.marker(bot,0).is_empty() and not intel.tags[0].has(bot.get_instance_id()), "death/respawn clears old life tag")
	barrier.queue_free(); await physics_frame
	bot.set_meta("enemy_swimming",true)
	intel.refresh()
	expect(intel.marker(bot,0).is_empty(), "concealed swimming enemy is not broadcast by map")
	combat.bow.fire(bot,walker.global_position+Vector3.UP,1)
	intel.refresh()
	expect(intel.marker(bot,0).status == "seen", "actual bow release breaks concealment briefly")
	intel.tick(2.6)
	expect(intel.marker(bot,0).is_empty(), "firing flash expires and concealment resumes")
	bot.global_position = walker.global_position + Vector3(0,0,2)
	intel.refresh()
	expect(not intel.marker(bot,0).is_empty(), "nearby submerged disturbance can be found")
	bot.global_position = Vector3(0,40,8)
	bot.set_meta("enemy_swimming",false)
	barrier = wall(Vector3(0,41,4),Vector3(20,6,.25))
	await physics_frame
	intel.clear_all()
	var ally: Node3D = game.extra_bots[0]
	ally.global_position = Vector3(1,40,9)
	intel.refresh()
	expect(intel.marker(bot,0).status == "seen", "living teammate shares discovered enemy location")
	ally.respawn_time = 4
	intel.tick(2)
	expect(intel.marker(bot,0).is_empty() and intel.marker(ally,0).status == "ally", "dead ally cannot spot but own team remains on map")
	barrier.queue_free(); await physics_frame
	intel.clear_all()
	bot.global_position = Vector3(0,44,4)
	var deck := wall(Vector3(0,42,2),Vector3(20,.2,20))
	await physics_frame
	intel.refresh()
	expect(intel.marker(bot,0).is_empty(), "thin raised floor blocks vertical observation")
	deck.queue_free(); await physics_frame
	# Information drives a real map route, while a physical obstruction still blocks firing.
	intel.clear_all()
	walker.global_position = Vector3(0,.05,-20); walker.update_form(false)
	bot.global_position = Vector3(3,.05,-20); bot.select_weapon("shooter"); bot.ink_amount = 100; bot.attack_cooldown = 0; bot.repath_time = 0
	barrier = wall(Vector3(1.5,1,-20),Vector3(.2,4,8))
	await physics_frame
	intel.tag(walker,1)
	var before: float = game.player_health
	var shots: int = combat.projectiles.size()
	bot.tick(.033)
	expect(bot.target_actor == null and not bot.route.is_empty() and bot.route[-1].distance_to(intel.marker(walker,1).point) < 2,"bot navigates to shared sonar contact")
	expect(game.player_health == before and combat.projectiles.size() == shots,"bot contact search does not fire through obstruction")
	barrier.queue_free()
	await finish("team-shared actual sight, concealment/attack flash, frozen expiring memory, sonar tags, death lifecycle, map parity, world labels, wall/deck occlusion and bot contact navigation without blind firing")
