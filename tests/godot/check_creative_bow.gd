extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")
func reset_target(at: Vector3) -> void:
	bot.global_position=at
	game.bot_health=120
	bot.health=120
	game.bot_respawn=0
	game.bot_invuln=0
	combat.ink_amount=100
	combat.bow.clear_all()
func _run() -> void:
	root.size=Vector2i(1280,720)
	await prepare()
	combat.select_weapon("bow")
	walker.global_position=Vector3(0,40,0)
	walker.grounded=true
	game.pointer_locked=true
	var camera: Camera3D=walker.get_node("Camera3D")
	for height in [-3.0,0.0,3.0,6.0]:
		reset_target(Vector3(0,40+height,8))
		camera.global_position=walker.global_position+Vector3(4,4,-6)
		camera.look_at(bot.global_position+Vector3.UP*.8)
		combat.cooldown=0
		combat.tick(1,true,false)
		expect(combat.charging and combat.charge_fraction==1 and combat.bow.arrows.is_empty(),"charge holds three arrows")
		combat.tick(.001,false,false)
		expect(combat.bow.arrows.size()==3 and is_equal_approx(combat.ink_amount,93),"full bow costs 7 on release")
		for i in 45: combat.bow.tick(1.0/30)
		print("AUDIT: bow crosshair height=",height," remainingHP=",game.bot_health)
		expect(game.bot_health<120 and game.bot_health>=12,"actual bow hits crosshair at "+str(height)+" without full-HP one shot")
	reset_target(Vector3(0,40,8))
	combat.bow.fire(walker,bot.global_position+Vector3.UP,0)
	expect(is_equal_approx(combat.ink_amount,97),"tap costs 3")
	var ground_first: Vector3=combat.bow.arrows[0].velocity
	var ground_last: Vector3=combat.bow.arrows[2].velocity
	expect(absf(ground_first.x-ground_last.x)>4 and absf(ground_first.y-ground_last.y)<.01,"ground fan is horizontal")
	combat.bow.clear_all()
	walker.grounded=false
	combat.bow.fire(walker,bot.global_position+Vector3.UP,1)
	var air_first: Vector3=combat.bow.arrows[0].velocity
	var air_last: Vector3=combat.bow.arrows[2].velocity
	expect(absf(air_first.y-air_last.y)>.8 and absf(air_first.x-air_last.x)<.01,"full air fan is vertical and narrow")
	walker.grounded=true
	combat.bow.clear_all()
	var barrier:=wall(Vector3(0,41,6),Vector3(6,8,.4))
	await physics_frame
	reset_target(Vector3(0,40,9))
	combat.bow.fire(walker,bot.global_position+Vector3.UP,1)
	for i in 8: combat.bow.tick(1.0/30)
	expect(combat.bow.planted.size()==3 and game.bot_health==120,"charged arrows embed in occluding wall")
	for i in 6: combat.bow.tick(1.0/30)
	expect(combat.bow.planted.size()==3 and game.bot_health==120,"embedded arrows wait visible full fuse")
	# Move a real capsule close to all three planted arrows. Blasts share one budget.
	bot.global_position=Vector3(0,40,5)
	for i in 12: combat.bow.tick(1.0/30)
	print("AUDIT: three planted blasts damage=",120-game.bot_health)
	expect(game.bot_health<120 and game.bot_health>=80 and combat.bow.planted.is_empty(),"three delayed blasts share 40 budget and expire")
	barrier.queue_free()
	await physics_frame
	# A thin deck separates a nearby target even within blast radius.
	var deck:=wall(Vector3(0,40.7,6),Vector3(8,.2,8))
	await physics_frame
	reset_target(Vector3(0,39.5,6))
	var first:=preload("res://src/combat/ink_equipment_mesh.gd").bolt(0)
	combat.bow.add_child(first)
	var arrow:Dictionary={"visual":first,"at":Vector3(0,40.84,6),"owner":walker,"team":0,"origin":walker.global_position,"weapon":combat.weapons.bow,"budget":{"hits":{},"blasts":{},"max":110}}
	combat.bow._explode(arrow)
	expect(game.bot_health==120,"explosion cannot cross a deck despite overlapping radius")
	first.queue_free();deck.queue_free()
	await physics_frame
	reset_target(Vector3(0,40,5))
	game.perks.choices[walker.get_instance_id()]="adrenaline"
	game.player_health=50
	combat.bow.fire(walker,bot.global_position+Vector3.UP,1)
	for i in 30: combat.bow.tick(1.0/30)
	expect(game.bot_health>0,"adrenaline three-arrow attack leaves reaction HP")
	game.perks.choices[walker.get_instance_id()]="balanced"
	combat.ink_amount=2
	expect(not combat.bow.fire(walker,bot.global_position,0),"dry tank cannot release")
	bot.select_weapon("bow")
	bot.global_position=Vector3(0,40,6)
	bot.ink_amount=100
	bot.attack_cooldown=0
	for i in 31:bot.tick(1.0/30)
	expect(not combat.bow.arrows.is_empty() and bot.ink_amount<=93,"bot charges and pays for real arrows")
	combat.bow.clear_all()
	await finish("bow actual reticle release at four heights, charge/cost, ground-air fans, delayed shared-budget blast, deck/wall occlusion, low-HP boost and bot dispatch")
