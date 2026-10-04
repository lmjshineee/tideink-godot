extends Node3D

# A finite, directional projectile intake. Rays, bombs, discs and melee never
# enter this path. The caller limits the segment to its first map/body collision.
const DURATION := 3.0
const WINDUP := .4
const REACH := 6.0
const CAPACITY := 100.0
const MOVE_LIMIT := 2.5
var game: Node3D
var combat: Node3D
var intakes: Dictionary = {}
var casts_total := 0
var absorbed_total := 0
var shots_total := 0

func setup(owner_game: Node3D, owner_combat: Node3D) -> void:
	game = owner_game
	combat = owner_combat

func busy(actor: Node3D) -> bool:
	return intakes.has(actor.get_instance_id())

func move_limit(actor: Node3D) -> float:
	return MOVE_LIMIT if busy(actor) else INF

func begin(actor: Node3D, direction: Vector3) -> bool:
	if busy(actor) or not game.actor_alive(actor) or direction.length_squared() < .1: return false
	combat.canopy.cancel(actor)
	var visual := Node3D.new()
	add_child(visual)
	var color: Color = preload("res://src/core/team_palette.gd").color(game.actor_team(actor)).lightened(.35)
	for z in [.65, 2.0, 4.0, 6.0]:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = .94; mesh.outer_radius = 1.0
		mesh.rings = 32; mesh.ring_segments = 6
		ring.mesh = mesh
		ring.rotation.x = PI / 2
		ring.position.z = z
		ring.scale = Vector3.ONE * (.55 + .45 * z)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(color, .5 if z < 1 else .16)
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(ring)
	var motes: Array[MeshInstance3D] = []
	for i in 8:
		var mote := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = .075; sphere.height = .15
		mote.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		mote.material_override = material
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(mote); motes.append(mote)
	intakes[actor.get_instance_id()] = {"actor":actor, "team":game.actor_team(actor), "time":DURATION,
		"phase":"intake", "charge":0.0, "direction":direction.normalized(), "visual":visual,
		"motes":motes, "age":0.0, "absorbed":0}
	if actor == combat.walker:
		actor.action_move_limit = MOVE_LIMIT
		actor._set_horizontal(Vector2(actor.velocity.x,actor.velocity.z))
	casts_total += 1
	actor.set_meta("counter_casts",int(actor.get_meta("counter_casts",0))+1)
	_pose(intakes[actor.get_instance_id()])
	return true

func _pose(s: Dictionary) -> void:
	s.visual.global_position = s.actor.global_position + Vector3.UP * 1.05
	var direction: Vector3 = s.direction
	s.visual.basis = Basis.looking_at(direction, Vector3.UP if absf(direction.y) < .99 else Vector3.RIGHT, true)
	for i in s.motes.size():
		var t := fmod(float(s.age) * 1.4 + float(i) / 8, 1.0)
		var z := lerpf(5.8, .65, t)
		var angle := float(s.age) * 6 + float(i) * TAU / 8
		var r := (.55 + .45 * z) * .6
		s.motes[i].position = Vector3(cos(angle)*r, sin(angle)*r, z)
		s.motes[i].visible = s.phase == "intake"
	var mouth: MeshInstance3D = s.visual.get_child(0)
	mouth.scale = Vector3.ONE * (.84 + float(s.charge) / CAPACITY * .25)
	mouth.get_active_material(0).albedo_color.a = .7 if s.phase == "windup" else .5

func tick(delta: float) -> void:
	for key in intakes.keys():
		var s: Dictionary = intakes[key]
		if not game.actor_alive(s.actor): cancel(s.actor); continue
		s.age += delta
		s.time -= delta
		if s.phase == "intake":
			if s.actor == combat.walker:
				s.direction = combat._aim_direction(s.actor.global_position + Vector3.UP * 1.05, 24)
			else:
				# Aim changes require actual visibility, never a hidden transform.
				var target: Node3D = s.actor.target_actor
				if target != null and game.intel.can_see(s.actor, target):
					s.direction = (game.intel.point(target) - (s.actor.global_position + Vector3.UP*1.05)).normalized()
			if s.time <= 0: _windup(s)
		elif s.time <= 0:
			_fire(s); cancel(s.actor); continue
		_pose(s)

