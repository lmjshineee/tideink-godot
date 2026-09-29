extends RefCounted

# config.js TEAM_PALETTES / COLORBLIND_PALETTE / TEAM_NAMES, reached through the export at
# assets/weapons.json -> teams + text.teams.
#
# Six scripts used to carry their own copy of the same two colours (surface_ink_view,
# paint_field, tidewater_combat, tidewater_character_visual, tidewater_play, main). They
# all read them here now, so the palette is config.js data instead of six literals, and
# check_team_palette.gd fails if a copy grows back.
#
# The web picks a palette in its settings and swaps COLORBLIND_PALETTE in when
# settings.colorblind is on; select() and set_colorblind() are that switch. No UI calls
# them yet, on purpose: the ink's colours are baked into surface_ink_view.gd, which
# carries another workstream's uncommitted changes, so switching today would recolour the
# HUD, the characters and the projectiles while the paint on the ground stayed orange and
# blue. Once that file reads color() (one line at its `TEAM_COLORS[value - 1]` lookup), a
# settings entry can call these two.
#
# Colours taken at build time stay put: label and material colours are assigned while the
# scene builds, so a switch applies to visuals built afterwards unless the caller rebuilds
# them. Nothing rebuilds yet, which is the other half of why there is no switch UI.
static var palette_index := 0
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
	palette_index = clampi(index, 0, maxi(0, palettes().size() - 1))


static func set_colorblind(enabled: bool) -> void:
	use_colorblind = enabled
