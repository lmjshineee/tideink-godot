extends RefCounted
# One public, finite central area. Ownership comes only from SurfaceInk.
var enabled := false
var region: Dictionary = {}
var owner := -1
var remaining := [100.0,100.0]
var best := [100.0,100.0]
var penalty := [0.0,0.0]
var capture_start := 100.0
var winner := -1

static func central_region(data: Dictionary, nav_data: Dictionary = {}, spawns: Array = []) -> Dictionary:
	# Prefer a live central platform to the buried floor below it. Small props,
	# border trims and spawn platforms cannot become the objective.
	var chosen: Dictionary = {}
	var nearest := INF
	var reachable := _reachable_keys(nav_data,spawns)
	for face in data.faces:
		if not bool(face.paintable) or not bool(face.turf) or float(face.n[1])<.99 or minf(float(face.su),float(face.sv))<6:continue
		var grid:Variant=face.grid
		if not grid is Dictionary:continue
		var blocked:=PackedByteArray();blocked.resize(int(grid.nu)*int(grid.nv))
		for run in grid.deadRuns:
			for index in range(int(run[0]),int(run[0])+int(run[1])):blocked[index]=1
		var prefix:=PackedInt32Array();prefix.resize((int(grid.nu)+1)*(int(grid.nv)+1))
		var stride:int=int(grid.nu)+1
		for y in int(grid.nv):
			for x in int(grid.nu):
				var pos:int=(y+1)*stride+x+1
				prefix[pos]=int(blocked[y*int(grid.nu)+x])+prefix[pos-1]+prefix[pos-stride]-prefix[pos-stride-1]
		var origin:=Vector3(face.origin[0],face.origin[1],face.origin[2])
		var u:=Vector3(face.u[0],face.u[1],face.u[2])
		var v:=Vector3(face.v[0],face.v[1],face.v[2])
		for index in blocked.size():
			if blocked[index]:continue
			var local_u:float=(float(index%int(grid.nu))+.5)*float(grid.cu)
			var local_v:float=(float(index/int(grid.nu))+.5)*float(grid.cv)
			# Keep the entire marker on this surface.
			if minf(local_u,float(face.su)-local_u)<2 or minf(local_v,float(face.sv)-local_v)<2:continue
			var at:=origin+u*local_u+v*local_v
			var distance:=Vector2(at.x,at.z).length()+absf(at.y)*.05
			if distance>=nearest:continue
			if not nav_data.is_empty() and not _near_reachable(at,reachable):continue
			var hu:=minf(6,minf(float(face.su)*.4,minf(local_u,float(face.su)-local_u)))
			var hv:=minf(5,minf(float(face.sv)*.4,minf(local_v,float(face.sv)-local_v)))
			var x0:=maxi(0,int((local_u-hu)/float(grid.cu)));var x1:=mini(int(grid.nu),ceili((local_u+hu)/float(grid.cu)))
			var y0:=maxi(0,int((local_v-hv)/float(grid.cv)));var y1:=mini(int(grid.nv),ceili((local_v+hv)/float(grid.cv)))
			var covered:int=prefix[y1*stride+x1]-prefix[y1*stride+x0]-prefix[y0*stride+x1]+prefix[y0*stride+x0]
			if float(covered)/float(maxi(1,(x1-x0)*(y1-y0)))>.25:continue
			nearest=distance
			chosen={"center":at,"u":u,"v":v,"n":Vector3.UP,
				"half_u":hu,"half_v":hv}
	return chosen

static func _reachable_keys(data: Dictionary, spawns: Array) -> Dictionary:
	if data.is_empty() or spawns.size()!=2:return {}
	var nodes:Dictionary={}
	for node in data.nodes:nodes[int(node.id)]=node
	var common:Dictionary={}
	for team in 2:
		var first:=-1;var distance:=INF
		for node in data.nodes:
			if int(node.zone)==1-team:continue
			var point:=Vector3(node.p[0],node.p[1],node.p[2])
			var d:float=point.distance_squared_to(spawns[team])
			if d<distance:distance=d;first=int(node.id)
		var reached:Dictionary={first:true};var queue:Array[int]=[first];var cursor:=0
		while cursor<queue.size():
			var id:int=queue[cursor];cursor+=1
			for edge in nodes[id].edges:
				var to:int=int(edge.to)
				if int(nodes[to].zone)==1-team or reached.has(to):continue
				reached[to]=true;queue.append(to)
		if team==0:common=reached
		else:
			for id in common.keys():
				if not reached.has(id):common.erase(id)
	var keys:Dictionary={}
	for id in common:
		var node:Dictionary=nodes[id]
		if int(node.zone)>=0:continue
		keys[Vector3i(roundi(node.p[0]),roundi(float(node.p[1])*4),roundi(node.p[2]))]=true
	return keys

static func _near_reachable(at: Vector3, keys: Dictionary) -> bool:
	var key:=Vector3i(roundi(at.x),roundi(at.y*4),roundi(at.z))
	for x in range(-1,2):
		for z in range(-1,2):
			if keys.has(key+Vector3i(x,0,z)):return true
	return false

func reset() -> void:
	owner=-1;remaining=[100.0,100.0];best=[100.0,100.0];penalty=[0.0,0.0];capture_start=100;winner=-1

func tick(delta: float, coverage: Array) -> void:
	if not enabled or winner>=0:return
	var next: int = owner
	if float(coverage[0])>=.8:next=0
	elif float(coverage[1])>=.8:next=1
	elif owner>=0 and float(coverage[owner])<=.4:next=-1
	if next!=owner:
		if owner>=0:penalty[owner]+=ceil(maxf(0,capture_start-float(remaining[owner]))*.5)
		owner=next
		if owner>=0:capture_start=float(remaining[owner])
	if owner<0:return
	var spent := minf(delta,float(penalty[owner]))
	penalty[owner]-=spent
	remaining[owner]=maxf(0,float(remaining[owner])-(delta-spent))
	best[owner]=minf(float(best[owner]),float(remaining[owner]))
	if remaining[owner]<=0:winner=owner

func overtime() -> bool:
	return enabled and owner>=0 and float(best[owner])>=float(best[1-owner])

func decide(coverage: Array) -> int:
	if winner>=0:return winner
	if not is_equal_approx(float(best[0]),float(best[1])):return 0 if best[0]<best[1] else 1
	if not is_equal_approx(float(coverage[0]),float(coverage[1])):return 0 if coverage[0]>coverage[1] else 1
	return -1

func goal(lane: int) -> Vector3:
	return region.center+region.u*float((lane%3)-1)*float(region.half_u)*.45+region.v*float((lane%2)*2-1)*float(region.half_v)*.35

func add_marker(parent: Node3D) -> void:
	if not enabled:return
	var center: Vector3 = region.center+Vector3.UP*.045
	for side in 4:
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size=Vector3(float(region.half_u)*2,.045,.16) if side<2 else Vector3(.16,.045,float(region.half_v)*2)
		line.mesh=mesh;line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("ffd949")
		line.material_override=mat;parent.add_child(line)
		line.global_basis=Basis(region.u,region.n,region.u.cross(region.n))
		line.global_position=center+(region.v if side<2 else region.u)*(float(region.half_v) if side<2 else float(region.half_u))*(-1 if side%2==0 else 1)
