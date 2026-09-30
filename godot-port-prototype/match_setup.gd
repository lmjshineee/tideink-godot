extends RefCounted

# Session-only setup preferences. No gameplay state or on-disk settings.
static var duration_index := 0
static var map_id := "tidewater"
static var team_size := 5
static var style_index := 0
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
