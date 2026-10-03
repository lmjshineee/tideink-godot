extends Node3D

# Original web squidkid geometry, 87-bone rig, source fragment details and sampled
# poses are the default. Feet are y=0, facing +Z. Visuals never own movement,
# collision, ink or damage state. Primitive meshes remain hidden API fallbacks.
#
# Source references: public/game/src/game/character.js — the idle layer (breathing,
# weight shift, arm sway) around :1013-1048 and the locomotion layer (gait phase,
# pelvis bob, counter-swinging arms, forward lean) around :1008-1048; config.js:25
# PLAYER.runSpeed for the speed the run pose is normalized against.
#
# Read-only motion source; owners pass animation configuration after loading it:
#   * the player's visual sits under the CharacterBody3D walker, so it reads the
#     walker's `velocity` and its `grounded` flag;
#   * the blue team's visual sits under a plain Node3D that is moved by writing
#     `global_position`, so its speed comes from the position delta instead.
# Team, weapon and form still arrive through the existing set_* API.
# configure_animation() only copies the animation normalization speed.
#
# Node paths Kid, Kid/HairCap and Kid/Weapon_<id> are part of the appearance checks
# and stay unchanged; animation recomputes each part from its rest transform rather
# than reparenting anything.
@export_range(0, 1) var team := 0
@export_range(0, 3) var style_index := 0
@export var ornament_seed := -1
var ornament_pattern := 0
var ornament_color := Color("ffc04a")
var ornament_pose := Vector4(1,0,0,0)
var ornament_side := 0
const ORIGINAL_SURFACE := preload("res://shaders/characters/character_surface.gdshader")
const SKIN_SURFACE := preload("res://shaders/characters/character_skin.gdshader")
const EYE_SURFACE := preload("res://shaders/characters/character_eyes.gdshader")
const HAIR_SURFACE := preload("res://shaders/characters/character_hair.gdshader")
const CLOTH_SURFACE := preload("res://shaders/characters/character_cloth.gdshader")
const IRIS := [Color("ffcf3a"),Color("4ff0dc"),Color("c9a2ff"),Color("a8f56a")]
const IRIS_DARK := [Color("ff7a00"),Color("0b7fb0"),Color("5b2ad6"),Color("1d9a4a")]
const OUTFITS := [
	["f4f2ec","27304a","272b34","f4f2ec","f7f7f4","30343d"],
	["2b2e36","cfbb92","f3f2ee","c98b4e","f7f7f4","24262c"],
	["bfc5cf","1f2127","f3f2ee","2a2c33","2a2c33","2a2c33"],
	["f2e6c9","3a5683","3a3f4b","f4f2ec","f7f7f4","3a3f4b"]
]
var face_material: ShaderMaterial
var eye_material: ShaderMaterial
var face_expression := "idle"
var face_ink := 1.0
var face_health := 1.0
var face_charge := 0.0
var face_special := false
var _face_bones: Array[int] = []
var _face_poses: Array[Transform3D] = []
var _mouth_pose := Vector4(0.75,1.0,0.0,0.0)
var _eye_look := Vector2.ZERO
var _blink_remaining := 2.0
var _blink_elapsed := 1.0
var _shot_age := 9.0
static var _original_team_materials: Dictionary = {}
var original_rig: Node3D
var skeleton: Skeleton3D
var original_weapons: Dictionary = {}
var aiming := false
var recoil := 0.0
var action_time := 0.0
var action_name := ""
var action_elapsed := 1.0
var aim_weight := 0.0
var aim_pitch := 0.0
var rolling_pose := false
static var _weapon_pose_data: Dictionary = {}
var _upper_bones: Array[int] = []
static var _action_data: Dictionary = {}
var _action_bones: Array[int] = []
var _gait_bones: Array[int] = []
var _gaits: Dictionary = {}
var _action_rest: Array[Transform3D] = []
var _kid_rig: Node3D
var reaction_name := ""
var reaction_elapsed := 0.0
var dance_name := ""
var dance_variant := 0
var _was_grounded := true

