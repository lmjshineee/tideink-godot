extends SceneTree

# match.pointsPerM2 finally has a consumer: actor.js:116-125 credits the turf an actor
# paints, and hud.js:482 turns that into points with `area * (MATCH.pointsPerM2 || 1)`
# for the local player's HUD counter, which hud.js:983-985 lets climb toward the true
# value instead of jumping to it. The results rows (menus.js:1400) show the raw area.
#
# The shipped config sets pointsPerM2 to 1, so comparing numbers would pass even for a
# hardcoded multiplier of one. Every case below therefore also drives an injected value.
#
# Painting happens on the orange spawn deck (surface face 38: origin (9, 2.2, -43.4),
# 18 x 8.4 m, turf and paintable, which contains the player's spawn). Four spots along it
# are used so no case repaints ink another case already claimed.
var scene: Node3D
var walker: CharacterBody3D


func _initialize() -> void:
	preload("res://src/core/match_setup.gd").team_size = 1
	call_deferred("_check")


func _check() -> void:
	scene = (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	walker = scene.get_node("World/Walker")
	var data: Dictionary = scene.get_node("Combat").get("weapon_data")
	var exported := float((data["match"] as Dictionary)["pointsPerM2"])
	if absf(float(scene.get("_points_per_m2")) - exported) > 0.000001:
		_fail("the HUD scale does not come from match.pointsPerM2: %s vs %s" % [
			scene.get("_points_per_m2"), exported])
		return
	if float(scene.get("player_respawn")) > 0.0:
		_fail("the check expects a live player")
		return
	var feet := walker.global_position

	# 1. a live player's paint adds its area, and points at the exported scale.
	var area := _paint_at(feet.x, feet.z, 0)
	var area_after := float((scene.get("turf_area") as Array)[0])
	var total_after := float(scene.get("turf_total"))
	if absf(area_after - area) > 0.0001 or absf(total_after - area * exported) > 0.0001:
		_fail("player paint did not reach the ledger: area=%.4f ledger=%.4f points=%.4f" % [
			area, area_after, total_after])
		return

	# 2. the scale is read, not assumed: a different pointsPerM2 changes the points only.
	scene.set("_points_per_m2", 7.0)
	var before_total := float(scene.get("turf_total"))
	var injected_area := _paint_at(feet.x + 5.0, feet.z, 0)
	if absf(float(scene.get("turf_total")) - before_total - injected_area * 7.0) > 0.0001:
		_fail("points do not follow match.pointsPerM2: gained %.4f for area %.4f" % [
			float(scene.get("turf_total")) - before_total, injected_area])
		return
	scene.set("_points_per_m2", exported)

	# 3. the other team's paint belongs to that team, not to the player's points.
	var blue_before := float((scene.get("turf_area") as Array)[1])
	before_total = float(scene.get("turf_total"))
	var blue_area := _paint_at(feet.x - 5.0, feet.z, 1)
	if absf(float((scene.get("turf_area") as Array)[1]) - blue_before - blue_area) > 0.0001:
		_fail("blue paint did not reach the blue ledger")
		return
	if absf(float(scene.get("turf_total")) - before_total) > 0.0001:
		_fail("blue paint was credited to the player's points")
		return

	# 4. a splatted player's paint still counts as area but not as points (hud.js `_live()`).
	scene.set("player_respawn", 3.0)
	var area_before := float((scene.get("turf_area") as Array)[0])
	before_total = float(scene.get("turf_total"))
	var dead_area := _paint_at(feet.x + 2.5, feet.z, 0)
	if absf(float((scene.get("turf_area") as Array)[0]) - area_before - dead_area) > 0.0001:
		_fail("a splatted player's paint stopped counting as area")
		return
	if absf(float(scene.get("turf_total")) - before_total) > 0.0001:
		_fail("a splatted player still earned points")
		return
	scene.set("player_respawn", 0.0)

	# 5. the shown value climbs toward the total (6/s or 7x the gap) and never overshoots.
	scene.set("turf_total", 42.0)
	scene.set("turf_shown", 0.0)
	scene.call("_update_turf_display", 0.1)
	var first := float(scene.get("turf_shown"))
	if absf(first - 29.4) > 0.0001:
		_fail("first display step is not 7x the gap: %.4f" % first)
		return
	scene.call("_update_turf_display", 0.1)
	var second := float(scene.get("turf_shown"))
	if second <= first or second > 42.0:
		_fail("display value did not climb toward the total: %.4f -> %.4f" % [first, second])
		return
	scene.set("turf_total", 10.0)
	scene.set("turf_shown", 9.9)
	scene.call("_update_turf_display", 0.1)
	if absf(float(scene.get("turf_shown")) - 10.0) > 0.0001:
		_fail("the 6 points/s floor or the clamp is missing: %.4f" % float(scene.get("turf_shown")))
		return

	# 6. both numbers reach the HUD: points while playing, raw area on the results panel.
	scene.set("phase", "playing")
	scene.set("turf_total", 42.0)
	scene.set("turf_shown", 29.4)
	scene.call("_update_hud")
	var turf_text := String((scene.get("turf_label") as Label).text)
	if turf_text != "涂地  29 p":
		_fail("the HUD counter does not show the floor of the shown value: %s" % turf_text)
		return
	scene.set("phase", "results")
	scene.set("result", "橙队胜利")
	scene.set("judged_coverage", [0.5, 0.5])
	scene.set("turf_area", [12.5, 8.0])
	scene.call("_update_hud")
	var result_text := String((scene.get("result_label") as Label).text)
	if not result_text.contains("12.5") or not result_text.contains("8.0"):
		_fail("the results panel does not show the raw area per team: %s" % result_text)
		return

	print("PASS: turf area and points ledger (scale from match.pointsPerM2), team split, "
		+ "splatted-player guard, display chase and HUD/results text")
	quit()


# Paints on the spawn deck with the radius the game's own death splat uses, and refuses to
# continue on an empty spot so a wrong location cannot make the assertions vacuous.
func _paint_at(x: float, z: float, team: int) -> float:
	var area := float(scene.call("paint_at_world", Vector3(x, 2.55, z), team, 2.0, 0.5))
	if area <= 0.0:
		_fail("the probe spot (%.1f, %.1f) painted nothing; the ledger cases would be vacuous" % [x, z])
		quit(1)
	return area


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
