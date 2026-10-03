"""Author the approved, simplified Wave character in Blender, then export GLB.

All meshes are newly authored here. No production character mesh is imported.
Coordinates in this source are Godot's +Y up, +Z face; P converts to Blender.
Run: Blender --background --factory-startup --python build_model.py
"""
from pathlib import Path
import math
import json
import hashlib
import bpy
from mathutils import Vector, Quaternion, Matrix

OUT = Path(__file__).resolve().parent
TAU = math.tau
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
parts = []


def P(p):
    return Vector((p[0], -p[2], p[1]))


def G(p):
    return Vector((p[0], p[2], -p[1]))


def color(s):
    rgb = [int(s[i:i+2], 16)/255 for i in (0, 2, 4)]
    return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1.,)


def material(name, tint, rough=.7, metallic=0., coat=0.):
    m = bpy.data.materials.new(name)
    m.diffuse_color = color(tint)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color(tint)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Coat Weight'].default_value = coat
    return m


MAT = {
    'skin': material('WaveSkin', 'ffd9c2', .68),
    'ink': material('WaveInkMark', '17202e', .78),
    'mouth': material('WaveMouth', '793c3a', .8),
    'eye': material('WaveEyes', 'f5f4e9', .32, coat=.18),
    'hair': material('WaveTeamHair', 'ff741b', .30, coat=.22),
    'cup': material('WaveSuction', 'ffd5a7', .50),
    'ear': material('WaveInnerEar', 'd28771', .72),
    'jacket': material('WaveJacket', '243148', .88),
    'accent': material('WaveAccent', 'f89532', .75),
    'tee': material('WaveTee', 'eee9dc', .92),
    'shorts': material('WaveShorts', '303c53', .88),
    'sock': material('WaveSocks', '394658', .9),
    'shoe': material('WaveShoes', 'efeadb', .73),
    'sole': material('WaveSoles', 'c8cecb', .83),
    'tooth': material('WaveTeeth', 'f6ebd9', .58),
}