const TeamPalette := preload("res://src/core/team_palette.gd")
const SKIN := Color("ffd9c2")
const SHIRT := Color("f4f2ec")
const DARK := Color("27304a")
const SOLE := Color("faf6eb")

# Fallback for standalone visuals without an owner configuration.
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
const Equipment:=preload("res://src/core/equipment_catalog.gd")
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
	_configure_ornament()
	kid = Node3D.new()
	kid.name = "Kid"
	add_child(kid)
	squid = Node3D.new()
	squid.name = "Squid"
	add_child(squid)
	_build_kid()
	_build_squid()
	_install_original()
	set_weapon(current_weapon)
	set_form(false)
	_previous_position = global_position


func _configure_ornament() -> void:
	# A private RNG preserves weapon spread/replay seeds. Reuse this seed in portraits.
	var rng := RandomNumberGenerator.new()
	if ornament_seed < 0:
		rng.randomize()
		ornament_seed = int(rng.randi() & 0x7fffffff)
	rng.seed = ornament_seed
	ornament_pattern = rng.randi_range(0,7)
	ornament_pose = Vector4(rng.randf_range(0.85,1.12),rng.randf_range(-0.22,0.22),rng.randf_range(-0.025,0.025),rng.randf_range(-0.02,0.02))
	ornament_side = [0,0,-1,1][rng.randi_range(0,3)]
	var colors := [Color("ffc04a"),Color("fff1ce"),Color("e87d94"),TeamPalette.color(team).lightened(0.25)]
	ornament_color = colors[rng.randi_range(0,colors.size()-1)]


func _physics_process(delta: float) -> void:
	_read_motion(delta)
	_animate(delta)


# Child _ready() runs before its owner loads the config. The walker calls this
# after loading player_config; the bot calls it from setup(), after Combat setup.
# Copy only a scalar: the visual cannot mutate the owner's configuration.
func configure_animation(config: Dictionary) -> void:
	run_speed = float(config.get("runSpeed", DEFAULT_RUN_SPEED))


func set_form(value: bool) -> void:
	is_squid = value
	if kid != null:
		kid.visible = not value
		squid.visible = value


func set_weapon(weapon_id: String) -> void:
	if not weapon_models.has(Equipment.base(weapon_id)):
		return
	current_weapon = weapon_id
	action_time = 0.0
	action_elapsed = 1.0
	action_name = ""
	for id in weapon_models:
		(weapon_models[id] as Node3D).visible = id == Equipment.base(weapon_id)
	for id in original_weapons:
		(original_weapons[id] as Node3D).visible = id == weapon_id or (id=="dualie_left" and weapon_id=="dualie")


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
		# The walker owns `grounded` from its foot probe. is_on_floor() is deliberately not
		# used as a fallback: both bodies are lifted out of the ground, so it is always
		# false and would make every frame look airborne.
		var flag: Variant = body.get("grounded")
		anim_grounded = bool(flag) if flag != null else true
	else:
		# The blue team is moved by writing global_position, so speed comes from the
		# travelled distance instead of a velocity it does not have.
		var current := global_position
		var mover: Variant = parent.get("team_mover")
		if mover is CharacterBody3D:
			horizontal = Vector2(mover.velocity.x, mover.velocity.z).length()
			vertical = mover.velocity.y
			anim_grounded = mover.is_on_floor()
		elif _has_previous_position:
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
	if anim_grounded != _was_grounded:
		set_reaction("land" if anim_grounded else "jump")
	_was_grounded = anim_grounded
	reaction_elapsed += delta
	recoil = move_toward(recoil, 0.0, delta * 5.0)
	action_time = maxf(0.0, action_time - delta)
	action_elapsed += delta
	var held_aim := aiming or (action_name == "shoot" and action_time > 0.3)
	aim_weight = lerpf(aim_weight, 1.0 if held_aim else 0.0, 1.0 - exp(-12.0 * delta))
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

	_animate_original(leg_l, leg_r, torso_pitch, vertical, delta)
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
	var ink: Color = TeamPalette.color(team)
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
	var ink: Color = TeamPalette.color(team)
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
				_box(model, "InkSpine", Vector3(0.0, 0.20, 0.10), Vector3(0.13, 0.04, 0.30), TeamPalette.color(team))
				var barrel := _cylinder(model, "Barrel", Vector3(0.0, 0.10, 0.40), 0.065, 0.23, DARK)
				barrel.rotation.x = PI * 0.5
			"roller":
				_box(model, "Handle", Vector3(0.0, 0.01, 0.28), Vector3(0.07, 0.07, 0.48), DARK)
				var drum := _cylinder(model, "Drum", Vector3(0.0, -0.20, 0.56), 0.18, 0.70, TeamPalette.color(team))
				drum.rotation.z = PI * 0.5
				_box(model, "DrumFork", Vector3(0.0, -0.12, 0.50), Vector3(0.65, 0.035, 0.06), SHIRT)
			"charger":
				_box(model, "Rail", Vector3(0.0, 0.10, 0.29), Vector3(0.12, 0.12, 0.82), SHIRT)
				_box(model, "Coil", Vector3(0.0, 0.19, 0.18), Vector3(0.08, 0.08, 0.35), TeamPalette.color(team))
				var nozzle := _cylinder(model, "Nozzle", Vector3(0.0, 0.10, 0.78), 0.045, 0.25, DARK)
				nozzle.rotation.x = PI * 0.5
			"blaster":
				_sphere(model, "Chamber", Vector3(0.0, 0.10, 0.15), Vector3(0.19, 0.19, 0.22), TeamPalette.color(team))
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


