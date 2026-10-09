extends "res://tests/godot/helpers/creative_fixture.gd"

const STEP := 1.0 / 30.0
const SurfaceInk := preload("res://src/world/surface_ink.gd")
var data: Dictionary

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	await prepare(5,"tidewater")
	data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater_surfaces.json"))
	Engine.time_scale=4;Engine.physics_ticks_per_second=120
	for team in [0,1]:
		var actor: Node3D = game.extra_bots[0] if team==0 else bot
		game.comeback.reset()
		await _place(actor,Vector3(0,.05,-20))
		_paint(actor.global_position,team,1.2)
		actor.ink_amount=10;actor.last_fire_time=0
		var position:Vector3=actor.global_position
		var counts: Array=game.ink.counts.duplicate()
		await _step(actor)
		expect(actor.get_meta("friendly_swimming",false) and game.intel.concealed(actor),"both teams enter real friendly-ink squid form")
		expect(is_equal_approx(actor.team_mover.get_child(0).shape.height,.54),"refill form uses the squid collision capsule")
		expect(is_equal_approx(actor.ink_amount,11.4),"friendly refill uses the existing 42/s rate, including immediately after firing")
		for i in 15:await _step(actor)
		expect(actor.global_position.distance_to(position)<.1 and game.ink.counts==counts,"refill stops movement and all passive painting")
		expect(actor.ink_brain.active,"20-to-60 percent hysteresis retains the pause past the entry threshold")
		var enemy: Node3D=bot if team==0 else walker
		enemy.global_position=position+Vector3(0,0,3)
		game.intel.clear_all()
		expect(not game.intel.can_see(enemy,actor),"friendly submerged bot is concealed beyond proximity")
		var high: Dictionary=combat._segment_team_hit(position+Vector3(-2,1.15,0),position+Vector3(2,1.15,0),.01,1-team)
		var low: Dictionary=combat._segment_team_hit(position+Vector3(-2,.25,0),position+Vector3(2,.25,0),.01,1-team)
		expect(high.is_empty() and not low.is_empty(),"actual projectile collision agrees with the submerged capsule height")
		actor.select_weapon("dualie")
		expect(not game.mobility.request(actor,Vector3.RIGHT),"submerged bot cannot begin a dodge")
		actor.select_weapon("shooter")
		var projectiles:int=combat.projectiles.size()
		counts=game.ink.counts.duplicate()
		await _step(actor)
		expect(combat.projectiles.size()==projectiles and game.ink.counts==counts,"visible enemy cannot make refilling bot fire or paint")
		for weapon_id in game.weapon_order:
			actor.select_weapon(weapon_id);actor.ink_amount=30
			counts=game.ink.counts.duplicate()
			await _step(actor)
			expect(is_equal_approx(actor.ink_amount,31.4) and game.ink.counts==counts,"every primary weapon pauses spending during refill: "+weapon_id)
		actor.select_weapon("shooter")
		enemy.global_position=Vector3(100,40,100)
		game.items.state(actor).cooldowns.bomb=4
		game.items.tick(.5)
		expect(is_equal_approx(game.items.state(actor).cooldowns.bomb,3.5),"item cooldown still ticks while refilling")
		actor.ink_amount=game.actor_ink_max(actor)*.6
		await _step(actor)
		expect(not actor.ink_brain.active and not actor.get_meta("friendly_swimming",true),"ready tank surfaces and leaves refill state")
		await _place(actor,Vector3(0,.05,-20))
		actor.ink_amount=10;actor.last_fire_time=99
		counts=game.ink.counts.duplicate()
		await _step(actor)
		expect(not actor.get_meta("friendly_swimming",true) and is_equal_approx(actor.ink_amount,10.3),"dry ground only receives the existing human refill rate")
		expect(game.ink.counts==counts,"no friendly patch fallback stops passive spending")
		_paint(actor.global_position,1-team,1.2)
		actor.ink_amount=10
		await _step(actor)
		expect(not actor.get_meta("friendly_swimming",true) and actor.ink_amount<11,"enemy ink cannot grant fast refill")
		game.perks.choices[actor.get_instance_id()]="enemy_swim"
		actor.ink_amount=10
		await _step(actor)
		expect(not game.perks.bot_swimming(actor) and actor.ink_amount>10 and actor.ink_amount<11,"low enemy-swim talent surfaces to refill without borrowing enemy ink")
		game.perks.choices[actor.get_instance_id()]="balanced"
		# A reachable patch is selected by real CPU ownership and the nav graph.
		await _place(actor,Vector3(0,.05,-20))
		var patch:=_near_node(actor,3.0,5.0)
		expect(patch!=Vector3.INF,"local reachable refill test point exists")
		_paint(patch,team,1.25)
		actor.ink_amount=10;actor.last_fire_time=0
		var swam:=false
		for i in 80:
			await _step(actor)
			if actor.get_meta("friendly_swimming",false):swam=true;break
		expect(swam and actor.global_position.distance_to(patch)<1.5,"low bot physically reaches a nearby friendly patch and submerges")
		print("AUDIT: refill team=",team," reached=",actor.global_position," goal=",patch," ink=",actor.ink_amount)
		# Repainting under a stopped squid must pop it out on the next decision.
		_paint(actor.global_position,1-team,1.5)
		await _step(actor)
		expect(not actor.get_meta("friendly_swimming",true),"enemy repaint invalidates the real refill support immediately")
		await _place(actor,Vector3(0,.05,-20))
		_paint(actor.global_position,team,1.2);actor.ink_amount=10
		await _step(actor)
		game.mobility.state(actor).recover=.2
		await _step(actor)
		expect(not actor.get_meta("friendly_swimming",true) and actor.ink_amount<13,"dodge recovery excludes submerged fast refill")
		game.mobility.cancel(actor)
		game.bot_specials.state(actor).active=true
		await _step(actor)
		expect(not actor.get_meta("friendly_swimming",true),"active special excludes refill form")
		game.bot_specials.on_death(actor)
		# A friendly node in a disconnected graph is not a teleport/refill source.
		await _place(actor,Vector3(0,.05,-20))
		_paint(patch,team,1.25);actor.ink_amount=10;actor.last_fire_time=99
		var graph:AStar3D=game.navigation.graphs[team]
		var enabled:Array[int]=[]
		for id in graph.get_point_ids():
			if not graph.is_point_disabled(id):enabled.append(id);graph.set_point_disabled(id,true)
		position=actor.global_position
		await _step(actor)
		expect(actor.global_position.distance_to(position)<.1 and not actor.get_meta("friendly_swimming",true) and is_equal_approx(actor.ink_amount,10.3),"unreachable own-ink nodes cannot move or remotely refill the bot")
		for id in enabled:graph.set_point_disabled(id,false)
		actor.reset()
		expect(not actor.ink_brain.active and not actor.get_meta("friendly_swimming",true),"respawn reset clears refill decision and form")
		actor.global_position=Vector3(100+team*3,40,100)
	# Layered surfaces and grates cannot borrow ownership from another floor.
	await _place(bot,Vector3(0,.05,-20))
	_paint(bot.global_position,bot.team,2)
	var deck:=wall(Vector3(0,.6,-20),Vector3(4,.2,4));deck.set_meta("paintable",false)
	await physics_frame
	bot.global_position=Vector3(0,.75,-20)
	expect(bot.floor_ink_owner()==-1,"unpaintable raised support cannot read friendly ink underneath")
	deck.queue_free();await physics_frame
	var grate:=wall(Vector3(0,.2,-20),Vector3(4,.1,4));grate.collision_layer=8
	await physics_frame
	bot.global_position=Vector3(0,.3,-20)
	expect(bot.floor_ink_owner()==-1,"grate contact stops the support ray before lower ink")
	grate.queue_free();await physics_frame
	bot.global_position=Vector3(0,2,-20)
	expect(bot.floor_ink_owner()==-1,"airborne bot cannot borrow ground ownership")
	Engine.time_scale=1;Engine.physics_ticks_per_second=30
	await finish("both-team low-ink seek/stop/refill/resume, real form/visibility/hitbox, dry/enemy/repaint/layer/grate negatives and cooldown/reset lifecycle")

