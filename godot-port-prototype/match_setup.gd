extends RefCounted

# Session-only setup preferences. No gameplay state or on-disk settings.
static var duration_index := 0
static var map_id := "tidewater"
static var team_size := 5
static var style_index := 0
static var appearance_seed := -1
static var player_name := "Wave"
static var selected_item := "bomb"
static var selected_perk := "balanced"
static var random_map := false
static var map_variant := 0
static var map_seed := -1
static var reroll_bots := true
static var screen := "home"
static var randomized := false
static var pending_loadout: Dictionary = {}


static func duration(config: Dictionary) -> float:
	var options: Array = config.get("durations", [])
	if options.is_empty():
		return float(config.get("defaultDuration", 180))
	return float(options[clampi(duration_index, 0, options.size() - 1)])


static func take_loadout() -> Dictionary:
	var loadout := pending_loadout.duplicate()
	pending_loadout.clear()
	return loadout


static func random_appearance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	style_index = rng.randi_range(0,3)
	appearance_seed = int(rng.randi() & 0x7fffffff)
	preload("res://team_palette.gd").random_pair(rng)
	randomized = true

static func ensure_randomized() -> void:
	if not randomized:
		random_appearance()
