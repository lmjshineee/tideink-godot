extends SceneTree

var failures: Array[String] = []
var game: Node3D
var walker: CharacterBody3D
var combat: Node3D
var bot: Node3D

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func prepare(match_size: int = 5, map_id: String = "modular_harbor", rule: String = "turf", mode: String = "custom") -> void:
	var setup := preload("res://src/core/match_setup.gd")
	setup.screen = "setup"
	assert(rule == "turf", "Only full-map turf remains playable")
	setup.loadout_mode = mode
	setup.map_id = map_id
	setup.random_map = false
	setup.map_variant = 6
	setup.team_size = match_size
	setup.selected_perk = "balanced"
	setup.selected_item = "bomb"
	setup.selected_attributes = preload("res://src/core/attribute_catalog.gd").empty()
	game = (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	walker = game.get_node("World/Walker")
	walker.set_physics_process(false)
	combat = game.get_node("Combat")
	bot = game.get_node("Bot")
	game._start_round()
	for actor in game.all_actors():
		game.attributes._store(actor, preload("res://src/core/attribute_catalog.gd").empty())
		game.perks.choices[actor.get_instance_id()] = "balanced"
		game.items.state(actor).kind = "bomb"
		game.items.state(actor).armor = 0.0
		if actor != walker:
			actor.global_position = Vector3(70 + game.actor_id(actor) * 3, 40, 70)
			actor.invuln = 0
			actor.health = game.actor_max_health(actor)
			actor.ink_amount = game.actor_ink_max(actor)
	game.perks.apply_movement()
	game.player_health = game.actor_max_health(walker)
	game.bot_health = game.actor_max_health(bot)
	combat.ink_amount = game.actor_ink_max(walker)
	game.player_invuln = 0
	game.bot_invuln = 0
	game.bot_respawn = 0
	game.player_respawn = 0
	game._set_pointer_lock(false)
	game.paused = false
	walker.active = true

func wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	game.add_child(body)
	body.global_position = at
	return body

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func finish(label: String) -> void:
	game.set_process(false)
	game.set_physics_process(false)
	await create_timer(.2).timeout
	for voice in game.sound.get_children():
		if voice.has_method("stop"):
			voice.stop()
			voice.stream=null
	await create_timer(.1).timeout
	game.queue_free()
	await process_frame
	# Audio playback references retire after the scene has left the tree.
	await create_timer(.1).timeout
	if failures.is_empty(): print("PASS: ", label)
	quit(0 if failures.is_empty() else 1)
