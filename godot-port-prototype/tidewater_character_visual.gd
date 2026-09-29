extends Node3D

# Readable stand-in for the web game's procedural squidkid rig, now with the basic
# idle and walk poses the demo needs. Feet are y=0, facing +Z. Visuals never own
# movement, collision, ink or damage state.
#
# Source references: public/game/src/game/character.js — the idle layer (breathing,
# weight shift, arm sway) around :1013-1048 and the locomotion layer (gait phase,
# pelvis bob, counter-swinging arms, forward lean) around :1008-1048; config.js:25
# PLAYER.runSpeed for the speed the run pose is normalized against.
#
# Read-only motion source, no new setters and no controller change:
#   * the player's visual sits under the CharacterBody3D walker, so it reads the
#     walker's `velocity` and its `grounded` flag;
#   * the blue team's visual sits under a plain Node3D that is moved by writing
#     `global_position`, so its speed comes from the position delta instead.
# Team, weapon and form still arrive through the existing set_* API.
#
# Node paths Kid, Kid/HairCap and Kid/Weapon_<id> are part of the appearance checks
# and stay unchanged; animation recomputes each part from its rest transform rather
# than reparenting anything.
@export_range(0, 1) var team := 0

const TEAM_COLORS := [Color("ff8a14"), Color("2f5bff")]
const SKIN := Color("ffd9c2")
const SHIRT := Color("f4f2ec")
const DARK := Color("27304a")
const SOLE := Color("faf6eb")

# Fallback when the parent exposes no player_config (the blue team's visual).
const DEFAULT_RUN_SPEED := 6.0
const STRIDE_METRES := 2.6
const MIN_CADENCE := 1.05
const MAX_CADENCE := 2.35
const LEG_SWING_WALK := 0.48
const LEG_SWING_RUN := 1.05
const ARM_SWING_WALK := 0.16
const ARM_SWING_RUN := 0.52
const BOB_DEPTH := 0.032
const FOOT_LIFT := 0.07
const LEAN_WALK := 0.035
const LEAN_RUN := 0.19
const BREATH_HZ := 0.30
const BREATH_DEPTH := 0.009
const SHIFT_HZ := 0.13
const SHIFT_ROLL := 0.035
const SHIFT_SIDEWAYS := 0.012
const AIR_LEG_FRONT := 0.35
const AIR_LEG_BACK := -0.45
const AIR_ARM := 0.45
const AIR_LEAN := -0.09
const GAIT_BLEND := 9.0
const AIR_BLEND := 7.0

var kid: Node3D
var squid: Node3D
var weapon_models: Dictionary = {}
var current_weapon := "shooter"
var is_squid := false

# Read-only animation state, sampled by tools/check_tidewater_visual.gd.
var anim_phase := 0.0
var anim_speed := 0.0
var anim_idle_time := 0.0
var anim_grounded := true
var gait_weight := 0.0
var air_weight := 0.0
var moving := false
var run_speed := DEFAULT_RUN_SPEED

var _materials: Dictionary = {}
# Animation groups. Each entry keeps the part's rest transform so a pose can be applied
# without accumulating error across frames.
var _legs_l: Array = []
var _legs_r: Array = []
var _arms_l: Array = []
var _arms_r: Array = []
var _torso: Array = []
var _head: Array = []
var _weapons: Array = []
var _squid_body: Array = []
var _squid_fins: Array = []
var _clock := 0.0
var _previous_position := Vector3.ZERO
var _has_previous_position := false

const HIP := Vector3(0.0, 0.5, 0.0)
const SHOULDER := Vector3(0.0, 0.99, 0.02)
const WAIST := Vector3(0.0, 0.52, 0.0)
const NECK := Vector3(0.0, 1.1, 0.0)


func _ready() -> void:
	kid = Node3D.new()
	kid.name = "Kid"
	add_child(kid)
	squid = Node3D.new()
	squid.name = "Squid"
	add_child(squid)
	_read_run_speed()
	_build_kid()
	_build_squid()
	set_weapon(current_weapon)
	set_form(false)
	_previous_position = global_position


func _process(delta: float) -> void:
	_read_motion(delta)
	_animate(delta)


# The walker owns the run speed; the blue team's parent does not expose it, so the
# source value is the fallback.
func _read_run_speed() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var config: Variant = parent.get("player_config")
	if config is Dictionary and (config as Dictionary).has("runSpeed"):
		run_speed = float((config as Dictionary)["runSpeed"])


