extends SceneTree

# Run with --headless --fixed-fps 30 --disable-render-loop. Actual scene physics,
# player input, combat, deaths, respawns and the 90-second timer remain enabled.
const Setup := preload("res://match_setup.gd")
const SEEDS := [701,1709,3253,6151]
const MAPS := ["tidewater","kelpline"]
const WEAPONS := ["shooter","roller","charger","blaster","dualie","heavy","rapid"]
var held := {}
var game: Node3D
var route := PackedVector3Array()
var route_index := 0
var goal_index := 0
var last_jump := -5.0
var last_death := 0
var report := {
	"method":"Headless fixed-30Hz actual scene simulation; normal input-driven local shooter, nine production bots, natural 90-second timer and results. No teleports, forced damage or phase/clock skips during play.",
	"limits":"Small automated sample, not human balance or rendering/performance acceptance. Local player is excluded from weapon aggregates; four allied vs five enemy bots and different routes/teams confound averages. Weapon-specific specials remain enabled. Turf is cumulative newly claimed area, including enemy overpaint, not final occupancy.",
	"conditions":{"perk":"balanced","item":"refill","reroll_bots":false,"map_variant":0,"physics_hz":30,"duration_seconds":90},
	"rounds":[]
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() != "headless":
		printerr("FAIL: this batch measurement requires headless simulation")
		quit(1)
		return
	var selected_case := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			selected_case = int(arg.trim_prefix("--case="))
	var output := "res://render-evidence/match-loadouts.json" if selected_case < 0 else "res://render-evidence/match-loadouts-case-%d.json" % selected_case
	var hashes := {}
	for name in ["tidewater_play.gd","tidewater_bot.gd","tidewater_combat.gd","gameplay_rules.gd","equipment_catalog.gd"]:
		hashes[name] = FileAccess.get_sha256("res://"+name)
	report["source_sha256"] = hashes
	for case_index in range(MAPS.size()*SEEDS.size()):
		if selected_case >= 0 and case_index != selected_case:
			continue
		Setup.screen = "setup"
		Setup.map_id = MAPS[case_index/SEEDS.size()]
		Setup.map_seed = SEEDS[case_index%SEEDS.size()]
		Setup.map_variant = 0
		Setup.random_map = false
		Setup.team_size = 5
		Setup.duration_index = 0
		Setup.selected_item = "refill"
		Setup.selected_perk = "balanced"
		Setup.reroll_bots = false
		Setup.pending_loadout = {"player":"shooter","settings_path":"/private/tmp/inkwave-match-loadouts-unused.cfg"}
		game = (load("res://tidewater_play.tscn") as PackedScene).instantiate()
		root.add_child(game)
		current_scene = game
		await physics_frame
		Engine.max_fps = 0
		var walker: CharacterBody3D = game.get_node("World/Walker")
		var roster: Array = game.all_actors()
		roster.sort_custom(func(a,b): return game.actor_id(a) < game.actor_id(b))
		var bot_index := 0
		for actor in roster:
			game.perks.choices[actor.get_instance_id()] = "balanced"
			game.items.equip(actor,"refill")
			if actor != walker:
				var weapon: String = WEAPONS[(bot_index+case_index*3)%WEAPONS.size()]
				actor.select_weapon(weapon)
				if actor == game.get_node("Bot"):
					game.selected_bot_weapon = weapon
				bot_index += 1
		game.perks.apply_movement()
		seed(Setup.map_seed)
		route.clear()
		route_index = 0
		goal_index = 0
		last_jump = -5.0
		last_death = 0
		_tap(KEY_ENTER)
		var phase_frames := 0
		while game.phase != "playing" and phase_frames < 180:
			await physics_frame
			phase_frames += 1
		if game.phase != "playing":
			printerr("FAIL: normal Enter/intro did not enter play")
			quit(1)
			return
		print("AUDIT: case ",case_index," start ",Setup.map_id," seed=",Setup.map_seed)
		var sample := {"case":case_index,"map":Setup.map_id,"seed":Setup.map_seed,"duration_seconds":game.round_time,"actors":[],"results":false}
		var observations := {}
		for actor in roster:
			observations[game.actor_id(actor)] = {"alive_seconds":0.0,"travel_m":0.0,"position":actor.global_position,"height_max":actor.global_position.y}
		var start := Time.get_ticks_usec()
		var elapsed := 0.0
		var frames := 0
		while game.phase == "playing" and frames < 2800:
			_drive(elapsed)
			await physics_frame
			var now: float = clampf(game.round_time-game.round_left,0.0,game.round_time)
			var delta := now-elapsed
			elapsed = now
			frames += 1
			for actor in roster:
				var o: Dictionary = observations[game.actor_id(actor)]
				if game.actor_alive(actor):
					o.alive_seconds += delta
					var movement: float = actor.global_position.distance_to(o.position)
					if movement < 2.0:
						o.travel_m += movement
					o.height_max = maxf(o.height_max,actor.global_position.y)
				o.position = actor.global_position
		_release()
		if game.phase != "finish" or absf(elapsed-90.0) > 0.05:
			printerr("FAIL: round did not finish naturally at 90 seconds: ",game.phase," / ",elapsed)
			quit(1)
			return
		phase_frames = 0
		while game.phase != "results" and phase_frames < 100:
			await physics_frame
			phase_frames += 1
		if game.phase != "results":
			printerr("FAIL: natural results did not appear")
			quit(1)
			return
		sample["results"] = true
		sample["simulation_seconds"] = elapsed
		sample["physics_frames"] = frames
		sample["wall_seconds"] = float(Time.get_ticks_usec()-start)/1000000.0
		sample["coverage"] = game.judged_coverage.duplicate()
		sample["team_cumulative_turf_m2"] = game.turf_area.duplicate()
		var totals := [0.0,0.0]
		for actor in roster:
			var o: Dictionary = observations[game.actor_id(actor)]
			var stats: Dictionary = actor.get_meta("match_stats").duplicate(true)
			totals[game.actor_team(actor)] += float(stats.turf)
			sample.actors.append({"id":game.actor_id(actor),"team":game.actor_team(actor),"local_player":actor==walker,"weapon":game.selected_weapon if actor==walker else actor.weapon_id,"perk":game.perks.kind(actor),"item":game.items.state(actor).kind,"alive_seconds":o.alive_seconds,"travel_m":o.travel_m,"height_max":o.height_max,"stats":stats})
		for team in range(2):
			if absf(totals[team]-float(game.turf_area[team])) > 0.01:
				printerr("FAIL: per-actor turf lost ownership in full round: ",totals," / ",game.turf_area)
				quit(1)
				return
		report.rounds.append(sample)
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  ")+"\n")
		file.close()
		print("AUDIT: case ",case_index," finished; coverage=",sample.coverage," cumulative_turf=",totals," wall=",snappedf(sample.wall_seconds,.01),"s")
		game.queue_free()
		await process_frame
	if report.rounds.is_empty():
		printerr("FAIL: selected case is outside the eight-case batch")
		quit(1)
		return
	print("PASS: ",report.rounds.size()," complete 90-second scene simulations; fixed kits, natural deaths/results, exact individual-to-team turf accounting; ",output)
	quit()

func _drive(elapsed: float) -> void:
	var walker: CharacterBody3D = game.get_node("World/Walker")
	var combat: Node3D = game.get_node("Combat")
	if game.player_respawn > 0.0:
		_release()
		if game.local_deaths > last_death:
			last_death = game.local_deaths
			route.clear()
		if game.respawn_ready:
			_tap(KEY_ENTER)
		return
	if combat.special_ready():
		_tap(KEY_F)
	if combat.ink_amount < 30.0 or game.player_health < 80.0:
		_tap(KEY_E)
	if route.is_empty() or route_index >= route.size():
		var goal := Vector3(6.0 if goal_index%2 == 0 else -6.0,0.0,[0.0,-10.0,10.0][goal_index%3])
		route = game.navigation.route(walker.global_position,goal,0)
		route_index = 1 if route.size() > 1 else 0
		goal_index += 1
	_key(KEY_W,false)
	if route_index < route.size():
		var offset := route[route_index]-walker.global_position
		var flat := Vector2(offset.x,offset.z)
		if flat.length() < 0.45 and absf(offset.y) < 0.65:
			route_index += 1
		elif flat.length() > 0.01:
			var yaw := atan2(offset.x,offset.z)
			var look := InputEventMouseMotion.new()
			look.relative = Vector2(-wrapf(yaw-walker.camera_yaw,-PI,PI)/walker.look_sensitivity,(walker.camera_pitch+0.22)/walker.look_sensitivity)
			Input.parse_input_event(look)
			Input.flush_buffered_events()
			_key(KEY_W,true)
			if walker.grounded and elapsed-last_jump > 1.2 and (offset.y > 0.45 or int(elapsed)%7 == 0):
				_tap(KEY_SPACE)
				last_jump = elapsed
	var squid: bool = walker.ink_owner == 0 and int(elapsed)%8 >= 5 and combat.ink_amount < 70.0
	_key(KEY_SHIFT,squid)
	_button(MOUSE_BUTTON_LEFT,not squid and combat.ink_amount > 3.0 and fmod(elapsed,3.0) < 2.0)

func _key(code: Key, pressed: bool) -> void:
	if held.get(code,false) == pressed:
		return
	held[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _button(code: MouseButton, pressed: bool) -> void:
	var key := "mouse%d" % code
	if held.get(key,false) == pressed:
		return
	held[key] = pressed
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tap(code: Key) -> void:
	_key(code,true)
	_key(code,false)

func _release() -> void:
	for code in [KEY_W,KEY_SHIFT,KEY_SPACE]:
		_key(code,false)
	_button(MOUSE_BUTTON_LEFT,false)
