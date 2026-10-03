extends RefCounted

# config.js TEAM_PALETTES / COLORBLIND_PALETTE / TEAM_NAMES, reached through the export at
# assets/weapons.json -> teams + text.teams.
#
# Six scripts used to carry their own copy of the same two colours (surface_ink_view,
# paint_field, tidewater_combat, tidewater_character_visual, tidewater_play, main). They
# all read them here now, so the palette is config.js data instead of six literals, and
# check_team_palette.gd fails if a copy grows back.
#
# select() and set_colorblind() must run before scene creation. The ink view
# captures the same palette as character materials, spawn pads and HUD labels.
# No settings UI or live-match switching is part of this batch.
#
# Colours taken at build time stay put: label and material colours are assigned while the
# scene builds, so a switch applies to visuals built afterwards unless the caller rebuilds
# them. Nothing rebuilds yet, which is the other half of why there is no switch UI.
static var palette_index := 0
static var random_palette: Dictionary = {}
static var use_colorblind := false
static var _payload: Dictionary = {}


static func _data() -> Dictionary:
	if _payload.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons.json"))
		if parsed is Dictionary:
			_payload = parsed
		if (((_payload.get("teams", {}) as Dictionary).get("palettes", [])) as Array).is_empty():
			push_error("assets/weapons.json carries no teams.palettes; team colours are unavailable")
	return _payload


static func palettes() -> Array:
	return (_data().get("teams", {}) as Dictionary).get("palettes", [])


# The palette in force: the colourblind one when it is switched on, else the selected one.
static func current() -> Dictionary:
	var teams: Dictionary = _data().get("teams", {})
	if use_colorblind and teams.get("colorblind") is Dictionary:
		return teams["colorblind"]
	if not random_palette.is_empty():
		return random_palette
	var list: Array = teams.get("palettes", [])
	return {} if list.is_empty() else list[clampi(palette_index, 0, list.size() - 1)]


# Team 0 is the palette's first colour (`a`), team 1 its second (`b`).
static func color(team: int) -> Color:
	var entry := current()
	return Color(String(entry.get("a" if team == 0 else "b", "#ffffff")))


# menus.js:339 shows the palette's own names and falls back to TEAM_NAMES when a palette
# has none; i18n turns those English names into the labels exported as text.teams[id].
static func display_name(team: int) -> String:
	var entry := current()
	var teams: Dictionary = _data().get("teams", {})
	var palette_names: Array = entry.get("names", [])
	var fallback_names: Array = teams.get("names", [])
	var name := ""
	if team < palette_names.size():
		name = String(palette_names[team])
	elif team < fallback_names.size():
		name = String(fallback_names[team])
	var localised: Dictionary = (_data().get("text", {}) as Dictionary).get("teams", {})
	var labels: Array = localised.get(String(entry.get("id", "")), [])
	return String(labels[team]) if team < labels.size() else name


static func select(index: int) -> void:
	random_palette.clear()
	palette_index = clampi(index, 0, maxi(0, palettes().size() - 1))


static func set_colorblind(enabled: bool) -> void:
	use_colorblind = enabled


# Original colour pairs, varied together in hue and saturation. Material creation
# follows this choice, so every scene, model, map and UI shares one pair.
static func random_pair(rng: RandomNumberGenerator) -> void:
	palette_index = rng.randi_range(0,palettes().size()-1)
	random_palette = palettes()[palette_index].duplicate(true)
	var shift := rng.randf_range(-0.055,0.055)
	for key in ["a","b"]:
		var c := Color(String(random_palette[key]))
		random_palette[key] = Color.from_hsv(fposmod(c.h+shift,1.0),rng.randf_range(0.82,1.0),rng.randf_range(0.92,1.0)).to_html()
	if rng.randf()<0.5:
		var a: String = random_palette["a"]
		random_palette["a"] = random_palette["b"]
		random_palette["b"] = a
		var names: Array = random_palette.get("names",[])
		names.reverse()
	# Names identify sides consistently when colours are varied or swapped.
	random_palette["id"] = "random"
	random_palette["names"] = ["我方","对方"]
