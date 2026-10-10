extends "/Users/yunni/Joy/inkwave-game-cleaned/render-evidence/app-build-2026-10-10/tactical-fixtures/creative_fixture.gd"
const Catalog := preload("res://src/core/attribute_catalog.gd")
const Setup := preload("res://src/core/match_setup.gd")
var output := ""
var report := {"kind":"weighted bot point allocation and read-only tactical list", "samples":{}, "matches":[], "images":[], "human_balance_acceptance":false}

func _initialize() -> void:call_deferred("_run")

func average(weapon: String, perk: String) -> Dictionary:
	var totals := Catalog.empty()
	var seen := {}
	for seed_number in 400:
		var rng := RandomNumberGenerator.new();rng.seed=seed_number+221
		var value := Catalog.roll_bot(rng,20,weapon,perk)
		expect(Catalog.valid(value) and Catalog.spent(value)==20,"weighted allocation respects actual rank and point limits")
		for ability in Catalog.ABILITIES:
			totals[ability]+=int(value[ability])
			if value[ability]>0:seen[ability]=true
	expect(seen.size()==8,"weighted ROLL keeps every attribute reachable")
	var result := {}
	for ability in Catalog.ABILITIES:result[ability]=float(totals[ability])/400.0
	report.samples[weapon+"/"+perk]=result
	return result

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if not output.is_empty():
		if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
			printerr("FAIL: capture requires native arm64 and new absolute directory");quit(1);return
		DirAccess.make_dir_recursive_absolute(output)
		report.environment={"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"arm64":OS.has_feature("arm64")}
		report.verification="explicit exported PCK; release receipt binds source and application bytes"
		Setup.pending_loadout={"settings_path":output.path_join("settings.cfg")}
	for weapon in Catalog.BOT_WEIGHTS:
		for perk in ["balanced","adrenaline","leech","enemy_swim","vault_runner","last_ink","dry_focus","turf_engine","unknown"]:
			var weights := Catalog.bot_weights(weapon,perk)
			expect(weights.size()==8,"complete weighted pool")
			for weight in weights.values():expect(weight>0,"no impossible stat or empty weighted lottery")
			weights.health=999
			expect(Catalog.bot_weights(weapon,perk).health<999,"weight snapshots cannot mutate shared profiles")
	for budget in [-9,0,1,7,13,20,100]:
		for seed_number in 40:
			var first := RandomNumberGenerator.new();first.seed=seed_number
			var second := RandomNumberGenerator.new();second.seed=seed_number
			var value := Catalog.roll_bot(first,budget,"unknown","unknown")
			expect(value==Catalog.roll_bot(second,budget,"unknown","unknown"),"unknown profile fallback is reproducible")
			expect(Catalog.valid(value) and Catalog.spent(value)==clampi(budget,0,20),"budget clamp covers zero, sparse and injected oversized allocations")
	var averages := {}
	for weapon in Catalog.BOT_WEIGHTS:averages[weapon]=average(weapon,"balanced")
	var sniper:Dictionary=averages.charger;var mobile:Dictionary=averages.dualie
	expect(sniper.ink_capacity+sniper.main_saver+sniper.ink_recovery > mobile.ink_capacity+mobile.main_saver+mobile.ink_recovery+2,"charger distribution favors actual ink endurance")
	expect(mobile.run_speed+mobile.swim_speed > sniper.run_speed+sniper.swim_speed+2,"dualie distribution favors movement")
	expect(averages.canopy.health > sniper.health+1.5,"canopy distribution favors survivability")
	var turf := average("shooter","turf_engine")
	var dry := average("charger","dry_focus")
	expect(turf.special_charge>averages.shooter.special_charge+1.5,"turf talent increases charge allocation tendency")
	expect(dry.ink_capacity<sniper.ink_capacity-1.5,"low-ink talent avoids preferring a larger tank")
	var brief_value:=Catalog.empty();brief_value.health=8;brief_value.ink_capacity=5;brief_value.ink_recovery=5;brief_value.run_speed=2
	expect(Catalog.brief(brief_value)=="20 点 · 生命8 / 墨量5 / 回墨5","brief displays spent points and stable top three actual ranks")
	expect(Catalog.brief(Catalog.empty())=="0 点 · 未分配","zero allocation is explicit")
	for match_size in [5,1]:await integration(match_size)
	if not output.is_empty():
		report.status="passed" if failures.is_empty() else "failed"
		var file:=FileAccess.open(output.path_join("bot-builds.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	await finish("weighted bot points: eight weapon/seven talent biases, deterministic fallback/rank/budget/alias negatives, 400 samples each, both teams in 5v5/1v1, match locks, real caps and native-ready Tab rows")

func integration(match_size: int) -> void:
	if is_instance_valid(game):
		for voice in game.sound.get_children():
			if voice.has_method("stop"):voice.stop();voice.stream=null
		game.queue_free();await process_frame;await create_timer(.1).timeout
	await prepare(match_size,"tidewater")
	game.phase="setup";game.perks.locked=false
	var allocation:=Catalog.empty();allocation.health=8;allocation.run_speed=8;allocation.ink_recovery=4
	expect(game.attributes.select_player(allocation),"player keeps direct allocation")
	var actors:Array[Node3D]=game.all_actors();var index:=0
	for actor in actors:
		if actor==walker:continue
		var weapon:String=game.weapon_order[index%game.weapon_order.size()];actor.select_weapon(weapon)
		if actor==bot:game.selected_bot_weapon=weapon
		game.perks.choices[actor.get_instance_id()]=game.perks.ORDER[index%game.perks.ORDER.size()]
		actor.health=23;actor.ink_amount=11;game.items.state(actor).cooldowns.bomb=3.25;index+=1
	game.attributes._bots_prepared=false;game.equipment_rng.seed=446
	var expected_rng:=RandomNumberGenerator.new();expected_rng.seed=446
	var expected:Dictionary={}
	for actor in actors:
		if actor!=walker:expected[actor.get_instance_id()]=Catalog.roll_bot(expected_rng,20,actor.weapon_id,game.perks.kind(actor))
	game._begin_intro()
	var snapshot:Dictionary={};var entries:=[]
	for actor in actors:
		var value:Dictionary=game.attributes.loadout(actor);snapshot[actor.get_instance_id()]=value
		expect(Catalog.valid(value) and Catalog.spent(value)==20,"all actors have equal valid budget")
		if actor!=walker:
			expect(value==expected[actor.get_instance_id()],"actual intro consumes weapon/talent weighted ROLL")
			expect(actor.health==23 and actor.ink_amount==11 and game.items.state(actor).cooldowns.bomb==3.25,"allocation does not restore resources or clear cooldown")
		entries.append({"id":game.actor_id(actor),"team":game.actor_team(actor),"weapon":game.selected_weapon if actor==walker else actor.weapon_id,"perk":game.perks.kind(actor),"allocation":value})
	game._start_round();game._set_pointer_lock(false);game.paused=false
	for actor in actors:
		expect(game.attributes.loadout(actor)==snapshot[actor.get_instance_id()],"intro to round does not reroll allocation")
		expect(is_equal_approx(game.actor_health(actor),game.actor_max_health(actor)),"actual start fills attribute-adjusted health")
		if actor!=walker:
			expect(is_equal_approx(actor.ink_amount,game.actor_ink_max(actor)),"actual bot start fills attribute-adjusted ink")
			if game.actor_team(actor)==1:actor.global_position=Vector3(75,40,75)
	for dimensions in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=dimensions;root.content_scale_size=dimensions;game.settings.ui_scale=1.1 if dimensions.x==960 else 1.0
		await process_frame;await process_frame;game._layout_hud()
		key(KEY_TAB,true);game._update_hud()
		var sample:Label=game.roster_rows[0]
		print("ROW_METRICS: ",dimensions," font=",sample.get_theme_font_size("font_size")," minimum=",sample.get_minimum_size().y," size=",sample.size.y," font_height=",sample.get_theme_font("font").get_height(sample.get_theme_font_size("font_size"))," spacing=",sample.get_theme_constant("line_spacing"))
		expect(game.scoreboard_panel.visible,"Tab opens actual tactical list")
		expect(game.hud_view.tactical_shade.visible,"Tab dims gameplay behind tactical panel")
		expect(game.expanded_map.position.x>game.hud_view.tactical_cards[0].get_rect().end.x and game.expanded_map.get_rect().end.x<game.hud_view.tactical_cards[5].position.x,"live map sits between separate team columns")
		var visible_rows: Array[Label]=[]
		for row in game.roster_rows:
			if not row.visible:continue
			visible_rows.append(row)
			expect(row.text.contains("\n20 点 · "),"visible row shows actual allocation separately from health/intel")
			expect(row.get_minimum_size().y<=row.size.y,"both row lines fit vertically")
			expect(game.scoreboard_panel.get_global_rect().encloses(row.get_global_rect()),"row remains within tactical panel")
			var card: Panel = row.get_parent()
			expect(card.visible and card.get_global_rect().encloses(row.get_global_rect()),"visible card contains complete weapon/status/point text")
			var name_label: Label = card.get_node("ActorName")
			expect(card.get_global_rect().encloses(name_label.get_global_rect()) and name_label.get_minimum_size().y<=name_label.size.y,"larger name fits the separate card header")
			expect(card.get_node("WeaponIcon").texture!=null,"card uses the actual main weapon icon")
			if row.name.begins_with("Roster_1_"):expect(not row.text.get_slice("\n",0).contains("生命 "),"static point display does not reveal unseen enemy health")
		for i in visible_rows.size():
			for j in range(i+1,visible_rows.size()):expect(not visible_rows[i].get_parent().get_global_rect().intersects(visible_rows[j].get_parent().get_global_rect()),"team cards do not overlap")
		expect(visible_rows.size()==match_size*2,"unused roster slots stay hidden in 1v1")
		var card_styles: Array=[]
		for card in game.hud_view.tactical_cards:card_styles.append(card.get_theme_stylebox("panel"))
		for refresh in 30:game._update_hud()
		for i in game.hud_view.tactical_cards.size():expect(game.hud_view.tactical_cards[i].get_theme_stylebox("panel")==card_styles[i],"visible refresh reuses card styles")
		if not output.is_empty():
			await process_frame;await RenderingServer.frame_post_draw
			var name_text:="tab-%dv%d-%d"%[match_size,match_size,dimensions.x]
			expect(root.get_texture().get_image().save_png(output.path_join(name_text+".png"))==OK,"save native tactical list")
			report.images.append(name_text)
		key(KEY_TAB,false);game._update_hud()
		expect(not game.scoreboard_panel.visible,"release Tab closes the list")
		expect(not game.hud_view.tactical_shade.visible,"release Tab removes the backdrop shade")
		game.roster_rows[0].text="hidden sentinel";game._update_hud()
		expect(game.roster_rows[0].text=="hidden sentinel","hidden roster does not format point summaries")
	game.damage_actor(bot,999,0,walker,"shooter");game.randomize_bot_kit(bot);bot.reset();game.attributes.prepare_bots()
	for actor in actors:expect(game.attributes.loadout(actor)==snapshot[actor.get_instance_id()],"death/weapon reroll/reset cannot adapt points mid-match")
	expect(game.items.state(bot).cooldowns.bomb==3.25,"bot death/reroll/reset retain item cooldown")
	expect(not game.attributes.roll_player(),"match still locks player points")
	report.matches.append({"team_size":match_size,"actors":entries,"allocation_retained":true})
