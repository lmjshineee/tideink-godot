extends SceneTree

# config.js TEAM_PALETTES / COLORBLIND_PALETTE, reached through assets/weapons.json.
#
# Two things are being pinned here. First, that the team colours really are palette data:
# six scripts used to carry the same two literals, so the way to tell a data lookup from
# another copy is to select a different palette and watch the colours move. Second, that
# no second copy grows back — the scan at the end fails if any production script hardcodes
# a palette colour.
const TeamPalette := preload("res://team_palette.gd")



func _initialize() -> void:
	preload("res://match_setup.gd").team_size = 1
	preload("res://match_setup.gd").randomized = true
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

	# All five palettes plus colorblind must reach every visible team consumer.
	var baseline_owners: Array = []
	var baseline_coverage: Array = []
	for mode in range(palettes.size() + 1):
		TeamPalette.select(mode if mode < palettes.size() else 0)
		TeamPalette.set_colorblind(mode == palettes.size())
		var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
		root.add_child(scene)
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		# Scenery adds pads/murals deferred, after the map has built its surfaces.
		await process_frame
		var wanted := [TeamPalette.color(0), TeamPalette.color(1)]
		for team in range(2):
			var body: Node3D = scene.get_node("World/Walker/Body" if team == 0 else "Bot/Body")
			var hair: MeshInstance3D = body.get_node("Kid/HairCap")
			var pad: MeshInstance3D = scene.get_node("World/Map/Scenery/SpawnPad_%d" % team)
			if (hair.material_override as StandardMaterial3D).albedo_color != wanted[team] \
				or (pad.material_override as ShaderMaterial).get_shader_parameter("team_color") != wanted[team]:
				_fail("character/spawn pad palette mismatch")
				return
			var score: Label = scene.get("orange_score" if team == 0 else "blue_score")
			if not score.text.begins_with(TeamPalette.display_name(team)):
				_fail("HUD/setup names do not follow selected palette")
				return
		var combat: Node3D = scene.get_node("Combat")
		for team in range(2):
			combat.call("_spawn_projectile", "shooter", Vector3(0, 3, 0), Vector3(0, 0, 1), combat.get("weapons")["shooter"], team)
			var shots: Array = combat.get("projectiles")
			var shot: MeshInstance3D = shots.back()["visual"]
			if (shot.material_override as StandardMaterial3D).albedo_color != wanted[team]:
				_fail("projectile palette mismatch")
				return
		var ink: RefCounted = scene.get("ink")
		var face: Dictionary = ink.get("surfaces")[12]
		var u := float(face["su"]) * 0.5
		var v := float(face["sv"]) * 0.5
		ink.call("splat_face", 12, u, v, 1.2, 0, 0.5)
		ink.call("splat_face", 12, u + 0.5, v, 0.6, 1, 0.5)
		var owners: Array = ink.get("owners").duplicate(true)
		var coverage := [ink.call("coverage", 0), ink.call("coverage", 1)]
		var view: Node3D = scene.get_node("InkView")
		view.call("sync_dirty")
		var material := (view.get_node("InkFace_12") as MeshInstance3D).material_override as ShaderMaterial
		if material.get_shader_parameter("team_a") != wanted[0] or material.get_shader_parameter("team_b") != wanted[1]:
			_fail("ink shader palette mismatch")
			return
		var image: Image = view.get("images")[12]
		var grid: Dictionary = face["grid"]
		var face_owners: PackedByteArray = owners[12]
		for cell in range(face_owners.size()):
			var owner := int(face_owners[cell])
			var expected := Color(0, 0, 0, 0) if owner == 0 else Color(1, 0, 0, 1) if owner == 1 else Color(0, 1, 0, 1)
			if image.get_pixel(cell % int(grid["nu"]), cell / int(grid["nu"])) != expected:
				_fail("ink mask changed team ownership at a cell/overpaint edge")
				return
		if owners != ink.get("owners") or coverage != [ink.call("coverage", 0), ink.call("coverage", 1)]:
			_fail("visual synchronization changed CPU ownership/coverage")
			return
		if mode == 0:
			baseline_owners = owners
			baseline_coverage = coverage
		elif owners != baseline_owners or coverage != baseline_coverage:
			_fail("palette selection changed CPU paint results")
			return
		scene.call("_judge_round")
		if not String(scene.get("result")).begins_with(TeamPalette.display_name(int(scene.get("winner")))):
			_fail("winner label does not follow palette")
			return
		for team in range(2):
			if not (scene.get("result_label") as Label).text.contains(TeamPalette.display_name(team)):
				_fail("results coverage/turf names do not follow palette")
				return
		scene.free()
	TeamPalette.set_colorblind(false)
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
		if not file.ends_with(".gd") :
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
	print("PASS: all five palettes + colorblind reach characters, projectiles, pads, ink shader and HUD names; masks and CPU coverage stay identical; no color copies")
	quit()


func _differs(got: Color, hex: String) -> bool:
	var want := Color(hex)
	return absf(got.r - want.r) > 0.001 or absf(got.g - want.g) > 0.001 or absf(got.b - want.b) > 0.001


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
