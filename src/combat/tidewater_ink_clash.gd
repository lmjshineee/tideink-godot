extends RefCounted

# Local action rule: enemy primary ink projectiles cancel one for one.
# Sweep in relative time; crossing paths at different times must never cancel.
var total:=0
var last_point:=Vector3.ZERO

func resolve(combat:Node3D,delta:float) -> void:
	if delta<=0:return
	var entries:Array[Dictionary]=[]
	var teams:Dictionary={}
	for shot in combat.projectiles:
		if shot.kind in ["shooter","canopy","blaster"]:
			entries.append({"shot":shot,"list":combat.projectiles,"arrow":false});teams[shot.team]=true
	for arrow in combat.bow.arrows:
		entries.append({"shot":arrow,"list":combat.bow.arrows,"arrow":true});teams[arrow.team]=true
	if teams.size()<2:return
	for entry in entries:_prepare(combat,entry,delta)
	var events:Array[Dictionary]=[]
	for i in entries.size():
		var a:Dictionary=entries[i]
		for j in range(i+1,entries.size()):
			var b:Dictionary=entries[j]
			if a.shot.team==b.shot.team:continue
			if not a.bounds.intersects(b.bounds):continue
			var t:=contact_time(a.start,a.motion,b.start,b.motion,float(a.radius)+float(b.radius))
			if t>=0 and t<float(a.limit) and t<float(b.limit):events.append({"a":i,"b":j,"t":t})
	events.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.t)<float(b.t))
	var consumed:Dictionary={}
	for event in events:
		if consumed.has(event.a) or consumed.has(event.b):continue
		var a:Dictionary=entries[event.a];var b:Dictionary=entries[event.b]
		consumed[event.a]=true;consumed[event.b]=true
		last_point=(a.start+a.motion*event.t+b.start+b.motion*event.t)*.5
		total+=1
		# Visual feedback carries no damage, explosion, ink ownership or special points.
		combat.feedback.emit("ink_hit",last_point,0,Vector3.UP)
		combat.feedback.emit("ink_hit",last_point,1,Vector3.UP)
		combat._sound("ink_hit_wall",last_point)
		for entry in [a,b]:
			entry.shot.visual.queue_free()
			entry.list.erase(entry.shot)

func _prepare(combat:Node3D,entry:Dictionary,delta:float) -> void:
	var shot:Dictionary=entry.shot
	var velocity:Vector3=shot.velocity
	var age:=float(shot.age)+delta
	if entry.arrow:
		if age>.16:velocity.y-=18*delta;velocity*=1-.15*delta
		entry.radius=float(shot.weapon.arrowRadius)
		entry.limit=minf(1.00001,(1.5-float(shot.age))/delta)
	else:
		if age>float(shot.straight):
			velocity.y-=float(shot.gravity)*delta
			velocity*=1-float(shot.drag)*delta
		entry.radius=.25 if shot.kind=="blaster" else .15
		entry.limit=minf(1.00001,(float(shot.life)-float(shot.age))/delta)
	entry.start=shot.visual.global_position
	entry.motion=velocity*delta
	var end:Vector3=entry.start+entry.motion
	var query:=PhysicsRayQueryParameters3D.create(entry.start,end,combat.world_mask(shot.team))
	query.hit_from_inside=true
	var hit:=combat.get_world_3d().direct_space_state.intersect_ray(query)
	var body_radius:float=float(shot.weapon.arrowRadius) if entry.arrow else .26 if shot.kind=="blaster" else .15
	var body:Dictionary=combat._segment_team_hit(entry.start,end,body_radius,shot.team)
	var length:float=entry.motion.length()
	if length>.0001:
		if not hit.is_empty():entry.limit=minf(entry.limit,(entry.start as Vector3).distance_to(hit.position)/length)
		if not body.is_empty():entry.limit=minf(entry.limit,float(body.distance)/length)
		if entry.arrow:entry.limit=minf(entry.limit,(float(shot.range)-float(shot.distance))/length)
	for intake in combat.counter.intakes.values():
		if intake.team==shot.team or intake.phase!="intake" or not combat.game.actor_alive(intake.actor):continue
		var t:float=combat.counter.entry_fraction(entry.start,end,intake)
		if t<entry.limit and combat._unblocked(intake.actor.global_position+Vector3.UP*1.05,(entry.start as Vector3).lerp(end,t)):
			entry.limit=t
	entry.bounds=AABB(entry.start,Vector3.ZERO).expand(end).grow(float(entry.radius))

static func contact_time(a:Vector3,am:Vector3,b:Vector3,bm:Vector3,radius:float) -> float:
	var separation:=a-b
	var motion:=am-bm
	var c:=separation.length_squared()-radius*radius
	if c<=0:return 0.0
	var speed:=motion.length_squared()
	if speed<.000001:return -1.0
	var dot:=separation.dot(motion)
	var discriminant:=dot*dot-speed*c
	if discriminant<0:return -1.0
	var t:=(-dot-sqrt(discriminant))/speed
	return t if t>=0 and t<=1 else -1.0
