extends "res://tools/capture_wings_results.gd"
const Icons := preload("res://loadout_icons.gd")

func _run() -> void:
	evidence_prefix = "creative23-gl" if OS.get_cmdline_user_args().has("--gl") else "creative23"
	if DisplayServer.get_name()=="headless": printerr("FAIL: native renderer required"); quit(1); return
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	await prepare(5,"prism_gallery")
	game.phase = "setup"; game.perks.locked=false; game._choose_player_weapon("bow")
	var atlas := Control.new(); atlas.mouse_filter = Control.MOUSE_FILTER_IGNORE; atlas.z_index = 200
	game.hud_root.add_child(atlas)
	var background := ColorRect.new(); background.color=Color("131e2e"); background.size=Vector2(1280,720); atlas.add_child(background)
	var entries: Array = []
	for id in game.items.KINDS: entries.append(["item",id,game.items.LABELS[id]])
	for id in game.perks.ORDER: entries.append(["perk",id,game.perks.LABELS[id]])
	for id in Icons.SPECIAL_NAMES: entries.append(["special",id,Icons.SPECIAL_NAMES[id]])
	for i in entries.size():
		var e: Array = entries[i]; var at := Vector2(40+(i%6)*206,45+(i/6)*160)
		for px in [48,24]:
			var image := TextureRect.new(); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.texture=Icons.icon(e[0],e[1]); image.position=at+Vector2(0 if px==48 else 76,0 if px==48 else 12); image.size=Vector2.ONE*px
			image.modulate=Color("82e4ed") if e[0]=="item" else Color("e2c9ff") if e[0]=="perk" else Color("ffe09c"); atlas.add_child(image)
		var label := Label.new(); label.text=e[2]+"\n"+e[0]; label.position=at+Vector2(0,60); label.add_theme_font_override("font",game.presentation.body_font); label.add_theme_font_size_override("font_size",15); atlas.add_child(label)
	await snap("icons"); atlas.queue_free(); await process_frame
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=pixels; root.content_scale_size=pixels; game.settings.ui_scale=1.1 if pixels.x<1000 else 1.0; await create_timer(.2).timeout; game._layout_hud()
		for kind in ["item","perk"]:
			var ids: Array = game.items.KINDS if kind=="item" else game.perks.ORDER
			for id in ids:
				var button: Button = game.frontend.item_buttons[id] if kind=="item" else game.frontend.perk_buttons[id]
				expect(button.icon==Icons.icon(kind,id),"actual card has its unique icon: "+id)
			game.frontend._select_item("ink_wings"); game.frontend._select_perk(game.perks.ORDER.find("dry_focus"))
			await hover(kind,"ink_wings" if kind=="item" else "dry_focus")
			await snap("menu-"+kind+("-small" if pixels.x<1000 else "")); game.frontend._end_hover()
	root.size=Vector2i(1280,720); root.content_scale_size=root.size; game.settings.ui_scale=1.0; await create_timer(.2).timeout; game._layout_hud()
	game.phase="playing"; game.phase_time=4; game.perks.locked=true; game.deployment.clear(); game.pointer_locked=true; game.paused=false
	for actor in game.all_actors():
		if actor!=walker: actor.global_position=Vector3(200,40,200)
	var floor: Dictionary = game.deployment.landing(Vector2(-15,-13),false,INF,0,walker)
	expect(not floor.is_empty(),"real supported native feedback fixture")
	if floor.is_empty(): await finish("supported display location"); return
	walker.global_position=floor.point; walker.reset_movement_state(); walker.grounded=true; await physics_frame
	var camera: Camera3D=walker.get_node("Camera3D"); camera.current=true; camera.global_position=walker.global_position+Vector3(5,4,-6); camera.look_at(walker.global_position+Vector3.UP)
	game.items.equip(walker,"ink_wings"); game.items.state(walker).cooldowns.ink_wings=0; combat.ink_amount=100
	game.presentation.ability_flash=0; combat.special_points=combat.special_cost()*.63
	game.tactics._process(.1); expect(game.tactics.loadout_status.state=="ready","enough ink and no cooldown show ready")
	var before: float=combat.ink_amount; var casts: int=game.wings.casts_total
	for i in 20: game.items.hud_status()
	expect(combat.ink_amount==before and game.wings.casts_total==casts and game.items.state(walker).cooldowns.ink_wings==0,"reading status never spends, deploys or changes cooldown")
	await snap("ready")
	combat.ink_amount=39; game.tactics._process(.1); expect(game.tactics.loadout_status.state=="blocked","unaffordable wings do not advertise ready"); await snap("low-ink")
	combat.ink_amount=100; key(KEY_E,true); key(KEY_E,false)
	expect(game.wings.busy(walker) and combat.ink_amount==60,"real E spends and deploys wings")
	game.tactics._process(.1); expect(game.tactics.loadout_status.state=="active" and game.tactics.loadout_status.detail.contains("Space"),"active flight controls replace ready text")
	await snap("active")
	game.wings.cancel(walker); game.items.tick(1)
	game.tactics._process(.1); expect(game.tactics.loadout_status.state=="cooldown" and game.tactics.loadout_status.cooldown==17,"actual cooldown ticks and is displayed")
	await snap("cooldown")
	game.items.equip(walker,"recall"); game.items.state(walker).cooldowns.recall=0; combat.ink_amount=100; walker.grounded=true; await physics_frame
	expect(game.items.use(walker),"real supported anchor placement")
	combat.ink_amount=0; game.tactics._process(.1)
	expect(game.tactics.loadout_status.state=="active" and game.tactics.loadout_status.detail.contains("返回"),"placed anchor offers return despite empty ink")
	await snap("recall")
	var origin: Vector3=walker.global_position; walker.global_position+=Vector3(21,0,0); game.tactics._process(.1)
	expect(game.tactics.loadout_status.state=="blocked" and game.tactics.loadout_status.detail.contains("超出"),"out-of-range anchor does not advertise a valid return")
	walker.global_position=origin
	game.items.equip(walker,"ink_wings"); combat.ink_amount=100
	game.presentation.ability_flash=0
	root.size=Vector2i(960,540); root.content_scale_size=root.size; game.settings.ui_scale=1.1; await create_timer(.2).timeout; game._layout_hud(); game.tactics._process(.1)
	await snap("cooldown-small")
	game.player_respawn=4; game._update_hud(); game.tactics._process(.1); await snap("death")
	game.player_respawn=0; game.items.on_respawn(walker); game.tactics._process(.1)
	expect(game.tactics.loadout_status.cooldown==17,"death/respawn does not disguise persistent cooldown")
	await finish("22 original vector icons / actual item-perk cards at two sizes / real E and resource spending / active controls / actual persistent cooldown / empty-ink recall / read-only status / death visibility")
