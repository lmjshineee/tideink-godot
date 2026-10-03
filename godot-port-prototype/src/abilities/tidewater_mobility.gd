extends Node

const ROLL_COST := 12.0
const ROLL_TIME := 0.18
const ROLL_SPEED := 15.0
var game: Node3D
var states: Dictionary = {}

func setup(owner_game: Node3D) -> void:
	game = owner_game
	for actor in game.all_actors():
		states[actor.get_instance_id()] = {"time": 0.0, "recover": 0.0, "chain": 0.0,
			"count": 0, "direction": Vector3.ZERO, "precision": 0.0, "ai_wait": 0.0}
	game.get_node("World/Walker").mobility = self

func state(actor: Node3D) -> Dictionary:
	return states[actor.get_instance_id()]

func request_player_roll() -> bool:
	var walker: Node3D = game.get_node("World/Walker")
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not walker.active:
		return false
	var local_axis := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	if local_axis.length_squared() < 0.1:
		return false
	var axis: Vector2 = walker._camera_relative_axis(local_axis.normalized())
	return request(walker, Vector3(axis.x, 0, axis.y))

func request(actor: Node3D, direction: Vector3) -> bool:
	var local: bool = actor == game.get_node("World/Walker")
	var combat: Node3D = game.get_node("Combat")
	var weapon: String = combat.selected_id if local else actor.weapon_id
	if game.phase != "playing" or game.paused or not game.actor_alive(actor) or weapon != "dualie" or game.wings.busy(actor):
		return false
	if local and (not actor.grounded or actor.squid_form or game.deployment.active or combat.special_active != "" or combat.action_lock > 0):
		return false
	if not local and (game.bot_specials.busy(actor) or bool(actor.get_meta("enemy_swimming", false)) or (actor.team_mover != null and not actor.team_mover.is_on_floor()) or float(actor.get_meta("action_lock", 0)) > 0):
		return false
	var s := state(actor)
	if float(s.time) > 0 or (int(s.count) >= 2 and float(s.chain) > 0):
		return false
	var ink_node: Node = combat if local else actor
	if float(ink_node.ink_amount) < ROLL_COST or direction.length_squared() < 0.1:
		return false
	ink_node.ink_amount -= ROLL_COST
	ink_node.last_fire_time = 0.0
	s.time = ROLL_TIME
	s.recover = 0.0
	s.chain = 0.9
	s.count = int(s.count) + 1
	s.total = int(s.get("total", 0)) + 1
	s.direction = Vector3(direction.x, 0, direction.z).normalized()
	s.precision = 0.0
	actor.get_node("Body").set_reaction("jump")
	combat.feedback.emit("jump", actor.global_position, game.actor_team(actor))
	game.play_sound("jump", actor.global_position)
	return true

func rolling(actor: Node3D) -> bool:
	return float(state(actor).time) > 0

func recovering(actor: Node3D) -> bool:
	return float(state(actor).recover) > 0

func busy(actor: Node3D) -> bool:
	return rolling(actor) or recovering(actor) or float(actor.get_meta("action_lock", 0.0)) > 0

func velocity_for(actor: Node3D) -> Vector3:
	return state(actor).direction * ROLL_SPEED * game.items.move_factor(actor)

func precision(actor: Node3D) -> bool:
	return float(state(actor).precision) > 0

func cancel(actor: Node3D) -> void:
	var s := state(actor)
	s.time = 0.0
	s.recover = 0.0
	s.precision = 0.0

func tick(delta: float) -> void:
	for actor in game.all_actors():
		var s := state(actor)
		s.chain = maxf(0, float(s.chain) - delta)
		s.ai_wait = maxf(0, float(s.ai_wait) - delta)
		s.precision = maxf(0, float(s.precision) - delta)
		actor.set_meta("action_lock", maxf(0, float(actor.get_meta("action_lock", 0)) - delta))
		if not game.actor_alive(actor):
			cancel(actor)
			continue
		if float(s.chain) <= 0:
			s.count = 0
		if float(s.time) > 0:
			s.time = maxf(0, float(s.time) - delta)
			if float(s.time) <= 0:
				s.recover = 0.16
				s.precision = 0.7
		else:
			s.recover = maxf(0, float(s.recover) - delta)

func consider_bot_roll(actor: Node3D, target: Node3D) -> void:
	if target == null or actor.weapon_id != "dualie" or float(state(actor).ai_wait) > 0 or busy(actor):
		return
	var recent: float = game.bot_last_damage if actor == game.get_node("Bot") else actor.last_damage
	if recent > 0.7:
		return
	var to: Vector3 = target.global_position - actor.global_position
	if to.length() > 11:
		return
	var side := to.cross(Vector3.UP).normalized() * (1.0 if game.actor_id(actor) % 2 == 0 else -1.0)
	if actor.team_mover == null:
		var checked: Dictionary = actor._ground_at(actor.global_position + side * 2.7)
		if checked.is_empty() or absf(float(checked.position.y) - actor.global_position.y) > 0.4:
			return
	if request(actor, side):
		state(actor).ai_wait = 1.8
