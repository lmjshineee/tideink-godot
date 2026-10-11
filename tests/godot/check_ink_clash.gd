extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void:call_deferred("_run")
func clear_shots() -> void:
	for shot in combat.projectiles:shot.visual.queue_free()
	combat.projectiles.clear();combat.bow.clear_all()
func shot(at:Vector3,velocity:Vector3,team:int,kind:String="shooter") -> void:
	combat._spawn_projectile(kind,at,velocity,combat.weapons.blaster if kind=="blaster" else combat.weapons.shooter,team,walker if team==0 else bot)
func _run() -> void:
	await prepare(5,"tidewater")
	walker.global_position=Vector3(-30,40,0);bot.global_position=Vector3(30,40,0)
	var hp:float=game.player_health;var ink:float=combat.ink_amount;var points:float=combat.special_points
	shot(Vector3(0,40,0),Vector3.BACK*34,0);shot(Vector3(0,40,2),Vector3.FORWARD*34,1)
	var total:int=combat.ink_clash.total
	combat._update_projectiles(.1)
	expect(combat.projectiles.is_empty() and combat.ink_clash.total==total+1,"head-on projectiles cancel despite crossing more than their diameter in one tick")
	expect(game.player_health==hp and combat.ink_amount==ink and combat.special_points==points,"clash creates no damage, refund or special charge")
	shot(Vector3(0,40,0),Vector3.BACK*34,0);shot(Vector3(0,40,2),Vector3.FORWARD*34,0)
	combat._update_projectiles(.1);expect(combat.projectiles.size()==2,"allied ink never cancels")
	clear_shots()
	shot(Vector3(-1,40,0),Vector3.RIGHT*20,0);shot(Vector3(0,40,-1),Vector3.BACK*10,1)
	combat._update_projectiles(.1);expect(combat.projectiles.size()==2,"spatially crossing paths at different times remain independent")
	clear_shots()
	shot(Vector3(0,40,0),Vector3.BACK*34,0);shot(Vector3(0,40,2),Vector3.FORWARD*34,1);shot(Vector3(.1,40,2),Vector3.FORWARD*34,1)
	combat._update_projectiles(.1);expect(combat.projectiles.size()==1,"one shot cannot cancel two enemy shots")
	clear_shots()
	var obstacle:=wall(Vector3(0,40,1),Vector3(2,2,.6));await physics_frame
	shot(Vector3(0,40,0),Vector3.BACK*34,0);shot(Vector3(0,40,2),Vector3.FORWARD*34,1)
	total=combat.ink_clash.total;combat._update_projectiles(.1)
	expect(combat.ink_clash.total==total,"a wall resolves before any collision behind its surface")
	obstacle.queue_free();await physics_frame;clear_shots()
	shot(Vector3(0,40,0),Vector3.BACK*34,0);shot(Vector3(0,40,2),Vector3.FORWARD*34,1,"blaster")
	combat._update_projectiles(.1);expect(combat.projectiles.is_empty(),"primary blaster is cancelled without a damaging explosion")
	clear_shots()
	var w:Dictionary=combat.weapons.bow
	bot.global_position=Vector3(0,40,2)
	expect(combat.bow.fire(bot,Vector3(0,41.05,-10),1),"actual bow creates primary arrows")
	bot.global_position=Vector3(30,40,0)
	shot(Vector3(0,41.05,0),Vector3.BACK*34,0)
	total=combat.ink_clash.total;combat._update_projectiles(.1)
	expect(combat.ink_clash.total>total and combat.bow.arrows.size()==2,"primary arrow also participates in one-for-one cancellation")
	await finish("swept opposing ink collision, friendly/time/wall negatives, one-for-one budget, cancelled explosion and primary arrow integration")
