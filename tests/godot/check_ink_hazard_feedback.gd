extends "res://tests/godot/helpers/creative_fixture.gd"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	await prepare(5, "tidewater")
	walker.grounded = true
	walker.ink_owner = 1
	# Run the real vitals path at different frame rates, rather than a UI-only hit.
	for hz in [30, 60, 120]:
		game._start_round()
		game.player_invuln = 0
		for i in hz: game._update_player_vitals(1.0 / hz)
		expect(absf(game.player_health - (game.actor_max_health(walker)-2)) < .01, "ordinary enemy ink costs two HP/s at %s Hz" % hz)
	# Leaving a short contact must finish its own report, not carry it into the next.
	game._start_round()
	game._update_player_vitals(.25)
	walker.ink_owner = -1
	game._update_player_vitals(.01)
	expect(is_zero_approx(game.ink_damage_trace), "leaving enemy ink clears pending damage")
	expect(game.damage_history.size() == 1 and absf(game.damage_history.back().amount - .5) < .01, "short contact reports actual fractional HP loss once")
	walker.ink_owner = 1
	game._update_player_vitals(.25)
	game.damage_player(300, false, bot, "shooter")
	game.damage_player(300, false, bot, "shooter")
	expect(game.player_respawn > 0, "real damage reaches death before lifecycle check")
	expect(is_zero_approx(game.ink_damage_trace), "death clears the remaining contact damage")
	game._start_round()
	expect(is_zero_approx(game.ink_damage_trace), "new round has no previous-life contact damage")
	# Already-applied environmental loss must not be clamped against the new HP.
	game.player_health = 3
	game._update_player_vitals(1)
	expect(game.player_health == 1 and game.player_respawn == 0, "enemy ink remains nonlethal")
	expect(game.damage_history.size() == 1 and absf(game.damage_history[0].amount - 2) < .01, "last two HP are reported as two, even with one HP remaining")
	# No fake damage/number when protection or the one-HP floor blocks the hazard.
	var count: int = game.damage_history.size()
	game._update_player_vitals(1)
	expect(game.damage_history.size() == count, "one-HP floor does not invent another hit")
	game._start_round()
	game.player_invuln = 2
	game._update_player_vitals(.5)
	expect(is_equal_approx(game.player_health,game.actor_max_health(walker)) and game.damage_history.is_empty(), "protection blocks hazard and feedback")
	# Environmental numbers cannot push an attributed shot out of the HUD.
	var feedback: RefCounted = game.presentation.incoming
	feedback.record("visible shooter", 12, Vector3.RIGHT)
	for i in 12: feedback.record("敌方墨面", 2, Vector3.INF, true)
	expect(feedback.entries.size() == 1 and feedback.entries[0].label == "visible shooter", "environment cannot evict an attacker card")
	expect(feedback.numeric_pops.size() == feedback.CAPACITY, "numeric feedback is bounded")
	expect(feedback.number_text(2) == "−2" and feedback.number_text(.5) == "−0.5", "numeric text contains only the actual loss")
	feedback.tick(.81)
	expect(feedback.numeric_pops.is_empty() and feedback.entries.size() == 1, "numbers expire sooner than weapon attribution")
	feedback.record("敌方墨面", 2, Vector3.INF, true)
	game._start_round()
	expect(feedback.numeric_pops.is_empty() and feedback.entries.is_empty(), "restart clears both display lifecycles")
	game.player_health = 118.00000000001
	combat.ink_amount = 98.00000000001
	game._update_hud()
	expect(game.health_label.text == "生命  118 / 132" and game.ink_label.text == "墨量  98 / 110", "HUD does not round floating-point noise up by one")
	expect(game.hud_view.displayed_amount(118.3) == 119, "real fractions keep the existing ceiling convention")
	await finish("two HP/s at three rates, short-contact/death reset, exact low-HP loss and blocked-hazard negatives")
