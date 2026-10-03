extends SceneTree
const SourceInventory := preload("res://tools/lib/source_inventory.gd")

# Configuration-consumption gate.
#
# The port has lost track of exported data three separate times, each invisible because
# "the data is in the JSON" looks identical to "the data is used":
#   * a hand-written whitelist silently dropped 25 of PLAYER's 88 fields;
#   * `finalCountdown` was exported while the HUD hardcoded 10;
#   * `spawnBarrier` sat in the map export with no reader at all until T05.
#
# So every leaf field of the three exported JSONs must either appear as a quoted string
# key in a production script — which is how GDScript reads JSON — or be listed in
# ALLOWED with the reason it has no runtime consumer. Adding a field to an exporter
# therefore forces a decision instead of creating a silent gap, and deleting the last
# consumer of a field fails here rather than in a playtest.
#
# ALLOWED is the written record: keep each reason short and true, and delete the entry
# as soon as the field is consumed. Keys are JSON paths (array indices are dropped), and
# an entry also covers everything below it, so `....stats` covers `....stats.mobility`.
# Entries that no longer match any exported field fail too, so the record cannot rot.
#
# Known limit of the rule: matching is by field name across every production script, so
# one consumer of a common name (id, name, size) clears that name everywhere. It catches
# whole missing systems — which is the failure mode that actually happened three times —
# not a field that shares a name with something else.
const SOURCES := [
	"res://assets/weapons.json",
	"res://assets/maps/tidewater.json",
	"res://assets/maps/tidewater_surfaces.json",
]

