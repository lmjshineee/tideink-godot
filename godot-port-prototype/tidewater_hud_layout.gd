extends RefCounted
# Reserve the timer and both roster rows before allocating the coverage block.
static func measure(view: Vector2, map_extent: Vector2, slots: int) -> Dictionary:
	var compact := view.x < 1100
	var timer := Rect2(Vector2(view.x*.5-52,12),Vector2(104,40))
	var pitch := 24.0 if compact else 26.0
	var roster_width := maxi(1,slots)*pitch
	var left := Rect2(Vector2(timer.position.x-10-roster_width,12),Vector2(roster_width,42))
	var right := Rect2(Vector2(timer.end.x+10,12),Vector2(roster_width,42))
	var map_size := map_extent/maxf(1,maxf(map_extent.x,map_extent.y))*(110 if compact else 132)
	var map := Rect2(Vector2(16,16),map_size)
	var coverage_x := map.end.x+10
	var coverage := Rect2(Vector2(coverage_x,16),Vector2(maxf(74,minf(136,left.position.x-12-coverage_x)),38))
	return {"timer":timer,"rosters":[left,right],"pitch":pitch,"map":map,"coverage":coverage}