func set_form(value: bool) -> void:
	is_squid = value
	if kid != null:
		kid.visible = not value
		squid.visible = value


func set_weapon(weapon_id: String) -> void:
	if not weapon_models.has(weapon_id):
		return
	current_weapon = weapon_id
	for id in weapon_models:
		(weapon_models[id] as Node3D).visible = id == weapon_id


# Read-only snapshot for the appearance check and for future spectators/name tags.
func animation_state() -> Dictionary:
	return {
		"phase": anim_phase,
		"speed": anim_speed,
		"idle_time": anim_idle_time,
		"grounded": anim_grounded,
		"gait": gait_weight,
		"air": air_weight,
		"moving": moving,
	}


# ------------------------------------------------------------------ motion input
func _read_motion(delta: float) -> void:
	var horizontal := 0.0
	var vertical := 0.0
	var parent := get_parent()
	if parent is CharacterBody3D:
		var body := parent as CharacterBody3D
		horizontal = Vector2(body.velocity.x, body.velocity.z).length()
		vertical = body.velocity.y
		var flag: Variant = body.get("grounded")
		anim_grounded = bool(flag) if flag != null else body.is_on_floor()
	else:
		# The blue team is moved by writing global_position, so speed comes from the
		# travelled distance instead of a velocity it does not have.
		var current := global_position
		if _has_previous_position:
			var step := current - _previous_position
			horizontal = Vector2(step.x, step.z).length() / maxf(delta, 1e-4)
			vertical = step.y / maxf(delta, 1e-4)
			anim_grounded = absf(vertical) < 0.6
		_previous_position = current
	_has_previous_position = true
	anim_speed = horizontal
	moving = horizontal > 0.35


