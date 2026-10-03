extends "res://tools/capture_counter_mist.gd"

func _run() -> void:
	evidence_prefix="hud24-gl" if OS.get_cmdline_user_args().has("--gl") else "hud24"
	if DisplayServer.get_name()=="headless": printerr("FAIL: native renderer required"); quit(1); return
	for id in ["prism_gallery","terrace_garden","viaduct"]:
		root.size=Vector2i(1280,720); root.content_scale_size=root.size; await prepare(5,id)
		var source_map: Node3D=game.get_node("World/Map")
		expect(source_map.MAP_FILE=="res://assets/maps/"+id+".json","fixture loads requested actual map "+id)
		expect(game.minimap.map_bounds==source_map.map_bounds and game.minimap.map_image.texture.resource_path=="res://assets/maps/"+id+"_minimap.png","minimap uses actual map bounds and texture "+id)
		print("AUDIT: ",source_map.MAP_FILE," bounds=",source_map.map_bounds.size," blocks=",source_map.block_count)
		game.phase="playing"; game.phase_time=4; game.deployment.clear(); game.paused=false; game.pointer_locked=true
		game.items.equip(walker,"ink_wings"); game.items.state(walker).cooldowns.ink_wings=8; game.perks.choices[walker.get_instance_id()]="dry_focus"
		combat.ink_amount=68; combat.special_points=combat.special_cost()*.63; game.player_health=93
		game.presentation.ability_flash=0
		var home: Vector3 = game.deployment.base_position(); walker.global_position=home
		var camera: Camera3D=walker.get_node("Camera3D"); camera.current=true; camera.global_position=home+Vector3(6,4,-8); camera.look_at(home+Vector3.UP)
		game.damage_actor(bot,100,0,walker,"shooter","躯干"); game.damage_actor(bot,100,0,walker,"shooter","躯干")
		expect(not game.actor_alive(bot),"actual dead actor state for compact roster")
		var center: Vector2=source_map.map_bounds.get_center()
		game.paint_at_world(Vector3(center.x,.9,center.y),0,16,.3)
		game.get_node("InkView").sync_dirty()
		for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
			for scale in [.9,1.0,1.1]:
				root.size=pixels; root.content_scale_size=pixels; game.settings.ui_scale=scale; await create_timer(.1).timeout; game._layout_hud(); game._update_hud(); game.tactics._process(.1)
				var layout: Dictionary=game.compact_hud_layout()
				var left: Rect2=layout.rosters[0]; var right: Rect2=layout.rosters[1]; var timer: Rect2=layout.timer; var shares: Rect2=layout.coverage
				expect(left.end.x<timer.position.x and right.position.x>timer.end.x,"both five-player rows flank countdown")
				expect(shares.end.x+10<=left.position.x and not shares.intersects(left),"true coverage block clears left actor row")
				expect(not shares.intersects(layout.map) and right.end.x<game.hud_root.size.x-90,"map, shares, players and special remain separate")
				expect(left.position.y==timer.position.y and right.position.y==timer.position.y and left.end.y<=56,"actor status belongs to the same compact top row")
				var f: Font=game.timer_label.get_theme_font("font"); var px: int=game.timer_label.get_theme_font_size("font_size")
				expect(f.get_string_size(game.timer_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x<=game.timer_label.size.x,"time digits fit at every scale")
				await snap(id+"-"+str(pixels.x)+"-"+str(roundi(scale*100)))
		# True face painting, rather than overriding percentages, exercises 100.0%.
		for i in game.ink.surfaces.size():
			var face: Dictionary=game.ink.surfaces[i]
			game.ink.splat_face(i,float(face.su)*.5,float(face.sv)*.5,maxf(face.su,face.sv)*2,0,0)
		game.get_node("InkView").sync_dirty(); game.comeback.tick(12)
		for i in 81: game.comeback.tick(.1)
		expect(game.ink.coverage(0)>.999 and game.comeback.team==1,"actual ink authority reaches 100% and weak-side support")
		game.round_left=8; combat.ink_amount=16; game.player_health=19; combat.special_points=combat.special_cost(); game.tactics._process(.5)
		await snap(id+"-low-final")
		for voice in game.sound.get_children():
			if voice.has_method("stop"): voice.stop()
		await create_timer(.06).timeout
		game.queue_free(); await process_frame; await process_frame
	await finish_without_game()

func finish_without_game() -> void:
	if failures.is_empty(): print("PASS: three verified map sources and aspects / both five-player rows beside timer / no map-coverage-roster-gauge overlap / two sizes and three UI scales / actual death, 100 percent paint, support and low-ink final countdown")
	quit(0 if failures.is_empty() else 1)