const ALLOWED := {
	# Unused by the web game itself: config.js keeps them as legacy names.
	"weapons.json.player.accelGround": "legacy in config.js; runAccel supersedes it",
	"weapons.json.player.accelAir": "legacy in config.js; airAccel supersedes it",
	"weapons.json.player.accelSwim": "legacy in config.js; swimAccel supersedes it",
	# Menu and stats text: there is no stats screen in the demo yet.
	"weapons.json.game": "game title/subtitle/version are display text",
	"weapons.json.weapons.shooter.name": "English brand name; the UI shows text.weapons[id]",
	"weapons.json.weapons.shooter.blurb": "display text",
	"weapons.json.weapons.shooter.stats": "weapon stats screen not ported",
	"weapons.json.weapons.roller.name": "English brand name; the UI shows text.weapons[id]",
	"weapons.json.weapons.roller.blurb": "display text",
	"weapons.json.weapons.roller.stats": "weapon stats screen not ported",
	"weapons.json.weapons.charger.name": "English brand name; the UI shows text.weapons[id]",
	"weapons.json.weapons.charger.blurb": "display text",
	"weapons.json.weapons.charger.stats": "weapon stats screen not ported",
	"weapons.json.weapons.blaster.name": "English brand name; the UI shows text.weapons[id]",
	"weapons.json.weapons.blaster.blurb": "display text",
	"weapons.json.weapons.blaster.stats": "weapon stats screen not ported",
	"weapons.json.specials.slam.name": "English name; the UI would show text.specials[id]",
	"weapons.json.specials.slam.blurb": "display text",
	"weapons.json.specials.storm.name": "English name; the UI would show text.specials[id]",
	"weapons.json.specials.storm.blurb": "display text",
	"weapons.json.sub.bomb.name": "English name; the UI would show text.sub[id]",
	# Superseded by a normalised field the exporter adds for the port.
	"weapons.json.weapons.shooter.spreadGround": "superseded by the exporter's spreadBaseGround",
	"weapons.json.weapons.shooter.spreadAir": "superseded by the exporter's spreadBaseAir",
	# Declared gaps: recorded in MIGRATION.md, waiting for the batch that owns them.
	"weapons.json.match.teamSize": "1v1 prototype; the roster batch consumes it",
	# Consumed through text.weapons[weapon_id], so the field names below are keys the
	# production code never spells out.
	"weapons.json.text": "looked up as text.weapons[weapon_id] and text for other groups",
	# Provenance written by the exporters for traceability; the map reader uses `geometry`.
	"weapons.json.source": "provenance",
	"tidewater.json.source": "provenance",
	"tidewater.json.layout": "provenance",
	"tidewater_surfaces.json.source": "provenance",
	"tidewater_surfaces.json.layout": "provenance",
	"tidewater.json.blocks.min": "source-form provenance; tidewater_map.gd reads geometry instead",
	"tidewater.json.blocks.max": "source-form provenance; tidewater_map.gd reads geometry instead",
	"tidewater.json.blocks.low": "source-form provenance; tidewater_map.gd reads geometry instead",
	"tidewater.json.blocks.high": "source-form provenance; tidewater_map.gd reads geometry instead",
	"tidewater.json.blocks.width": "source-form provenance; tidewater_map.gd reads geometry instead",
	"tidewater.json.blocks.thickness": "source-form provenance; tidewater_map.gd reads geometry instead",
	# Data invariants that only a check reads; asserted by check_tidewater_scene.gd.
	"tidewater.json.structuralBlocks": "asserted by check_tidewater_scene.gd",
	"tidewater.json.dressing": "cross-checked against the surfaces export by check_tidewater_scene.gd",
	"tidewater_surfaces.json.dressing": "cross-checked against the map export by check_tidewater_scene.gd",
	"tidewater_surfaces.json.cellSize": "asserted by check_tidewater_scene.gd",
	"tidewater_surfaces.json.gridCells": "asserted by check_tidewater_scene.gd",
}


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var consumed := _production_source_text()
	if consumed.is_empty():
		_fail("no production script sources were readable; this gate needs a dev checkout")
		return
	var gaps: Dictionary = {}
	var exported: Dictionary = {}
	for file in SOURCES:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not parsed is Dictionary:
			_fail("could not parse " + file)
			return
		_collect(parsed, file.get_file(), gaps, consumed, exported)
	# A key that no longer matches any path means the export moved or dropped a field and
	# this record would otherwise keep claiming an exemption for something that is gone.
	var stale: Array = []
	for key in ALLOWED:
		if not exported.has(key):
			stale.append(key)
	if not stale.is_empty():
		stale.sort()
		printerr("FAIL: ALLOWED entries that no longer match any exported field:")
		for entry in stale:
			printerr("   ", entry, "  (", ALLOWED[entry], ")")
		quit(1)
		return
	if not gaps.is_empty():
		printerr("FAIL: exported fields with no consumer and no recorded reason:")
		var gap_paths: Array = gaps.keys()
		gap_paths.sort()
		for entry in gap_paths:
			printerr("   ", entry)
		printerr("Either read the field in a production script, or add its JSON path to ALLOWED in %s with a reason."
			% "res://tests/godot/check_config_consumption.gd")
		quit(1)
		return
	print("PASS: all exported fields are consumed by a production script or have a recorded reason (%d recorded)"
		% ALLOWED.size())
	quit()


# A field counts as consumed when it appears as a quoted string key: that is how every
# JSON field is read in GDScript, and it avoids matching unrelated identifiers such as a
# variable called `title`.
func _is_referenced(consumed: String, name: String) -> bool:
	return consumed.contains("\"" + name + "\"") or consumed.contains("'" + name + "'")


func _is_allowed(path: String) -> bool:
	if ALLOWED.has(path):
		return true
	for key in ALLOWED:
		if path.begins_with(String(key) + "."):
			return true
	return false


func _collect(value: Variant, path: String, gaps: Dictionary, consumed: String, exported: Dictionary) -> void:
	if value is Dictionary:
		for key in value:
			var name := String(key)
			var here := path + "." + name
			exported[here] = true
			if not _is_referenced(consumed, name) and not _is_allowed(here):
				gaps[here] = true
			_collect(value[key], here, gaps, consumed, exported)
	elif value is Array:
		for item in value:
			_collect(item, path, gaps, consumed, exported)


# Only src/ contains production scripts. Tests and tools are excluded, so a check
# reading a field does not count as a runtime consumer.
func _production_source_text() -> String:
	var text := ""
	for path in SourceInventory.scripts():
		text += "\n" + FileAccess.get_file_as_string(path)
	return text


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