# ------------------------------------------------------------------ pose
func _animate(delta: float) -> void:
	_clock += delta
	var target_gait := 1.0 if (anim_grounded and moving) else 0.0
	gait_weight = move_toward(gait_weight, target_gait, GAIT_BLEND * delta)
	air_weight = move_toward(air_weight, 0.0 if anim_grounded else 1.0, AIR_BLEND * delta)
	var run_weight := clampf(anim_speed / maxf(run_speed, 0.1), 0.0, 1.0)
	if anim_grounded and moving:
		var cadence := clampf(anim_speed / STRIDE_METRES * TAU, MIN_CADENCE * TAU, MAX_CADENCE * TAU)
		anim_phase = fmod(anim_phase + cadence * delta, TAU)
	elif anim_grounded:
		anim_idle_time += delta

	# Idle layer: breathing, a slow weight shift and a small arm sway
	# (character.js:1013-1026).
	var breath := sin(anim_idle_time * TAU * BREATH_HZ)
	var shift := sin(anim_idle_time * TAU * SHIFT_HZ)
	var idle_weight := (1.0 - gait_weight) * (1.0 - air_weight)
	var idle_bob := breath * BREATH_DEPTH * idle_weight
	var idle_roll := shift * SHIFT_ROLL * idle_weight
	var idle_side := shift * SHIFT_SIDEWAYS * idle_weight

	# Locomotion layer: counter-swinging limbs, pelvis bob and a speed-scaled lean
	# (character.js:1038-1048).
	var step := sin(anim_phase)
	var leg_amp := lerpf(LEG_SWING_WALK, LEG_SWING_RUN, run_weight) * gait_weight
	var arm_amp := lerpf(ARM_SWING_WALK, ARM_SWING_RUN, run_weight) * gait_weight
	var bob := (-BOB_DEPTH * (0.5 - 0.5 * cos(anim_phase * 2.0))) * gait_weight
	var lean := lerpf(LEAN_WALK, LEAN_RUN, run_weight) * gait_weight

	# Airborne pose, blended in over the first frames off the ground.
	var air := air_weight
	var leg_l := step * leg_amp * (1.0 - air) + AIR_LEG_BACK * air
	var leg_r := -step * leg_amp * (1.0 - air) + AIR_LEG_FRONT * air
	var arm_l := -step * arm_amp * (1.0 - air) + AIR_ARM * air
	var arm_r := step * arm_amp * (1.0 - air) + AIR_ARM * air
	var torso_pitch := lean * (1.0 - air) + AIR_LEAN * air
	var torso_roll := step * 0.045 * gait_weight + idle_roll
	var vertical := bob + idle_bob

	# A negative pitch swings a leg forward (see _apply_group), so the forward leg is
	# the one that lifts; this is what makes the stride readable in a still frame.
	var lift_l := maxf(0.0, -step) * FOOT_LIFT * gait_weight
	var lift_r := maxf(0.0, step) * FOOT_LIFT * gait_weight
	_apply_group(_legs_l, HIP, leg_l, 0.0, Vector3(0.0, vertical + lift_l, 0.0))
	_apply_group(_legs_r, HIP, leg_r, 0.0, Vector3(0.0, vertical + lift_r, 0.0))
	_apply_group(_torso, WAIST, torso_pitch, torso_roll, Vector3(idle_side, vertical, 0.0))
	_apply_group(_arms_l, SHOULDER, arm_l, 0.0, Vector3(0.0, vertical, 0.0))
	_apply_group(_arms_r, SHOULDER, arm_r, 0.0, Vector3(0.0, vertical, 0.0))
	# The head stabilises against the torso pitch (character.js: stabilised head look).
	_apply_group(_head, NECK, torso_pitch * 0.4, torso_roll * 0.35,
		Vector3(idle_side * 0.6, vertical, 0.0))
	# Weapon models carry a different entry shape, so they get their own helper, and
	# they ride the right arm so they stay in the hand instead of floating beside the
	# chest (they used to sit at a fixed offset relative to the body).
	_apply_weapons_group(arm_r, torso_roll, Vector3(0.0, vertical + lift_r, 0.0))

	# Squid: a soft mantle bob plus fin flutter, faster while swimming.
	var squid_bob := sin(_clock * TAU * 0.45) * 0.012 + sin(anim_phase * 2.0) * 0.02 * gait_weight
	var flutter := sin(_clock * TAU * 1.15) * 0.16
	_apply_group(_squid_body, Vector3(0.0, 0.0, 0.0), 0.0, 0.0, Vector3(0.0, squid_bob, 0.0), false)
	for entry in _squid_fins:
		var fin: MeshInstance3D = entry["node"]
		var rest: Vector3 = entry["rest"]
		var rest_rotation: Vector3 = entry["rest_rotation"]
		fin.position = rest + Vector3(0.0, squid_bob, 0.0)
		fin.rotation = Vector3(rest_rotation.x + flutter * 0.25 * entry["side"],
			rest_rotation.y + flutter * entry["side"], rest_rotation.z)


# Applies a rigid rotation about `pivot` plus an offset to every part of a group, and
# writes the combined Euler rotation. Rest transforms are the source of truth, so the
# pose never accumulates drift.
func _apply_group(group: Array, pivot: Vector3, pitch: float, roll: float, offset: Vector3,
		rotate: bool = true) -> void:
	for entry in group:
		var part: MeshInstance3D = entry["node"]
		var rest: Vector3 = entry["rest"]
		var rest_rotation: Vector3 = entry["rest_rotation"]
		var local: Vector3 = rest - pivot
		var posed := local
		if rotate:
			posed = posed.rotated(Vector3(1.0, 0.0, 0.0), pitch)
			posed = posed.rotated(Vector3(0.0, 0.0, 1.0), roll)
		part.position = pivot + posed + offset
		if rotate:
			part.rotation = Vector3(rest_rotation.x + pitch, rest_rotation.y, rest_rotation.z + roll)
		else:
			part.rotation = rest_rotation


func _track(group: Array, part: MeshInstance3D) -> MeshInstance3D:
	group.append({
		"node": part,
		"rest": part.position,
		"rest_rotation": part.rotation,
	})
	return part


