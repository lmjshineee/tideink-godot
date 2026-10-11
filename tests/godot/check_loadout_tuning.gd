extends "res://tests/godot/check_damage_contract.gd"
const Setup = preload("res://src/core/match_setup.gd")
const Kits = preload("res://src/core/loadout_rules.gd")

func _run() -> void:
	await prepare(5,"tidewater")
	game.show_preparation();game.perks.locked=false
	expect(game.perks.select_player("balanced"),"baseline selectable before play")
	expect(is_equal_approx(game.player_health,132) and is_equal_approx(combat.ink_amount,110),"baseline actually fills boosted HP and ink")
	expect(is_equal_approx(walker.player_config.runSpeed,6.3),"baseline improves actual walking speed")
	expect(game.perks.outgoing(walker)==1 and game.perks.incoming(walker,"shooter")==1,"baseline does not hide a damage modifier")
	for actor in game.all_actors():
		expect(is_equal_approx(game.actor_max_health(actor),132) and is_equal_approx(game.actor_ink_max(actor),110),"baseline bonus applies fairly to every actor")
	for id in game.weapon_order:
		expect(Kits.KITS.has(id) and game.items.KINDS.has(Kits.sub_for(id)),"each main has one active sub")
	game.items.state(walker).cooldowns.bomb=9
	expect(game.set_loadout_mode("kit"),"kit mode accepted before play")
	for actor in game.all_actors():
		if actor!=walker:expect(game.items.state(actor).kind==Kits.sub_for(actor.weapon_id),"mode switch applies fixed associations fairly to bots")
	for id in game.weapon_order:
		game._choose_player_weapon(id)
		expect(Setup.selected_item==Kits.sub_for(id) and game.items.state(walker).kind==Kits.sub_for(id),"kit main selects actual sub")
	expect(game.items.state(walker).cooldowns.bomb==9,"kit switching preserves sub cooldown")
	game.frontend._select_item("ink_buddy")
	expect(Setup.loadout_mode=="custom" and game.items.state(walker).kind=="ink_buddy","independent sub selection switches to custom")
	game._choose_player_weapon("charger")
	expect(Setup.selected_item=="ink_buddy","custom main selection retains independent sub")
	var seen_main := {};var seen_perk := {};var seen_sub := {}
	game.equipment_rng.seed=932
	for mode in Kits.MODES:
		expect(game.set_loadout_mode(mode),"both loadout modes accepted")
		for i in 100:
			var before := [game.selected_weapon,Setup.selected_perk,Setup.selected_item]
			expect(game.roll_setup_loadout(),"roll returns a changed loadout")
			expect([game.selected_weapon,Setup.selected_perk,Setup.selected_item]!=before,"roll does not return identical triplet")
			expect(game.weapon_order.has(game.selected_weapon) and game.perks.ORDER.has(Setup.selected_perk) and game.items.KINDS.has(Setup.selected_item),"roll contains only active catalog entries")
			if mode=="kit":expect(Setup.selected_item==Kits.sub_for(game.selected_weapon),"kit roll preserves main/sub association")
			else:seen_main[game.selected_weapon]=true;seen_perk[Setup.selected_perk]=true;seen_sub[Setup.selected_item]=true
	expect(seen_main.size()==8 and seen_perk.size()==8 and seen_sub.size()==11,"custom roll reaches every main/perk/sub")
	expect(game.items.state(walker).cooldowns.bomb==9,"200 rolls preserve existing sub cooldown")
	var front:Control=game.frontend
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=pixels;root.content_scale_size=pixels;game.settings.ui_scale=1;await process_frame;game._layout_hud();front.sync();await process_frame;front.sync()
		var row:Rect2=front.strips.perk.get_global_rect()
		for control in [front.kit_mode,front.roll_button]:
			expect(not row.intersects(control.get_global_rect()),"new controls do not overlap perk cards")
			expect(Rect2(Vector2.ZERO,Vector2(pixels)).encloses(control.get_global_rect()),"new controls fit viewport")
		expect(front.kit.text.contains("大招") and front.kit.text.contains("天赋") and front.kit.text.contains("生命"),"loadout header explains all roles and stats")
	for selector in [front.kit_mode,front.roll_button]:
		var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.pressed=true
		selector.grab_focus();game._input(enter)
		expect(game.phase=="setup","focused loadout control retains Enter")
		selector.release_focus()
	game._start_round()
	var locked_perk:String=game.perks.kind(walker)
	for phase in ["intro","playing","results"]:
		game.phase=phase
		expect(not game.roll_setup_loadout() and not game.set_loadout_mode("kit"),"roll and mode changes rejected during locked match")
	game.show_preparation()
	expect(not game.roll_setup_loadout(),"returning to preparation cannot unlock match talents")
	game.phase="playing";game.player_respawn=3
	game.randomize_player_kit()
	expect(game.perks.kind(walker)==locked_perk and game.items.state(walker).cooldowns.bomb==9,"death reroll preserves locked talent and cooldown")
	# The selected 132 HP baseline has the promised real physical thresholds.
	for id in ["shooter","dualie"]:
		reset_fight(bot,walker,132)
		for count in 3:shoot(id,walker,bot)
		expect(game.actor_alive(bot),id+" leaves reaction HP after three accurate rounds")
		shoot(id,walker,bot);expect(not game.actor_alive(bot),id+" splats on fourth near round")
		reset_fight(bot,walker,132);bot.global_position.z=12 if id=="shooter" else 10.3
		for count in 4:shoot(id,walker,bot)
		expect(game.actor_alive(bot),id+" retains falloff against baseline")
		shoot(id,walker,bot);expect(not game.actor_alive(bot),id+" splats on fifth far round")
	reset_fight(bot,walker,132)
	combat.bow.fire(walker,bot.global_position+Vector3.UP*.9,1)
	for i in 50:combat.bow.tick(1.0/30)
	expect(is_equal_approx(game.bot_health,27),"full bow leaves 27 HP against improved baseline")
	combat.bow.fire(walker,bot.global_position+Vector3.UP*.9,0)
	for i in 50:combat.bow.tick(1.0/30)
	expect(game.bot_health==0,"bow follow-up actually splats")
	reset_fight(bot,walker,300)
	game.perks.choices[walker.get_instance_id()]="adrenaline";game.player_health=40
	game.perks.choices[bot.get_instance_id()]="vault_runner";bot.set_meta("vault_boost",2.0)
	combat.bow.fire(walker,bot.global_position+Vector3.UP*.9,1)
	for i in 50:combat.bow.tick(1.0/30)
	expect(is_equal_approx(game.bot_health,170),"combined attacker/defender modifiers respect final bow cap 130")
	await finish("boosted baseline, 200 pre-match rolls, fixed/custom associations, active pools, UI bounds, match lock/cooldowns, actual 4/5-round shooting and bow follow-up/final cap")
