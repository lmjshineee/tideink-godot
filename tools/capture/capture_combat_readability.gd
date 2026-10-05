extends "res://tests/godot/helpers/creative_fixture.gd"
var output:=""
func _initialize() -> void:call_deferred("_run")
func capture(label:String) -> void:
 game.paused=false;game._update_hud();await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func _run() -> void:
 if DisplayServer.get_name()=="headless" or Engine.get_architecture_name()!="arm64":quit(1);return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 preload("res://src/core/match_setup.gd").pending_loadout={"player":"shooter","settings_path":"/private/tmp/tideink-experience-unused.cfg"}
 root.size=Vector2i(1280,720);await prepare(1,"tidewater")
 game.phase_time=2;walker.global_position=Vector3(0,.05,-28);bot.global_position=Vector3(0,.05,-21);bot.select_weapon("shooter")
 var camera:Camera3D=walker.get_node("Camera3D");camera.global_position=Vector3(3.8,3.2,-24);camera.look_at(Vector3(0,1,-24.5));camera.current=true
 await physics_frame
 combat._spawn_projectile("shooter",bot.global_position+Vector3.UP*1.05,Vector3(0,0,-30),combat.weapons.shooter,1,bot)
 combat.advance_effects(.10)
 var transform:Transform3D=combat.feedback.trail_pools[2].get_instance_transform(0)
 expect(absf(transform.basis.y.length()-3.0)<.01,"native trail has actual swept length in local mesh axis")
 await capture("hostile-trail")
 for i in range(3):combat.advance_effects(.07)
 expect(game.presentation.incoming.entries.size()>0 and game.player_health<120,"actual hostile projectile yields named hit and HP loss")
 await capture("attacker-direction")
 bot.global_position=Vector3(3,.05,-22);bot.select_weapon("charger");bot.attack_cooldown=0;bot.target_actor=walker;bot.reaction_target=walker;bot.reaction_time=0
 bot.ink_amount=100;game._update_bot(.12)
 expect(bot.attack_tracer.visible and bot.charge_time>0,"native charge has visible pre-aim before firing")
 await capture("charger-preaim")
 combat.throw_actor_bomb(bot);var bomb:Dictionary=combat.bombs.back()
 bomb.position=Vector3(2,.21,-26);bomb.velocity=Vector3(0,-2,0);bomb.visual.global_position=bomb.position
 for i in range(3):combat._update_bombs(.05)
 expect(combat.feedback.warnings.has(bomb.visual.get_instance_id()),"native real bomb fuse has terrain warning")
 await capture("bomb-warning")
 var report:={"kind":"controlled native: real swept projectile and hit, bot charger charge, confirmed bomb fuse","fixture_focus_pause_overridden":true,"architecture":Engine.get_architecture_name(),"failures":failures,"source_sha256":{}}
 for path in preload("res://tools/lib/source_inventory.gd").scripts():report.source_sha256[path]=FileAccess.get_sha256(path)
 var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
 await finish("native actual trail geometry, real named hit/direction, charger pre-aim and bomb-fuse warning")