# Original skinned meshes and 87-bone rig. The primitive builder remains an offline
# fallback and API adapter; all its meshes are hidden when the source assets load.
func _install_original() -> void:
	var path := "res://assets/characters/kid_%d.glb" % posmod(style_index, 4)
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	_hide_primitive_meshes(kid)
	_hide_primitive_meshes(squid)
	original_rig = packed.instantiate()
	original_rig.name = "OriginalRig"
	kid.add_child(original_rig)
	skeleton = _find_skeleton(original_rig)
	_load_weapon_poses()
	_kid_rig = original_rig.find_child("KidRig",true,false) as Node3D
	if _action_data.is_empty():
		_action_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/actions.json"))
	for bone_name in _action_data["bones"]:
		_action_bones.append(skeleton.find_bone(bone_name))
	for values in _action_data["rest"]:
		_action_rest.append(_sample_values(values))
	for bone_name in _action_data["gaitBones"]:
		_gait_bones.append(skeleton.find_bone(bone_name))
	for weapon in _action_data["gaits"]:
		var clips := {}
		for mode in _action_data["gaits"][weapon]:
			var frames := []
			for frame in _action_data["gaits"][weapon][mode]["frames"]:
				var poses: Array[Transform3D] = []
				for values in frame["bones"]:poses.append(_sample_values(values))
				frames.append({"bones":poses,"kid":_sample_values(frame["kid"])})
			clips[mode] = frames
		_gaits[weapon] = clips
	for bone_name in _action_data["faceBones"]:
		var bone := skeleton.find_bone(bone_name)
		_face_bones.append(bone)
		_face_poses.append(skeleton.get_bone_rest(bone))
	_blink_remaining += style_index*0.7+team*0.35+fmod(float(get_instance_id()),7.0)*0.12
	var squid_root := original_rig.find_child("SquidRig", true, false) as Node3D
	if squid_root != null:
		squid_root.reparent(squid)
		squid_root.position.y = 0.2
	_materialize_original(original_rig)
	_materialize_original(squid)
	for id in weapon_models:
		var model := original_rig.find_child("Weapon_" + id, true, false) as Node3D
		if model != null:
			original_weapons[id] = model

	for id in Equipment.EXTRA:
		var source:Node3D=original_weapons[Equipment.base(id)]
		var copy:Node3D=source.duplicate();copy.name="Weapon_"+id;source.get_parent().add_child(copy)
		copy.scale*=Vector3(1,1,1.35) if id=="heavy" else (Vector3.ONE*.82 if id=="rapid" else Vector3.ONE*.8)
		original_weapons[id]=copy
		if id=="dualie":
			var left:=BoneAttachment3D.new();left.bone_name="handL";skeleton.add_child(left)
			var twin:Node3D=source.duplicate();left.add_child(twin);twin.scale*=.8
			original_weapons["dualie_left"]=twin

	var hand := BoneAttachment3D.new()
	hand.bone_name = "handR"
	skeleton.add_child(hand)
	var disc: Node3D = preload("res://src/combat/ink_disc_mesh.gd").make(team, 0.36)
	hand.add_child(disc)
	disc.position = Vector3(0, 0.08, 0.04)
	disc.rotation.x = PI * 0.5
	original_weapons["disc"] = disc
	for id in ["bow","canopy"]:
		var equipment: Node3D = preload("res://src/combat/ink_equipment_mesh.gd").bow(team) if id=="bow" else preload("res://src/combat/ink_equipment_mesh.gd").canopy(team)
		hand.add_child(equipment)
		var source:Node3D=original_weapons[Equipment.base(id)]
		# The authored hand bone points along the handle, not the barrel.
		equipment.basis=(source.get_child(0) as Node3D).basis
		equipment.position=source.position
		original_weapons[id]=equipment


