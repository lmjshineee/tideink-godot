extends "res://tests/godot/helpers/creative_fixture.gd"

const Setup := preload("res://src/core/match_setup.gd")
const Palette := preload("res://src/core/team_palette.gd")
var output := ""
var report := {"kind":"controlled native Tidewater ink and traversal acceptance",
	"limits":"Fixed placement, frozen bots and manually advanced production match ticks. Input uses keyboard/mouse events and real walker physics. Not human feel, natural match, all-grid visibility, temperature or export evidence.",
	"cases":[],"focus_resumes":0,"source_sha256":{}}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not OS.has_feature("arm64") or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("FAIL: native arm64 display and new absolute evidence directory required");quit(1);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		printerr("FAIL: cannot create evidence directory");quit(1);return
	Setup.appearance_seed=731;Setup.randomized=true;Setup.style_index=0;Setup.ai_level="standard"
	Palette.random_palette={};Palette.palette_index=0
	Setup.pending_loadout={"player":"roller","settings_path":output.path_join("isolated-settings.cfg")}
	root.size=Vector2i(1280,720)
	await prepare(5,"tidewater")
	game.phase_time=1.0
	game.bot_respawn=999
	for actor in game.all_actors():
		if actor!=walker:
			actor.set_physics_process(false)
			if actor!=bot:actor.respawn_time=999
	report.environment={"engine":Engine.get_version_info().string,"arm64":OS.has_feature("arm64"),
		"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"api":RenderingServer.get_video_adapter_api_version(),"window":[root.size.x,root.size.y],
		"physics_hz":Engine.physics_ticks_per_second,"fps_cap":Engine.max_fps,"team_size":Setup.team_size,
		"render_scale":root.scaling_3d_scale}
	var paths: Array[String]=preload("res://tools/lib/source_inventory.gd").scripts()
	paths.append_array(["res://project.godot","res://assets/integrity.json",
		"res://tools/capture/verify_tidewater_ink_loop.gd","res://shaders/world/surface_ink.gdshader",
		"res://assets/maps/tidewater.json","res://assets/maps/tidewater_surfaces.json"])
	for path in paths:report.source_sha256[path]=FileAccess.get_sha256(path)
	await physics_frame
	_surface_samples()
	await _overview("surfaces-and-score")
	await _roll_route("downhill",Vector3(2.2,2.25,-6.375),PI)
	await _roll_route("uphill",Vector3(-2.2,.55,10.625),PI)
	await _dive_and_refill()
	await _dive_rejection()
	await _wall_climb()
	_release()
	report.status="passed" if failures.is_empty() else "failed"
	report.failures=failures.duplicate()
	var file:=FileAccess.open(output.path_join("ink-loop.json"),FileAccess.WRITE)
	if file==null:expect(false,"write native report")
	else:file.store_string(JSON.stringify(report,"\t"));file.close()
	await finish("native Tidewater 61 surface samples, CPU/texture/score agreement, uphill/downhill rolling, dive/refill, rejection and wall ledge")

