extends SceneTree

# Minimal real walker/bot lifecycle, without loading the map or a match scene.
# test_visual_config.py also runs this with an isolated runSpeed=12 export.
const Visual := preload("res://tidewater_character_visual.gd")
const Walker := preload("res://tidewater_walker.gd")
const Bot := preload("res://tidewater_bot.gd")

class TestGame:
	extends Node3D
	var bot_health := 100.0

class TestCombat:
	extends Node3D
	var weapon_data: Dictionary
	var weapons: Dictionary

class TestMap:
	extends Node3D
	var spawn_pads: Array = [Vector3.ZERO, Vector3(0.0, 0.0, 10.0)]

var _config_empty_at_body_ready := false


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons.json"))
	var expected := float(payload["player"]["runSpeed"])
	var game := TestGame.new()
	var combat := TestCombat.new()
	combat.name = "Combat"
	combat.weapon_data = payload
	combat.weapons = payload["weapons"]
	game.add_child(combat)
	var level := TestMap.new()
	game.add_child(level)
	var walker := Walker.new()
	walker.set_physics_process(false)
	var player := Visual.new()
	player.name = "Body"
	player.set_process(false)
	walker.add_child(player)
	player.ready.connect(func(): _config_empty_at_body_ready = walker.player_config.is_empty())
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	walker.add_child(collision)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	walker.add_child(camera)
	level.add_child(walker)
	var bot := Bot.new()
	var opponent := Visual.new()
	opponent.name = "Body"
	opponent.team = 1
	opponent.set_process(false)
	bot.add_child(opponent)
	game.add_child(bot)
	root.add_child(game)
	bot.setup(game, walker, level)
	if not _config_empty_at_body_ready:
		_fail("test did not exercise child-ready before owner config")
		return
	for visual in [player, opponent]:
		if not is_equal_approx(visual.run_speed, expected):
			_fail("team %d kept run_speed=%s instead of %s" % [visual.team, visual.run_speed, expected])
			return
		# At speed 6 and phase PI/2 the leg angle is exactly the normalized swing.
		# This checks the resulting pose, rather than only the stored config scalar.
		visual.anim_speed = 6.0
		visual.anim_grounded = true
		visual.moving = true
		visual.anim_phase = PI / 2.0
		visual.gait_weight = 1.0
		visual._animate(0.0)
		var angle := lerpf(0.48, 1.05, clampf(6.0 / expected, 0.0, 1.0))
		var leg: MeshInstance3D = visual.get_node("Kid/LegL")
		if not is_equal_approx(leg.rotation.x, angle):
			_fail("team %d leg pose did not follow runSpeed normalization" % visual.team)
			return
		for weapon in ["shooter", "roller", "charger", "blaster"]:
			visual.set_weapon(weapon)
			for id in visual.weapon_models:
				if (visual.weapon_models[id] as Node3D).visible != (id == weapon):
					_fail("team %d weapon visibility did not follow %s" % [visual.team, weapon])
					return
		visual.set_form(true)
		if visual.kid.visible or not visual.squid.visible:
			_fail("squid form visibility regressed")
			return
		visual.set_form(false)
		if not visual.kid.visible or visual.squid.visible:
			_fail("kid form visibility regressed")
			return
	if walker.player_config != payload["player"] or combat.weapon_data != payload:
		_fail("visual configuration mutated gameplay data")
		return
	print("PASS: owner initialization, both teams runSpeed=%s, normalized leg pose, four weapons and forms" % expected)
	quit()


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
