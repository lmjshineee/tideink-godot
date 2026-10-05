extends "res://tests/godot/helpers/creative_fixture.gd"
var preview:Node3D
var home:=Vector3(0,.05,-25)
func _initialize() -> void:call_deferred("_run")
func ready(kind:String) -> void:
	game.items.equip(walker,kind);game.items.state(walker).cooldowns[kind]=0;combat.ink_amount=100;combat.special_active="";combat.action_lock=0
func _run() -> void:
	await prepare(5,"tidewater");preview=game.items.placement_preview
	for actor in game.all_actors():
		if actor==walker:continue
		if actor==bot:game.bot_respawn=999
		else:actor.respawn_time=999
	walker.global_position=home;walker.update_form(false);walker.velocity=Vector3(1,0,0);game.pointer_locked=true
	var camera:Camera3D=walker.get_node("Camera3D");camera.global_position=home+Vector3(0,1.4,-2);camera.look_at(home+Vector3(0,0,7));camera.current=true
	await physics_frame;ready("bomb")
	var before:float=game.ink.coverage(0)
	var prediction:Dictionary=preview.predict_bomb(walker)
	expect(prediction.valid and prediction.points.size()>5,"bomb preview reaches a real terrain contact, bounce and timed explosion")
	expect(combat.ink_amount==100 and combat.bombs.is_empty() and game.ink.coverage(0)==before,"prediction never throws, spends or paints")
	combat.tick(1.0/30,false,false,true);preview.tick(.1)
	expect(preview.visible and preview.batch.visible_instance_count>0 and preview.label.text.contains("预计爆点"),"held sub button displays predicted blast and physical arc")
	combat.tick(1.0/30,false,false,false)
	expect(combat.bombs.size()==1 and combat.ink_amount<100,"release performs exactly one actual bomb cast")
	var bomb:Dictionary=combat.bombs[0];var delta:=1.0/float(Engine.physics_ticks_per_second)
	for i in range(300):
		combat._update_bombs(delta)
		if combat.bombs.is_empty():break
	expect(combat.bombs.is_empty() and bomb.position.distance_to(prediction.point)<.001,"actual throw including inherited movement, bounces and fuse explodes at prediction")
	walker.velocity=Vector3.ZERO;ready("bomb")
	var blocker:=wall(home+Vector3(0,1,2.5),Vector3(4,2.5,.1));await physics_frame
	prediction=preview.predict_bomb(walker)
	expect(prediction.valid,"wall collision is reflected in a valid rebound prediction")
	game.items.use(walker);bomb=combat.bombs[0]
	for i in range(300):
		combat._update_bombs(delta)
		if combat.bombs.is_empty():break
	expect(bomb.position.distance_to(prediction.point)<.001 and bomb.position.z<home.z+2.5,"thin wall blocks real and predicted throw at the same side")
	blocker.queue_free();await physics_frame
	for kind in ["mine","sonar","supply_box"]:
		ready(kind);preview.tick(.1);var checked:Dictionary=preview.query(walker,kind)
		expect(preview.visible and checked.valid,"valid "+kind+" preview uses real standing clearance")
		var tank:float=combat.ink_amount;var serial:int=game.items.mines.serial
		for i in range(10):preview.query(walker,kind)
		expect(combat.ink_amount==tank and game.items.mines.serial==serial,"reading "+kind+" placement is mutation-free")
		expect(game.items.use(walker),"actual "+kind+" cast accepts the preview location")
		var placed:Vector3
		if kind=="mine":placed=game.items.mines.mines.values()[0].point
		elif kind=="sonar":placed=game.items.sonar.stations.values()[0].point
		else:placed=game.items.supply.boxes.values()[0].point
		expect(placed.distance_to(checked.point)<.001,"actual "+kind+" placement matches its marker")
		game.items.mines.clear_all();game.items.sonar.clear_all();game.items.supply.clear_all();await physics_frame
	ready("mine");combat.ink_amount=0;preview.tick(.1)
	expect(preview.material.albedo_color==Color("ff5c72"),"insufficient resource marks unavailable placement red")
	combat.ink_amount=100;game.items.state(walker).cooldowns.mine=3;preview.tick(.1)
	expect(preview.label.text.contains("冷却"),"cooldown cannot appear as an available placement")
	game.items.state(walker).cooldowns.mine=0
	var roof:=wall(home+Vector3(0,.9,0),Vector3(2,.1,2));await physics_frame
	expect(not preview.query(walker,"mine").valid,"thin ceiling denies full standing clearance instead of marking an upper floor")
	roof.queue_free();await physics_frame
	ready("beacon");game.paint_at_world(home+Vector3.UP*.05,1,3,0);await physics_frame
	expect(not preview.query(walker,"beacon").valid,"enemy-ink beacon location is rejected in the preview")
	game.paint_at_world(home+Vector3.UP*.05,0,3,0);await physics_frame
	var beacon:Dictionary=preview.query(walker,"beacon")
	expect(beacon.valid and game.items.use(walker),"beacon marker and actual cast share own-ink landing gate")
	if not game.deployment.beacons.is_empty():expect(game.deployment.beacons[-1].point.distance_to(beacon.point)<.001,"beacon uses its marked flank position")
	for kind in ["echo_decoy","intel_mist"]:
		ready(kind);var checked:Dictionary=preview.query(walker,kind)
		expect(checked.valid and game.items.use(walker),"aimed "+kind+" preview agrees with actual cast")
		var point:Vector3=game.items.decoys.decoys.values()[0].point if kind=="echo_decoy" else game.items.mist.volumes[0].point
		expect(point.distance_to(checked.point)<.001,"aimed "+kind+" appears at the preview point")
	preview.tick(.1);game.paused=true;preview.tick(.1);expect(not preview.visible,"pause hides placement hints")
	game.paused=false;game.player_respawn=4;preview.tick(.1);expect(not preview.visible,"death hides placement hints")
	game.player_respawn=0;game.phase="results";preview.tick(.1);expect(not preview.visible,"end of round hides hints")
	await finish("bomb bounce/fuse/motion prediction versus actual cast, thin walls, six shared deployment queries, resources and pause/death/end lifecycle")