func _surface_samples() -> void:
	var map: Node3D=game.get_node("World/Map")
	var view: Node3D=game.get_node("InkView")
	var samples: Array=[]
	for face in game.ink.surfaces:
		if not bool(face.turf):continue
		var g: Dictionary=face.grid
		var point:=Vector3.ZERO
		var selected:=-1
		# Select an exposed, live cell using the real map collision, not a guessed
		# bridge coordinate. One sample per face is deliberately a bounded audit.
		for index in game.ink.owners[int(face.id)].size():
			if game.ink.buried[int(face.id)][index]!=0:continue
			point=_vec(face.origin)+_vec(face.u)*(float(index%int(g.nu))+.5)*float(g.cu)+_vec(face.v)*(float(index/int(g.nu))+.5)*float(g.cv)
			var n:=_vec(face.n)
			var hit: Dictionary=map.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+n*.05,point-n*.05,1))
			if hit.is_empty():continue
			var found: Dictionary=map.find_surface(hit.position,hit.normal,int(hit.collider.get_meta("source_id",-1)))
			if not found.is_empty() and int(found.id)==int(face.id):selected=index;break
		expect(selected>=0,"physical paint sample for turf face %d" % int(face.id))
		if selected<0:continue
		var local_u:=(float(selected%int(g.nu))+.5)*float(g.cu)
		var local_v:=(float(selected/int(g.nu))+.5)*float(g.cv)
		for team in [0,1]:
			game.paint_at_world(point+_vec(face.n)*.06,team,.42,.31,Vector3.ZERO,0,walker if team==0 else bot)
			var counts: Array=game.ink.counts.duplicate()
			view.sync_dirty()
			expect(game.ink.owner_at(int(face.id),local_u,local_v)==team,"physical sample receives team ownership")
			expect(view.images.has(int(face.id)),"sample allocates visual texture")
			if view.images.has(int(face.id)):
				expect(view.images[int(face.id)].get_pixel(selected%int(g.nu),selected/int(g.nu))==view.TEAM_MASKS[team],"texture encodes actual sampled cell owner")
			expect(game.ink.counts==counts,"visual synchronization preserves score")
		samples.append({"face":int(face.id),"block":int(face.block),"cell":selected,"normal":face.n})
	expect(samples.size()==61,"all 61 Tidewater turf faces have physical samples")
	var counted:=[0,0]
	for face in game.ink.surfaces:
		if not bool(face.turf):continue
		for i in game.ink.owners[int(face.id)].size():
			var owner:int=game.ink.owners[int(face.id)][i]
			if owner>0 and game.ink.buried[int(face.id)][i]==0:counted[owner-1]+=1
	expect(game.ink.counts==counted,"coverage numerator equals owned, live turf cells")
	for team in [0,1]:expect(is_equal_approx(game.ink.coverage(team),float(counted[team])/float(game.ink.turf_total)),"coverage divides by the fixed effective-cell denominator")
	var counts_before: Array=game.ink.counts.duplicate()
	var wall: Dictionary=game.ink.surfaces[5]
	var wall_center:=_vec(wall.origin)+_vec(wall.u)*float(wall.su)*.5+_vec(wall.v)*float(wall.sv)*.5
	game.paint_at_world(wall_center+_vec(wall.n)*.06,0,.42,.31)
	view.sync_dirty()
	var wall_score_unchanged:bool=game.ink.counts==counts_before
	expect(wall_score_unchanged,"wall ink does not change final turf score")
	var lower_before: PackedByteArray=game.ink.owners[2].duplicate()
	game.paint_at_world(Vector3(-2.5,2.86,-2.5),0,.42,.31)
	expect(game.ink.owners[2]==lower_before,"upper deck paint does not reach the lower floor")
	report.cases.append({"case":"surface ownership/visual/scoring","sample_count":samples.size(),"samples":samples,
		"counts":counted,"turf_cells":game.ink.turf_total,"wall_score_unchanged":wall_score_unchanged,
		"upper_deck_leaves_lower_floor_unchanged":game.ink.owners[2]==lower_before})

func _roll_route(label: String, at: Vector3, yaw: float) -> void:
	await _place(at,yaw)
	combat.select_weapon("roller");game.selected_weapon="roller"
	combat.ink_amount=100
	var start:=walker.global_position
	var frames:=0
	key(KEY_W,true);mouse(true)
	while frames<100 and Vector2(walker.global_position.x-start.x,walker.global_position.z-start.z).length()<3.2:
		await _tick();frames+=1
	_release()
	await _ticks(6)
	var distance:=Vector2(walker.global_position.x-start.x,walker.global_position.z-start.z).length()
	var delta_y:=walker.global_position.y-start.y
	var owner:int=walker._floor_ink_owner()
	expect(distance>=3.0,"actual rolling input travels on "+label)
	expect(delta_y<-.8 if label=="downhill" else delta_y>.8,"actual rolling follows slope on "+label)
	expect(owner==0,"roller leaves own ink under the player on "+label)
	report.cases.append({"case":label,"input":"W + left mouse","start":_array(start),"end":_array(walker.global_position),
		"travel_xz_m":distance,"height_delta_m":delta_y,"frames":frames,"floor_owner":owner,"ink":combat.ink_amount})
	await _capture("roller-"+label)