func _hide_primitive_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_primitive_meshes(child)


func _materialize_original(node: Node) -> void:
	if node is MeshInstance3D and node.get_parent() != kid:
		# Preserve the smooth authored silhouette/face at portrait distances. Godot's
		# automatic low-detail mesh otherwise collapses cheeks and cap into facets.
		(node as MeshInstance3D).lod_bias = 6.0
		if node.name == "TankGlass":
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.65,0.9,1.0,0.18)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.18
			(node as MeshInstance3D).material_override = glass
			return
		var mesh := (node as MeshInstance3D).mesh
		var imported := mesh.surface_get_material(0)
		var semantic := imported.resource_name if imported != null else "Equipment"
		if semantic == "Skin" or semantic == "Eyes":
			var instance_material := face_material if semantic == "Skin" else eye_material
			if instance_material == null:
				instance_material = ShaderMaterial.new()
				instance_material.shader = SKIN_SURFACE if semantic == "Skin" else EYE_SURFACE
				instance_material.set_shader_parameter("team_color",TeamPalette.color(team))
				if semantic == "Skin":
					instance_material.set_shader_parameter("freckles",style_index == 0)
					instance_material.set_shader_parameter("ornament_pattern",ornament_pattern)
					instance_material.set_shader_parameter("ornament_color",ornament_color)
					instance_material.set_shader_parameter("ornament_pose",ornament_pose)
					instance_material.set_shader_parameter("ornament_side",ornament_side)
					face_material = instance_material
				else:
					instance_material.set_shader_parameter("iris_color",IRIS[posmod(style_index,4)])
					instance_material.set_shader_parameter("iris_dark",IRIS_DARK[posmod(style_index,4)])
					eye_material = instance_material
			(node as MeshInstance3D).material_override = instance_material
			return
		var key := TeamPalette.color(team).to_html()+semantic+str(style_index)
		if not _original_team_materials.has(key):
			var shared := ShaderMaterial.new()
			shared.shader = HAIR_SURFACE if semantic == "TeamHair" else CLOTH_SURFACE if semantic == "Cloth" else ORIGINAL_SURFACE
			shared.set_shader_parameter("team_color", TeamPalette.color(team))
			shared.set_shader_parameter("pattern",posmod(style_index,4))
			if semantic == "Cloth":
				var names := ["shirt_color","shorts_color","shoe_color","sole_color","sock_color","strap_color"]
				for i in names.size():shared.set_shader_parameter(names[i],Color(OUTFITS[posmod(style_index,4)][i]))
			_original_team_materials[key] = shared
		(node as MeshInstance3D).material_override = _original_team_materials[key]
	for child in node.get_children():
		_materialize_original(child)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func set_action(name_text: String) -> void:
	action_name = name_text
	action_time = 0.8
	action_elapsed = 0.0
	recoil = 0.17
	_shot_age = 0.0


