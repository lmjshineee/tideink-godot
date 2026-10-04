extends "res://tools/capture/capture_expand14.gd"
func _run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	Setup.screen="setup";Setup.map_id="terrace_garden";Setup.selected_perk="focus";Setup.selected_item="healing";Setup.team_size=5
	Setup.pending_loadout={"player":"dualie","settings_path":"/private/tmp/inkwave-expand14-ui.cfg"}
	await fresh();var front:Control=game.frontend
	await save("garden-selection");await save("stage-selection")
	root.size=Vector2i(960,540);root.content_scale_size=root.size;game.settings.ui_scale=1.1;await frames(4);game._layout_hud();game._update_hud();await frames(8)
	for kind in front.strips:
		if not check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(front.strips[kind].get_global_rect()),"responsive strip "+kind):return
	for kind in ["weapon","item","perk"]:
		var strip:ScrollContainer=front.strips[kind];var area:Control=strip.get_child(0)
		print("AUDIT: min ",kind," strip=",strip.get_minimum_size()," area=",area.get_combined_minimum_size()," hbar=",strip.get_h_scroll_bar().get_combined_minimum_size()," vbar=",strip.get_v_scroll_bar().get_combined_minimum_size())
	print("AUDIT: responsive strips=",front.strips.weapon.get_global_rect()," / ",front.strips.item.get_global_rect()," / ",front.strips.perk.get_global_rect())
	if not check(not front.strips.weapon.get_global_rect().intersects(front.strips.item.get_global_rect()) and not front.strips.item.get_global_rect().intersects(front.strips.perk.get_global_rect()),"responsive rows do not overlap"):return
	for ch in "稳枪专注":
		if not check((load("res://assets/fonts/NotoSansSC.ttf") as Font).has_char(ch.unicode_at(0)),"bundled native glyph "+ch):return
	await save("small-selection")
	front.strips.weapon.ensure_control_visible(game.weapon_buttons.rapid);await frames(4);await click(game.weapon_buttons.rapid);await move(point(game.weapon_buttons.rapid));await frames(8)
	if not check(game.selected_weapon=="rapid" and front.hover_panel.visible and Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(front.hover_panel.get_global_rect()),"small card and real floating stats"):return
	await save("small-details")
	await click(front.pose_buttons.shoot);await frames(10);await save("character-close")
	print("AUDIT: small strips=",front.strips.weapon.get_global_rect()," / ",front.strips.item.get_global_rect()," / ",front.strips.perk.get_global_rect())
	print("PASS: final bundled font weight, compact item card, clipped rows without overlap and small-window native selection/detail")
	quit()
