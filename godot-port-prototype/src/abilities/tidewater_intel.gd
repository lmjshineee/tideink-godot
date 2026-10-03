extends Node3D

# Team information contains observations, never hidden actors' current transforms.
const VISION_RANGE := 30.0
const MEMORY_TIME := 1.5
const TAG_TIME := 2.0
var game: Node3D
var clock := 0.0
var refresh_time := 0.0
var contacts: Array[Dictionary] = [{}, {}]
var tags: Array[Dictionary] = [{}, {}]
var shot_until: Dictionary = {}
var labels: Dictionary = {}

func setup(owner_game: Node3D) -> void:
	game = owner_game

func concealed(actor: Node3D) -> bool:
	if actor == game.get_node("World/Walker"):
		return bool(actor.squid_form) and bool(actor.grounded) and (actor._floor_ink_owner() == 0 or (actor.enemy_swim_enabled and actor._floor_ink_owner() == 1))
	return bool(actor.get_meta("enemy_swimming", false))

func point(actor: Node3D) -> Vector3:
	return actor.global_position + Vector3.UP * (.3 if concealed(actor) else .85)

func can_see(observer: Node3D, target: Node3D) -> bool:
	if not game.actor_alive(observer) or not game.actor_alive(target): return false
	var distance: float = observer.global_position.distance_to(target.global_position)
	if distance > VISION_RANGE: return false
	var flashed := float(shot_until.get(target.get_instance_id(), 0)) > clock
	var tagged := float(tags[game.actor_team(observer)].get(target.get_instance_id(), 0)) > clock
	if concealed(target) and distance > 2.5 and not flashed and not tagged: return false
	if not game.get_node("Combat")._unblocked(point(observer), point(target)): return false
	return tagged or not game.items.mist.obscures(point(observer),point(target),game.actor_team(observer))

func visible_point(at: Vector3, team: int) -> bool:
	for observer in game.all_actors():
		if game.actor_team(observer) == team and game.actor_alive(observer) and observer.global_position.distance_to(at) <= VISION_RANGE and game.get_node("Combat")._unblocked(point(observer), at) and not game.items.mist.obscures(point(observer),at,team): return true
	return false

func on_shot(actor: Node3D) -> void:
	if actor != null: shot_until[actor.get_instance_id()] = clock + .9

func tag(actor: Node3D, team: int) -> void:
	if game.actor_alive(actor) and game.actor_team(actor) != team:
		tags[team][actor.get_instance_id()] = clock + TAG_TIME
		_record(actor, team, "sonar")

func _record(actor: Node3D, team: int, status: String) -> void:
	contacts[team][actor.get_instance_id()] = {"actor": actor, "point": actor.global_position,
		"yaw": actor.get_node("Body").rotation.y, "time": clock, "status": status}

func marker(actor: Node3D, team: int) -> Dictionary:
	if game.actor_team(actor) == team:
		return {"actor": actor, "point": actor.global_position, "yaw": float(actor.camera_yaw) if actor == game.get_node("World/Walker") else actor.get_node("Body").rotation.y, "status": "ally"}
	var key := actor.get_instance_id()
	if not game.actor_alive(actor) or not contacts[team].has(key): return {}
	var contact: Dictionary = contacts[team][key]
	if clock - float(contact.time) > MEMORY_TIME: return {}
	return contact.duplicate()

func nearest_contact(observer: Node3D) -> Dictionary:
	var result := {}
	var best := 22.0
	for enemy in game.enemies(game.actor_team(observer)):
		var info := marker(enemy, game.actor_team(observer))
		if info.is_empty(): continue
		var gap: float = observer.global_position.distance_to(info.point)
		if gap < best: best = gap; result = info
	return result

func forget(actor: Node3D) -> void:
	var key := actor.get_instance_id()
	for team in range(2): contacts[team].erase(key); tags[team].erase(key)
	shot_until.erase(key)
	if labels.has(key): labels[key].visible = false

func tick(delta: float) -> void:
	clock += delta
	refresh_time -= delta
	if refresh_time > 0: return
	refresh_time = .15
	refresh()

func refresh() -> void:
	for actor in game.all_actors():
		if not game.actor_alive(actor): forget(actor); continue
		var key: int = actor.get_instance_id()
		var team: int = 1 - game.actor_team(actor)
		var status := "last"
		if float(tags[team].get(key, 0)) > clock:
			status = "sonar"
		else:
			tags[team].erase(key)
			for observer in game.all_actors():
				if game.actor_team(observer) == team and can_see(observer, actor):
					status = "seen"; break
		if status != "last": _record(actor, team, status)
		elif contacts[team].has(key):
			contacts[team][key].status = "last"
			if clock - float(contacts[team][key].time) > MEMORY_TIME: contacts[team].erase(key)
		if actor != game.get_node("World/Walker"):
			actor.health_bar.visible = game.actor_team(actor) == 0 or can_see(game.get_node("World/Walker"), actor)
		_world_tag(actor)
	for key in shot_until.keys():
		if float(shot_until[key]) <= clock: shot_until.erase(key)

func _world_tag(actor: Node3D) -> void:
	var key := actor.get_instance_id()
	var active: bool = game.actor_team(actor) == 1 and float(tags[0].get(key, 0)) > clock
	if active and not labels.has(key):
		var label := Label3D.new()
		label.font = preload("res://assets/fonts/NotoSansSC.ttf")
		label.font_size = 36
		label.pixel_size = .008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.render_priority = 100
		label.modulate = preload("res://src/core/team_palette.gd").color(1).lightened(.4)
		label.outline_size = 8
		add_child(label)
		labels[key] = label
	if labels.has(key):
		labels[key].visible = active
		labels[key].global_position = point(actor) + Vector3.UP * .8
		labels[key].text = "◎ 声呐 · %.0fm" % actor.global_position.y

func clear_all() -> void:
	contacts = [{}, {}]; tags = [{}, {}]; shot_until.clear()
	for label in labels.values(): label.queue_free()
	labels.clear()