func set_aim(value: bool) -> void:
	aiming = value


func _bone_angle(name_text: String, pitch: float, yaw: float = 0.0, roll: float = 0.0) -> void:
	var index := skeleton.find_bone(name_text)
	if index >= 0:
		skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(Vector3(pitch, yaw, roll)))


func _animate_original(left: float, right: float, lean: float, lift: float, _delta: float) -> void:
	if skeleton == null:
		return
	if not anim_grounded:
		_bone_angle("thighL", left * 0.75)
		_bone_angle("thighR", right * 0.75)
		_bone_angle("shinL", maxf(0.0, left) * 0.6)
		_bone_angle("shinR", maxf(0.0, right) * 0.6)
	_bone_angle("spine", lean * 0.5)
	_bone_angle("head", -lean * 0.35)
	_apply_original_hold(_delta)
	var hips := skeleton.find_bone("hips")
	if hips >= 0 and not anim_grounded:
		skeleton.set_bone_pose_position(hips, skeleton.get_bone_rest(hips).origin + Vector3(0.0, lift, 0.0))
	if anim_grounded:
		_apply_source_gait(_delta)
	for strand in range(8):
		_bone_angle("hair%d_0" % strand, sin(_clock * 3.0 + strand) * 0.025 + lean * 0.2)
	_apply_face(_delta)
	_apply_reaction(_delta)
	if _kid_rig != null and not anim_grounded and reaction_name.is_empty() and dance_name.is_empty():
		_kid_rig.transform = _kid_rig.transform.interpolate_with(Transform3D.IDENTITY,1.0-exp(-15.0*_delta))


# Read-only expression inputs. The game retains all health/ink/charge authority.
func set_expression_state(ink_fraction: float, health_fraction: float, charge: float, special: bool) -> void:
	face_ink = clampf(ink_fraction,0.0,1.0)
	face_health = clampf(health_fraction,0.0,1.0)
	face_charge = clampf(charge,0.0,1.0)
	face_special = special


func _apply_face(delta: float) -> void:
	_shot_age += delta
	face_expression = "tired" if face_health < 0.3 else "low" if face_ink < 0.15 else "charge" if face_charge > 0.5 else "fire" if _shot_age < 0.25 or rolling_pose else "focus" if aiming else "special" if face_special else "idle"
	var expression: Dictionary = _action_data["expressions"][Equipment.base(current_weapon)][face_expression]
	var weight := 1.0-exp(-12.0*delta)
	_blink_remaining -= delta
	_blink_elapsed += delta
	if _blink_remaining <= 0.0:
		_blink_elapsed = 0.0
		_blink_remaining = 2.3+fmod(float(get_instance_id())*0.17+_clock,2.5)
	var blink := sin(PI*_blink_elapsed/0.15) if _blink_elapsed < 0.15 else 0.0
	for i in _face_bones.size():
		var bone := _face_bones[i]
		var target := _sample_values(expression["bones"][i])
		var source_index: int = _action_data["bones"].find(skeleton.get_bone_name(bone))
		target.origin += skeleton.get_bone_rest(bone).origin-_action_rest[source_index].origin
		_face_poses[i] = _face_poses[i].interpolate_with(target,weight)
		var pose := _face_poses[i]
		skeleton.set_bone_pose_position(bone,pose.origin)
		skeleton.set_bone_pose_rotation(bone,pose.basis.get_rotation_quaternion())
		var scale_value := pose.basis.get_scale()
		if skeleton.get_bone_name(bone).begins_with("eye"):
			scale_value.y *= maxf(0.07,1.0-blink*0.94)
		skeleton.set_bone_pose_scale(bone,scale_value)
	var values: Array = expression["mouth"]
	_mouth_pose = _mouth_pose.lerp(Vector4(values[0],values[1],values[2],values[3]),weight)
	values = expression["look"]
	var glance := Vector2(sin(_clock*0.73+style_index)*0.04,sin(_clock*0.51)*0.018) if not aiming else Vector2(0.0,aim_pitch*0.08)
	_eye_look = _eye_look.lerp(Vector2(values[0],values[1])+glance,weight)
	if face_material != null:
		face_material.set_shader_parameter("mouth",_mouth_pose)
	if eye_material != null:
		eye_material.set_shader_parameter("look",_eye_look)


