extends SceneTree
func _initialize() -> void:
 call_deferred("_check")
func _check() -> void:
 var scene := (load("res://scenes/world/tidewater_walk.tscn") as PackedScene).instantiate()
 root.add_child(scene)
 var walker: CharacterBody3D = scene.get_node("Walker")
 walker.collision_mask=16
 walker.auto_respawn=false
 # Kid fits under the roof on the lower floor, but not after raising feet 0.35 m.
 _box(Vector3(0,99.8,0),Vector3(8,0.4,10))
 _box(Vector3(0,100.175,2.5),Vector3(4,0.35,4))
 _box(Vector3(0,102.15,2.5),Vector3(4,1.0,4))
 walker.global_position=Vector3(0,100.05,-1)
 walker.velocity=Vector3.ZERO
 for i in range(12): await physics_frame
 var key := InputEventKey.new()
 key.physical_keycode=KEY_W
 key.pressed=true
 Input.parse_input_event(key)
 for i in range(50): await physics_frame
 key.pressed=false
 Input.parse_input_event(key)
 if walker.global_position.z>0.5 or not walker._body_fits_at(walker.global_position) or absf(walker.global_position.y-100.0)>0.05:
  printerr("FAIL: stepped through curb or into ceiling: ",walker.global_position)
  quit(1);return
 print("PASS: real movement rejects a curb under a low ceiling without embedding the character")
 quit()
func _box(at: Vector3,size: Vector3) -> void:
 var body:=StaticBody3D.new()
 body.collision_layer=16
 body.position=at
 var collision:=CollisionShape3D.new()
 var shape:=BoxShape3D.new()
 shape.size=size
 collision.shape=shape
 body.add_child(collision)
 root.add_child(body)
