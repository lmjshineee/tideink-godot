extends SceneTree

# config.js TEAM_PALETTES / COLORBLIND_PALETTE, reached through assets/weapons.json.
#
# Two things are being pinned here. First, that the team colours really are palette data:
# six scripts used to carry the same two literals, so the way to tell a data lookup from
# another copy is to select a different palette and watch the colours move. Second, that
# no second copy grows back — the scan at the end fails if any production script hardcodes
# a palette colour, with the one deliberate exception named below.
const TeamPalette := preload("res://team_palette.gd")

# The ink's colours are written into its textures inside surface_ink_view.gd, which
# carries another workstream's uncommitted changes this round and exposes them as a
# `const`, so a palette switch cannot reach them from outside. One line at its
# `TEAM_COLORS[value - 1]` lookup retires this exception.
const KNOWN_COPY := {
	"surface_ink_view.gd": "ink colours are baked into its textures; another workstream's file",
}


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons.json"))
	var teams: Dictionary = payload["teams"]
	var palettes: Array = teams["palettes"]
	var text_teams: Dictionary = (payload["text"] as Dictionary)["teams"]
	if TeamPalette.palettes().size() != palettes.size():
		_fail("TeamPalette does not see the exported palettes: %d vs %d" % [
			TeamPalette.palettes().size(), palettes.size()])
		return

	# 1. the palette in force is the exported default, label included.
	if _differs(TeamPalette.color(0), String(palettes[0]["a"])) \
			or _differs(TeamPalette.color(1), String(palettes[0]["b"])):
		_fail("team colours are not the exported first palette")
		return
	var expected_label := String((text_teams[String(palettes[0]["id"])] as Array)[0])
	if TeamPalette.display_name(0) != expected_label:
		_fail("palette label is not the exported one: %s" % TeamPalette.display_name(0))
		return

	# 2. selecting another palette actually moves them (a copy could not).
	TeamPalette.select(2)
	if _differs(TeamPalette.color(0), String(palettes[2]["a"])) \
			or _differs(TeamPalette.color(1), String(palettes[2]["b"])):
		_fail("select(2) did not switch the palette")
		return
	if TeamPalette.display_name(0) != String((text_teams[String(palettes[2]["id"])] as Array)[0]):
		_fail("select(2) did not switch the palette label")
		return

	# 3. the colourblind palette replaces it, as settings.colorblind does in the web.
	TeamPalette.set_colorblind(true)
	if _differs(TeamPalette.color(0), String(teams["colorblind"]["a"])) \
			or _differs(TeamPalette.color(1), String(teams["colorblind"]["b"])):
		_fail("the colourblind palette is not applied")
		return
	TeamPalette.set_colorblind(false)

	# 4. a scene built while a palette is selected wears it: HUD text and character ink.
	TeamPalette.select(1)
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var wanted := TeamPalette.color(0)
	if (scene.get("orange_score") as Label).get_theme_color("font_color") != wanted:
		_fail("the HUD did not take the selected palette")
		return
	var hair: MeshInstance3D = scene.get_node("World/Walker/Body/Kid/HairCap")
	if (hair.material_override as StandardMaterial3D).albedo_color != wanted:
		_fail("the player's character did not take the selected palette")
		return
	scene.queue_free()
	TeamPalette.select(0)

	# 5. no production script keeps its own copy of a palette colour.
	# The export writes "#rrggbb" while GDScript literals are "rrggbb", so the hash has to
	# come off before comparing; an earlier version of this scan compared with it and could
	# therefore never find anything.
	var hexes: Array = []
	for palette in palettes:
		hexes.append(String(palette["a"]).lstrip("#").to_lower())
		hexes.append(String(palette["b"]).lstrip("#").to_lower())
	hexes.append(String(teams["colorblind"]["a"]).lstrip("#").to_lower())
	hexes.append(String(teams["colorblind"]["b"]).lstrip("#").to_lower())
	var offenders: Array = []
	for file in DirAccess.get_files_at("res://"):
		if not file.ends_with(".gd") or KNOWN_COPY.has(file):
			continue
		var source := FileAccess.get_file_as_string("res://" + file).to_lower()
		for hex in hexes:
			if source.contains(hex):
				offenders.append("%s (%s)" % [file, hex])
				break
	if not offenders.is_empty():
		printerr("FAIL: these scripts hardcode a palette colour; read TeamPalette.color() instead:")
		for entry in offenders:
			printerr("   ", entry)
		quit(1)
		return
	# The exception must still be needed, or the record above is stale.
	if not FileAccess.get_file_as_string("res://surface_ink_view.gd").to_lower().contains(
			String(palettes[0]["a"]).lstrip("#").to_lower()):
		_fail("surface_ink_view.gd no longer hardcodes a palette colour; delete it from KNOWN_COPY")
		return

	print("PASS: team colours come from the exported palette (%d palettes + colourblind), "
		% TeamPalette.palettes().size()
		+ "select() and set_colorblind() move them, scenes build with them, and only the "
		+ "documented ink view keeps a copy")
	quit()


func _differs(got: Color, hex: String) -> bool:
	var want := Color(hex)
	return absf(got.r - want.r) > 0.001 or absf(got.g - want.g) > 0.001 or absf(got.b - want.b) > 0.001


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
