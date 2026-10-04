"""Wave v3: slender facial planes, closed mouth and layered fine tentacles.

Game coordinates throughout: +Y up, +Z front, feet at zero. The body is reused
in Godot; the head is authored at its final size, with no guessed scale offset.
The editable cages and fused sculpt are kept separately in the .blend source.
"""
from pathlib import Path
import math, json, hashlib
import bpy, bmesh
from mathutils import Vector, Quaternion

OUT=Path(__file__).resolve().parent
TAU=math.tau
FACE_X=.88
HEAD_XZ=.92
HEAD_HEIGHT=.80
HEAD_PIVOT_Y=1.018
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
parts=[]
guides=bpy.data.collections.new('Editable sculpt cages');bpy.context.scene.collection.children.link(guides)
guides.hide_render=True

def head_y(y):return HEAD_PIVOT_Y+(y-HEAD_PIVOT_Y)*HEAD_HEIGHT if y>HEAD_PIVOT_Y else y
def P(p):return Vector((p[0]*HEAD_XZ,-p[2]*HEAD_XZ,head_y(p[1])))
def G(p):
    y=HEAD_PIVOT_Y+(p[2]-HEAD_PIVOT_Y)/HEAD_HEIGHT if p[2]>HEAD_PIVOT_Y else p[2]
    return Vector((p[0]/HEAD_XZ,y,-p[1]/HEAD_XZ))
