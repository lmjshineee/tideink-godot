extends Node3D

const LIFETIME := 12.0
const RANGE := 18.0
const COST := 25.0
const HEALTH := 40.0
var game: Node3D
var anchors: Dictionary = {}

func setup(owner_game: Node3D) -> void:
	game = owner_game

func use(actor: Node3D) -> bool:
	if (actor == game.get_node("World/Walker") and (game.deployment.live_jump or game.deployment.flying)) or game.mobility.busy(actor):
		return false
	var key := actor.get_instance_id()
	if anchors.has(key):
		var anchor: Dictionary = anchors[key]
		if actor.global_position.distance_to(anchor.point) > RANGE:
			_notice(actor, "超出回溯范围 · 18 m")
			return false
		var checked: Dictionary = game.deployment.landing(Vector2(anchor.point.x, anchor.point.z), false, anchor.point.y, game.actor_team(actor), actor)
		if checked.is_empty() or absf(float(checked.point.y) - float(anchor.point.y)) > 0.15:
			_notice(actor, "锚点落位被占用，暂时不能回溯")
			return false
		actor.set_meta("recall_count", int(actor.get_meta("recall_count", 0)) + 1)
		var from := actor.global_position
		actor.global_position = checked.point
		game.mobility.cancel(actor)
		if actor == game.get_node("World/Walker"):
			actor.reset_movement_state()
			actor.update_form(false)
			game.get_node("Combat").action_lock = 0.35
			actor._update_camera()
		else:
			actor.set_meta("action_lock", 0.35)
			actor.route.clear()
			actor.repath_time = 0.0
			if actor.team_mover != null:
				actor.team_mover.position = Vector3.ZERO
				actor.team_mover.velocity = Vector3.ZERO
		game.get_node("Combat")._ability_ring(from, 0.8, 0.3, game.actor_team(actor))
		game.get_node("Combat")._ability_ring(actor.global_position, 0.8, 0.3, game.actor_team(actor))
		_clear(key)
		_notice(actor, "已回溯 · 生命与墨水保留 · 0.35 秒出枪空档")
		return true
	var ink_node: Node = game.get_node("Combat") if actor == game.get_node("World/Walker") else actor
	if float(ink_node.ink_amount) < COST:
		return false
	var checked: Dictionary = game.deployment.landing(Vector2(actor.global_position.x, actor.global_position.z), false, actor.global_position.y, game.actor_team(actor), actor)
	if checked.is_empty() or absf(float(checked.point.y) - actor.global_position.y) > 0.25:
		return false
	var body := StaticBody3D.new()
	body.collision_layer = 16 if game.actor_team(actor) == 0 else 32
	body.collision_mask = 0
	body.set_meta("recall_owner", actor)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 0.9
	shape.shape = capsule
	shape.position.y = 0.45
	body.add_child(shape)
	var color: Color = preload("res://team_palette.gd").color(game.actor_team(actor))
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lightened(0.2)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.4
	var visual := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.25
	ring.outer_radius = 0.42
	visual.mesh = ring
	visual.position.y = 0.45
	visual.rotation.x = PI * 0.5
	visual.material_override = material
	body.add_child(visual)
	var stem := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 0.23
	cone.height = 0.65
	stem.mesh = cone
	stem.position.y = 0.325
	stem.material_override = material
	body.add_child(stem)
	add_child(body)
	body.global_position = checked.point
	anchors[key] = {"owner": actor, "team": game.actor_team(actor), "point": checked.point,
		"visual": body, "ring": visual, "time": LIFETIME, "health": HEALTH}
	ink_node.ink_amount -= COST
	ink_node.last_fire_time = 0.0
	_notice(actor, "锚点已标记 · 再按 E / 右键回溯 · 12 秒 / 18 m")
	return true

func damage_hit(hit: Dictionary, amount: float, team: int) -> bool:
	if hit.is_empty() or not hit.collider.has_meta("recall_owner"):
		return false
	var owner: Node3D = hit.collider.get_meta("recall_owner")
	var key := owner.get_instance_id()
	if not anchors.has(key) or int(anchors[key].team) == team:
		return false
	anchors[key].health -= maxf(0, amount)
	game.get_node("Combat").feedback.emit("hit", anchors[key].point + Vector3.UP * 0.45, team)
	if float(anchors[key].health) <= 0:
		_notice(owner, "回溯锚被摧毁")
		_clear(key)
	return true

func damage_area(at: Vector3, radius: float, amount: float, team: int) -> void:
	for key in anchors.keys():
		var anchor: Dictionary = anchors[key]
		var target: Vector3 = anchor.point + Vector3.UP * 0.45
		if int(anchor.team) != team and at.distance_to(target) < radius and game.get_node("Combat")._unblocked(at + Vector3.UP * 0.1, target):
			damage_hit({"collider": anchor.visual}, amount, team)

func tick(delta: float) -> void:
	for key in anchors.keys():
		var anchor: Dictionary = anchors[key]
		anchor.time -= delta
		anchor.ring.rotation.z += delta * 2
		anchor.ring.scale = Vector3.ONE * (0.9 + sin(float(anchor.time) * 6) * 0.1)
		if float(anchor.time) <= 0 or not game.actor_alive(anchor.owner):
			_clear(key)

func clear_actor(actor: Node3D) -> void:
	_clear(actor.get_instance_id())

func _clear(key: int) -> void:
	if not anchors.has(key):
		return
	var anchor: Dictionary = anchors[key]
	var state: Dictionary = game.items.state(anchor.owner)
	state.cooldowns.recall = game.perks.item_cooldown(anchor.owner, game.items.COOLDOWNS.recall)
	anchor.visual.queue_free()
	anchors.erase(key)

func clear_all() -> void:
	for key in anchors.keys():
		_clear(key)

func _notice(actor: Node3D, message: String) -> void:
	game.play_sound("special_activate", actor.global_position)
	if actor == game.get_node("World/Walker"):
		game.presentation.notify_ability(message)