func _dive_and_refill() -> void:
	combat.ink_amount=35.0
	var start:=walker.global_position
	key(KEY_SHIFT,true)
	await _ticks(30)
	var gained:float=combat.ink_amount-35.0
	expect(walker.squid_form and walker.grounded,"actual Shift enters grounded own-ink swimming")
	expect(gained>20,"own-ink swimming restores ink through production combat ticks")
	key(KEY_S,true)
	await _ticks(8)
	var moved:=walker.global_position.distance_to(start)
	expect(moved>.5 and walker.squid_form,"own-ink movement continues with Shift + S")
	report.cases.append({"case":"dive/refill/swim","input":"Shift then S","fixture_ink_start":35,
		"ink_gain_after_30_ticks":gained,"travel_m":moved,"squid":walker.squid_form})
	_release()
	await _ticks(4)
	expect(not walker.squid_form,"releasing Shift exits swim on open ground")
	await _capture("swim-and-refill")

func _dive_rejection() -> void:
	await _place(Vector3(0,.03,-28),0)
	key(KEY_SHIFT,true);await _ticks(4)
	expect(not walker.squid_form,"dry floor rejects actual Shift input")
	_release();await _ticks(3)
	game.paint_at_world(walker.global_position+Vector3.UP*.06,1,1.4,.31)
	key(KEY_SHIFT,true);await _ticks(4)
	expect(walker._floor_ink_owner()==1 and not walker.squid_form,"balanced player cannot dive into enemy ink")
	report.cases.append({"case":"dry/enemy dive rejection","input":"Shift","enemy_floor_owner":walker._floor_ink_owner(),"squid":walker.squid_form})
	_release()

func _wall_climb() -> void:
	game.ink.splat_face(5,5,1.4,3,0,.31)
	game.paint_at_world(Vector3(3.8,2.86,0),0,1.5,.31)
	game.get_node("InkView").sync_dirty()
	await _place(Vector3(5.5,.03,0),-PI/2)
	var start:=walker.global_position
	var peak:=start.y
	var snapped:=false
	key(KEY_W,true);key(KEY_SHIFT,true)
	for i in 100:
		await _tick()
		peak=maxf(peak,walker.global_position.y)
		if not snapped and peak>1.3:await _capture("wall-climb");snapped=true
		if walker.global_position.x<4.65 and walker.global_position.y>2.7:break
	_release();await _ticks(20)
	expect(peak>2.6 and walker.global_position.x<4.8 and walker.grounded,"actual Shift + W climbs and settles above the painted wall ledge")
	report.cases.append({"case":"wall climb/ledge","input":"Shift + W then release","start":_array(start),
		"end":_array(walker.global_position),"peak_y":peak,"grounded":walker.grounded})
	await _capture("wall-ledge")
	walker.set_physics_process(false)

func _place(at: Vector3, yaw: float) -> void:
	_release()
	walker.set_physics_process(false)
	walker.reset_movement_state();walker.global_position=at
	walker.camera_yaw=yaw;walker.camera_pitch=-.3;walker.look_enabled=true
	walker.get_node("Camera3D").current=true;walker._update_camera()
	game._set_pointer_lock(true);game.paused=false
	walker.set_physics_process(true)
	await _ticks(6)

func _tick() -> void:
	await physics_frame
	if game.paused:
		report.focus_resumes+=1;game._set_pointer_lock(true);game.paused=false
	game._physics_process(1.0/float(Engine.physics_ticks_per_second))

func _ticks(count: int) -> void:
	for i in count:await _tick()

func _release() -> void:
	for code in [KEY_W,KEY_S,KEY_SHIFT]:key(code,false)
	mouse(false)

func _overview(label: String) -> void:
	var camera:=Camera3D.new();game.add_child(camera);camera.current=true
	camera.global_position=Vector3(11,10,-15);camera.look_at(Vector3(0,1.4,-3))
	await _capture(label)
	camera.queue_free()

func _capture(label: String) -> void:
	game._update_hud()
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	expect(not picture.is_empty() and picture.save_png(output.path_join(label+".png"))==OK,"native screenshot "+label)

static func _vec(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
static func _array(v: Vector3) -> Array:return [v.x,v.y,v.z]
