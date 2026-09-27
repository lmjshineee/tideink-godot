extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	# Fixed RNG seed: spread and impact-radius jitter draw from the global generator,
	# so the assertions below would otherwise be flaky run to run.
	seed(20260927)
	var scene := (load("res://tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var combat: Node3D = scene.get_node("Combat")
	var ink: RefCounted = scene.get("ink")
	var data: Dictionary = combat.get("weapon_data")
	if int(data["schema"]) != 1 or (data["weaponOrder"] as Array).size() != 4:
		_fail("source weapon data")
		return
	var select := InputEventKey.new()
	select.keycode = KEY_3
	select.pressed = true
	scene.call("_input", select)
	if scene.get("selected_weapon") != "charger" or combat.get("selected_id") != "charger":
		_fail("pre-match weapon choice")
		return
	scene.call("_start_round")
	select.keycode = KEY_4
	scene.call("_input", select)
	if scene.get("selected_weapon") != "charger":
		_fail("live weapon switch must be disabled")
		return
	combat.call("select_weapon", "shooter")
	var before := float(combat.get("ink_amount"))
	combat.call("tick", 0.1, true, false)
	if (combat.get("projectiles") as Array).size() != 1 or absf(float(combat.get("ink_amount")) - before + 0.95) > 0.001:
		_fail("shooter projectile or source ink cost")
		return
	var launched: Dictionary = (combat.get("projectiles") as Array)[0]
	if (launched["visual"] as MeshInstance3D).global_position.distance_to(launched["origin"]) > 0.0001:
		_fail("projectile muzzle position")
		return
	var shooter: Dictionary = data["weapons"]["shooter"]
	combat.call("_spawn_projectile", "shooter", Vector3(0.0, 4.0, -39.2), Vector3(0.0, -34.0, 0.0), shooter)
	combat.call("_update_projectiles", 0.1)
	if float(ink.call("coverage", 0)) <= 0.0 or int(scene.get_node("InkView").call("sync_dirty")) <= 0:
		_fail("shooter collision-to-ink path")
		return
	combat.call("tick", 0.02, false, false)
	# Trail drips: the web drops ink straight down every trailEvery metres of flight
	# (weapons.js:681-687). That is the shooter's main turf channel; the port had no
	# ink along the flight path at all.
	var trail_before := float(ink.call("coverage", 0))
	combat.call("_spawn_projectile", "shooter", Vector3(0.0, 3.5, -39.2), Vector3(0.0, 0.0, 20.0), shooter)
	for step in range(3):
		combat.call("_update_projectiles", 0.05)
	if float(ink.call("coverage", 0)) <= trail_before:
		_fail("shooter trail drips did not paint along the flight path")
		return
	combat.call("tick", 0.02, false, false)
	# Spread: consecutive shots must fan out inside the source cone instead of all
	# following the crosshair exactly (weapons.js:57-64, 119).
	var walker := scene.get_node("World/Walker")
	var cone := float(shooter["spreadBaseGround"]) if walker.is_on_floor() else float(shooter["spreadBaseAir"])
	var directions: Array[Vector3] = []
	for shot_index in range(8):
		combat.call("_spawn_shot", shooter)
		var list: Array = combat.get("projectiles")
		var latest: Dictionary = list[list.size() - 1]
		directions.append((latest["velocity"] as Vector3).normalized())
		(latest["visual"] as MeshInstance3D).queue_free()
		list.remove_at(list.size() - 1)
	var widest := 0.0
	for i in range(directions.size()):
		for j in range(i + 1, directions.size()):
			widest = maxf(widest, rad_to_deg(directions[i].angle_to(directions[j])))
	if widest < 0.2:
		_fail("shooter fired with no spread")
		return
	if widest > cone * 2.0 + 0.5:
		_fail("shooter spread exceeded the source cone: %.2f deg (cone %.1f)" % [widest, cone])
		return
	combat.call("select_weapon", "blaster")
	before = float(combat.get("ink_amount"))
	combat.call("tick", 0.05, true, false)
	if absf(float(combat.get("ink_amount")) - before + 9.0) > 0.001 or not _has_projectile(combat, "blaster"):
		_fail("blaster projectile or source ink cost")
		return
	var paint_version := int(ink.get("version"))
	var blaster: Dictionary = data["weapons"]["blaster"]
	combat.call("_spawn_projectile", "blaster", Vector3(4.0, 4.0, -39.2), Vector3(0.0, -23.0, 0.0), blaster)
	combat.call("_update_projectiles", 0.1)
	if int(ink.get("version")) <= paint_version:
		_fail("blaster world impact paint")
		return
	combat.call("tick", 0.02, false, false)
	combat.call("select_weapon", "charger")
	combat.call("tick", 0.5, true, false)
	combat.call("tick", 0.5, true, false)
	before = float(combat.get("ink_amount"))
	combat.call("tick", 0.01, false, false)
	if (combat.get("beams") as Array).is_empty() or float(combat.get("ink_amount")) > before - 17.0:
		_fail("charger release, beam or ink cost")
		return
	paint_version = int(ink.get("version"))
	var charger: Dictionary = data["weapons"]["charger"]
	combat.call("_fire_charger", charger, 0.5, Vector3(0.0, -0.2, 1.0))
	if int(ink.get("version")) <= paint_version:
		_fail("charger ground line or impact paint")
		return
	combat.call("select_weapon", "roller")
	before = float(combat.get("ink_amount"))
	combat.call("tick", 0.01, true, false)
	combat.call("tick", 0.23, true, false)
	var drops := 0
	for shot in combat.get("projectiles"):
		if shot["kind"] == "drop":
			drops += 1
	if drops != 9 or float(combat.get("ink_amount")) > before - 8.9:
		_fail("roller flick count or ink cost")
		return
	paint_version = int(ink.get("version"))
	before = float(combat.get("ink_amount"))
	var roller: Dictionary = data["weapons"]["roller"]
	combat.call("_paint_roll_at", Vector3(5.0, 2.2, -39.2), Vector3(0.0, 0.0, 0.5), roller)
	if int(ink.get("version")) <= paint_version or float(combat.get("ink_amount")) >= before:
		_fail("roller stripe paint or distance ink cost")
		return
	combat.call("select_weapon", "shooter")
	combat.set("ink_amount", 50.0)
	combat.call("tick", 0.1, true, false)
	before = float(combat.get("ink_amount"))
	combat.call("tick", 0.5, false, false)
	if not is_equal_approx(float(combat.get("ink_amount")), before):
		_fail("kid ink refilled before source idle delay")
		return
	combat.call("tick", 0.5, false, false)
	if float(combat.get("ink_amount")) <= before:
		_fail("kid ink did not refill after source idle delay")
		return
	# An empty tank with the trigger still held must refill: the delay is measured from
	# the last shot that actually fired, not from the button state (actor.js:311-313).
	# The port reset the delay every frame the trigger was held, so the player stayed
	# locked at zero ink until they let go.
	combat.set("ink_amount", 0.0)
	combat.set("last_fire_time", 2.0)
	combat.call("tick", 0.6, true, false)
	if float(combat.get("ink_amount")) <= 0.0:
		_fail("holding the trigger on empty ink never refilled")
		return
	# A squid on dry ground still trickles at half the kid rate (actor.js:314).
	combat.set("ink_amount", 0.0)
	walker.set("ink_owner", -1)
	walker.set("climbing", false)
	combat.call("tick", 1.0, false, true)
	if absf(float(combat.get("ink_amount")) - 4.5) > 0.01:
		_fail("dry-ground squid trickle: " + str(combat.get("ink_amount")))
		return
	print("PASS: four source-configured weapons, selection, ink costs and map paint impacts")
	quit()


func _has_projectile(combat: Node3D, kind: String) -> bool:
	for shot in combat.get("projectiles"):
		if shot["kind"] == kind:
			return true
	return false


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
