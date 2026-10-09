extends "res://tests/godot/helpers/creative_fixture.gd"
const Ink = preload("res://src/world/surface_ink.gd")
const Area = preload("res://src/match/area_control.gd")

func _initialize() -> void:call_deferred("_run")
func face(id:int,paintable:bool,turf:bool,origin:Array,dead:Array=[]) -> Dictionary:
	return {"id":id,"paintable":paintable,"turf":turf,"wall":not turf,"origin":origin,"u":[1,0,0],"v":[0,0,1],"n":[0,1,0],"su":10,"sv":10,"grid":{"nu":10,"nv":10,"cu":1,"cv":1,"deadRuns":dead}}
func _run() -> void:
	var data := {"turfCells":99,"faces":[face(0,true,true,[0,0,0],[[0,1]]),face(1,true,false,[0,3,0]),face(2,false,true,[0,6,0])]}
	var ink:=Ink.new(data)
	var before:int=ink.version
	expect(ink.splat_face(2,5,5,2,0,.5)==0 and ink.version==before and ink.owner_at(2,5,5)==-1,"direct nonpaintable API cannot bypass restriction")
	expect(ink.splat_face(1,5,5,2,0,.5)==0 and ink.counts==[0,0] and ink.owner_at(1,5,5)==0,"wall ink is real but grants no turf credit or score")
	expect(ink.version>before and ink.consume_dirty_cells().has(1),"unscored wall changes still reach rendering")
	expect(ink.splat_face(0,.5,.5,.4,0,.5)==0 and ink.counts==[0,0],"covered cell grants no score or personal credit")
	var region:Dictionary={"center":Vector3(5,0,5),"u":Vector3.RIGHT,"v":Vector3.BACK,"n":Vector3.UP,"half_u":2.2,"half_v":2.2}
	var zone:=Ink.new(data,region)
	expect(zone.turf_total>0 and zone.turf_total<99,"zone denominator is only eligible central cells")
	expect(zone.splat_face(0,1,1,.9,0,.5)>0 and zone.counts==[0,0],"outside-zone ground charges resources without objective points")
	zone.splat_face(0,5,5,2,0,.5)
	expect(zone.coverage(0)>.5,"central ground scores")
	zone.splat_face(0,5,5,2,1,.5)
	expect(zone.counts[0]==0 and zone.counts[1]>0,"zone overwrite deducts previous team exactly")
	var rules:=Area.new();rules.enabled=true
	rules.tick(1,[.79,0]);expect(rules.owner==-1,"partial painting cannot capture")
	rules.tick(10,[.8,0]);expect(rules.owner==0 and rules.remaining[0]==90,"80 percent capture starts actual countdown")
	rules.tick(1,[.41,.59]);expect(rules.owner==0 and rules.remaining[0]==89,"ownership persists above loss threshold")
	rules.tick(1,[.4,.6]);expect(rules.owner==-1 and rules.penalty[0]==6,"losing control stops count and applies half-progress penalty")
	rules.tick(3,[.8,.2]);expect(rules.penalty[0]==3 and rules.remaining[0]==89,"recapture pays penalty before advancing count")
	rules.tick(4,[.8,.2]);expect(rules.penalty[0]==0 and rules.remaining[0]==88,"partial tick crosses penalty/count boundary exactly")
	rules.tick(1,[.1,.9]);expect(rules.owner==1 and rules.overtime(),"trailing controlling team gets overtime")
	rules.tick(13,[.1,.9]);expect(not rules.overtime() and rules.decide([.1,.9])==1,"overtime ends when controlling side takes the lead")
	rules.tick(90,[.1,.9]);expect(rules.winner==1,"zero counter wins early")
	rules.reset();expect(rules.decide([0,0])==-1 and rules.penalty==[0.0,0.0],"reset clears penalties and tied empty zone is a draw")
	rules.enabled=false;rules.tick(999,[1,0]);expect(rules.remaining==[100.0,100.0],"turf mode cannot run zone counter")
	expect(Area.central_region({"faces":[face(0,false,true,[0,0,0])]}).is_empty(),"invalid area has no silent fallback")
	# Every existing asset layout has a live central score denominator and both
	# navigation graphs can reach a point within its public bounds.
	var maps:=preload("res://src/core/map_catalog.gd")
	var layouts:=0
	for id in maps.IDS:
		for variant in maps.variant_count(id):
			var asset:String=id if variant==0 else id+"_v%d"%variant
			var real:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s_surfaces.json"%asset))
			var geometry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s.json"%asset))
			var spawn_points:Array=[]
			for values in geometry.spawnPads:spawn_points.append(Vector3(values[0],values[1],values[2]))
			var nav_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s_nav.json"%asset))
			var central:Dictionary=Area.central_region(real,nav_data,spawn_points)
			var field:=Ink.new(real,central)
			expect(not central.is_empty() and field.turf_total>0,asset+" has eligible zone cells")
			print("AUDIT: ",asset," center=",central.center," cells=",field.turf_total)
			var nav:=preload("res://src/world/team_navigation.gd").new();nav.setup(asset)
			for team in 2:
				var first:Vector3=spawn_points[team]
				var path:PackedVector3Array=nav.route(first,central.center,team)
				if path.is_empty() or path[-1].distance_to(central.center)>=3:print("AUDIT: failed route ",asset," team=",team," start=",first," end=",path[-1] if not path.is_empty() else Vector3.INF)
				expect(not path.is_empty() and path[-1].distance_to(central.center)<3,asset+" central goal reachable from team graph")
			layouts+=1
	expect(layouts==19,"all 19 layouts checked")
	await prepare(5,"tidewater","area","kit")
	expect(game.area.enabled and game.ink.turf_total<69366,"selected area rule reaches real scene and CPU grid")
	var at:Vector3=game.area.region.center
	game.ink.splat_world(at+Vector3.UP*.05,12,0,.5)
	game.area.tick(1,[game.ink.coverage(0),game.ink.coverage(1)])
	expect(game.area.owner==0,"actual painted CPU zone captures")
	var counts:Array=game.ink.counts.duplicate()
	game._update_hud()
	expect(game.ink.counts==counts and game.zone_label.visible and game.zone_label.text.contains("计数"),"HUD reads area truth without writing ledger")
	game.area.tick(100,[game.ink.coverage(0),game.ink.coverage(1)])
	game._judge_round()
	expect(game.winner==0 and game.result.contains("胜利"),"knockout winner reaches real results")
	game._start_round()
	expect(game.area.owner==-1 and game.area.remaining==[100.0,100.0] and game.area.penalty==[0.0,0.0],"restart resets area controller")
	await finish("nonpaintable/dead/wall restrictions, resource versus objective credit, capture/loss/penalty/overtime/draw, 19 layouts, CPU-driven scene HUD/results/restart")
