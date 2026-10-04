extends SceneTree
# Wall-clock native input replay. No teleports, damage fixtures or forced phase changes.
const Setup := preload("res://src/core/match_setup.gd")
var held := {}
var report := {"kind":"native automated input replay; human acceptance and temperature unmeasured","fps_cap":30,"render_scale":0.75,"rounds":[]}
var game: Node3D

func _initialize() -> void:
 seed(731)
 call_deferred("_run")

func _run() -> void:
 if DisplayServer.get_name() == "headless":
  printerr("FAIL: native Metal display required");quit(1);return
 root.size = Vector2i(1280,720)
 if OS.get_cmdline_user_args().has("--resume"):
  report = JSON.parse_string(FileAccess.get_file_as_string("res://render-evidence/creative16-full-matches.json"))
 var long_round := OS.get_cmdline_user_args().has("--long")
 var specs := [["modular_harbor",0,"disc","enemy_swim"],["prism_gallery",0,"dualie","balanced"]]
 for spec in specs:
  var completed := false
  for done in report["rounds"]:
   if done["map"] == spec[0] and int(done["duration"]) == (90 if spec[1] == 0 else 180):
    completed = true
  if completed:
   continue
  Setup.screen = "home"
  Setup.selected_item = "recall" if spec[2] == "disc" else "mist"
  Setup.map_id = spec[0]
  Setup.selected_perk=spec[3]
  Setup.random_map=Setup.map_id in ["tidewater","kelpline"]
  Setup.map_variant=1 if Setup.random_map else 0
  Setup.map_seed=731
  Setup.team_size = 5
  Setup.duration_index = spec[1]
  Setup.pending_loadout = {"player":spec[2],"settings_path":"/private/tmp/inkwave-full-qa-unused.cfg"}
  game = (load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
  root.add_child(game)
  current_scene = game
  await _frames(4)
  _tap(KEY_ENTER)
  await _frames(2)
  _tap(KEY_ENTER)
  await _frames(2)
  while game.get("phase") == "intro":
   await process_frame
  if game.get("phase") != "playing":
   printerr("FAIL: start input did not enter play");quit(1);return
  var duration := float(game.get("round_time"))
  var start := Time.get_ticks_usec()
  var previous := start
  var frames := PackedFloat64Array()
  var distances := 0.0
  var walker: CharacterBody3D = game.get_node("World/Walker")
  var combat: Node3D = game.get_node("Combat")
  var last_position := walker.global_position
  var highest := walker.global_position.y
  var lowest := highest
  var route := PackedVector3Array()
  var index := 0
  var target_index := 0
  var last_jump := -5.0
  var last_death := 0
  var last_progress := -20.0
  var diving := 0
  var weapons_seen := {}
  var jumped := 0
  var map_captured := false
  var warning_sampled := false
  print("AUDIT: start ",Setup.map_id," ",duration," seconds / native input / 5v5")
  while game.get("phase") == "playing":
   await process_frame
   var now := Time.get_ticks_usec()
   var elapsed := float(now-start)/1000000.0
   if elapsed > duration*1.7+30.0:
    printerr("FAIL: full match timed out; phase=",game.get("phase"));quit(1);return
   if elapsed > 1.0:
    frames.append(float(now-previous)/1000.0)
   previous = now
   if elapsed-last_progress >= 20.0:
    last_progress = elapsed
    print("AUDIT: ",Setup.map_id," elapsed=",roundi(elapsed)," remaining=",roundi(float(game.get("round_left")))," deaths=",game.get("local_deaths"))
   if game.perks.kind(walker)!=spec[3] or not game.perks.locked:
    printerr("FAIL: talent changed during play");quit(1);return
   if game.paused:
    _release()
    _button(MOUSE_BUTTON_LEFT, true)
    _button(MOUSE_BUTTON_LEFT, false)
    continue
   var dead := float(game.get("player_respawn")) > 0.0
   if dead:
    _key(KEY_W,false);_key(KEY_SHIFT,false);_button(MOUSE_BUTTON_LEFT,false);_button(MOUSE_BUTTON_RIGHT,false)
    var deaths := int(game.get("local_deaths"))
    if deaths > last_death:
     last_death = deaths
     _tap(KEY_R)
     route.clear()
    if bool(game.get("respawn_ready")):
     _tap(KEY_ENTER) # Player aims at the default base launch point and launches in one keypress.
    continue
   if bool(combat.call("special_ready")):
    _tap(KEY_F)
   if elapsed > 4 and fmod(elapsed, 9.0) < 0.1:
    _tap(KEY_E)
   if combat.selected_id == "dualie" and elapsed-last_jump > 1.3 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
    _tap(KEY_SPACE)
    last_jump = elapsed
   var displacement := walker.global_position.distance_to(last_position)
   if displacement < 2.0:
    distances += displacement
   last_position = walker.global_position
   highest = maxf(highest,walker.global_position.y)
   lowest = minf(lowest,walker.global_position.y)
   weapons_seen[combat.get("selected_id")] = true
   if route.is_empty() or index >= route.size():
    var target := Vector3(6.0 if target_index%2 == 0 else -6.0,0.0,0.0 if target_index%3 == 0 else (-10.0 if target_index%3 == 1 else 10.0))
    route = game.get("navigation").route(walker.global_position,target,0)
    index = 1 if route.size()>1 else 0
    target_index += 1
   if index < route.size():
    var offset := route[index]-walker.global_position
    var flat := Vector2(offset.x,offset.z)
    if flat.length()<0.45 and absf(offset.y)<0.65:
     index += 1
    elif flat.length()>0.01:
     var yaw := atan2(offset.x,offset.z)
     var look := InputEventMouseMotion.new()
     look.relative = Vector2(-wrapf(yaw-float(walker.get("camera_yaw")),-PI,PI)/float(walker.get("look_sensitivity")),(float(walker.get("camera_pitch"))+0.22)/float(walker.get("look_sensitivity")))
     Input.parse_input_event(look)
     Input.flush_buffered_events()
     _key(KEY_W,true)
     if bool(walker.get("grounded")) and elapsed-last_jump>1.2 and (offset.y>0.45 or int(elapsed)%7==0):
      _tap(KEY_SPACE)
      last_jump = elapsed
      jumped += 1
   var ink := float(combat.get("ink_amount"))
   var squid := int(walker.get("ink_owner")) == 0 and int(elapsed)%8>=5 and ink<70.0
   _key(KEY_SHIFT,squid)
   if bool(walker.get("squid_form")):
    diving += 1
   var firing := not squid and ink>3.0 and fmod(elapsed,3.0)<2.0
   _button(MOUSE_BUTTON_LEFT,firing)
   _button(MOUSE_BUTTON_RIGHT,elapsed>12.0 and fmod(elapsed,23.0)<0.16 and ink>71.0)
   _key(KEY_TAB,elapsed>20.0 and elapsed<21.3)
   if elapsed>20.5 and not map_captured:
    await _save("creative16-full-%s-%d-map" % [Setup.map_id,roundi(duration)])
    map_captured = true
   if not warning_sampled and elapsed>25.0:
    await _save("creative16-full-%s-%d-play" % [Setup.map_id,roundi(duration)])
    warning_sampled = true
  _release()
  var play_wall := float(Time.get_ticks_usec()-start)/1000000.0
  while game.get("phase") != "results":
   await process_frame
   if float(Time.get_ticks_usec()-start)/1000000.0>duration*1.7+40:
    printerr("FAIL: judging did not finish");quit(1);return
  await _frames(12)
  await _save("creative16-full-%s-%d-results" % [Setup.map_id,roundi(duration)])
  frames.sort()
  var average := 0.0
  for value in frames:
   average += value
  average /= maxf(1.0,frames.size())
  var sample := {"map":Setup.map_id,"geometry":preload("res://src/core/map_catalog.gd").asset_id(),"perk":game.perks.kind(walker),"max_hp":game.actor_max_health(walker),"max_ink":game.actor_ink_max(walker),"last_damage_history":game.damage_history.duplicate(true),"duration":duration,"play_wall_seconds":play_wall,"frames":frames.size(),"average_fps":1000.0/average,"p95_frame_ms":frames[int(frames.size()*0.95)],"p99_frame_ms":frames[int(frames.size()*0.99)],"p99_equivalent_fps":1000.0/frames[int(frames.size()*0.99)],"travel_m":distances,"height_min":lowest,"height_max":highest,"jump_inputs":jumped,"dive_frames":diving,"natural_deaths":last_death,"weapons_used":weapons_seen.keys(),"player_roll_count":int(game.mobility.state(walker).get("total",0)),"player_recall_count":int(walker.get_meta("recall_count",0)),"fx_events":combat.get("feedback").get("events").duplicate(),"turf_counts":game.get("ink").get("counts").duplicate(),"results":true,"restart":false}
  var bots_report: Array = []
  for actor in game.all_actors():
   if actor==walker: continue
   bots_report.append({"id":game.actor_id(actor),"name":game.actor_name(actor),"weapon":actor.weapon_id,"item":game.items.state(actor)["kind"],"perk":game.perks.kind(actor),"max_hp":game.actor_max_health(actor),"special_casts":game.bot_specials.state(actor)["casts"],"stats":actor.get_meta("match_stats").duplicate(true)})
  sample["bots"] = bots_report
  _tap(KEY_ENTER)
  await _frames(8)
  game = current_scene
  if game.get("phase") != "home":
   printerr("FAIL: results replay input did not return to home");quit(1);return
  sample["restart"] = true
  sample["restart_input"] = "Enter"
  report["rounds"].append(sample)
  var file := FileAccess.open("res://render-evidence/creative16-full-matches%s.json" % ("180" if long_round else ""),FileAccess.WRITE)
  file.store_string(JSON.stringify(report,"  ")+"\n")
  file.close()
  print("AUDIT: complete ",sample)
  game.queue_free()
  await _frames(2)
 Setup.duration_index = 0
 Setup.map_id = "tidewater"
 print("PASS: native full-duration creative-kit timed rounds with one-action base launcher respawn and item/special inputs, natural timer/results/restart; see measured coverage and limits in JSON")
 quit()

func _frames(n: int) -> void:
 for i in range(n):
  await process_frame
func _key(code: Key, pressed: bool) -> void:
 if held.get(code,false) == pressed:
  return
 held[code] = pressed
 var event := InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func _button(code: MouseButton, pressed: bool) -> void:
 var key := "mouse%d" % code
 if held.get(key,false) == pressed:
  return
 held[key] = pressed
 var event := InputEventMouseButton.new()
 event.button_index = code
 event.pressed = pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func _tap(code: Key) -> void:
 _key(code,true);_key(code,false)
func _release() -> void:
 for code in [KEY_W,KEY_SHIFT,KEY_SPACE,KEY_TAB]:
  _key(code,false)
 for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
  _button(button,false)
func _click(control: Control) -> void:
 var at := control.get_global_transform_with_canvas()*(control.size*0.5)
 var motion := InputEventMouseMotion.new()
 motion.position = at
 root.push_input(motion,true)
 await _frames(2)
 for pressed in [true,false]:
  var event := InputEventMouseButton.new()
  event.position = at
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed
  root.push_input(event,true)
  await _frames(1)
func _save(label: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://render-evidence/%s.png" % label)
