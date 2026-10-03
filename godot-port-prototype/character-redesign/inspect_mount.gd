extends SceneTree
const Original := preload("res://tidewater_character_visual.gd")

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var model := Original.new()
	root.add_child(model)
	model.set_physics_process(false)
	for frame in 91:
		if frame in [0,30,90]:
			for name_text in ["chest","neck","head"]:
				var bone := model.skeleton.find_bone(name_text)
				print(frame," ",name_text," rest ",model.skeleton.get_bone_global_rest(bone)," pose ",model.skeleton.get_bone_global_pose(bone)," skeleton transform ",model.skeleton.global_transform)
		model.call("_animate",1.0/30.0)
	quit()
