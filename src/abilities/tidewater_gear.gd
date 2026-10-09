extends RefCounted

const Catalog := preload("res://src/core/gear_catalog.gd")
const Setup := preload("res://src/core/match_setup.gd")
var game: Node3D
var _loadouts: Dictionary = {}
var _totals: Dictionary = {}
var _bots_prepared := false

func setup(owner_game: Node3D) -> void:
	game = owner_game
	Setup.selected_gear = Catalog.normalize(Setup.selected_gear)
	for actor in game.all_actors():
		_store(actor, Setup.selected_gear if actor == game.get_node("World/Walker") else Catalog.empty())

func prepare_bots() -> void:
	if _bots_prepared: return
	var shape := loadout(game.get_node("World/Walker"))
	for actor in game.all_actors():
		if actor == game.get_node("World/Walker"): continue
		var value := Catalog.roll(game.equipment_rng, {})
		for piece in Catalog.PIECES:
			for index in 4:
				if shape[piece][index] == "none": value[piece][index] = "none"
		_store(actor, value)
	_bots_prepared = true

func _store(actor: Node3D, value: Dictionary) -> void:
	var clean := Catalog.normalize(value)
	_loadouts[actor.get_instance_id()] = clean
	_totals[actor.get_instance_id()] = Catalog.points(clean)

func loadout(actor: Node3D) -> Dictionary:
	return _loadouts.get(actor.get_instance_id(), Catalog.empty()).duplicate(true)

func totals(actor: Node3D) -> Dictionary:
	return _totals.get(actor.get_instance_id(), {}).duplicate()

func bonus(actor: Node3D, ability: String) -> float:
	return Catalog.bonus(ability, int(_totals.get(actor.get_instance_id(), {}).get(ability, 0)))

func can_edit() -> bool:
	return game.phase in ["home", "setup"] and game.perks != null and not game.perks.locked

func select_player(value: Dictionary) -> bool:
	if not can_edit() or not Catalog.valid(value): return false
	var actor: Node3D = game.get_node("World/Walker")
	_store(actor, value)
	Setup.selected_gear = loadout(actor)
	game.perks.apply_movement()
	return true

func select_slot(piece: String, index: int, ability: String) -> bool:
	if not Catalog.PIECES.has(piece) or index < 0 or index > 3 or not Catalog.LABELS.has(ability): return false
	var next := loadout(game.get_node("World/Walker"))
	next[piece][index] = ability
	return select_player(next)

func roll_player() -> bool:
	if not can_edit(): return false
	return select_player(Catalog.roll(game.equipment_rng, loadout(game.get_node("World/Walker"))))

func summary(actor: Node3D) -> String:
	var parts: Array[String] = []
	for ability in Catalog.ABILITIES:
		var value := bonus(actor, ability)
		if value <= 0: continue
		parts.append("%s %s%.1f%%" % [Catalog.LABELS[ability], "−" if ability in ["main_saver", "sub_cooldown"] else "+", value * 100])
	return "12 个空槽 · 点击选择或 ROLL" if parts.is_empty() else " · ".join(parts)
