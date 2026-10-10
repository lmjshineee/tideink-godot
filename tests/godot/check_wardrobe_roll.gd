extends SceneTree
const Visual := preload("res://src/actors/tidewater_character_visual.gd")
const Wardrobe := preload("res://src/actors/wardrobe_palette.gd")
const WardrobeMesh := preload("res://src/actors/wardrobe_mesh.gd")
const Setup := preload("res://src/core/match_setup.gd")
const Palette := preload("res://src/core/team_palette.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)
func cloth_material(node: Node) -> ShaderMaterial:
	if node is MeshInstance3D and node.mesh.surface_get_material(0).resource_name=="Cloth": return node.material_override
	for child in node.get_children():
		var result:=cloth_material(child)
		if result!=null:return result
	return null
func check_lod(node: Node, portrait: bool) -> void:
	if node is MeshInstance3D and not node.get_meta("procedural_equipment",false):
		var semantic: String=node.mesh.surface_get_material(0).resource_name
		var expected:=6.0 if portrait else (3.0 if semantic in ["Skin","Eyes","TeamHair"] else 1.0)
		expect(is_equal_approx(node.lod_bias,expected),"LOD budget "+semantic)
	for child in node.get_children():check_lod(child,portrait)
func _run() -> void:
	var seen: Dictionary={}
	var cuts: Dictionary={}
	var bottom_colors: Dictionary={}
	var shoe_colors: Dictionary={}
	for seed_value in 1200:
		var look:=Wardrobe.look(seed_value)
		expect(look==Wardrobe.look(seed_value),"seed reproducibility")
		seen[str(look.palette)+":"+str(look.graphic)]=true
		cuts[str([look.top,look.trousers,look.shoes])]=true
		bottom_colors[look.trouser_palette]=true;shoe_colors[look.shoe_palette]=true
	expect(seen.size()==32,"every curated colour/graphic combination reachable")
	expect(cuts.size()==64 and bottom_colors.size()==8 and shoe_colors.size()==8,"top/trousers/shoes and their colours roll independently")
	Palette.select(0);Setup.randomized=true;Setup.selected_attributes={"health":3,"ink":4}
	var team_colors: Array=[Palette.color(0),Palette.color(1)]
	var previous:=Setup.style_index
	for i in 128:
		Setup.random_appearance()
		expect(Setup.style_index!=previous,"ROLL must visibly change silhouette")
		expect(team_colors==[Palette.color(0),Palette.color(1)],"clothing ROLL cannot recolour teams/ink")
		expect(Setup.selected_attributes=={"health":3,"ink":4},"clothing ROLL cannot change attributes")
		previous=Setup.style_index
	# Deliberately mismatched seeds exercise the equality oracle below.
	var seeds: Array=[401,402]
	while Wardrobe.look(seeds[0])==Wardrobe.look(seeds[1]):seeds[1]+=1
	for style in 4:
		var bodies: Array[Node3D]=[]
		for seed_value in [seeds[0],seeds[0],seeds[1]]:
			var body:=Visual.new();body.style_index=style;body.ornament_seed=seed_value
			body.portrait_detail=bodies.size()==1
			root.add_child(body);body.set_physics_process(false);bodies.append(body)
			check_lod(body.original_rig,body.portrait_detail)
			var cloth:=cloth_material(body.original_rig)
			expect(cloth!=null,"production cloth exists")
			expect(int(cloth.get_shader_parameter("garment_kind"))==int(body.wardrobe.top),"cut independent of body and graphics")
			expect(int(cloth.get_shader_parameter("trouser_kind"))==int(body.wardrobe.trousers),"trouser decorations follow independently selected trousers")
			expect(cloth.get_shader_parameter("shirt_color")==Color(Wardrobe.COLORS[body.wardrobe.palette][0]).lerp(Palette.color(0),0.38),"shirt follows team theme with curated secondary colour")
			expect(int(cloth.get_shader_parameter("graphic"))==int(body.wardrobe.graphic),"seed reaches real material graphic")
		expect(cloth_material(bodies[0].original_rig)==cloth_material(bodies[1].original_rig),"preview and combat share immutable garment material")
		expect(cloth_material(bodies[0].original_rig)!=cloth_material(bodies[2].original_rig),"cache must distinguish different rolled clothes")
		for body in bodies:body.queue_free()
		await process_frame
	for top in 4:
		for trousers in 4:
			for shoes in 4:
				var mesh:=WardrobeMesh.combined(top,trousers,shoes)
				expect(mesh.get_surface_count()==1,"mixed clothing keeps one draw surface")
				expect(int(mesh.get_meta("lod_levels"))>=3,"mixed clothing retains imported distance LODs")
				expect(mesh.get_meta("garment_sources")==[top,trousers,shoes],"real garment geometry comes from each selected source")
				expect(mesh==WardrobeMesh.combined(top,trousers,shoes),"mesh combination cached")
				var arrays:=mesh.surface_get_arrays(0)
				for index in range(0,arrays[Mesh.ARRAY_WEIGHTS].size(),4):
					var total:=0.0
					for slot in 4:total+=arrays[Mesh.ARRAY_WEIGHTS][index+slot]
					expect(absf(total-1.0)<0.0001,"mixed geometry weights normalized")
	var original: Array=WardrobeMesh._arrays[0]
	var malformed: Array=original.duplicate(true)
	malformed[Mesh.ARRAY_INDEX][0]+=1
	expect(not WardrobeMesh.compatible(original,malformed),"negative: refuse reordered clothing topology")
	malformed=original.duplicate(true);malformed[Mesh.ARRAY_CUSTOM1][0]+=1
	expect(not WardrobeMesh.compatible(original,malformed),"negative: refuse semantic part mismatch")
	Setup.selected_attributes={};Setup.appearance_seed=401;Setup.style_index=0
	Setup.team_size=5;Setup.pending_loadout={"settings_path":"/private/tmp/wardrobe-rules.cfg"}
	var game: Node3D=(load("res://scenes/match/tidewater_play.tscn") as PackedScene).instantiate()
	root.add_child(game);game.set_physics_process(false)
	var player: Node3D=game.get_node("World/Walker/Body")
	expect(player.wardrobe==game.frontend.preview.model.wardrobe,"menu appearance matches player's actual clothes")
	for team in 2:
		var styles: Dictionary={}
		for actor in game.extra_bots:
			if actor.team==team:styles[actor.get_node("Body").style_index]=true
		expect(styles.size()==4,"both AI teams contain four distinct silhouettes")
	game._start_round();var seed_before:=Setup.appearance_seed;var style_before:=Setup.style_index
	var materials: Array=[]
	for actor in game.all_actors():materials.append(cloth_material(actor.get_node("Body").original_rig))
	game.randomize_appearance();game.choose_appearance(2)
	expect(Setup.appearance_seed==seed_before and Setup.style_index==style_before,"match lock rejects appearance changes")
	game.damage_player(1000.0)
	for i in game.all_actors().size():expect(materials[i]==cloth_material(game.all_actors()[i].get_node("Body").original_rig),"death keeps every actor's clothes")
	game.queue_free();await process_frame;await process_frame
	if failures.is_empty():print("PASS: seeded real wardrobe colours/graphics, cache separation negative, preview/combat match, no repeat or ink recolour, AI diversity and match/death locks; portrait/combat LOD budgets")
	else:printerr("FAIL: "+str(failures))
	quit(0 if failures.is_empty() else 1)
