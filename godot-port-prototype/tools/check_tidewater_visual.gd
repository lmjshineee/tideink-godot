extends SceneTree

const TeamPalette := preload("res://team_palette.gd")

# Appearance check for the character visual: teams, weapon/form/facing, opponent
# feedback, and the idle / walk / airborne poses added with the animation work.
#
# The pose section suspends the play scene's own physics and re-asserts the visual's
# read-only motion source (velocity + grounded) every frame. Without that the match
# controller finishes its respawn wait during the window and calls
# reset_movement_state(), which clears the grounded flag and freezes the idle clock.
# Headless frames run far faster than 60 fps, so every window is measured in animation
# time reported by animation_state() rather than in frame counts.
const FRAME_CAP := 200000

var _frames_used := 0


func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player: Node3D = scene.get_node("World/Walker/Body")
	var bot: Node3D = scene.get_node("Bot/Body")
	if not player.get_node("Kid").visible or player.get_node("Squid").visible \
		or not bot.get_node("Kid").visible or int(bot.get("team")) != 1:
		_fail("team character visuals did not initialize in kid form")
		return
	var hair: MeshInstance3D = bot.get_node("Kid/HairCap")
	# Compared against the palette rather than the literal, so the check follows config.js.
	if (hair.material_override as StandardMaterial3D).albedo_color != TeamPalette.color(1):
		_fail("blue opponent has the wrong team hair colour")
		return
	var combat: Node3D = scene.get_node("Combat")
	combat.call("select_weapon", "roller")
	if not player.get_node("Kid/Weapon_roller").visible or player.get_node("Kid/Weapon_shooter").visible:
		_fail("selected roller is not shown on the player")
		return
	var walker: CharacterBody3D = scene.get_node("World/Walker")
	walker.call("update_form", true)
	if player.get_node("Kid").visible or not player.get_node("Squid").visible:
		_fail("squid visual did not follow the collision form")
		return
	walker.call("update_form", false)
	if not player.get_node("Kid").visible or player.get_node("Squid").visible:
		_fail("kid visual did not return after standing")
		return
	scene.call("_start_round")
	scene.call("_update_bot", 0.1)
	if absf(absf(bot.rotation.y) - PI) > 0.01:
		_fail("opponent visual does not face its travel direction")
		return
	var opponent: Node3D = scene.get_node("Bot")
	opponent.call("select_weapon","shooter")
	walker.global_position = opponent.global_position + Vector3(2.0, 0.0, 0.0)
	scene.call("_update_bot", 0.1)
	var tracer: MeshInstance3D = scene.get_node("BotAttackTracer")
	var shots: Array = combat.get("projectiles")
	if shots.is_empty() or int((shots.back() as Dictionary)["team"]) != 1 or not tracer.visible:
		_fail("opponent projectile has no visible firing cue")
		return
	scene.call("damage_bot", 25.0)
	scene.call("_update_bot", 0.01)
	var fill: MeshInstance3D = opponent.get_node("HealthBar/Fill")
	if not is_equal_approx(fill.scale.x, scene.actor_health(opponent)/scene.actor_max_health(opponent)):
		_fail("opponent health bar did not track damage")
		return
	scene.set("player_respawn", 1.0)
	scene.call("_update_bot", 0.2)
	if tracer.visible:
		_fail("opponent attack trace did not expire")
		return

	# --- team silhouette ---------------------------------------------------------
	if not player.has_node("Kid/TeamCrest") or not bot.has_node("Kid/TeamCrest"):
		_fail("team crest is missing from the character visual")
		return
	var player_crest: MeshInstance3D = player.get_node("Kid/TeamCrest")
	var bot_crest: MeshInstance3D = bot.get_node("Kid/TeamCrest")
	if player_crest.scale.is_equal_approx(bot_crest.scale):
		_fail("both teams share the same hair silhouette")
		return

	# --- idle / walk / airborne poses --------------------------------------------
	scene.set_physics_process(false)
	walker.set_physics_process(false)
	var shirt: MeshInstance3D = player.get_node("Kid/Shirt")
	var leg_l: MeshInstance3D = player.get_node("Kid/LegL")
	var leg_r: MeshInstance3D = player.get_node("Kid/LegR")
	var start_idle: float = _state(player)["idle_time"]
	var lowest := 1000.0
	var highest := -1000.0
	while float(_state(player)["idle_time"]) - start_idle < 1.2:
		_drive(walker, Vector3.ZERO, true)
		await _step()
		lowest = minf(lowest, shirt.position.y)
		highest = maxf(highest, shirt.position.y)
		if _frames_used > FRAME_CAP:
			_fail("idle window never advanced in animation time")
			return
	if highest - lowest < 0.004:
		_fail("idle pose does not breathe: torso y range %.5f" % (highest - lowest))
		return
	var idle_state: Dictionary = _state(player)
	if float(idle_state["gait"]) > 0.05:
		_fail("idle pose still carries gait weight: %.3f" % idle_state["gait"])
		return

	var phase_before := float(idle_state["phase"])
	var amplitude := 0.0
	var counter_swung := true
	while float(_state(player)["gait"]) < 0.95:
		_drive(walker, Vector3(0.0, 0.0, -6.0), true)
		await _step()
		amplitude = maxf(amplitude, absf(leg_l.rotation.x))
		if absf(leg_l.rotation.x + leg_r.rotation.x) > 0.02:
			counter_swung = false
		if _frames_used > FRAME_CAP:
			_fail("walk gait weight never reached full")
			return
	# Keep sampling past the ramp so the swing reaches its extremes.
	for i in range(60):
		_drive(walker, Vector3(0.0, 0.0, -6.0), true)
		await _step()
		amplitude = maxf(amplitude, absf(leg_l.rotation.x))
		if absf(leg_l.rotation.x + leg_r.rotation.x) > 0.02:
			counter_swung = false
	var walk_state: Dictionary = _state(player)
	if amplitude < 0.25:
		_fail("walk pose does not swing the legs: %.3f rad" % amplitude)
		return
	if not counter_swung:
		_fail("walk pose does not counter-swing the legs: L=%.3f R=%.3f" % [leg_l.rotation.x, leg_r.rotation.x])
		return
	if is_equal_approx(phase_before, float(walk_state["phase"])):
		_fail("walk phase did not advance")
		return

	while float(_state(player)["air"]) < 0.95:
		_drive(walker, Vector3(0.0, 5.0, 0.0), false)
		await _step()
		if _frames_used > FRAME_CAP:
			_fail("airborne blend never engaged")
			return
	if leg_l.rotation.x >= -0.05 or leg_r.rotation.x <= 0.05:
		_fail("airborne pose did not tuck the legs: L=%.3f R=%.3f" % [leg_l.rotation.x, leg_r.rotation.x])
		return

	print("PASS: teams, weapon/form/facing, opponent feedback, idle breath, walk cycle and airborne pose")
	quit()


# Re-asserts the visual's read-only motion source so nothing else in the scene can
# change it mid-window.
func _drive(walker: CharacterBody3D, velocity: Vector3, grounded: bool) -> void:
	walker.velocity = velocity
	walker.set("grounded", grounded)


func _step() -> void:
	_frames_used += 1
	await process_frame


func _state(target: Node3D) -> Dictionary:
	return target.call("animation_state") as Dictionary


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
