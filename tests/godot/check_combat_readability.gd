extends "res://tests/godot/helpers/creative_fixture.gd"
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 await prepare(1,"tidewater")
 walker.global_position=Vector3(0,.05,-28);bot.global_position=Vector3(0,.05,-22)
 var blocker:=wall(Vector3(0,1.5,-25),Vector3(4,3,.5));await physics_frame
 combat._spawn_projectile("shooter",Vector3(0,1.1,-22),Vector3(0,0,-60),combat.weapons.shooter,1,bot)
 combat._update_projectiles(.1)
 expect(combat.projectiles.is_empty() and is_equal_approx(game.player_health,game.actor_max_health(walker)),"real wall stops hostile projectile and damage")
 var segment:Dictionary=combat.feedback.trail_states[96]
 expect(absf(segment.to.z-(-24.75))<.01,"visible trail ends at actual wall face")
 combat.feedback.advance(.3);expect(segment.life<=0,"trail expires")
 blocker.queue_free();await physics_frame
 # Real primary damage is attributed only after armour and respects frozen source.
 game.items.equip(walker,"shield");game.items.use(walker);bot.select_weapon("blaster")
 game.damage_player(82,false,bot,"blaster")
 var incoming:RefCounted=game.presentation.incoming
 expect(incoming.entries.size()==1 and incoming.entries[0].amount==22,"incoming indicator reports post-shield HP loss")
 expect(incoming.entries[0].label.contains(game.actor_name(bot)) and incoming.entries[0].label.contains(game._weapon_text("blaster")),"name and weapon preserved")
 var origin:Vector3=incoming.entries[0].origin;bot.global_position+=Vector3.RIGHT*8
 expect(incoming.entries[0].origin==origin,"hit direction never follows a hidden attacker")
 var camera:Camera3D=walker.get_node("Camera3D");camera.global_position=walker.global_position+Vector3.UP*2
 camera.look_at(camera.global_position+Vector3.FORWARD)
 incoming.entries.clear();incoming.record("right",5,walker.global_position+Vector3.RIGHT*5)
 expect(incoming.direction(incoming.entries[0],camera,walker.global_position).x>.99,"right-side attacker points right")
 camera.look_at(camera.global_position+Vector3.RIGHT)
 expect(incoming.direction(incoming.entries[0],camera,walker.global_position).y<-.99,"compass rotates with view")
 incoming.record("environment",3,Vector3.INF)
 expect(incoming.direction(incoming.entries[0],camera,walker.global_position)==Vector2.ZERO,"environment has no fabricated direction")
 incoming.tick(3);expect(incoming.entries.is_empty(),"incoming list expires")
 # Actual AI charge announces the shot, with finite depth-tested geometry.
 bot.global_position=Vector3(0,.05,-22);bot.select_weapon("charger");game.ai_level="standard"
 bot.target_actor=walker;bot.reaction_target=walker;bot.reaction_time=0;bot.attack_cooldown=0;bot.charge_time=0;bot.ink_amount=100
 game._update_bot(.1)
 expect(bot.charge_time>0 and bot.attack_tracer.visible,"charger pre-aim visible before firing")
 expect(combat.beams.is_empty(),"pre-aim does not fire or apply ray damage")
 # Real floor contact starts a fuse marker; airborne bombs do not project one.
 combat.throw_actor_bomb(bot);var bomb:Dictionary=combat.bombs.back()
 bomb.position=Vector3(6,.21,-26);bomb.velocity=Vector3(0,-2,0);bomb.visual.global_position=bomb.position
 for step in range(4):combat._update_bombs(.05)
 expect(combat.feedback.warnings.has(bomb.visual.get_instance_id()),"landed live bomb announces blast radius")
 combat._update_bombs(2)
 expect(combat.feedback.warnings.is_empty(),"exploded bomb clears its warning")
 await finish("wall-clipped real trails, post-armour named source, frozen view-relative direction, charger pre-aim and actual-fuse warning")
