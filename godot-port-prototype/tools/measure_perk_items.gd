extends "res://tools/measure_match_loadouts.gd"

# Fixed kits and real 90-second rounds; never inject damage, positions or time in play.
const Perks := preload("res://tidewater_perks.gd")
const Items := preload("res://tidewater_items.gd")
const GROUP_MAPS := ["prism_gallery","terrace_garden"]

func _run() -> void:
	if DisplayServer.get_name()!="headless": printerr("FAIL: grouped measurement requires headless fixed-30Hz simulation"); quit(1); return
	report={"method":"Headless fixed-30Hz production scene, actual input and nine bots; all use shooter, fixed kits, natural 90-second timer and results. No damage/position/phase/clock injections during play.",
		"limits":"Exploratory sample, not a causal perk comparison or human balance verdict. One seed per map; bots share rounds and items, talents rotate across team/slot. Specials and comeback support remain enabled. Local enemy-swim player excluded from bot aggregates. No GPU/FPS/temperature evidence.",
		"conditions":{"weapon":"shooter","local_perk":"enemy_swim","maps":GROUP_MAPS,"items":Items.KINDS,"perks":Perks.ORDER,"reroll_bots":false,"physics_hz":30,"duration_seconds":90},"source_sha256":{},"rounds":[]}
	for name in DirAccess.get_files_at("res://"):
		if name.ends_with(".gd"): report.source_sha256[name]=FileAccess.get_sha256("res://"+name)
	var selected_case := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): selected_case=int(arg.trim_prefix("--case="))
	var output := "res://render-evidence/swim25-perk-items.json" if selected_case<0 else "res://render-evidence/swim25-perk-items-case-%d.json" % selected_case
	for case_index in GROUP_MAPS.size()*Items.KINDS.size():
		if selected_case>=0 and case_index!=selected_case: continue
		Setup.screen="setup"; Setup.map_id=GROUP_MAPS[case_index/Items.KINDS.size()]
		Setup.map_seed=701+100*int(case_index/Items.KINDS.size()); Setup.map_variant=0; Setup.random_map=false
		Setup.team_size=5; Setup.duration_index=0; Setup.selected_item=Items.KINDS[case_index%Items.KINDS.size()]
		Setup.selected_perk="enemy_swim"; Setup.reroll_bots=false
		Setup.pending_loadout={"player":"shooter","settings_path":"/private/tmp/inkwave-group-measurement-unused.cfg"}
		game=(load("res://tidewater_play.tscn") as PackedScene).instantiate(); root.add_child(game); current_scene=game
		await physics_frame; Engine.max_fps=0
		var walker: CharacterBody3D=game.get_node("World/Walker")
		var roster: Array=game.all_actors(); roster.sort_custom(func(a,b):return game.actor_id(a)<game.actor_id(b))
		var index := 0
		for actor in roster:
			game.items.equip(actor,Setup.selected_item)
			if actor!=walker:
				game.perks.choices[actor.get_instance_id()]=Perks.ORDER[(index+case_index)%Perks.ORDER.size()]
				actor.select_weapon("shooter"); index+=1
		game.selected_bot_weapon="shooter"; game.perks.apply_movement(); seed(Setup.map_seed)
		route.clear(); route_index=0; goal_index=0; last_jump=-5; last_death=0
		_tap(KEY_ENTER)
		var guard := 0
		while game.phase!="playing" and guard<180: await physics_frame; guard+=1
		if game.phase!="playing": printerr("FAIL: input/intro did not start grouped round"); quit(1); return
		var sample := {"case":case_index,"map":Setup.map_id,"seed":Setup.map_seed,"item":Setup.selected_item,"actors":[],"results":false}
		var observations := {}
		for actor in roster:
			observations[game.actor_id(actor)]={"alive_seconds":0.0,"travel_m":0.0,"position":actor.global_position,"height_max":actor.global_position.y,"enemy_swim_seconds":0.0,"enemy_ink_seconds":0.0,"item_cd_starts":0,"previous_cd":0.0}
		print("AUDIT: case ",case_index," ",Setup.map_id," / ",Setup.selected_item," / fixed shooter + rotated talents")
		var elapsed := 0.0
		var frames := 0
		while game.phase=="playing" and frames<2800:
			_drive(elapsed); await physics_frame
			var now: float=clampf(game.round_time-game.round_left,0,game.round_time)
			var dt := now-elapsed; elapsed=now; frames+=1
			for actor in roster:
				var o: Dictionary=observations[game.actor_id(actor)]
				if game.actor_alive(actor):
					o.alive_seconds+=dt
					var distance: float=actor.global_position.distance_to(o.position)
					if distance<2: o.travel_m+=distance
					o.height_max=maxf(o.height_max,actor.global_position.y)
					var hostile: bool=walker.grounded and walker.ink_owner==1 if actor==walker else actor.floor_ink_owner()==1-game.actor_team(actor)
					if hostile: o.enemy_ink_seconds+=dt
					var swimming: bool=walker.squid_form and hostile if actor==walker else actor.get_meta("enemy_swimming",false)
					if swimming: o.enemy_swim_seconds+=dt
				var kit: Dictionary=game.items.state(actor)
				var cd: float=kit.cooldowns.get(kit.kind,0)
				if cd>o.previous_cd+.1: o.item_cd_starts+=1
				o.previous_cd=cd; o.position=actor.global_position
		_release()
		if game.phase!="finish" or absf(elapsed-90)>.05: printerr("FAIL: grouped match did not finish naturally at 90 seconds"); quit(1); return
		guard=0
		while game.phase!="results" and guard<100: await physics_frame; guard+=1
		if game.phase!="results": printerr("FAIL: natural results missing"); quit(1); return
		sample.results=true; sample.simulation_seconds=elapsed; sample.physics_frames=frames
		sample.coverage=game.judged_coverage.duplicate(); sample.team_cumulative_turf_m2=game.turf_area.duplicate()
		sample.comeback_events=game.comeback.events; sample.wing_casts=game.wings.casts_total
		sample.decoy_fooled=game.items.decoys.fooled_total; sample.supply_received=game.items.supply.received_total
		var totals := [0.0,0.0]
		for actor in roster:
			var o: Dictionary=observations[game.actor_id(actor)]; var stats: Dictionary=actor.get_meta("match_stats").duplicate(true)
			totals[game.actor_team(actor)]+=float(stats.turf)
			if game.perks.kind(actor)!=("enemy_swim" if actor==walker else Perks.ORDER[(game.actor_id(actor)-2+case_index)%Perks.ORDER.size()]):
				printerr("FAIL: talent changed during grouped match"); quit(1); return
			var row := {"id":game.actor_id(actor),"team":game.actor_team(actor),"local_player":actor==walker,"weapon":game.selected_weapon if actor==walker else actor.weapon_id,"perk":game.perks.kind(actor),"item":game.items.state(actor).kind,"stats":stats,"special_casts":game.bot_specials.state(actor).casts if actor!=walker else null}
			for field in ["alive_seconds","travel_m","height_max","enemy_swim_seconds","enemy_ink_seconds","item_cd_starts"]: row[field]=o[field]
			sample.actors.append(row)
		for team in 2:
			if absf(totals[team]-float(game.turf_area[team]))>.01: printerr("FAIL: grouped match lost individual paint attribution"); quit(1); return
		report.rounds.append(sample)
		var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
		print("AUDIT: complete case ",case_index," / 90 seconds / coverage=",sample.coverage)
		for voice in game.sound.get_children():
			if voice.has_method("stop"): voice.stop()
		game.queue_free(); await process_frame; await process_frame
	if report.rounds.is_empty(): printerr("FAIL: selected case outside eighteen-case batch"); quit(1); return
	print("PASS: ",report.rounds.size()," natural 90-second grouped matches; fixed shooter and kits, three-dimensional maps, exact personal/team paint ledger; ",output)
	quit()

func _drive(elapsed: float) -> void:
	super._drive(elapsed)
	if game.player_respawn>0: return
	var walker: CharacterBody3D=game.get_node("World/Walker")
	var combat: Node3D=game.get_node("Combat")
	if elapsed>4 and fmod(elapsed,9.0)<1.0/30 and combat.ink_amount>40: _tap(KEY_E)
	if game.wings.busy(walker):
		_key(KEY_SHIFT,false); _key(KEY_SPACE,float(game.wings.flights[walker.get_instance_id()].age)<1.5)
	elif walker.grounded and walker.ink_owner==1 and int(elapsed)%8>=5:
		_key(KEY_SHIFT,true); _button(MOUSE_BUTTON_LEFT,false)
	var box: Dictionary=game.items.supply.destination(walker) if combat.ink_amount<=70 else {}
	if not box.is_empty() and walker.global_position.distance_to(box.point)<1.4:
		_key(KEY_W,false); _key(KEY_SHIFT,false); _button(MOUSE_BUTTON_LEFT,false)