func _place(actor: Node3D, at: Vector3) -> void:
	game.ink=SurfaceInk.new(data);walker.ink=game.ink
	for other in game.all_actors():
		if other!=actor:other.global_position=Vector3(100+game.actor_id(other)*3,40,100)
	actor.reset();actor.global_position=at;actor.select_weapon("shooter")
	actor.ink_brain.reset();actor.route=PackedVector3Array([at]);actor.route_index=1;actor.route_purpose="patrol";actor.repath_time=999
	actor.team_mover.position=Vector3.ZERO;actor.team_mover.velocity=Vector3.ZERO
	for i in 3:
		await physics_frame
		actor.team_mover.global_position=actor.global_position;actor.team_mover.velocity=Vector3.DOWN
		actor.team_mover.move_and_slide();actor.global_position=actor.team_mover.global_position;actor.team_mover.position=Vector3.ZERO

func _paint(at: Vector3, team: int, radius: float) -> void:
	game.paint_at_world(at+Vector3.UP*.08,team,radius,.41,Vector3.ZERO,0,walker if team==0 else bot)

func _step(actor: Node3D) -> void:
	await physics_frame
	game.painting_actor=actor;game.bot_painting=true
	actor.tick(STEP)
	game.painting_actor=null;game.bot_painting=false

func _near_node(actor: Node3D, near: float, far: float) -> Vector3:
	var graph:AStar3D=game.navigation.graphs[actor.team]
	for node in game.navigation.nodes:
		if not graph.has_point(int(node.id)):continue
		var point:=graph.get_point_position(int(node.id))
		var distance:=point.distance_to(actor.global_position)
		if distance<near or distance>far or absf(point.y-actor.global_position.y)>.2:continue
		var route:PackedVector3Array=game.navigation.route(actor.global_position,point,actor.team)
		if route.size()>1:return point
	return Vector3.INF
