extends Node

# Source builders are baked once; gameplay only selects sounds and bus volumes.
var manifest: Dictionary
var streams: Dictionary = {}
var music_player: AudioStreamPlayer
var music_track := ""
var loops: Dictionary = {}
var history: Array[String] = []
var last_play: Dictionary = {}
var previous_phase := ""
var previous_dead := false
var previous_squid := false
var previous_grounded := true
var previous_ready := false
var previous_charge := 0.0
var previous_ink := 100.0
var previous_count := -1
var step_clock := 0.0
var duck := 1.0
var target_music_db := 0.0 # The baked source MusicEngine already applies its 0.42 mix level.
var game: Node3D

func setup(owner_game: Node3D) -> void:
	game = owner_game
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	apply_settings(game.get("settings"))
	# UI sounds are shared by menus, settings and death loadout controls.
	_bind_controls(game.get("hud_root"))
	play_music("menu")

func _bind_controls(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(func(): play_sound("ui_click"))
		(node as BaseButton).mouse_entered.connect(func(): play_sound("ui_hover"))
	if node is OptionButton:
		(node as OptionButton).item_selected.connect(func(_index: int): play_sound("ui_toggle"))
	for child in node.get_children():
		_bind_controls(child)

func apply_settings(model: RefCounted) -> void:
	for pair in [["Master","master_volume"],["Music","music_volume"],["SFX","sfx_volume"]]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]), linear_to_db(pow(float(model.get(pair[1])),1.5)))

func _stream(id: String) -> AudioStreamWAV:
	if streams.has(id):
		return streams[id]
	if not manifest["sounds"].has(id):
		return null
	var info: Dictionary = manifest["sounds"][id]
	var stream := load("res://assets/audio/" + String(info["file"])) as AudioStreamWAV
	if stream == null:
		return null
	stream = stream.duplicate() as AudioStreamWAV
	if bool(info["loop"]):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = int(info["loopStart"])
		stream.loop_end = int(info["frames"])
	streams[id] = stream
	return stream

func play_sound(id: String, at: Vector3 = Vector3.INF, gain: float = 1.0) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(id, -1000)) < 45:
		return
	last_play[id] = now
	var stream := _stream(id)
	if stream == null:
		return
	history.append(id)
	if history.size() > 64:
		history.pop_front()
	# Bounded voice pool, including bot shots. Continuous voices live separately.
	if get_child_count() > 28:
		return
	var player: Node
	if at.is_finite():
		var spatial := AudioStreamPlayer3D.new()
		spatial.unit_size = 3.0
		spatial.max_distance = 60.0
		player = spatial
		add_child(player)
		spatial.global_position = at
	else:
		player = AudioStreamPlayer.new()
		add_child(player)
	player.set("stream", stream)
	player.set("bus", "SFX")
	player.set("volume_db", linear_to_db(maxf(gain,0.001)))
	# Loop definitions can also be requested as short one-shots (judge roll).
	if stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		player.set("stream", stream.duplicate())
		player.get("stream").loop_mode = AudioStreamWAV.LOOP_DISABLED
	player.connect("finished",player.queue_free)
	player.call("play")

func play_music(id: String) -> void:
	if music_track == id:
		return
	music_track = id
	music_player.stop()
	if id.is_empty():
		return
	music_player.stream = _stream(id)
	music_player.volume_db = -30.0
	music_player.play()

func _loop(id: String, enabled: bool, pitch: float = 1.0, gain: float = 0.65) -> void:
	if not enabled:
		if loops.has(id):
			loops[id].queue_free()
			loops.erase(id)
		return
	if not loops.has(id):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.stream = _stream(id)
		add_child(player)
		player.play()
		loops[id] = player
	loops[id].pitch_scale = clampf(pitch,0.5,2.5)
	loops[id].volume_db = linear_to_db(maxf(gain,0.001))

func sync(delta: float) -> void:
	var phase: String = game.get("phase")
	var dead: bool = float(game.get("player_respawn")) > 0.0
	var paused: bool = game.get("paused")
	var combat: Node = game.get_node("Combat")
	var walker: CharacterBody3D = game.get_node("World/Walker")
	if phase != previous_phase:
		match phase:
			"setup": play_music("menu")
			"intro": play_sound("ready"); play_music("")
			"playing": play_sound("go_horn"); play_music("battle")
			"finish": play_sound("times_up"); play_music("")
			"results":
				play_sound("judge_reveal")
				play_sound("victory_fanfare" if int(game.get("winner")) == 0 else "defeat_jingle")
				play_music("results_win" if int(game.get("winner")) == 0 else "results_lose")
		previous_phase = phase
	music_player.stream_paused = paused
	duck = move_toward(duck, 0.4 if dead else 1.0, delta * 2.0)
	music_player.volume_db = move_toward(music_player.volume_db,target_music_db + linear_to_db(duck),delta*45.0)
	var live := phase == "playing" and not paused and not dead
	var squid: bool = walker.get("squid_form")
	var grounded: bool = walker.get("grounded")
	var speed := Vector2(walker.velocity.x,walker.velocity.z).length()
	_loop("swim",live and squid and speed > 0.3,0.7+speed/10.0)
	_loop("roll",live and bool(combat.get("rolling")),0.7+speed/8.0)
	_loop("charger_charge",live and bool(combat.get("charging")),1.0+1.5*float(combat.get("charge_fraction")))
	_loop("storm_rain",phase=="playing" and not paused and not (combat.get("clouds") as Array).is_empty(),1.0,0.3)
	if live:
		var charge: float = combat.get("charge_fraction")
		if charge >= 0.99 and previous_charge < 0.99: play_sound("charger_full")
		previous_charge = charge
		if float(game.get("round_left")) <= 60.0 and music_track == "battle":
			play_music("battle_final"); play_sound("one_minute")
		var count := int(ceil(float(game.get("round_left"))))
		if count <= int(game.get("final_countdown")) and count != previous_count:
			play_sound("final_count")
		previous_count = count
		if squid != previous_squid: play_sound("squid_in" if squid else "squid_out")
		if grounded != previous_grounded: play_sound("land" if grounded else "jump")
		var ready: bool = combat.call("special_ready")
		if ready and not previous_ready: play_sound("special_ready")
		previous_ready = ready
		var ink: float = combat.get("ink_amount")
		if ink < 20.0 and previous_ink >= 20.0: play_sound("low_ink")
		if ink >= 100.0 and previous_ink < 100.0: play_sound("refill_full")
		previous_ink = ink
		step_clock += delta * speed
		if grounded and not squid and speed > 0.5 and step_clock >= 1.4:
			step_clock = 0.0
			play_sound("step_ink" if int(walker.get("ink_owner")) == 0 else "step_dry",walker.global_position,0.5)
	if previous_dead and not dead and phase == "playing": play_sound("respawn")
	previous_dead = dead
	previous_squid = squid
	previous_grounded = grounded