# ------------------------------------------------------------------ appearance
func _build_kid() -> void:
	var ink: Color = TEAM_COLORS[team]
	_track(_head, _sphere(kid, "Head", Vector3(0.0, 1.214, 0.012), Vector3(0.178, 0.176, 0.165), SKIN))
	_track(_head, _sphere(kid, "HairCap", Vector3(0.0, 1.365, -0.025), Vector3(0.182, 0.095, 0.17), ink))
	# Team silhouette: the source varies hair per roster slot (character.js style.hair);
	# with one player and one bot, the two teams are what has to read apart.
	if team == 0:
		# Tangerine: strands kicked out to the sides, crest standing up.
		for side in [-1.0, 1.0]:
			var up := _sphere(kid, "Tentacle%s" % ("L" if side < 0.0 else "R"),
				Vector3(side * 0.155, 1.155, -0.08), Vector3(0.065, 0.23, 0.066), ink)
			up.rotation.z = side * -0.26
			_track(_head, up)
		_track(_head, _sphere(kid, "TeamCrest", Vector3(0.0, 1.44, -0.05),
			Vector3(0.045, 0.085, 0.16), ink.lightened(0.12)))
	else:
		# Cobalt: strands swept back and low, crest flattened along the skull.
		for side in [-1.0, 1.0]:
			var back := _sphere(kid, "Tentacle%s" % ("L" if side < 0.0 else "R"),
				Vector3(side * 0.135, 1.18, -0.135), Vector3(0.062, 0.2, 0.075), ink)
			back.rotation.z = side * -0.10
			back.rotation.x = -0.62
			_track(_head, back)
		var crest := _sphere(kid, "TeamCrest", Vector3(0.0, 1.425, -0.06),
			Vector3(0.07, 0.03, 0.145), ink.darkened(0.12))
		crest.rotation.x = -0.18
		_track(_head, crest)
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		_track(_head, _sphere(kid, "Eye" + suffix, Vector3(side * 0.073, 1.242, 0.170),
			Vector3(0.052, 0.048, 0.016), Color.WHITE))
		_track(_head, _sphere(kid, "Pupil" + suffix, Vector3(side * 0.073, 1.24, 0.187),
			Vector3(0.018, 0.029, 0.008), DARK))
	_track(_head, _box(kid, "VisorBridge", Vector3(0.0, 1.25, 0.163), Vector3(0.24, 0.025, 0.025), DARK))
	_track(_torso, _box(kid, "Shirt", Vector3(0.0, 0.84, 0.0), Vector3(0.39, 0.39, 0.255), SHIRT))
	_track(_torso, _box(kid, "Shorts", Vector3(0.0, 0.565, 0.0), Vector3(0.3, 0.19, 0.27), DARK))
	# Team trim so the two sides read apart even without colour.
	_track(_torso, _box(kid, "Trim", Vector3(0.0, 0.655, 0.13), Vector3(0.32, 0.035, 0.02), ink))
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		var arm := _sphere(kid, "Arm" + suffix, Vector3(side * 0.245, 0.79, 0.02),
			Vector3(0.075, 0.22, 0.075), SKIN)
		arm.rotation.z = side * 0.3
		_track(_arms_l if side < 0.0 else _arms_r, arm)
		_track(_arms_l if side < 0.0 else _arms_r,
			_sphere(kid, "Hand" + suffix, Vector3(side * 0.275, 0.57, 0.09), Vector3(0.075, 0.07, 0.07), SKIN))
		_track(_legs_l if side < 0.0 else _legs_r,
			_box(kid, "Leg" + suffix, Vector3(side * 0.105, 0.32, 0.0), Vector3(0.13, 0.36, 0.13), SKIN))
		_track(_legs_l if side < 0.0 else _legs_r,
			_box(kid, "Shoe" + suffix, Vector3(side * 0.105, 0.09, 0.09), Vector3(0.19, 0.15, 0.32), DARK))
		_track(_legs_l if side < 0.0 else _legs_r,
			_box(kid, "Sole" + suffix, Vector3(side * 0.105, 0.028, 0.105), Vector3(0.2, 0.05, 0.33), SOLE))
	var tank := _cylinder(kid, "InkTank", Vector3(0.0, 0.79, -0.17), 0.098, 0.40, ink)
	tank.rotation.z = 0.09
	_track(_torso, tank)
	_track(_torso, _cylinder(kid, "TankCap", Vector3(0.0, 1.0, -0.17), 0.11, 0.055, DARK))
	_build_weapons()