func _windup(s: Dictionary) -> void:
	s.phase = "windup"; s.time = WINDUP
	combat._ability_ring(s.actor.global_position, 2.2, WINDUP, s.team)

func _fire(s: Dictionary) -> void:
	var amount := 40.0 + .6 * float(s.charge)
	var weapon := {"id":"absorb_counter", "damage":amount, "directDamage":amount,
		"splashDamageMax":amount*.5, "splashDamageMin":amount*.25, "splashRadius":2.3,
		"burstRadius":2.3, "impactRadius":2.3}
	# Start at the body, so a close wall cannot be skipped by a muzzle offset.
	combat._spawn_projectile("counter", s.actor.global_position+Vector3.UP*1.05,
		(s.direction as Vector3)*38, weapon, s.team, s.actor)
	game.play_sound("shoot_blaster", s.actor.global_position)
	shots_total += 1

# Exact segment/cone intervals, including a segment with both endpoints outside.
# Cone axis z is limited to [.15, 6]; r = .55 + .45*z. Incoming direction matters.
func entry_fraction(start: Vector3, end: Vector3, s: Dictionary) -> float:
	var axis: Vector3 = s.direction
	var step := end - start
	if step.length_squared() < .000001 or step.normalized().dot(axis) > -.3: return INF
	var offset: Vector3 = start - (s.actor.global_position + Vector3.UP * 1.05)
	var z := offset.dot(axis); var dz := step.dot(axis)
	var radial := offset - axis*z; var dr := step - axis*dz
	var a := dr.dot(dr) - .2025*dz*dz
	var b := 2*(radial.dot(dr) - (.55+.45*z)*.45*dz)
	var c := radial.dot(radial) - pow(.55+.45*z, 2)
	var cuts: Array[float] = [0.0, 1.0]
	if absf(dz) > .000001:
		for plane in [.15, REACH]:
			var t: float = (plane-z)/dz
			if t > 0 and t < 1: cuts.append(t)
	if absf(a) < .000001:
		if absf(b) > .000001:
			var t := -c/b
			if t > 0 and t < 1: cuts.append(t)
	else:
		var discriminant := b*b-4*a*c
		if discriminant >= 0:
			for t in [(-b-sqrt(discriminant))/(2*a), (-b+sqrt(discriminant))/(2*a)]:
				if t > 0 and t < 1: cuts.append(t)
	cuts.sort()
	for i in cuts.size()-1:
		var middle := (cuts[i]+cuts[i+1])*.5
		var depth := z+dz*middle
		if depth >= .15 and depth <= REACH and (radial+dr*middle).length_squared() <= pow(.55+.45*depth,2): return cuts[i]
	return INF

func consume(start: Vector3, end: Vector3, team: int, damage: float) -> bool:
	var best := INF
	var selected: Dictionary = {}
	for s in intakes.values():
		if s.team == team or s.phase != "intake" or not game.actor_alive(s.actor): continue
		var t := entry_fraction(start, end, s)
		if t < best and combat._unblocked(s.actor.global_position+Vector3.UP*1.05, start.lerp(end,t)):
			best = t; selected = s
	if selected.is_empty(): return false
	selected.charge = minf(CAPACITY, float(selected.charge) + maxf(0, damage))
	selected.absorbed += 1; absorbed_total += 1
	combat.feedback.emit("hit", start.lerp(end,best), selected.team, -selected.direction)
	if selected.charge >= CAPACITY: _windup(selected)
	return true

func cancel(actor: Node3D) -> void:
	var key := actor.get_instance_id()
	if not intakes.has(key): return
	intakes[key].visual.queue_free(); intakes.erase(key)
	if actor == combat.walker:
		actor.firing_speed_limit = INF
		actor.action_move_limit = INF

func clear_all() -> void:
	for s in intakes.values(): cancel(s.actor)
