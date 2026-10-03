extends "res://tools/creative_fixture.gd"
func _initialize() -> void: call_deferred("_run")
func shares(a: float, b: float) -> void:
	# Isolate the controller using authority counts; never touch its derived team state.
	game.ink.counts = [roundi(game.ink.turf_total*a),roundi(game.ink.turf_total*b)]
func advance(seconds: float) -> void:
	for i in ceili(seconds/.1): game.comeback.tick(.1)
func _run() -> void:
	await prepare(); shares(.40,.10)
	advance(11.9); expect(game.comeback.team == -1,"initial twelve-second grace prevents early support")
	advance(7.8); expect(game.comeback.team == -1,"persistent gap requires eight seconds")
	advance(.4); expect(game.comeback.team == 1,"actual 30-point deficit activates weaker side")
	expect(is_equal_approx(game.perks.refill(bot),1.2) and game.perks.refill(walker) == 1,"team buff includes bot with no leading-side gain")
	bot.global_position = Vector3(0,.05,-20); bot.route = [bot.global_position]; bot.route_index = 0; bot.repath_time = 99
	bot.select_weapon("shooter"); bot.ink_amount = 10; bot.last_fire_time = 99; bot.paint_cooldown = 99; bot.attack_cooldown = 99; bot.target_actor = null; await physics_frame
	var rate: float = combat.weapon_data.player.inkRefillKid; bot._tick_team(.1)
	expect(is_equal_approx(bot.ink_amount,10+rate*1.2*.1),"actual bot refill uses weaker-side rate")
	var bs: Dictionary = game.bot_specials.state(bot); bs.points = 0; game.bot_specials.charge(bot,10)
	expect(is_equal_approx(bs.points,11.5),"bot actual special meter gains support factor")
	shares(.26,.18); advance(4.9); expect(game.comeback.team == 1,"recovery hold prevents threshold flicker")
	advance(.2); expect(game.comeback.team == -1,"support expires after sustained gap <= ten points")
	shares(.10,.40); advance(8.1); expect(game.comeback.team == 0,"symmetric support can move to local weaker side")
	combat.ink_amount = 10; combat.last_fire_time = 99; combat.tick(.1,false,false)
	expect(is_equal_approx(combat.ink_amount,10+rate*1.2*.1),"local actual standing refill receives the same support")
	combat.special_points = 0; combat._add_turf(10); expect(is_equal_approx(combat.special_points,11.5),"local actual charge receives support")
	var points: float = combat.special_points; combat.special_active = "storm"; combat._add_turf(10); expect(combat.special_points == points,"support never bypasses special self-charge exclusion"); combat.special_active = ""
	game.paused = true; var age: float = game.comeback.age; advance(5); expect(game.comeback.age == age,"pause freezes threshold clocks"); game.paused = false
	game.phase = "results"; game.judged_coverage = [.35,.22]; game.winner = 0
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = pixels; root.content_scale_size = pixels; await process_frame; game._layout_hud(); game.tactics._process(.033)
		var t: Control = game.tactics; var map_rect := Rect2(t.map.position,t.map.size)
		expect(t.map.size.x >= t.size.x*.44 and map_rect.end.x < t.panel.position.x,"larger map remains in left half without table overlap")
		for label in t.coverage_labels: expect(label.position.y >= map_rect.end.y and label.get_rect().end.x <= t.panel.position.x,"both final shares fit below left map")
		expect(t.map.quarter_turns == 1 and t.map.map_image.size.y > t.map.map_image.size.x,"long map rotates to fill left region without stretching")
		expect(not t.map.show_border and not t.map.show_live_marks,"results retain no border/live clutter")
		var p0: Vector2 = t.map._project(Vector3(t.map.map_bounds.position.x,0,t.map.map_bounds.position.y)); var p1: Vector2 = t.map._project(Vector3(t.map.map_bounds.end.x,0,t.map.map_bounds.end.y))
		expect(Rect2(Vector2.ZERO,t.map.size).grow(1).has_point(p0) and Rect2(Vector2.ZERO,t.map.size).grow(1).has_point(p1),"rotated map corners remain within view")
	game.phase = "playing"; game.tactics._process(.1)
	for pixels in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = pixels; root.content_scale_size = pixels; game.settings.ui_scale = 1.1 if pixels.x<1000 else 1.0; await process_frame; game._layout_hud(); game._update_hud(); game.tactics._process(.033)
		var minimap_rect: Rect2 = game.minimap.get_rect(); var coverage_rect: Rect2 = game.tactics.live_rect
		expect(minimap_rect.position==Vector2(16,16),"playing map is in upper-left corner")
		expect(not game.minimap.show_border and is_equal_approx(minimap_rect.size.x/minimap_rect.size.y,game.minimap.map_bounds.size.x/game.minimap.map_bounds.size.y),"live map has no frame or padded square container")
		expect(coverage_rect.position.x>=minimap_rect.end.x+10 and coverage_rect.position.y==minimap_rect.position.y,"live shares align above and beside minimap")
		expect(coverage_rect.end.x<game.score_panel.position.x,"live shares leave room for timer at both UI scales")
		expect(game.feed_label.position.y>=minimap_rect.end.y,"kill feed clears new minimap position")
	expect(is_equal_approx(game.tactics.live_coverage.x,game.ink.coverage(0)*100) and is_equal_approx(game.tactics.live_coverage.y,game.ink.coverage(1)*100),"live HUD retains real all-surface shares including neutral ground")
	game._finish_round(); expect(game.comeback.team == -1,"finish clears support")
	await finish("result larger rotated left map/below-map percentages at two sizes, live true shares, timed/hysteretic symmetric support, actual player/bot refill/charge, pause/finish and no special loop")
