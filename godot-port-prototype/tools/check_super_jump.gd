extends SceneTree
const Setup:=preload("res://match_setup.gd")
var failed:=false
func _initialize() -> void:call_deferred("_run")
func expect(ok:bool,label:String) -> void:
	if not ok:failed=true;printerr("FAIL: ",label)
func _run() -> void:
	Setup.team_size=5;Setup.screen="setup";Setup.selected_perk="balanced"
	for map_id in ["tidewater","prism_gallery"]:
		Setup.map_id=map_id;Setup.random_map=false
		var game:Node3D=(load("res://tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game);await physics_frame;game.set_physics_process(false);game._start_round()
		var walker:CharacterBody3D=game.get_node("World/Walker");walker.set_physics_process(false)
		for actor in game.all_actors():
			game.perks.choices[actor.get_instance_id()]="balanced"
			if actor!=walker:actor.global_position=Vector3(60,40,60)
		var ally:Node3D=game.extra_bots[0]
		for actor in game.extra_bots:
			if game.actor_team(actor)==0:ally=actor;break
		ally.global_position=Vector3(-8.5,6.05,-3) if map_id=="prism_gallery" else Vector3(0,.05,-24);ally.team_mover.velocity=Vector3.ZERO;ally.respawn_time=0;ally.health=120
		await physics_frame
		var d:Node3D=game.deployment;var key:String="actor:%d" % game.actor_id(ally)
		expect(not d._destination(key).is_empty(),map_id+" teammate has clear ground on its current level")
		game.player_health=84;game.get_node("Combat").ink_amount=21;game.player_invuln=0
		var original:Vector3=walker.global_position
		d.select_destination("actor:%d" % game.actor_id(game.get_node("Bot")))
		expect(not d.live_jump,"enemy cannot be a jump destination")
		d.select_destination(key);d.tick_live(.4)
		expect(d.live_jump and not d.flying and not walker.active,"live jump has vulnerable departure windup")
		d.cancel_selection();expect(not d.active and walker.active and walker.global_position.is_equal_approx(original),"departure can cancel without teleport")
		d.select_destination(key);d.tick_live(.4);game.damage_player(30,false,game.get_node("Bot"),"shooter")
		expect(game.player_health==54,"windup does not make player invincible")
		d.tick_live(.65);var snapshot:Vector3=d.target
		expect(d.flying and d.marker.visible and walker.global_position.y>original.y,"jump arc and public landing marker")
		d.tick_live(d.flight_duration+.1)
		expect(not d.live_jump and walker.active and walker.global_position.distance_to(snapshot)<.15,"lands adjacent to teammate with clear geometry")
		expect(game.player_health==54 and game.get_node("Combat").ink_amount==21,"live jump never replenishes HP or ink")
		if map_id=="prism_gallery":expect(walker.global_position.y>5.8,"high platform stays on teammate's six-metre layer")
		d.cooldown=0;d.select_destination(key);ally.respawn_time=4;d.tick_live(.1)
		expect(not d.live_jump and walker.active,"target death cancels before takeoff")
		ally.respawn_time=0;d.cooldown=0
		game.damage_player(1000,false,game.get_node("Bot"),"shooter");d.select_destination(key)
		expect(d.queued and not d.flying and not game.respawn_ready and d.selected_key==key,"choose teammate during countdown with one action")
		ally.respawn_time=4;game._update_player_respawn(4.1);game._update_player_respawn(3)
		expect(game.player_respawn==0 and walker.global_position.distance_to(d.base_position())<.3,"invalid countdown target falls back to base without trapping respawn")
		ally.respawn_time=0;walker.global_position=ally.global_position+Vector3(3,0,0);await physics_frame
		game.paint_at_world(walker.global_position+Vector3.UP*.06,0,4,.3)
		game.items.equip(walker,"beacon");game.get_node("Combat").ink_amount=100
		expect(game.items.use(walker),map_id+" places beacon on friendly painted platform")
		expect(d.beacons.size()==1 and game.get_node("Combat").ink_amount==65,"beacon costs 35 ink and belongs to team")
		expect(not game.items.use(walker),"beacon cooldown prevents repeated placement")
		if d.beacons.size()==1:
			var beacon:Dictionary=d.beacons[0];var beacon_key:String="beacon:%d" % beacon.id
			game.items.equip(walker,"shield");game.items.on_respawn(walker)
			expect(game.items.state(walker).cooldowns.beacon>0 and d.beacons.size()==1,"equipment reroll and death do not erase beacon or CD")
			expect(not d._destination(beacon_key).is_empty(),"friendly beacon is a legal jump target")
			d.cooldown=0;d.select_destination(beacon_key);d.tick_live(1.01);d.tick_live(3)
			expect(beacon.uses==1,"successful landing consumes exactly one beacon use")
			game.paint_at_world(beacon.point+Vector3.UP*.06,1,3,.6);d.advance_beacons(.2)
			expect(not beacon.available and d._destination(beacon_key).is_empty(),"enemy ink disables covered beacon")
			d.advance_beacons(46);expect(d.beacons.is_empty(),"expired beacon removed from scene and choices")
		print("AUDIT: ",map_id," live cancellation/damage/landing, queued death fallback and beacon ink/CD/uses/invalidation")
		game.queue_free();await process_frame
	if not failed:print("PASS: one-action teammate and beacon jumps, countdown choice, vulnerable cancelable departure, geometry/height recheck, HP/ink preserved, marker and beacon lifecycle")
	quit(1 if failed else 0)
