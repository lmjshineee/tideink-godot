extends "res://tools/creative_fixture.gd"
var supply: Node3D
var home := Vector3(0,.05,-20)
func _initialize() -> void: call_deferred("_run")
func advance(seconds: float) -> void:
	for i in ceili(seconds/.01): supply.tick(.01)
func deploy() -> Dictionary:
	supply.clear_all(); walker.global_position = home; walker.update_form(false); combat.ink_amount = 100; combat.last_fire_time = 99; combat.action_lock = 0; combat.charging = false; combat.special_active = ""
	game.items.equip(walker,"supply_box"); game.items.state(walker).cooldowns.supply_box = 0
	bot.global_position = Vector3(70,40,70); game.bot_health = 120; bot.health = 120; game.player_last_damage = 99
	await physics_frame
	expect(game.items.use(walker),"supply places on actual supported floor")
	combat.last_fire_time = 99
	return supply.boxes.values()[0] if not supply.boxes.is_empty() else {}
func _run() -> void:
	await prepare(); supply = game.items.supply
	for ch in "敌墨潜游接力补给领取": expect(game.tactics.item_label.get_theme_font("font").has_char(ch.unicode_at(0)),"tactical HUD uses bundled CJK glyph "+ch)
	walker.global_position = home; game.items.equip(walker,"supply_box"); combat.ink_amount = 39; await physics_frame
	expect(not game.items.use(walker) and game.items.state(walker).cooldowns.supply_box == 0,"insufficient ink preserves CD")
	var b: Dictionary = await deploy()
	if b.is_empty(): await finish("supply placement"); return
	expect(combat.ink_amount == 60 and b.health == 60 and b.stock == 2 and game.items.state(walker).cooldowns.supply_box == 20,"real resource/health/stock/cooldown")
	combat.ink_amount = 30; var meter: float = combat.special_points
	advance(.3); expect(combat.ink_amount == 30 and not supply.channel_text(walker).is_empty(),"stationary hold begins readable channel without instant refill")
	walker.global_position.x += .15; await physics_frame; advance(.3); expect(combat.ink_amount == 30,"movement resets channel")
	advance(.31); expect(combat.ink_amount == 65 and b.stock == 1 and combat.action_lock >= .25,"completed real channel returns one pack and locks attack briefly")
	combat.action_lock = 0; combat.last_fire_time = 99; advance(1)
	expect(combat.ink_amount == 65 and b.stock == 1 and combat.special_points == meter and game.player_health == 120,"same actor cannot repeatedly draw or heal/charge")
	bot.global_position = b.point+Vector3(.8,.05,0); bot.target_actor = null; bot.set_meta("decoy_target",0); bot.set_meta("enemy_swimming",false); bot.last_fire_time = 99; bot.ink_amount = 20; game.bot_last_damage = 99
	await physics_frame; advance(.61)
	expect(bot.ink_amount == 55 and supply.stolen_total == 1 and supply.boxes.is_empty(),"enemy can steal final pack and exhausted box disappears")
	# Two teammates race for two physical packs; the third receives none.
	b = await deploy(); combat.ink_amount = 20
	var mates: Array[Node3D] = []
	for actor in game.all_actors():
		if actor != walker and game.actor_team(actor) == 0:
			mates.append(actor)
			if mates.size() == 2: break
	for i in mates.size():
		mates[i].global_position = b.point+Vector3(.7*(i+1),.05,0); mates[i].target_actor = null; mates[i].ink_amount = 20; mates[i].last_fire_time = 99; mates[i].last_damage = 99; mates[i].set_meta("action_lock",0); mates[i].set_meta("enemy_swimming",false)
	await physics_frame; var received: int = supply.received_total; advance(.61)
	expect(supply.received_total == received+2 and supply.boxes.is_empty(),"simultaneous allied channels never duplicate two-pack stock")
	var unchanged := 0
	for actor in mates:
		if actor.ink_amount == 20: unchanged += 1
		actor.global_position = Vector3(70,40,70)
	expect(unchanged == 1 and combat.ink_amount == 55,"owner and one teammate take exactly two packs; third receives none")
	b = await deploy(); combat.ink_amount = 92; advance(1); expect(b.stock == 2,"near-full tanks do not waste stock")
	combat.ink_amount = 80; advance(.61); expect(combat.ink_amount == 100 and b.stock == 1,"partial pack respects real capacity")
	b = await deploy(); combat.ink_amount = 20; advance(.3); combat.last_fire_time = 0; advance(.6); expect(combat.ink_amount == 20,"firing resets and prevents refill channel")
	combat.last_fire_time = 99; advance(.3); game.player_last_damage = 0; advance(.6); expect(combat.ink_amount == 20,"incoming damage interrupts channel")
	game.player_last_damage = 99; walker.update_form(true); advance(.7); expect(combat.ink_amount == 20,"squid cannot receive")
	walker.update_form(false); walker.global_position.y += 1.2; await physics_frame; advance(.7); expect(combat.ink_amount == 20,"unsupported airborne actor cannot receive")
	walker.global_position = b.point+Vector3(0,1.25,0); var deck := wall(b.point+Vector3(0,1.1,0),Vector3(5,.1,5)); await physics_frame
	advance(.7); expect(combat.ink_amount == 20,"thin floor blocks other-layer pickup despite close XZ")
	deck.queue_free(); await physics_frame
	walker.global_position = b.point+Vector3(1,.05,0); var barrier := wall(b.point+Vector3(.5,1,0),Vector3(.1,3,4)); await physics_frame
	advance(.7); expect(combat.ink_amount == 20,"thin wall blocks nearby pickup")
	supply.damage_area(walker.global_position+Vector3.UP*.25,2,100,1); expect(supply.boxes.size() == 1,"wall blocks device splash damage")
	barrier.queue_free(); await physics_frame
	expect(not supply.damage_hit({"collider":b.visual},100,0),"friendly fire cannot break own supply")
	walker.global_position = b.point+Vector3(4,.05,0); bot.global_position = b.point+Vector3(0,.05,-4); await physics_frame
	combat._fire_charger_ray(combat.weapons.charger,1,bot.global_position+Vector3.UP,(b.point+Vector3.UP*.25-bot.global_position-Vector3.UP).normalized(),1,bot)
	expect(supply.boxes.is_empty() and supply.channels.is_empty(),"actual hostile ray destroys box and cancels all channels")
	b = await deploy(); combat.ink_amount = 20; advance(.3); game.items.on_death(walker); game.items.equip(walker,"bomb")
	expect(supply.boxes.size() == 1 and supply.channels.is_empty() and game.items.state(walker).cooldowns.supply_box == 20,"death cancels channel while preserving box and CD")
	var first: int = b.id; game.items.equip(walker,"supply_box"); game.items.state(walker).cooldowns.supply_box = 0; combat.ink_amount = 100
	expect(game.items.use(walker) and supply.boxes.size() == 1 and not supply.boxes.has(first),"new box replaces owner old box")
	supply.tick(14.1); expect(supply.boxes.is_empty(),"expiry removes unused box")
	b = await deploy(); walker.global_position = Vector3(70,40,70); bot.global_position = b.point+Vector3(4,.05,0); bot.ink_amount = 20; bot.target_actor = null; bot.last_fire_time = 99
	await physics_frame; var wanted: Dictionary = supply.destination(bot); expect(not wanted.is_empty(),"visible enemy supplies can guide low-ink bot")
	barrier = wall(b.point+Vector3(2,1,0),Vector3(.1,3,5)); await physics_frame
	expect(supply.destination(bot).is_empty(),"bot cannot know enemy box through wall")
	barrier.queue_free(); await physics_frame; game.items.equip(bot,"supply_box"); bot.ink_amount = 55; bot.set_meta("action_lock",0); game.items.state(bot).cooldowns.supply_box = 0; game.intel.clear_all()
	game.items.tick(.01); expect(supply.casts_total >= 2 and bot.ink_amount == 15,"low-ink AI can deploy support without inventing enemy contact")
	game._finish_round(); expect(supply.boxes.is_empty() and supply.channels.is_empty(),"round completion clears supply and channel state")
	await finish("relay supply resources/stock, timed stationary draw, once-per-actor/enemy stealing, capacity, motion/fire/damage/dive/air interruptions, wall/deck occlusion, real destructive ray, death/CD/owner limit/expiry, bot knowledge and cleanup")