def mesh(name, vertices, faces, mat, weights='head', uv=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata([P(v) for v in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(MAT[mat])
    for poly in data.polygons:
        poly.use_smooth = True
    if uv is not None:
        layer = data.uv_layers.new(name='UVMap')
        for loop in data.loops:
            layer.data[loop.index].uv = uv[loop.vertex_index]
    if isinstance(weights, str):
        weights = [{weights: 1.} for _ in vertices]
    for i, values in enumerate(weights):
        total = sum(values.values())
        assert total > 0 and all(v >= 0 for v in values.values())
        for bone, w in values.items():
            group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            if w > 1e-6:
                group.add([i], w/total, 'REPLACE')
    parts.append(obj)
    return obj


def mix(a, b, w):
    return {a: 1-w, b: w}


def smooth(a, b, x):
    t = min(1., max(0., (x-a)/(b-a)))
    return t*t*(3-2*t)


def ellipsoid(name, center, radii, mat, bone='head', seg=40, rings=24):
    vertices, faces = [], []
    c = Vector(center)
    for j in range(rings+1):
        e = -math.pi/2 + math.pi*j/rings
        for i in range(seg+1):
            a = TAU*i/seg
            vertices.append(c+Vector((radii[0]*math.sin(a)*math.cos(e), radii[1]*math.sin(e), radii[2]*math.cos(a)*math.cos(e))))
    for j in range(rings):
        for i in range(seg):
            a = j*(seg+1)+i; b=a+1; d=a+seg+1; c=d+1
            faces.append((a,b,c,d))
    return mesh(name,vertices,faces,mat,bone)


def bezier(points, t):
    # Cubic Hermite interpolation through authored silhouette landmarks.
    points = [Vector(p) for p in points]
    x = t*(len(points)-1); i=min(len(points)-2,int(x)); u=x-i
    a,b = points[i],points[i+1]
    m0=(points[min(i+1,len(points)-1)]-points[max(i-1,0)])*.5
    m1=(points[min(i+2,len(points)-1)]-points[i])*.5
    return a*(2*u**3-3*u*u+1)+m0*(u**3-2*u*u+u)+b*(-2*u**3+3*u*u)+m1*(u**3-u*u)


def curve_frame(points, t, outward_center=None):
    c=bezier(points,t)
    tangent=(bezier(points,min(1.,t+.001))-bezier(points,max(0.,t-.001))).normalized()
    hint=(c-Vector(outward_center)).normalized() if outward_center else Vector((0,0,1))
    width=tangent.cross(hint).normalized()
    if width.length < .1:
        width=tangent.cross(Vector((1,0,0))).normalized()
    up=width.cross(tangent).normalized()
    return c,tangent,width,up


def sweep(name, points, radius, mat, weights, flat=1., steps=40, radial=20, outward=None):
    vertices, faces, uv, groups = [], [], [], []
    for j in range(steps+1):
        t=j/steps; c,tangent,width,up=curve_frame(points,t,outward)
        r=radius(t) if callable(radius) else radius
        for i in range(radial+1):
            a=TAU*i/radial
            vertices.append(c+width*(r*math.cos(a))+up*(r*flat*math.sin(a)))
            uv.append((i/radial,t))
            groups.append(weights(t) if callable(weights) else {weights:1.})
    for j in range(steps):
        for i in range(radial):
            a=j*(radial+1)+i; b=a+1; d=a+radial+1; c=d+1
            faces.append((a,d,c,b))
    faces.append(tuple(range(radial)))
    faces.append(tuple(steps*(radial+1)+i for i in reversed(range(radial))))
    return mesh(name,vertices,faces,mat,groups,uv)


HEAD_Y=1.518
HEAD_H=.198
HEAD_W=.229
HEAD_D=.187


def head_width(y):
    t=max(-.9999,min(.9999,(y-HEAD_Y)/HEAD_H))
    return HEAD_W*math.sqrt(1-t*t)*(1-.31*smooth(-.01,.19,HEAD_Y-y))


def front(x,y):
    t=max(-.9999,min(.9999,(y-HEAD_Y)/HEAD_H))
    c=math.sqrt(1-t*t)
    nx=min(.9999,abs(x)/max(.001,head_width(y)))
    z=HEAD_D*c*(1-nx*nx)**.44
    z+=.010*math.exp(-(x/.023)**2-((y-1.50)/.072)**2)
    z+=.032*math.exp(-(x/.023)**2-((y-1.449)/.026)**2)
    z+=.007*math.exp(-((abs(x)-.108)/.046)**2-((y-1.414)/.055)**2)
    return z


vertices, faces = [], []
seg,rings=112,64
for j in range(rings+1):
    e=-math.pi/2+math.pi*j/rings
    y=HEAD_Y+HEAD_H*math.sin(e)
    width=head_width(y)
    for i in range(seg+1):
        a=-math.pi+TAU*i/seg
        x=width*math.sin(a)
        z=front(x,y) if math.cos(a)>=0 else HEAD_D*math.cos(e)*math.cos(a)*1.04
        back_lift=.048*smooth(.06,.18,HEAD_Y-y)*max(0.,-math.cos(a))
        vertices.append((x,y+back_lift,z))
for j in range(rings):
    for i in range(seg):
        a=j*(seg+1)+i; d=a+seg+1
        faces.append((a,a+1,d+1,d))
mesh('SculptedHead',vertices,faces,'skin')

# Short neck seated inside the jacket collar, not a visible cylinder column.
sweep('Neck',[(0,1.176,0),(0,1.27,.006),(0,1.365,.006)],lambda t:.058-.008*t,'skin',lambda t:mix('chest','head',smooth(.2,.85,t)),steps=24)


def eye_point(side,u,v,scale=1.,bulge=.009):
    # Unequal upper/lower arcs make a sharp almond opening with a fleshy dome.
    x=side*(.096+.065*u*scale)
    shape=math.sqrt(max(0.,1-u*u))
    height=.019 if v>=0 else .037
    y=1.541 + .017*u + height*v*shape*scale
    r2=u*u+v*v*(1-u*u)
    return Vector((x,y,front(x,y)+.003+bulge*max(0.,1-r2)))


for side,label in [(1,'L'),(-1,'R')]:
    # Skin ink mark: a conforming angular patch, not a raised circular goggle.
    vertices,faces=[],[]
    for j in range(21):
        v=-1+2*j/20
        for i in range(49):
            u=-1+2*i/48
            p=eye_point(side,u,v,1.21,0.)
            if v < 0:
                p.y -= .008*(-v)*max(0.,u)
            p.z=front(p.x,p.y)+.0014
            vertices.append(p)
    for j in range(20):
        for i in range(48):
            a=j*49+i;d=a+49
            faces.append((a,a+1,d+1,d) if side==1 else (a,d,d+1,a+1))
    mesh('InkEyeMark'+label,vertices,faces,'ink')
    vertices,faces,uv=[],[],[]
    for j in range(25):
        v=-1+2*j/24
        for i in range(65):
            u=-1+2*i/64
            vertices.append(eye_point(side,u,v))
            uv.append(((u*side+1)*.5,(v+1)*.5))
    for j in range(24):
        for i in range(64):
            a=j*65+i;d=a+65
            faces.append((a,a+1,d+1,d) if side==1 else (a,d,d+1,a+1))
    mesh('EyeDome'+label,vertices,faces,'eye','eye'+label,uv)
    for upper in [True,False]:
        pts=[eye_point(side,-1+2*i/16,1 if upper else -1) for i in range(17)]
        sweep(('UpperLid' if upper else 'LowerLid')+label,pts,lambda t:(.0045 if upper else .0017)*(.28+.72*math.sin(math.pi*t)),'ink','eye'+label,steps=48,radial=12)
    # Assertive brows with real volume, broad near the nose and tapered outward.
    pts=[]
    for x,y in [(.027,1.573),(.085,1.604),(.168,1.642)]:
        x*=side;pts.append((x,y,front(x,y)+.011))
    sweep('Brow'+label,pts,lambda t:.0145*(1-.30*t),'ink','head',flat=.36,steps=30,radial=12)
    # A pointed shell with an inset concha, rather than two stacked spheres.
    outline=[(.206,1.549,.016),(.239,1.574,.005),(.302,1.575,-.010),(.292,1.524,.012),(.274,1.490,.026),(.235,1.477,.027),(.216,1.491,.027)]
    center=Vector((.248,1.522,.012))
    verts=[]
    for r,depth in [(.02,.006),(.40,.004),(.76,.025),(1.,.008)]:
        for p in outline:
            q=center+(Vector(p)-center)*r;q.x*=side;q.z+=depth;verts.append(q)
    faces=[]
    for row in range(3):
        for i in range(7):
            a=row*7+i;b=row*7+(i+1)%7;c=b+7;d=a+7
            faces.append((a,b,c,d) if side==1 else (a,d,c,b))
    faces.append(tuple(reversed(range(7))) if side==1 else tuple(range(7)))
    mesh('EarShell'+label,verts,faces,'skin')
    concha=[Vector(v)+Vector((0,0,.0008)) for v in verts[:14]]
    mesh('EarInset'+label,concha,[tuple(reversed(range(7,14))) if side==1 else tuple(range(7,14))],'ear')
    # The small ink tail is flush against the outer cheek.
    coords=[(side*.167,1.552),(side*.192,1.552),(side*.176,1.488)]
    mesh('InkTail'+label,[(x,y,front(x,y)+.0015) for x,y in coords],[(0,2,1) if side==1 else (0,1,2)],'ink')

# Asymmetric sculpted smile; a small off-white tooth wedge is tucked behind it.
smile=[]
for i in range(9):
    t=i/8;x=-.064+.137*t;y=1.406+.019*t-.013*math.sin(math.pi*t)
    smile.append((x,y,front(x,y)+.0025))
sweep('Smile',smile,lambda t:.0038*(.35+.65*math.sin(math.pi*t)),'mouth','head',steps=36,radial=10)
verts=[(.010,1.401,front(.010,1.401)+.004),(.067,1.421,front(.067,1.421)+.004),(.052,1.407,front(.052,1.407)+.004)]
mesh('SmileTooth',verts,[(0,2,1)],'tooth')

# Volumetric tentacle hair: round fleshy sections, no stretched ribbon sheets.
HAIR=[
 [( .105,1.678,.036),(.04,1.750,.137),(-.065,1.675,.219),(-.167,1.576,.240),(-.207,1.453,.235)],
 [(.155,1.670,-.042),(.244,1.665,-.078),(.293,1.596,-.058),(.292,1.508,.009),(.262,1.452,.074)],
 [(-.095,1.683,-.049),(-.207,1.649,-.085),(-.272,1.582,-.055),(-.295,1.498,.020),(-.259,1.456,.083)],
 [(.025,1.686,-.048),(.049,1.734,-.112),(.115,1.692,-.186),(.177,1.607,-.223),(.191,1.542,-.195)],
 [(.060,1.652,-.072),(.095,1.590,-.160),(.142,1.504,-.201),(.162,1.420,-.166),(.179,1.391,-.094)],
 [(-.048,1.669,-.062),(-.104,1.607,-.145),(-.156,1.523,-.196),(-.181,1.437,-.152),(-.186,1.402,-.079)],
 [(-.015,1.678,-.060),(-.008,1.596,-.172),(.012,1.524,-.214),(.031,1.441,-.199),(.065,1.402,-.147)],
]
# Continuous scalp beneath the separate tentacles. Front hairline stays high,
# sides and nape are covered so the rear never becomes a bald spherical cap.
cap_v,cap_f=[],[]
for j in range(25):
    for i in range(97):
        a=-math.pi+TAU*i/96
        ymin=1.642-.076*smooth(.15,1.7,abs(a))-.106*smooth(1.65,2.8,abs(a))
        emin=math.asin((ymin-HEAD_Y)/HEAD_H)
        e=emin+(math.pi/2-emin)*j/24
        y=HEAD_Y+HEAD_H*math.sin(e)
        x=head_width(y)*math.sin(a)*1.035
        z=(front(x/1.035,y) if math.cos(a)>=0 else HEAD_D*math.cos(e)*math.cos(a)*1.04)*1.038
        cap_v.append((x,y+.004,z))
for j in range(24):
    for i in range(96):
        a=j*97+i;d=a+97;cap_f.append((a,a+1,d+1,d))
mesh('HairRootVolume',cap_v,cap_f,'hair')
for strand,points in enumerate(HAIR):
    def weight(t,s=strand):
        if t<.30:return mix('head',f'hair{s}a',smooth(.04,.30,t))
        return mix(f'hair{s}a',f'hair{s}b',smooth(.38,.92,t))
    def radius(t,s=strand):
        base=.084 if s==0 else (.067 if s==3 else .061)
        return base*(.88+.12*math.sin(math.pi*t))*(1-.985*smooth(.56,1.,t))
    sweep(f'Tentacle{strand}',points,radius,'hair',weight,flat=.69,steps=64,radial=28,outward=(0,HEAD_Y,0))
    if strand not in [0,1,2]:continue
    for k,t in enumerate([.58,.74,.88]):
        c,tangent,width,up=curve_frame(points,t,(0,HEAD_Y,0))
        radius_at=radius(t)*.69
        # Expose a few simple suction cups on the outward-facing side.
        at=c+up*radius_at
        cup_radius=.024*(1-.38*k)
        verts,faces=[],[]
        profiles=[(1.0,0.),(1.05,.005),(.81,.008),(.57,.006),(.48,.001)]
        for rr,depth in profiles:
            for i in range(25):
                a=TAU*i/24
                verts.append(at+width*(cup_radius*rr*math.cos(a))+tangent*(cup_radius*rr*math.sin(a))+up*depth)
        for row in range(len(profiles)-1):
            for i in range(24):
                a=row*25+i;d=a+25;faces.append((a,a+1,d+1,d))
        mesh(f'Suction{strand}_{k}',verts,faces,'cup',[weight(t) for _ in verts])


head_parts=[o for o in parts if o.name != 'Neck']

def torso(name,ys,rxs,rzs,mat,gap=False):
    verts,faces,groups=[],[],[]
    seg=64
    for row,y in enumerate(ys):
        for i in range(seg+1):
            a=-math.pi+TAU*i/seg
            verts.append((rxs[row]*math.sin(a),y,rzs[row]*math.cos(a)))
            if y<.98:groups.append(mix('hips','spine',smooth(.84,.98,y)))
            else:groups.append(mix('spine','chest',smooth(.98,1.14,y)))
    for row in range(len(ys)-1):
        for i in range(seg):
            angle=-math.pi+TAU*(i+.5)/seg
            if gap and abs(angle)<(.32+.12*smooth(.86,1.18,ys[row])):continue
            a=row*(seg+1)+i;d=a+seg+1;faces.append((a,a+1,d+1,d))
    return mesh(name,verts,faces,mat,groups)


torso('SimpleTee',[.87,.89,.94,1.04,1.12,1.19,1.248],[.16,.163,.166,.186,.199,.158,.060],[.102,.104,.109,.117,.114,.091,.057],'tee')
torso('OpenJacket',[.861,.870,.91,1.00,1.10,1.165,1.203,1.246],[.177,.181,.185,.204,.220,.225,.162,.074],[.113,.116,.122,.128,.123,.112,.092,.064],'jacket',True)
for side,label in [(1,'L'),(-1,'R')]:
    collar=[(side*.052,1.163,.103),(side*.092,1.250,.060),(side*.162,1.218,.022),(side*.150,1.148,.083)]
    mesh('JacketCollar'+label,collar,[(0,1,2,3) if side==1 else (0,3,2,1)],'jacket','chest')
    inset=[Vector(p)+Vector((0,0,.0015)) for p in collar]
    mesh('OrangeCollarLining'+label,inset,[(0,1,2,3) if side==1 else (0,3,2,1)],'accent','chest')
    shoulder=(side*.211,1.161,-.003);elbow=(side*.258,.964,.014);wrist=(side*.283,.790,.032)
    sleeve=[(side*.181,1.158,-.003),(side*.236,1.089,-.001),(side*.253,1.005,.012)]
    sweep('JacketSleeve'+label,sleeve,lambda t:.075-.012*t,'jacket',lambda t:mix('chest','uArm'+label,smooth(0.,.30,t)),steps=28,radial=24)
    sweep('PlainSleeveHem'+label,[(side*.250,1.020,.011),(side*.254,.999,.013)],.064,'jacket','uArm'+label,steps=4,radial=24)
    arm=[shoulder,elbow,(side*.272,.877,.026),wrist]
    sweep('Arm'+label,arm,lambda t:.046*(1-.24*smooth(.3,1.,t)),'skin',lambda t:mix('uArm'+label,'fArm'+label,smooth(.32,.59,t)),steps=38,radial=24)
    ellipsoid('Palm'+label,(side*.287,.757,.033),(.036,.048,.025),'skin','hand'+label,seg=28,rings=18)
    for k in range(4):
        x=side*(.263+k*.014)
        finger=[(x,.747,.043),(x,.711-.004*math.sin(k),.047),(x,.699-.004*math.sin(k),.036)]
        sweep('Finger'+label+str(k),finger,.0085,'skin','hand'+label,steps=16,radial=12)
    sweep('Thumb'+label,[(side*.262,.772,.034),(side*.246,.750,.060),(side*.254,.729,.065)],.012,'skin','hand'+label,steps=16,radial=12)

# A plain short silhouette, with the waist above the shared crotch region.
torso('ShortsWaist',[.716,.74,.79,.835,.874],[.164,.174,.171,.165,.161],[.093,.101,.104,.100,.098],'shorts')
for side,label in [(1,'L'),(-1,'R')]:
    hip=(side*.112,.791,.001);knee=(side*.117,.410,.015);ankle=(side*.119,.105,-.006)
    sweep('ShortsLeg'+label,[(side*.096,.752,0),(side*.110,.66,.002),(side*.115,.568,.008)],lambda t:.098-.011*t,'shorts',lambda t:mix('hips','thigh'+label,smooth(.0,.67,t)),flat=1.02,steps=22,radial=32)
    sweep('Leg'+label,[hip,(side*.115,.586,.009),knee,(side*.119,.270,.005),ankle],lambda t:.049+.006*math.sin(math.pi*t)-.014*smooth(.55,1.,t),'skin',lambda t:mix('thigh'+label,'shin'+label,smooth(.40,.62,t)),steps=44,radial=24)
    sweep('Sock'+label,[(side*.119,.097,-.005),(side*.119,.211,.003)],lambda t:.041+.002*t,'sock','shin'+label,steps=12,radial=24)
    ellipsoid('SimpleSneaker'+label,(side*.119,.084,.053),(.075,.061,.144),'shoe','foot'+label,seg=44,rings=26)
    # Flatten the outsole bottom; three broad shapes, no laces or hardware.
    bpy.ops.mesh.primitive_cube_add(size=1, location=P((side*.119,.030,.057)))
    sole=bpy.context.object;sole.name='SimpleOutsole'+label
    sole.scale=(.154,.286,.043)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel=sole.modifiers.new('Rounded sole','BEVEL');bevel.width=.018;bevel.segments=4
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    sole.data.materials.append(MAT['sole'])
    for poly in sole.data.polygons:poly.use_smooth=True
    group=sole.vertex_groups.new(name='foot'+label);group.add(list(range(len(sole.data.vertices))),1.,'REPLACE')
    parts.append(sole)
    ellipsoid('HeelColor'+label,(side*.119,.091,-.067),(.054,.029,.019),'accent','foot'+label,seg=24,rings=14)

# User approved reusing the existing body. Export only the newly authored head.
for obj in parts:
    if obj not in head_parts:
        bpy.data.objects.remove(obj,do_unlink=True)
parts=head_parts

# The independent head rig follows the game's head bone via BoneAttachment3D.
bone_defs={
 'head':(None,(0,1.264,0),(0,1.576,0)),
}
for side,label in [(1,'L'),(-1,'R')]:
    bone_defs.update({
      'eye'+label:('head',(side*.096,1.541,front(side*.096,1.541)+.008),(side*.096,1.569,front(side*.096,1.541)+.008)),
    })
for strand,points in enumerate(HAIR):
    bone_defs[f'hair{strand}a']=('head',bezier(points,.12),bezier(points,.55))
    bone_defs[f'hair{strand}b']=(f'hair{strand}a',bezier(points,.55),bezier(points,.95))
arm_data=bpy.data.armatures.new('WaveSkeleton')
arm=bpy.data.objects.new('WaveRig',arm_data);bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm;arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name,(parent,head,tail) in bone_defs.items():
    b=arm_data.edit_bones.new(name);b.head=P(head);b.tail=P(tail)
    b.align_roll(Vector((0,-1,0)))
    if parent:b.parent=arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')

# Merge each semantic material, preserving vertex groups, to limit draw calls.
merged=[]
material_groups=[(mat,[o for o in parts if o.data.materials[0]==mat]) for mat in MAT.values()]
for mat,selected in material_groups:
    if not selected:continue
    bpy.ops.object.select_all(action='DESELECT')
    for obj in selected:obj.select_set(True)
    bpy.context.view_layer.objects.active=selected[0]
    if len(selected)>1:bpy.ops.object.join()
    obj=bpy.context.object;obj.name=mat.name
    for group in obj.vertex_groups:assert group.name in bone_defs,group.name
    modifier=obj.modifiers.new('Wave skinning','ARMATURE');modifier.object=arm
    obj.parent=arm;merged.append(obj)

arm.animation_data_create()


def rotate_world(name,angle,axis=(1,0,0)):
    b=arm.pose.bones[name]
    local=b.bone.matrix_local.to_3x3().inverted()@Vector(axis)
    b.rotation_mode='QUATERNION'
    b.rotation_quaternion=Quaternion(local,angle)


for clip,end in [('idle',91)]:
    action=bpy.data.actions.new(clip)
    arm.animation_data.action=action
    for frame in range(1,end+1):
        phase=TAU*(frame-1)/(end-1)
        for b in arm.pose.bones:
            b.rotation_mode='QUATERNION';b.rotation_quaternion=Quaternion();b.location=(0,0,0);b.scale=(1,1,1)
        if clip=='idle':
            blink=max(0.,1-abs(frame-66)/2.) if frame in range(64,69) else 0.
            for label in ['L','R']:arm.pose.bones['eye'+label].scale.y=1-.93*blink
        for strand in range(len(HAIR)):
            rotate_world(f'hair{strand}a',.015*math.sin(phase+strand*.7))
            rotate_world(f'hair{strand}b',.022*math.sin(phase+strand*.7-.45))
        for b in arm.pose.bones:
            b.keyframe_insert('rotation_quaternion',frame=frame)
            b.keyframe_insert('location',frame=frame)
            b.keyframe_insert('scale',frame=frame)
    action.use_fake_user=True
arm.animation_data.action=bpy.data.actions['idle']
bpy.context.scene.frame_set(1)
bpy.context.scene.render.fps=30
bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=91

# The .blend remains the editable source; only model/rig/actions go into GLB.
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
for obj in merged:obj.select_set(True)
bpy.context.view_layer.objects.active=arm
(OUT/'source').mkdir(exist_ok=True)
(OUT/'source'/'.gdignore').write_text('')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/'head.blend'))
props=bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
options={'filepath':str(OUT/'wave.glb'),'export_format':'GLB','use_selection':True,'export_animations':True,'export_yup':True,'export_materials':'EXPORT'}
if 'export_animation_mode' in props:options['export_animation_mode']='ACTIONS'
if 'export_force_sampling' in props:options['export_force_sampling']=True
if 'export_frame_range' in props:options['export_frame_range']=False
bpy.ops.export_scene.gltf(**options)
stats={'authoring':'New head meshes authored in Blender from the approved reference; original body reused by the Godot adapter','body':'Unchanged original kid_0 body mesh, rig and game actions','blender':bpy.app.version_string,'head_bones':len(bone_defs),'semantic_meshes':len(merged),'base_polygons':sum(len(o.data.polygons) for o in merged),'head_actions':['idle (hair sway and blink)'],'reference_sha256':hashlib.sha256((OUT/'design-reference-v1.png').read_bytes()).hexdigest(),'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256((OUT/'wave.glb').read_bytes()).hexdigest()}
(OUT/'model-manifest.json').write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n')
print('PASS: authored Wave .blend and skinned animated GLB',json.dumps(stats,ensure_ascii=False))