func _build_squid() -> void:
	var ink: Color = TEAM_COLORS[team]
	_track(_squid_body, _sphere(squid, "Mantle", Vector3(0.0, 0.24, 0.0), Vector3(0.35, 0.20, 0.40), ink))
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		_track(_squid_body, _sphere(squid, "SquidEye" + suffix, Vector3(side * 0.12, 0.28, 0.355),
			Vector3(0.060, 0.073, 0.025), Color.WHITE))
		_track(_squid_body, _sphere(squid, "SquidPupil" + suffix, Vector3(side * 0.12, 0.28, 0.382),
			Vector3(0.025, 0.045, 0.012), DARK))
		var fin := _sphere(squid, "Fin" + suffix, Vector3(side * 0.26, 0.13, -0.27),
			Vector3(0.095, 0.10, 0.22), ink.darkened(0.15))
		fin.rotation.y = side * 0.35
		_squid_fins.append({"node": fin, "rest": fin.position, "rest_rotation": fin.rotation, "side": side})


func _build_weapons() -> void:
	for id in ["shooter", "roller", "charger", "blaster"]:
		var model := Node3D.new()
		model.name = "Weapon_" + id
		model.position = Vector3(0.27, 0.62, 0.24)
		kid.add_child(model)
		weapon_models[id] = model
		_weapons.append({"model": model, "rest": model.position})
		match id:
			"shooter":
				_box(model, "Receiver", Vector3(0.0, 0.1, 0.12), Vector3(0.20, 0.17, 0.42), SHIRT)
				_box(model, "InkSpine", Vector3(0.0, 0.20, 0.10), Vector3(0.13, 0.04, 0.30), TEAM_COLORS[team])
				var barrel := _cylinder(model, "Barrel", Vector3(0.0, 0.10, 0.40), 0.065, 0.23, DARK)
				barrel.rotation.x = PI * 0.5
			"roller":
				_box(model, "Handle", Vector3(0.0, 0.01, 0.28), Vector3(0.07, 0.07, 0.48), DARK)
				var drum := _cylinder(model, "Drum", Vector3(0.0, -0.20, 0.56), 0.18, 0.70, TEAM_COLORS[team])
				drum.rotation.z = PI * 0.5
				_box(model, "DrumFork", Vector3(0.0, -0.12, 0.50), Vector3(0.65, 0.035, 0.06), SHIRT)
			"charger":
				_box(model, "Rail", Vector3(0.0, 0.10, 0.29), Vector3(0.12, 0.12, 0.82), SHIRT)
				_box(model, "Coil", Vector3(0.0, 0.19, 0.18), Vector3(0.08, 0.08, 0.35), TEAM_COLORS[team])
				var nozzle := _cylinder(model, "Nozzle", Vector3(0.0, 0.10, 0.78), 0.045, 0.25, DARK)
				nozzle.rotation.x = PI * 0.5
			"blaster":
				_sphere(model, "Chamber", Vector3(0.0, 0.10, 0.15), Vector3(0.19, 0.19, 0.22), TEAM_COLORS[team])
				var muzzle := _cylinder(model, "Muzzle", Vector3(0.0, 0.10, 0.40), 0.14, 0.25, DARK)
				muzzle.rotation.x = PI * 0.5
				_box(model, "Guard", Vector3(0.0, -0.07, 0.04), Vector3(0.14, 0.15, 0.12), SHIRT)


# The weapon models only translate; their own rest transform is the reference.
func _apply_weapons_group(pitch: float, roll: float, offset: Vector3) -> void:
	for entry in _weapons:
		var model: Node3D = entry["model"]
		var rest: Vector3 = entry["rest"]
		var local: Vector3 = rest - SHOULDER
		var posed := local.rotated(Vector3(1.0, 0.0, 0.0), pitch).rotated(Vector3(0.0, 0.0, 1.0), roll)
		model.position = SHOULDER + posed + offset


# ------------------------------------------------------------------ primitives
func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.48
		material.clearcoat_enabled = true
		material.clearcoat = 0.3
		_materials[key] = material
	return _materials[key] as StandardMaterial3D


func _sphere(parent: Node3D, name_text: String, at: Vector3, radii: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var part := MeshInstance3D.new()
	part.name = name_text
	part.mesh = mesh
	part.position = at
	part.scale = radii
	part.material_override = _material(color)
	parent.add_child(part)
	return part


func _box(parent: Node3D, name_text: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = name_text
	part.mesh = mesh
	part.position = at
	part.material_override = _material(color)
	parent.add_child(part)
	return part


func _cylinder(parent: Node3D, name_text: String, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var part := MeshInstance3D.new()
	part.name = name_text
	part.mesh = mesh
	part.position = at
	part.material_override = _material(color)
	parent.add_child(part)
	return part