func set_reaction(id: String) -> void:
	reaction_name = id
	reaction_elapsed = 0.0


func set_dance(id: String, variant: int = 0) -> void:
	dance_name = id
	dance_variant = variant % 3
	reaction_elapsed = 0.0


func _sample_values(values: Array) -> Transform3D:
	return Transform3D(Basis(Quaternion(values[3],values[4],values[5],values[6]).normalized()).scaled(Vector3(values[7],values[8],values[9])),Vector3(values[0],values[1],values[2]))


func _apply_reaction(delta: float) -> void:
	var id := dance_name+"_"+str(dance_variant) if not dance_name.is_empty() else reaction_name
	var clips: Dictionary = _action_data["clips"][Equipment.base(current_weapon)]
	if not clips.has(id):
		return
	var frames: Array = clips[id]
	var duration := (frames.size()-1)/30.0
	if dance_name.is_empty() and reaction_elapsed >= duration:
		reaction_name = ""
		for bone in _action_bones:
			if bone >= 0:
				skeleton.set_bone_pose_scale(bone,Vector3.ONE)
				if not _upper_bones.has(bone) and skeleton.get_bone_name(bone) != "hips":
					skeleton.set_bone_pose_position(bone,skeleton.get_bone_rest(bone).origin)
		if _kid_rig != null:
			_kid_rig.transform = _kid_rig.transform.interpolate_with(Transform3D.IDENTITY,1.0-exp(-15*delta))
		return
	var time := fmod(reaction_elapsed,duration) if not dance_name.is_empty() else reaction_elapsed
	var index := mini(int(time*30),frames.size()-2)
	var blend := time*30-index
	var weight := minf(1.0,time/0.07)*minf(1.0,(duration-time)/0.18) if dance_name.is_empty() else 1.0-exp(-15*delta)
	for i in _action_bones.size():
		var bone := _action_bones[i]
		if bone < 0:
			continue
		var a: Array = frames[index]["bones"][i]
		var b: Array = frames[index+1]["bones"][i]
		var pose := _sample_values(a).interpolate_with(_sample_values(b),blend)
		# Source actions use hair style 0. Preserve each variant's authored rest
		# positions instead of moving its strands to another hairstyle's anchors.
		pose.origin += skeleton.get_bone_rest(bone).origin-_action_rest[i].origin
		skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(pose.origin,weight))
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(pose.basis.get_rotation_quaternion(),weight))
		skeleton.set_bone_pose_scale(bone,skeleton.get_bone_pose_scale(bone).lerp(pose.basis.get_scale(),weight))
	if _kid_rig != null:
		var pose := _sample_values(frames[index]["kid"]).interpolate_with(_sample_values(frames[index+1]["kid"]),blend)
		_kid_rig.transform = _kid_rig.transform.interpolate_with(pose,weight)
	var mouth_a: Array = frames[index]["mouth"]
	var mouth_b: Array = frames[index+1]["mouth"]
	var mouth_target := Vector4(mouth_a[0],mouth_a[1],mouth_a[2],mouth_a[3]).lerp(Vector4(mouth_b[0],mouth_b[1],mouth_b[2],mouth_b[3]),blend)
	var look_a: Array = frames[index]["look"]
	var look_b: Array = frames[index+1]["look"]
	if face_material != null:
		face_material.set_shader_parameter("mouth",_mouth_pose.lerp(mouth_target,weight))
	if eye_material != null:
		eye_material.set_shader_parameter("look",_eye_look.lerp(Vector2(look_a[0],look_a[1]).lerp(Vector2(look_b[0],look_b[1]),blend),weight))


func set_weapon_charge(amount: float) -> void:
	if current_weapon=="bow" and original_weapons.has("bow"):
		preload("res://src/combat/ink_equipment_mesh.gd").set_bow_charge(original_weapons.bow,amount)