def srgb(s):
    a=[int(s[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in a)+(1.,)
def material(name,tint,rough=.7,coat=0):
    m=bpy.data.materials.new(name);m.diffuse_color=srgb(tint)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=srgb(tint);p.inputs['Roughness'].default_value=rough;p.inputs['Coat Weight'].default_value=coat
    return m
MAT={'skin':material('SculptSkin','ffd5b8',.74),'eye':material('SculptEyes','f5f0e6',.27,.1),'ink':material('SculptInk','18202b',.82),'hair':material('SculptHair','ff681d',.4,.12),'cup':material('SculptSuction','ffd6a9',.58),'ear':material('SculptEar','cb876e',.78),'mouth':material('SculptMouth','713631',.8),'tooth':material('SculptTeeth','f2e9d5',.56)}

def activate(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
def mesh(name,v,f,mat,uv=None):
    data=bpy.data.meshes.new(name);data.from_pydata([P(p) for p in v],[],f);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.data.materials.append(MAT[mat])
    for p in data.polygons:p.use_smooth=True
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    if uv:
        layer=data.uv_layers.new(name='UVMap')
        for loop in data.loops:layer.data[loop.index].uv=uv[loop.vertex_index]
    parts.append(o);return o
def subdiv(o,n=2,keep=False):
    if keep:
        cage=o.copy();cage.data=o.data.copy();guides.objects.link(cage);cage.name=o.name+' control cage';cage.hide_set(True)
    activate(o);m=o.modifiers.new('Sculpt surface subdivision','SUBSURF');m.levels=n;m.render_levels=n;bpy.ops.object.modifier_apply(modifier=m.name)
    return o
def sphere(name,c,r,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=P(c));o=bpy.context.object;o.name=name;o.scale=(r[0]*HEAD_XZ,r[2]*HEAD_XZ,r[1]*HEAD_HEIGHT)
    bpy.ops.object.transform_apply(location=True,rotation=False,scale=True);o.data.materials.append(MAT[mat]);parts.append(o)
    for p in o.data.polygons:p.use_smooth=True
    return o
def interpolate(points,t):
    ps=[Vector(p) for p in points];x=t*(len(ps)-1);i=min(len(ps)-2,int(x));u=x-i
    a,b=ps[i],ps[i+1];m0=(ps[min(i+1,len(ps)-1)]-ps[max(i-1,0)])*.5;m1=(ps[min(i+2,len(ps)-1)]-ps[i])*.5
    return a*(2*u**3-3*u*u+1)+m0*(u**3-2*u*u+u)+b*(-2*u**3+3*u*u)+m1*(u**3-u*u)
def smooth(a,b,x):
    t=min(1.,max(0.,(x-a)/(b-a)));return t*t*(3-2*t)
def loft(name,profiles,mat,radial=32,n=2):
    # Cross-sections: y, width, front depth, rear depth, front/back centre shift.
    v=[];f=[]
    for y,w,front,back,zcenter in profiles:
        for i in range(radial):
            a=TAU*i/radial;c=math.cos(a)
            z=(front*max(c,0.)**.66 if c>=0 else back*c)+zcenter
            v.append((w*math.sin(a),y,z))
    for j in range(len(profiles)-1):
        for i in range(radial):a=j*radial+i;b=j*radial+(i+1)%radial;f.append((a,b,b+radial,a+radial))
    f.extend([tuple(reversed(range(radial))),tuple((len(profiles)-1)*radial+i for i in range(radial))])
    return subdiv(mesh(name,v,f,mat),n,True) if n else mesh(name,v,f,mat)

# Closely spaced sections describe a continuous, narrower jaw-to-temple curve.
PROFILE=[(1.018,.017,.062,.028,-.004),(1.027,.035,.084,.048,-.002),(1.043,.061,.103,.066,0),(1.065,.083,.114,.084,0),(1.090,.106,.120,.104,0),(1.120,.124,.125,.119,0),(1.148,.138,.129,.133,0),(1.181,.146,.130,.141,0),(1.218,.147,.128,.143,0),(1.255,.140,.115,.134,0),(1.286,.125,.094,.116,0),(1.310,.098,.064,.085,0),(1.329,.049,.024,.036,0),(1.338,.010,.005,.008,0)]
face=loft('Face planes',PROFILE,'skin',32,2)
neck=loft('Short tapered neck',[(.976,.046,.040,.043,-.008),(.987,.043,.038,.040,-.011),(1.017,.035,.036,.036,-.016),(1.047,.038,.037,.043,-.019),(1.076,.047,.045,.055,-.014)],'skin',24,2)
nose=loft('Nose bridge and alae',[(1.148,.005,.003,.009,.126),(1.154,.012,.008,.014,.130),(1.164,.015,.012,.018,.129),(1.173,.010,.009,.015,.125),(1.185,.004,.004,.010,.119),(1.194,.002,.003,.006,.115)],'skin',20,2)

def front(x,y):
    i=max(0,min(len(PROFILE)-2,next((j-1 for j,p in enumerate(PROFILE) if p[0]>=y),len(PROFILE)-2)))
    a,b=PROFILE[i],PROFILE[i+1];t=max(0.,min(1.,(y-a[0])/(b[0]-a[0])));w=a[1]*(1-t)+b[1]*t;d=a[2]*(1-t)+b[2]*t
    return d*max(.002,1-(x/max(.005,w))**2)**.33

# Cheekbones are already shaped in the continuous face cage. Additional spheres
# created unwanted hamster-like cheek lobes and are deliberately not used.

# Eye aperture boundary is drawn as two distinct Bezier arcs, not an ellipse.
UP=[(.031,1.194),(.055,1.224),(.090,1.231),(.123,1.227)]
LOW=[(.031,1.194),(.058,1.173),(.094,1.182),(.123,1.227)]
def cubic(ps,t):
    a,b,c,d=[Vector(p) for p in ps];return a*(1-t)**3+b*3*(1-t)**2*t+c*3*(1-t)*t*t+d*t**3
def bounds(t):return cubic(LOW,t),cubic(UP,t)
def eye_z(x,y):return .082+math.sqrt(max(.000025,.052**2-(x-.076)**2-((y-1.201)*.94)**2))
def eye_outline(side):
    xy=[cubic(UP,i/24) for i in range(25)]+[cubic(LOW,i/24) for i in range(23,-1,-1)]
    return [Vector((side*p.x*FACE_X,p.y,eye_z(p.x,p.y))) for p in xy]
def tube(name,points,radius,mat,closed=False,radial=10):
    v=[];f=[];ps=[Vector(p) for p in points]
    for j,c in enumerate(ps):
        tangent=(ps[(j+1)%len(ps)]-ps[j-1 if j else (-1 if closed else 0)]).normalized()
        up=Vector((0,0,1));width=tangent.cross(up).normalized();up=width.cross(tangent).normalized()
        for i in range(radial):a=TAU*i/radial;v.append(c+width*(radius*math.cos(a))+up*(radius*math.sin(a)))
    for j in range(len(ps) if closed else len(ps)-1):
        for i in range(radial):a=j*radial+i;b=j*radial+(i+1)%radial;d=((j+1)%len(ps))*radial+i;c=((j+1)%len(ps))*radial+(i+1)%radial;f.append((a,d,c,b))
    if not closed:f.extend([tuple(reversed(range(radial))),tuple((len(ps)-1)*radial+i for i in range(radial))])
    return mesh(name,v,f,mat)
for side in [-1,1]:
    tube('Continuous orbital rim',eye_outline(side),.0040,'skin',True,12)

# Pointed ears with a real raised helix and recessed centre. The shell joins skin.
EAR=[(.151,1.224,.007),(.180,1.242,-.004),(.235,1.246,-.011),(.226,1.207,.010),(.205,1.178,.026),(.172,1.179,.026),(.152,1.196,.018)]
for side in [-1,1]:
    center=Vector((.186,1.210,.004));v=[];f=[]
    for r,d in [(.01,.002),(.42,.003),(.73,.022),(1.,.002),(1.,-.010),(.01,-.017)]:
        for p in EAR:q=center+(Vector(p)-center)*r;q.x*=side*FACE_X;q.z+=d;v.append(q)
    for j in range(5):
        for i in range(7):a=j*7+i;b=j*7+(i+1)%7;f.append((a,b,b+7,a+7))
    f.extend([tuple(range(7)),tuple(reversed(range(35,42)))])
    subdiv(mesh('Ear helix',v,f,'skin'),2,True)
    inner=[]
    for r,d in [(.015,.005),(.45,.005),(.55,.009)]:
        for p in EAR:q=center+(Vector(p)-center)*r;q.x*=side*FACE_X;q.z+=d;inner.append(q)
    f=[]
    for j in range(2):
        for i in range(7):a=j*7+i;b=j*7+(i+1)%7;f.append((a,b,b+7,a+7))
    f.append(tuple(range(7)))
    mesh('Ear concha tint',inner,f,'ear')

# Fuse skin volumes into one sculpt, then smooth its transitions and cut sockets.
skin_parts=[p for p in parts if p.data.materials[0]==MAT['skin']]
activate(skin_parts[0])
for p in skin_parts:p.select_set(True)
bpy.ops.object.join();face=bpy.context.object;face.name='Sculpted continuous face'
parts=[p for p in bpy.context.scene.objects if p.type=='MESH' and p.users_collection[0]!=guides]
activate(face);face.data.remesh_voxel_size=.00165;face.data.use_remesh_preserve_volume=True
bpy.ops.object.voxel_remesh()
modifier=face.modifiers.new('Relax sculpt transitions','SMOOTH');modifier.factor=.7;modifier.iterations=8;bpy.ops.object.modifier_apply(modifier=modifier.name)

def cutter(name,outline,z0=.060,z1=.21):
    v=[(p.x,p.y,z) for z in [z0,z1] for p in outline];n=len(outline)
    f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,v,f,'ink')
def subtract(o,cut):
    activate(o);m=o.modifiers.new('Sculpt aperture','BOOLEAN');m.operation='DIFFERENCE';m.solver='EXACT';m.object=cut;bpy.ops.object.modifier_apply(modifier=m.name)
    if cut in parts:parts.remove(cut)
    bpy.data.objects.remove(cut,do_unlink=True)
for side in [-1,1]:subtract(face,cutter('Eye socket cutting tool',eye_outline(side)))

# A relaxed closed mouth keeps the skin continuous. The thin lip seam and soft
# lower-lip tint are projected onto this actual surface in skin.gdshader.
for side in [-1,1]:
    sphere('Nostril',(side*.009,1.158,.139),(.0022,.0011,.0008),'mouth')

# Reduce first, then project UVs onto final vertices so lip/eye marks stay aligned.
for p in face.data.polygons:p.use_smooth=True
decimate=face.modifiers.new('Game sculpt reduction','DECIMATE');decimate.ratio=.10;activate(face);bpy.ops.object.modifier_apply(modifier=decimate.name)
while face.data.uv_layers:face.data.uv_layers.remove(face.data.uv_layers[0])
uv=face.data.uv_layers.new(name='UVMap')
for loop in face.data.loops:
    p=G(face.data.vertices[loop.vertex_index].co);uv.data[loop.index].uv=(p.x,p.y)

# The eye whites use the spherical front surface inside the sculpted aperture.
for side,label in [(1,'L'),(-1,'R')]:
    v=[];f=[];uv=[]
    for j in range(17):
        blend=j/16
        for i in range(49):
            t=i/48;low,up=bounds(t);q=low.lerp(up,blend);v.append((side*q.x*FACE_X,q.y,eye_z(q.x,q.y)-.0004));uv.append(((side*(q.x-.076))/.106+.5,(q.y-1.201)/.106+.5))
    for j in range(16):
        for i in range(48):a=j*49+i;b=a+1;d=a+49;f.append((a,b,d+1,d) if side==1 else (a,d,d+1,b))
    o=mesh('Spherical eye '+label,v,f,'eye',uv);o['bone']='eye'+label
    # Broad, asymmetric brows are a tapered sculpted wedge with support loops.
    bv=[];bf=[]
    for i in range(25):
        t=i/24;x=.027+.097*t;y=1.235+.030*t;thick=.0065*(1-.67*t)
        for yy,dz in [(y-thick,.003),(y+thick,.003),(y+thick,.006),(y-thick,.006)]:bv.append((side*x*FACE_X,yy,front(x*FACE_X,yy)+dz))
    for i in range(24):
        for k in range(4):a=i*4+k;b=i*4+(k+1)%4;bf.append((a,b,b+4,a+4))
    bf.extend([tuple(range(4)),tuple(reversed(range(96,100)))])
    subdiv(mesh('Brow '+label,bv,bf,'ink'),1,True)

# Parallel-transport frames, hand-authored cross-sections and subdivision cages.
HAIR=[
[(.054,1.313,.055),(.060,1.358,.098),(.003,1.355,.141),(-.061,1.291,.155),(-.113,1.216,.143),(-.134,1.158,.112)],
[(.061,1.313,.047),(.109,1.349,.097),(.128,1.315,.134),(.112,1.262,.146),(.087,1.215,.128)],
[(-.074,1.301,.008),(-.120,1.334,.040),(-.153,1.278,.040),(-.163,1.209,.028),(-.152,1.146,.067)],
[(.003,1.319,-.020),(-.011,1.391,-.012),(-.049,1.403,-.039),(-.076,1.380,-.061),(-.094,1.390,-.063)],
[(.082,1.300,-.035),(.127,1.346,-.060),(.153,1.276,-.077),(.166,1.205,-.030),(.158,1.143,.010)],
[(-.069,1.293,-.047),(-.112,1.337,-.092),(-.155,1.280,-.103),(-.174,1.212,-.085),(-.168,1.147,-.042)],
[(.015,1.309,-.071),(.035,1.352,-.147),(.054,1.289,-.166),(.059,1.221,-.171),(.091,1.164,-.129)],
[(-.026,1.302,-.065),(-.048,1.348,-.136),(-.073,1.278,-.171),(-.085,1.211,-.166),(-.113,1.157,-.119)],
[(.038,1.320,.088),(.023,1.367,.118),(-.031,1.328,.172),(-.059,1.280,.173),(-.084,1.237,.160)],
[(.086,1.300,.024),(.140,1.334,.081),(.151,1.293,.106),(.139,1.244,.098),(.128,1.218,.066)],
[(-.105,1.293,-.021),(-.148,1.310,-.026),(-.177,1.258,-.016),(-.178,1.215,-.019),(-.185,1.186,-.043)],
[(.046,1.325,-.007),(.075,1.390,-.016),(.104,1.395,-.045),(.125,1.367,-.066),(.143,1.376,-.068)],
[(.061,1.302,-.060),(.112,1.316,-.123),(.134,1.269,-.161),(.137,1.215,-.158),(.154,1.178,-.118)],
[(-.004,1.308,-.079),(-.049,1.345,-.131),(-.079,1.275,-.181),(-.080,1.218,-.171),(-.119,1.181,-.113)]
]
HAIR_WIDTH=[.034,.023,.026,.024,.027,.026,.028,.024,.020,.020,.019,.018,.022,.020]
def hair_frame(points,t,previous=None):
    c=interpolate(points,t);tan=(interpolate(points,min(1,t+.001))-interpolate(points,max(0,t-.001))).normalized()
    up=Vector((0,0,1)) if previous is None else previous
    up=(up-tan*up.dot(tan)).normalized()
    if up.length<.1:up=Vector((0,1,0))
    width=tan.cross(up).normalized();return c,tan,width,up
def radius(t,s):
    width=HAIR_WIDTH[s]
    root=.58+.42*smooth(0,.22,t);tip=(1-.985*smooth(.43,1.,t))
    return width*root*tip

# A close-fitting, non-visible-in-front scalp fills gaps beneath the strand roots.
cap_v=[];cap_f=[]
for j in range(17):
    for i in range(65):
        a=-math.pi+TAU*i/64;ymin=1.300-.078*smooth(.93,1.65,abs(a))-.107*smooth(1.64,2.8,abs(a));y=ymin+(1.335-ymin)*j/16
        lo=max(0,min(len(PROFILE)-2,next((k-1 for k,p in enumerate(PROFILE) if p[0]>=y),len(PROFILE)-2)))
        pa,pb=PROFILE[lo],PROFILE[lo+1];t=(y-pa[0])/(pb[0]-pa[0]);w=pa[1]*(1-t)+pb[1]*t;zf=pa[2]*(1-t)+pb[2]*t;zb=pa[3]*(1-t)+pb[3]*t;c=math.cos(a)
        cap_v.append((w*math.sin(a)*1.012,y+.0025,(zf*max(c,0.)**.66 if c>=0 else zb*c)*1.014))
for j in range(16):
    for i in range(64):a=j*65+i;d=a+65;cap_f.append((a,a+1,d+1,d))
subdiv(mesh('Hair scalp',cap_v,cap_f,'hair'),1,True)
for strand,points in enumerate(HAIR):
    v=[];f=[];uv=[];previous=None;frames=[]
    for j in range(17):
        t=j/16;c,tan,w,up=hair_frame(points,t,previous);previous=up;frames.append((c,tan,w,up));r=radius(t,strand)
        for i in range(16):
            a=TAU*i/16;depth=.60+.07*math.cos(a)
            v.append(c+w*(r*math.cos(a))+up*(r*depth*math.sin(a)));uv.append((t,i/16))
    for j in range(16):
        for i in range(16):a=j*16+i;b=j*16+(i+1)%16;f.append((a,a+16,b+16,b))
    f.extend([tuple(reversed(range(16))),tuple(16*16+i for i in range(16))])
    o=subdiv(mesh('Tentacle sculpt '+str(strand),v,f,'hair',uv),1,True);o['strand']=strand
    if strand not in [0,2,4,5,6,7,9,12]:continue
    for k,t in enumerate([.51,.68,.82]):
        row=t*16;i=min(15,int(row));blend=row-i;previous=frames[i][3].lerp(frames[i+1][3],blend).normalized()
        c,tan,w,up=hair_frame(points,t,previous);at=c+up*(radius(t,strand)*.578);cr=HAIR_WIDTH[strand]*.265*(1-.24*k)
        vv=[];ff=[]
        for rr,d in [(1.,-.002),(1.08,.002),(.87,.005),(.58,.004),(.49,-.0008),(.01,-.0018)]:
            for i in range(24):a=TAU*i/24;vv.append(at+w*math.cos(a)*cr*rr+tan*math.sin(a)*cr*rr+up*d)
        for j in range(5):
            for i in range(24):a=j*24+i;b=j*24+(i+1)%24;ff.append((a,b,b+24,a+24))
        cup=mesh('Inset suction '+str(strand)+' '+str(k),vv,ff,'cup');cup['strand']=strand;cup['t']=t

# Correct bone weights for the sculpt and authored strands. Body keeps its rig.
bone_defs={'head':(None,(0,1.04304,-.00088),(0,1.19,-.00088))}
for side,label in [(1,'L'),(-1,'R')]:bone_defs['eye'+label]=('head',(side*.076*FACE_X,1.201,.13),(side*.076*FACE_X,1.23,.13))
for s,ps in enumerate(HAIR):
    bone_defs[f'hair{s}a']=('head',interpolate(ps,.12),interpolate(ps,.52));bone_defs[f'hair{s}b']=(f'hair{s}a',interpolate(ps,.52),interpolate(ps,.95))
arm_data=bpy.data.armatures.new('SculptRig');arm=bpy.data.objects.new('SculptRig',arm_data);bpy.context.collection.objects.link(arm);activate(arm);bpy.ops.object.mode_set(mode='EDIT')
for name,(parent,h,t) in bone_defs.items():
    b=arm_data.edit_bones.new(name);b.head=P(h);b.tail=P(t);b.align_roll(Vector((0,-1,0)))
    if parent:b.parent=arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
    if o not in bpy.context.scene.objects.values():continue
    if 'strand' in o:
        s=int(o['strand']);ps=HAIR[s]
        for vert in o.data.vertices:
            p=G(vert.co);t=float(o.get('t',min(range(65),key=lambda i:(interpolate(ps,i/64)-p).length_squared)/64))
            w=smooth(.32,.86,t)
            for name,value in [(f'hair{s}a',1-w),(f'hair{s}b',w)]:
                group=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);group.add([vert.index],value,'REPLACE')
    else:
        group=o.vertex_groups.new(name=o.get('bone','head'));group.add(list(range(len(o.data.vertices))),1.,'REPLACE')
    modifier=o.modifiers.new('Sculpt skinning','ARMATURE');modifier.object=arm;o.parent=arm

# Merging preserves sculpt-space UV, semantic materials, morph/rig ownership.
merged=[]
groups=[(m,[o for o in parts if o.data.materials[0]==m]) for m in MAT.values()]
for m,objects in groups:
    if not objects:continue
    activate(objects[0])
    for o in objects:o.select_set(True)
    if len(objects)>1:bpy.ops.object.join()
    o=bpy.context.object;o.name=m.name;merged.append(o)
arm.animation_data_create();action=bpy.data.actions.new('idle');arm.animation_data.action=action
for frame in range(1,91):
    phase=TAU*(frame-1)/89
    for b in arm.pose.bones:b.rotation_mode='QUATERNION';b.rotation_quaternion=Quaternion();b.scale=(1,1,1)
    for s in range(len(HAIR)):
        for suffix,strength in [('a',.012),('b',.024)]:
            b=arm.pose.bones[f'hair{s}{suffix}'];axis=b.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0));b.rotation_quaternion=Quaternion(axis,strength*math.sin(phase+s*.6))
    for b in arm.pose.bones:b.keyframe_insert('rotation_quaternion',frame=frame);b.keyframe_insert('scale',frame=frame)
action.use_fake_user=True;bpy.context.scene.frame_set(1);bpy.context.scene.render.fps=30;bpy.context.scene.frame_end=90

activate(arm)
for o in merged:o.select_set(True)
(OUT/'source').mkdir(exist_ok=True);(OUT/'source'/'.gdignore').write_text('')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/'sculpt-head.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'sculpt-head.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS')
manifest={'method':'Compact narrow continuous facial planes; fused nose/neck/ears/orbital rims; cut eye apertures; relaxed closed mouth material; fourteen tapered parallel-transport tentacles','head_bones':len(bone_defs),'meshes':len(merged),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in merged),'hair_strands':len(HAIR),'face_max_half_width':max(p[1] for p in PROFILE)*HEAD_XZ,'head_width_scale':HEAD_XZ,'head_height_scale':HEAD_HEIGHT,'head_height_pivot':HEAD_PIVOT_Y,'neck_base_y':.976,'chin_y':1.018,'body':'Original body/rig/actions retained; old neck replaced with a short tapered connection','blender':bpy.app.version_string,'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256((OUT/'sculpt-head.glb').read_bytes()).hexdigest()}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print('PASS: sculpt authoring/export',json.dumps(manifest,ensure_ascii=False))
