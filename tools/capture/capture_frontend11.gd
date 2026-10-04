extends SceneTree
var current_map := ""
func _initialize() -> void: call_deferred("_run")
func frames(count: int) -> void:
	for i in range(count): await process_frame
func save(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://render-evidence/balance11-%s-%s.png" % [current_map,label])
func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await frames(2)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)
func click(control: Control) -> void:
	await click_at(control.get_global_transform_with_canvas()*(control.size*0.5))
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await frames(1)
func fail(message: String) -> void:
	printerr("FAIL: ",message);quit(1)
func _run() -> void:
	if DisplayServer.get_name()=="headless":fail("native display required");return
	var setup := preload("res://src/core/match_setup.gd")
	for map_id in (["tidewater"] if OS.get_cmdline_user_args().has("--menu-only") else ["tidewater","coral_market","prism_gallery","viaduct"]):
		current_map = map_id
		setup.map_id = map_id
		setup.screen = "home"
		setup.selected_item = "bomb"
		root.size = Vector2i(1280,720)
		root.content_scale_size = Vector2i(1280,720)
		await frames(5)
		var game := (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
		game.settings_path = "/private/tmp/inkwave-balance11-ui.cfg"
		root.add_child(game)
		current_scene = game
		game.set_physics_process(false)
		await frames(5)
		await save("main")
		await click(game.frontend.play_button)
		if game.phase!="setup":fail("mouse PLAY must enter preparation");return
		await click(game.frontend.item_buttons["shield"])
		await click(game.weapon_buttons["roller"])
		if game.items.state(game.get_node("World/Walker"))["kind"]!="shield" or game.selected_weapon!="roller":fail("mouse weapon/item selection");return
		var previous: int = setup.appearance_seed
		await click(game.frontend.random_button)
		await frames(5)
		game = current_scene
		game.set_physics_process(false)
		if game.phase!="setup" or game.selected_weapon!="roller" or setup.appearance_seed==previous:fail("mouse RANDOM rebuild loses equipment/preparation");return
		game.frontend.perk_choice.select(1)
		game.frontend.perk_choice.item_selected.emit(1)
		if game.actor_max_health(game.get_node("World/Walker"))!=150:fail("chosen vitality applies to preview and health");return
		await save("preparation")
		await key(KEY_ENTER)
		if game.phase!="intro":fail("Enter begins battle");return
		game._start_round()
		game.phase_time = 2.0
		var walker: CharacterBody3D = game.get_node("World/Walker")
		walker.set_physics_process(false)
		var combat: Node3D = game.get_node("Combat")
		await key(KEY_E)
		if game.items.state(walker)["armor"]!=60:fail("selected shield E shortcut");return
		for hit in range(3): game.damage_player(82,false,game.get_node("Bot"),"blaster")
		game._update_hud()
		await frames(4)
		await key(KEY_R)
		if game.perks.kind(walker)!="vitality" or game.perks.select_player("runner"):fail("death reroll cannot change talent");return
		await save("death")
		if not game.deployment.active or game.respawn_ready or game.player_respawn!=4:fail("launcher must open while countdown runs");return
		var before: Vector3 = game.deployment.target
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(95,-35)
		root.push_input(motion,true)
		await frames(3)
		var target: Vector3 = game.deployment.target
		if target==before:fail("mouse selects landing during countdown");return
		await key(KEY_SPACE)
		if game.deployment.flying or not game.deployment.queued:fail("Space must queue, not bypass countdown");return
		game._update_player_respawn(1.0)
		game._update_hud()
		await save("launcher-countdown")
		game._update_player_respawn(2.99)
		game._update_player_respawn(0.02)
		game._update_hud()
		if not game.deployment.flying:fail("selected point launches when countdown ends");return
		await save("launcher")
		game._update_player_respawn(0.25)
		await save("launch-arc")
		game._update_player_respawn(0.5)
		game._update_hud()
		if game.player_respawn>0 or not game.pointer_locked or not walker.active or walker.global_position.distance_to(target)>0.1:fail("launch lands and restores controls");return
		# Selected item is also usable from the actual right-click path.
		game.items.equip(walker,"shield")
		setup.selected_item="shield"
		game.items.state(walker)["cooldowns"]["shield"] = 0.0
		for pressed in [true,false]:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_RIGHT
			mouse.pressed = pressed
			root.push_input(mouse,true)
			game._physics_process(0.01)
		if game.items.state(walker)["armor"]<=0:fail("right click activates chosen shield");return
		await save("battle-kit")
		game._finish_round()
		game._judge_round()
		game.phase = "results"
		game._update_hud()
		await frames(4)
		await save("results")
		await key(KEY_ENTER)
		await frames(5)
		game = current_scene
		game.set_physics_process(false)
		if game.phase!="home":fail("results return to main menu");return
		root.size = Vector2i(960,540)
		root.content_scale_size = Vector2i(960,540)
		game.settings.set("ui_scale",1.1)
		game._layout_hud()
		game.show_preparation()
		await frames(4)
		await save("small")
		for control in [game.frontend.random_button,game.frontend.back_button,game.frontend.settings_button]:
			if not Rect2(Vector2.ZERO,Vector2(960,540)).encloses(control.get_global_rect()):fail("small menu control overflow");return
		for card in game.weapon_cards.values():
			if not card.get_global_rect().encloses(card.get_node("Stars").get_global_rect()):fail("small weapon stars overflow card");return
		if game.frontend.random_button.get_global_rect().intersects(game.frontend.back_button.get_global_rect()):fail("small RANDOM overlaps back button");return
		print("AUDIT: ",map_id," mouse main/prep/weapon/item/random, launcher aim/Space arc, E/right-click cooldown item, results/home, 960x540/110%")
		game.queue_free()
		await frames(3)
	print("PASS: native main menu, full-body random preview, chosen kits, one-action Squid Spawn, results and small-window layout on ","one revised menu" if OS.get_cmdline_user_args().has("--menu-only") else "four stages")
	quit()
