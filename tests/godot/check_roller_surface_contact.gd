extends "res://tests/godot/helpers/creative_fixture.gd"

const SurfaceInk := preload("res://src/world/surface_ink.gd")
const RAMP_FACES := [42,46,81,124,133,179,183,218,261,270]
var data: Dictionary

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await prepare(5,"tidewater")
	# This fast rule fixture does not exercise sound; stop the opening music before
	# freeing its scene, allowing the audio server to drain its playback queue.
	for voice in game.sound.get_children():
		if voice.has_method("stop"):
			voice.stop()
			voice.stream = null
	await create_timer(.15).timeout
	await physics_frame
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tidewater_surfaces.json"))
	# Same contact centres, same seeds and width, both travel directions. Exercise
	# the player and bot callers, not a second implementation of the ink stamp.
	for face_id in RAMP_FACES + [76,119]:
		var face: Dictionary = data.faces[face_id]
		var n := _vec(face.n)
		var along: Vector3 = _vec(face.u) if absf(n.x) > .01 else _vec(face.v)
		var forward := Vector3(along.x,0,along.z).normalized()
		for team in [0,1]:
			var a := _stroke(face,along,forward,team)
			var b := _stroke(face,along,-forward,team)
			expect(mini(a,b)>40,"roller paints a usable route on face %d team %d" % [face_id,team])
			expect(absf(float(a-b))/float(maxi(1,maxi(a,b))) <= .05,
				"roller route footprint must not collapse downhill: face %d team %d cells %d/%d" % [face_id,team,a,b])
			print("AUDIT: roller face=",face_id," team=",team," opposite direction cells=",a,"/",b)
	# The stamp must stop at unsupported drops and at an unpaintable prop, rather
	# than projecting through the obstruction onto the scoreable base floor.
	_reset_ink()
	combat.paint_bot_roll(Vector3(35,0,0),Vector3.FORWARD,1)
	expect(game.ink.counts == [0,0],"water/gap receives no floor stamp")
	var blocker := wall(Vector3(0,.25,-28),Vector3(4,.5,4))
	blocker.set_meta("paintable",false)
	await physics_frame
	combat.paint_bot_roll(Vector3(0,.5,-28),Vector3.FORWARD,1)
	expect(game.ink.counts == [0,0],"unpaintable support does not ink the floor underneath")
	blocker.queue_free()
	await physics_frame
	var grate := wall(Vector3(0,.2,-28),Vector3(4,.1,4))
	grate.collision_layer = 8
	grate.set_meta("paintable",false)
	await physics_frame
	combat.paint_bot_roll(Vector3(0,.25,-28),Vector3.FORWARD,1)
	expect(game.ink.counts == [0,0],"standing roller does not stamp through an unpaintable grate")
	grate.queue_free()
	# The brush is shared by every map. Include the steepest long ramp in each
	# other layout so a Tidewater fix cannot silently stop painting steeper slopes.
	for map_id in ["kelpline","coral_market","prism_gallery","viaduct","modular_harbor","terrace_garden"]:
		game.queue_free()
		await process_frame
		await prepare(5,map_id)
		for voice in game.sound.get_children():
			if voice.has_method("stop"):
				voice.stop();voice.stream=null
		await create_timer(.15).timeout
		await physics_frame
		data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s_surfaces.json" % map_id))
		var selected:Dictionary={}
		for face in data.faces:
			if bool(face.turf) and float(face.n[1])<.999 and (selected.is_empty() or float(face.n[1])<float(selected.n[1])):
				selected=face
		expect(not selected.is_empty(),"shared roller ramp fixture in "+map_id)
		if selected.is_empty():continue
		var n:=_vec(selected.n)
		var along:Vector3=_vec(selected.u) if absf(n.x)>.01 else _vec(selected.v)
		var forward:=Vector3(along.x,0,along.z).normalized()
		for team in [0,1]:
			var a:=_stroke(selected,along,forward,team)
			var b:=_stroke(selected,along,-forward,team)
			expect(mini(a,b)>40 and absf(float(a-b))/float(maxi(1,maxi(a,b)))<=.05,
				"shared roller slope footprint in %s team %d cells %d/%d" % [map_id,team,a,b])
			print("AUDIT: shared roller map=",map_id," face=",selected.id," team=",team," opposite direction cells=",a,"/",b)
	await finish("roller surface contact: both teams, ten Tidewater ramps, flat decks, shared seven-map slopes, unsupported drop, unpaintable support and grate")

func _stroke(face: Dictionary, along: Vector3, forward: Vector3, team: int) -> int:
	_reset_ink()
	var n := _vec(face.n)
	var center := _vec(face.origin)+_vec(face.u)*float(face.su)*.5+_vec(face.v)*float(face.sv)*.5
	combat.ink_amount = 100.0
	walker.get_node("Body").rotation.y = atan2(forward.x,forward.z)
	game.painting_actor = walker if team==0 else bot
	game.bot_painting = team==1
	seed(731)
	for i in range(-5,6):
		var target := center+along*float(i)*.28
		var feet := target-forward*.75
		feet.y = (n.dot(center)-n.x*feet.x-n.z*feet.z)/n.y
		if team==0: combat._paint_roll_at(feet,forward*.28,combat.weapons.roller)
		else: combat.paint_bot_roll(feet,forward,team)
	var count := 0
	for owner in game.ink.owners[int(face.id)]:
		if int(owner)==team+1: count += 1
	return count

func _reset_ink() -> void:
	game.ink = SurfaceInk.new(data)
	walker.ink = game.ink
	game.charge_special = false

static func _vec(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
