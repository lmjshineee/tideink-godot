extends SceneTree
const Setup:=preload("res://match_setup.gd")
const Details:=preload("res://loadout_details.gd")
var failed:=false
func _initialize() -> void:call_deferred("_run")
func expect(ok:bool,label:String) -> void:
	if not ok:failed=true;printerr("FAIL: ",label)
func _run() -> void:
	Setup.screen="setup";Setup.selected_perk="balanced";Setup.map_id="prism_gallery";Setup.team_size=5
	var game:Node3D=(load("res://tidewater_play.tscn") as PackedScene).instantiate();root.add_child(game);await process_frame;game.set_physics_process(false)
	var front:Control=game.frontend
	expect(front.map_buttons.size()==preload("res://map_catalog.gd").IDS.size() and front.stage_preview.asset_id=="prism_gallery","seven scrollable map choices and actual selected geometry")
	expect(front.stage_preview.map.block_count==game.get_node("World/Map").block_count,"map preview and real stage share all collision definitions")
	expect(front.stage_preview.view.own_world_3d and front.preview.view.own_world_3d,"independent inspection worlds")
	for ch in "稳枪专注":expect((load("res://assets/fonts/NotoSansSC.ttf") as Font).has_char(ch.unicode_at(0)),"bundled CJK glyph "+ch)
	var initial:Vector3=game.get_node("World/Walker").global_position
	front.preview.set_pose("run");front.preview._process(0.1);front.model._physics_process(0.1)
	expect(front.model.animation_state()["moving"] and front.model.gait_weight>0,"inspection stage uses source gait")
	expect(game.get_node("World/Walker").global_position==initial,"preview never moves match character")
	expect(Details.weapon(game,"shooter")["body"].contains("伤害 30") and Details.item(game,"bomb")["body"].contains("消耗 70"),"hover reads adjusted combat data")
	game.perks.select_player("saver")
	expect(Details.weapon(game,"shooter")["body"].contains("0.76") and Details.weapon(game,"shooter")["body"].contains("节墨"),"hover reflects actual selected talent cost")
	for id in game.weapon_order:
		expect(Details.weapon(game,id)["body"].count("★")>=5 and Details.weapon(game,id)["body"].contains("机动") and Details.weapon(game,id)["body"].contains("相对比较"),"floating stars and expanded detail "+id)
		expect(not game.weapon_cards[id].has_node("Stars"),"undivided weapon card "+id)
	for id in game.items.KINDS:expect(Details.item(game,id)["body"].contains("冷却"),"item detail "+id)
	for id in preload("res://tidewater_perks.gd").ORDER:expect(Details.perk(id)["body"].contains("锁定"),"perk detail "+id)
	expect(front.weapon_area.visible and front.item_area.visible and front.perk_area.visible,"all loadout categories visible on one screen")
	game.weapon_buttons["charger"].pressed.emit();front.item_buttons["recall"].pressed.emit();front.perk_buttons["enemy_swim"].pressed.emit()
	expect(game.selected_weapon=="charger" and Setup.selected_item=="recall" and Setup.selected_perk=="enemy_swim","one-screen choices preserve each other")
	root.size=Vector2i(960,540);root.content_scale_size=root.size;game.settings.ui_scale=1.1;game._layout_hud();game._update_hud();await process_frame
	expect(not front.strips.weapon.get_global_rect().intersects(front.strips.item.get_global_rect()) and not front.strips.item.get_global_rect().intersects(front.strips.perk.get_global_rect()),"small-window loadout rows never overlap")
	game._begin_intro();expect(not front.preview.enabled and not front.stage_preview.enabled and not front.hover_panel.visible,"inspectors stop and hover closes at match start")
	expect(not game.perks.select_player("enemy_swim"),"talent still locked at intro")
	game.queue_free();await process_frame
	if not failed:print("PASS: stage-first real geometry, isolated source animation, adjusted weapon/item/perk details, live talent costs, simultaneous loadout choices and match visibility/lock")
	quit(1 if failed else 0)