func set_weapon_pose(pitch: float, rolling: bool) -> void:
	aim_pitch = clampf(pitch, -0.8, 0.8)
	rolling_pose = rolling


func _gait_pose(frames: Array,index: int,phase: float) -> Transform3D:
	var frame := fposmod(phase,1.0)*frames.size()
	var first := int(frame)%frames.size()
	return (frames[first]["bones"][index] as Transform3D).interpolate_with(frames[(first+1)%frames.size()]["bones"][index],frame-first)


func _apply_source_gait(delta: float) -> void:
	var clips: Dictionary = _gaits[Equipment.base(current_weapon)]
	var phase := anim_phase/TAU
	var run_blend := clampf((anim_speed/maxf(run_speed,0.1)-0.3)/0.7,0.0,1.0)
	var weight := 1.0-exp(-15.0*delta)
	for i in _gait_bones.size():
		var bone := _gait_bones[i]
		var idle: Transform3D = clips["idle"][0]["bones"][i]
		var moving_pose := _gait_pose(clips["walk"],i,phase).interpolate_with(_gait_pose(clips["run"],i,phase),run_blend)
		var pose := idle.interpolate_with(moving_pose,gait_weight)
		skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(pose.origin,weight))
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(pose.basis.get_rotation_quaternion(),weight))
	if _kid_rig != null and reaction_name.is_empty() and dance_name.is_empty():
		_kid_rig.transform = _kid_rig.transform.interpolate_with(clips["idle"][0]["kid"],weight)


func _load_weapon_poses() -> void:
	if _weapon_pose_data.is_empty():
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/weapon_poses.json"))
		_weapon_pose_data = {"bones": raw["bones"], "weapons": {}}
		for weapon in raw["weapons"]:
			var clips := {}
			for clip in raw["weapons"][weapon]:
				var frames := []
				for frame in raw["weapons"][weapon][clip]:
					var poses: Array[Transform3D] = []
					for v in frame:
						poses.append(Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()),Vector3(v[0],v[1],v[2])))
					frames.append(poses)
				clips[clip] = frames
			_weapon_pose_data["weapons"][weapon] = clips
	for name_text in _weapon_pose_data["bones"]:
		_upper_bones.append(skeleton.find_bone(name_text))


func _clip_pose(frames: Array, bone: int, time: float) -> Transform3D:
	var frame := clampf(time * 30.0, 0.0, frames.size() - 1.0)
	var index := int(frame)
	return (frames[index][bone] as Transform3D).interpolate_with(frames[mini(index+1,frames.size()-1)][bone],frame-index)


func _apply_original_hold(delta: float) -> void:
	if not _weapon_pose_data.get("weapons", {}).has(Equipment.base(current_weapon)):
		return
	var clips: Dictionary = _weapon_pose_data["weapons"][Equipment.base(current_weapon)]
	var pitch_clip: String = "aim_high" if aim_pitch >= 0.0 else "aim_low"
	var weight := 1.0 - exp(-22.0 * delta)
	for i in _upper_bones.size():
		var bone := _upper_bones[i]
		if bone < 0:
			continue
		var carry: Transform3D = clips["roll" if rolling_pose and current_weapon == "roller" else "carry"][0][i]
		var aim: Transform3D = (clips["aim"][0][i] as Transform3D).interpolate_with(clips[pitch_clip][0][i],absf(aim_pitch)/0.8)
		var pose := carry.interpolate_with(aim,aim_weight if current_weapon != "roller" else 0.0)
		if action_time > 0.0 and clips.has(action_name):
			var action := _clip_pose(clips[action_name],i,action_elapsed)
			if action_name == "shoot":
				# Recoil is additive to the current camera pitch, rather than snapping to a neutral aim.
				var neutral: Transform3D = clips["aim"][0][i]
				pose.basis *= neutral.basis.inverse() * action.basis
				pose.origin += action.origin - neutral.origin
			else:
				pose = action
		var target := pose.basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(target,weight))
		skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(pose.origin,weight))
