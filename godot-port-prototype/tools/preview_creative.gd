extends SceneTree
# Opens the rebuilt bow on the six-metre hollow viaduct.
func _initialize() -> void:
 var setup:=preload("res://match_setup.gd")
 setup.screen="setup";setup.selected_perk="balanced";setup.selected_item="bomb"
 setup.map_id="viaduct";setup.random_map=false;setup.team_size=5
 setup.pending_loadout={"player":"bow"}
 call_deferred("_open")
func _open() -> void:
 var game:Node3D=(load("res://tidewater_play.tscn") as PackedScene).instantiate()
 root.add_child(game);current_scene=game
 game.frontend._select_pose("shoot")
 game.frontend.preview.yaw=1.1;game.frontend.preview._update_camera()
 DisplayServer.window_set_title("INKWAVE · 三弦墨弓重做 · 半蓄爆裂 / 满蓄精准 · 当前源码")
