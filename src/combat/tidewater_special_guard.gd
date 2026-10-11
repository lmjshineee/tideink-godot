extends Node3D

var game:Node3D
var combat:Node3D
var guards:Dictionary={}
func setup(owner:Node3D,source:Node3D) -> void:game=owner;combat=source
func remaining(actor:Node3D) -> float:
	return float(game.player_invuln) if actor==combat.walker else float(game.bot_invuln) if actor==game.get_node("Bot") else float(actor.invuln)
func begin(actor:Node3D,seconds:float) -> void:
	var id:=actor.get_instance_id()
	if guards.has(id):guards[id].visual.queue_free()
	var visual:=MeshInstance3D.new()
	var sphere:=SphereMesh.new();sphere.radius=.95;sphere.height=1.9;sphere.radial_segments=24;sphere.rings=12
	visual.mesh=sphere;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color=Color(preload("res://src/core/team_palette.gd").color(game.actor_team(actor)).lightened(.4),.17)
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled=true;mat.emission=Color(mat.albedo_color,.6)
	visual.material_override=mat;add_child(visual)
	visual.global_position=actor.global_position+Vector3.UP*.7
	guards[id]={"actor":actor,"visual":visual,"total":seconds,"age":0.0}
func cancel(actor:Node3D) -> void:
	var id:=actor.get_instance_id()
	if not guards.has(id):return
	guards[id].visual.queue_free();guards.erase(id)
func clear_all() -> void:
	for s in guards.values():s.visual.queue_free()
	guards.clear()
func tick(delta:float) -> void:
	for id in guards.keys():
		var s:Dictionary=guards[id]
		if game.phase!="playing" or not game.actor_alive(s.actor) or remaining(s.actor)<=0:
			s.visual.queue_free();guards.erase(id);continue
		s.age+=delta;s.visual.global_position=s.actor.global_position+Vector3.UP*.7
		s.visual.scale=Vector3.ONE*(1+.035*sin(float(s.age)*18))
		s.visual.material_override.albedo_color.a=.12+.07*remaining(s.actor)/float(s.total)
