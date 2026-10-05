extends "res://tests/godot/helpers/creative_fixture.gd"
var home:=Vector3(12,.05,-23)
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	await prepare(5,"tidewater")
	var companions:Node3D=game.items.buddies
	for actor in game.all_actors():
		if actor==walker:continue
		if actor==bot:game.bot_respawn=999
		else:actor.respawn_time=999
	walker.global_position=home;walker.update_form(false)
	var camera:Camera3D=walker.get_node("Camera3D");camera.global_position=home+Vector3(0,1.4,-2);camera.look_at(home+Vector3(0,.9,8));camera.current=true;game.pointer_locked=true
	game.items.equip(walker,"ink_buddy");combat.ink_amount=44
	expect(not game.items.use(walker) and companions.buddies.is_empty() and game.items.state(walker).cooldowns.ink_buddy==0,"insufficient ink does not spawn or start cooldown")
	combat.ink_amount=100
	var blocked:=wall(home+Vector3(0,1.2,.7),Vector3(4,3,.15));await physics_frame
	expect(not game.items.use(walker) and combat.ink_amount==100,"blocked capsule launch is rejected before spending")
	blocked.queue_free();await physics_frame
	var before:float=game.ink.coverage(0)
	var trajectory:PackedVector3Array=companions.trajectory(walker)
	for i in range(20):game.items.hud_status();companions.trajectory(walker)
	expect(trajectory.size()>2 and combat.ink_amount==100 and game.ink.coverage(0)==before and companions.buddies.is_empty(),"trajectory and HUD preview cannot paint, spawn or spend")
	expect(game.items.use(walker),"valid creature launch")
	var b:Dictionary=companions.buddies.values()[0]
	for mode in ["search","chase","flying","windup","bite"]:
		b.visual.animate(.1,mode,1,.1)
		var bounds:AABB=b.visual.mouth.global_transform*b.visual.mouth.mesh.get_aabb()
		expect(bounds.size.y<.2,"animated "+mode+" mouth stays inside the creature face")
	game.items.state(walker).cooldowns.ink_buddy=0
	expect(not game.items.use(walker) and combat.ink_amount==55 and companions.buddies.size()==1,"one-per-owner cap survives a fixture cooldown reset")
	game.items.state(walker).cooldowns.ink_buddy=18
	var status:Dictionary=game.items.hud_status()
	expect(status.state=="active" and status.detail.contains("墨仔"),"HUD shows actual living creature, health and lifetime")
	game.paused=true;var life:float=b.time;var at:Vector3=b.body.global_position;companions.tick(2)
	expect(b.time==life and b.body.global_position==at,"pause freezes lifespan and physical movement")
	game.paused=false
	game.damage_player(1000,false,bot,"shooter")
	game.damage_player(1000,false,bot,"shooter")
	expect(companions.buddies.is_empty() and game.items.state(walker).cooldowns.ink_buddy==18,"real owner death removes creature without resetting cooldown")
	game.player_respawn=0;game.player_health=120;game.items.on_respawn(walker)
	game.items.equip(walker,"bomb");game.items.equip(walker,"ink_buddy");game.items.tick(1)
	expect(game.items.state(walker).cooldowns.ink_buddy==17 and not game.items.use(walker),"respawn and reroll retain remaining per-kind cooldown")
	# AI cannot summon toward an unknown enemy. Both sides use the same cast path.
	game.bot_respawn=0;game.bot_health=120;bot.health=120;bot.global_position=home+Vector3(0,0,7);bot.ink_amount=100
	game.items.equip(bot,"ink_buddy");game.intel.clear_all()
	walker.global_position=Vector3(70,40,70);await physics_frame;game.items.tick(.01)
	expect(companions.buddies.is_empty() and bot.ink_amount==100,"AI cannot summon toward hidden opponent coordinates")
	walker.global_position=home;await physics_frame;game.intel.refresh();game.items.tick(.01)
	expect(companions.buddies.size()==1 and bot.ink_amount==55,"opposing AI summons after a real shared observation")
	if not companions.buddies.is_empty():
		b=companions.buddies.values()[0]
		expect(b.team==1 and b.body.collision_layer==2048,"opposing creature has its actual team damage layer")
		b.time=.01;companions.tick(.02)
		expect(companions.buddies.is_empty(),"lifetime expiry cleans collision and visual")
	game.items.state(bot).cooldowns.ink_buddy=0;bot.ink_amount=100;game.intel.refresh()
	expect(game.items.use(bot),"second legitimate cast after reset fixture")
	companions.buddies.values()[0].body.global_position.y=-20;companions.tick(.01)
	expect(companions.buddies.is_empty(),"falling into water cleans creature")
	game.items.state(bot).cooldowns.ink_buddy=0;bot.ink_amount=100;game.intel.refresh();game.items.use(bot)
	game._finish_round()
	expect(companions.buddies.is_empty() and not companions.preview.visible,"natural round cleanup removes summons and preview")
	var icon:Texture2D=preload("res://src/ui/loadout_icons.gd").icon("item","ink_buddy")
	expect(icon!=null and icon.resource_path.ends_with("item-ink_buddy.svg") and icon.get_width()==128,"original creature icon loads instead of a fallback")
	expect(game.frontend.item_buttons.has("ink_buddy") and game.items.KINDS.size()==11,"new creature is in the real selection and random pool")
	await finish("creature resources/cap/readonly trajectory/HUD, pause/death/reroll CD, observed AI, lifetime/water/round cleanup and original selectable icon")
