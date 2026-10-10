#!/usr/bin/env python3
"""Derive four bind-space silhouettes from local licensed rigs, preserving skinning.

No external checkout or DCC runtime is required. Original kid_*.glb are read-only.
Positions, inverse-transpose normals and tailored garment weights change. Original
faces/semantic UVs remain; long tops add 594 triangles of weighted inner sleeves.
Joint palette, source license metadata, weapons and squid are retained.
"""
import argparse, copy, hashlib, json, math, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILES = (
    ('reef_runner', 0, .98, .95, .96, .60, 1.03, .99),
    ('fin_drifter', 2, .93, .89, 1.00, 1.03, .98, 1.00),
    ('dock_worker', 3, 1.40, 1.08, .90, .54, 1.20, 1.08),
    ('spark_writer', 1, 1.30, .95, .98, .72, 1.12, 1.06),
)
CUTS = {
    'reef_runner': (1.00, .52, .52, 1.00, .88, 1.00),
    'fin_drifter': (1.10, 3.05, 3.05, 3.00, .92, 1.00),
    'dock_worker': (1.18, 3.05, 3.05, 3.02, 1.16, 1.18),
    'spark_writer': (1.00, 1.30, 1.30, 1.42, 1.16, 1.05),
}


def smooth(a, b, x):
    t = max(0., min(1., (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def transform(p, semantic, profile, part=0, uv=None):
    _, _, torso, face_x, face_y, hair_length, shoe_x, shoe_z = profile
    x, y, z = p
    if semantic in ('Skin', 'Eyes', 'TeamHair') and y > 1.0:
        t = smooth(1.0, 1.065, y)
        x *= 1 + (face_x - 1) * t
        z *= 1 - .075 * t
        y = 1.17 + (y - 1.17) * (1 + (face_y - 1) * t) - .025*t
        if semantic == 'Skin':
            x *= 1 - .10*(1-smooth(1.09,1.18,p[1]))*t
    if semantic == 'Eyes':
        center = (.056 if x > 0 else -.056) * face_x
        x = center + (x-center)*.91
        y = 1.165 + (y-1.165) * (.78 if profile[0]=='dock_worker' else .90)
    if semantic == 'Cloth':
        shirt, left, right, pants, leg_width, boot = CUTS[profile[0]]
        if part == 1:
            y -= (shirt-1)*max(0.,.93-y)
            # Leave room for the existing pelvis mesh under a longer shirt.
            z *= 1+.25*(1-smooth(.72,.87,y))
        if part in (4,5,15):
            y -= (pants-1)*max(0.,.645-y)
            center = .078 if x > 0 else -.078
            taper = 1 - .20*(1-smooth(.11,.40,y)) if pants>2 else 1.0
            fit=1+(leg_width*taper-1)*(1-smooth(.58,.63,p[1]))
            x = center + (x-center)*fit
            z = -.005 + (z+.005)*fit
        if part == 2:
            # The curved shoulder join has s=0. Stretch the tube's centreline,
            # not each vertex's y: stretching radial offsets tears the join.
            s=uv[1] if uv is not None else max(0.,.981-y)
            extended=max(0.,s-.009)*((left if x>0 else right)-1)
            new_s=s+extended
            y-=extended*.992
            side=1 if x>0 else -1
            old_center=.14499+s*.1125
            cy=.981-new_s*.992
            new_center=.14499+new_s*.1125 if cy>=.771 else .16899+(.771-cy)*(.014/.194)
            if max(left,right)>2.5:
                new_center+=.009*smooth(.009,.030,s)*(1-smooth(.82,.90,cy))
            fullness=1.15 if profile[0]=='dock_worker' else 1.06 if profile[0]=='fin_drifter' else 1.12 if profile[0]=='spark_writer' else 1.0
            # Sparse source sleeve rings need loose elbow ease when extended.
            fullness+=.30*smooth(.675,.73,cy)*(1-smooth(.77,.825,cy))
            fullness=1+(fullness-1)*smooth(.009,.025,s)
            if s>.009:
                old_z=-.0124-s*.038
                new_z=-.0124-new_s*.038 if cy>=.771 else -.0204+(.771-cy)*(.016/.194)
                x=side*new_center+(x-side*old_center)*fullness
                z=new_z+(z-old_z)*fullness
        if part == 3 and profile[0]=='fin_drifter':
            y=.973+(y-.973)*1.90
        if part == 3 and profile[0]=='dock_worker':
            # Lay the front collar down; its neck attachment stays fixed.
            t=smooth(.978,1.001,p[1])*smooth(-.002,.032,p[2])
            y-=.025*t;z+=.018*t;x*=1+.22*t
        if part in [7,11,17,19,20] or (part==16 and y<.22):
            y=.04+(y-.04)*boot
    if semantic == 'TeamHair':
        # Only strand-weighted hair is cut; the scalp cap must still meet the skin.
        if part==1 and p[1] < 1.14: y = 1.115 + (p[1]-1.14)*hair_length
        return [x, y, z]
    if semantic=='Skin' and profile[0]=='fin_drifter' and .14<y<.66 and abs(x)<.14:
        w=smooth(.14,.18,y)*(1-smooth(.60,.66,y))*smooth(.02,.055,abs(x))
        center=.078 if x>0 else -.078
        x=center+(x-center)*(1-.20*w); z=-.005+(z+.005)*(1-.20*w)
    if semantic == 'Cloth':
        # Chest and hips change proportion without shifting hand/weapon anchors.
        # One continuous chest/hip fit across panel joins. Shoulder attachments
        # stay fixed; lower sleeve fullness is independent of the torso width.
        w = smooth(.60,.72,p[1])*(1-smooth(.89,.98,p[1]))*(1-smooth(.12,.15,abs(p[0]))) if part in [1,2,4,5,15] else 0.0
        if part==2 and uv is not None:w*=1-smooth(0.,.009,uv[1])
        x *= 1 + (torso - 1) * w
        z *= 1 + (torso - 1) * w * .5
        if semantic == 'Cloth' and y < .19:
            foot = .084 if x > 0 else -.084
            x = foot + (x - foot) * shoe_x
            z = .03 + (z - .03) * shoe_z
            # Grounded sole, with a thicker work/skate profile and continuous
            # transition through laces/socks. No detached cube shoe covers.
            sole_height=1.24 if profile[0]=='dock_worker' else 1.12 if profile[0]=='spark_writer' else 1.0
            y*=1+(sole_height-1)*(1-smooth(.09,.19,p[1]))
    return [x, y, z]


def garment_weights(profile, part, p, q, palette, uv=None):
    """Extended cloth follows the existing elbow/knee, rather than a rigid thigh."""
    y=q[1]; side='L' if p[0]>0 else 'R'
    if part in [2,5] and uv is not None and uv[1]<.009:return None
    if part==2:
        # Match the source skin's elbow blend (upper arm down to ~.775,
        # forearm fully weighted below ~.705), so flexed skin stays inside.
        names=['uArm'+side,'fArm'+side]; t=1-smooth(.705,.775,y)
    elif part in [5,15]:
        names=['thigh'+side,'shin'+side]; t=1-smooth(.29,.40,y)
    elif part in [7,11,17,19,20] or (part==16 and p[1]<.22):
        names=['foot'+side,'shin'+side]; t=smooth(.11,.22,y)*.80
    else: return None
    return [palette[names[0]],palette[names[1]],0,0], [1-t,t,0.,0.]


def normal(p, n, semantic, profile, part=0, uv=None):
    eps = .00001
    cols = []
    for k in range(3):
        a = list(p); b = list(p); a[k] += eps; b[k] -= eps
        ta = transform(a, semantic, profile, part, uv); tb = transform(b, semantic, profile, part, uv)
        cols.append([(ta[i] - tb[i]) / (2 * eps) for i in range(3)])
    # J^-T n from column cofactors.
    cross = lambda a,b: [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
    c = [cross(cols[1],cols[2]),cross(cols[2],cols[0]),cross(cols[0],cols[1])]
    v = [sum(c[k][i]*n[k] for k in range(3)) for i in range(3)]
    length = math.sqrt(sum(a*a for a in v))
    if length < 1e-12: return list(n)  # Source degenerate triangles carry zero normals.
    return [a / length for a in v]


def accessor_rows(doc, binary, index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    fmt='<'+str(size)+{5126:'f',5123:'H',5125:'I',5121:'B'}[a['componentType']]
    width=struct.calcsize(fmt);start=view.get('byteOffset',0)+a.get('byteOffset',0)
    rows=[struct.unpack_from(fmt,binary,start+i*view.get('byteStride',width)) for i in range(a['count'])]
    return rows,fmt

def sleeve_lining(doc,binary,profile):
    """Dense, flexible inner sleeve; same arm weights as the visible skin.

    The sparse extended outer sleeve leaves an elbow exposed when bent. This
    594-triangle lining follows the actual arm, inside that loose outer cut.
    It is part of the existing cloth surface, without extra nodes/draw calls.
    """
    if profile[0] not in ['fin_drifter','dock_worker']:return 0
    primitives=[p for mesh in doc['meshes'] for p in mesh['primitives']]
    cloth=next(p for p in primitives if doc['materials'][p['material']]['name']=='Cloth')
    skin=next(p for p in primitives if doc['materials'][p['material']]['name']=='Skin' and 'JOINTS_0' in p['attributes'])
    names=[doc['nodes'][n]['name'] for n in doc['skins'][0]['joints']]
    points,_=accessor_rows(doc,binary,skin['attributes']['POSITION'])
    normals,_=accessor_rows(doc,binary,skin['attributes']['NORMAL'])
    joints,_=accessor_rows(doc,binary,skin['attributes']['JOINTS_0'])
    weights,_=accessor_rows(doc,binary,skin['attributes']['WEIGHTS_0'])
    selected={i for i,(p,js,ws) in enumerate(zip(points,joints,weights)) if .59<p[1]<.96 and sum(w for j,w in zip(js,ws) if names[j] in ['uArmL','fArmL','uArmR','fArmR'])>.999}
    source_indices,_=accessor_rows(doc,binary,skin['indices']);source_indices=[row[0] for row in source_indices]
    faces=[source_indices[i:i+3] for i in range(0,len(source_indices),3) if all(v in selected for v in source_indices[i:i+3])]
    used=sorted({v for face in faces for v in face});old_count=doc['accessors'][cloth['attributes']['POSITION']]['count']
    mapping={v:old_count+i for i,v in enumerate(used)}
    def store(index,rows,fmt):
        while len(binary)%4:binary.append(0)
        start=len(binary);raw=b''.join(struct.pack(fmt,*row) for row in rows);binary.extend(raw)
        view={'buffer':0,'byteOffset':start,'byteLength':len(raw)}
        doc['bufferViews'].append(view);a=doc['accessors'][index]
        a['bufferView']=len(doc['bufferViews'])-1;a['byteOffset']=0;a['count']=len(rows)
        if a['type']=='VEC3' and 'min' in a:
            a['min']=[min(p[k] for p in rows) for k in range(3)];a['max']=[max(p[k] for p in rows) for k in range(3)]
    for name,index in cloth['attributes'].items():
        rows,fmt=accessor_rows(doc,binary,index)
        for v in used:
            p=points[v];n=normals[v];q=tuple(p[k]+n[k]*.0035 for k in range(3))
            values={'POSITION':q,'NORMAL':n,'COLOR_0':(1.,1.,1.,0.),
                    'TEXCOORD_0':(math.atan2(p[2]+.02,abs(p[0])-.175)/(2*math.pi)%1,.981-p[1]),
                    'TEXCOORD_1':(1.,0.),'TEXCOORD_2':(p[0],p[1]),'TEXCOORD_3':(p[2],2.),
                    'TEXCOORD_4':(21.,0.),'TEXCOORD_5':(.38,0.),'JOINTS_0':joints[v],'WEIGHTS_0':weights[v]}
            rows.append(values[name])
        store(index,rows,fmt)
    rows,fmt=accessor_rows(doc,binary,cloth['indices'])
    rows.extend((mapping[v],) for face in faces for v in face);store(cloth['indices'],rows,fmt)
    doc['buffers'][0]['byteLength']=len(binary)
    return len(faces)

def derive(profile):
    source = ROOT / 'assets/characters' / f'kid_{profile[1]}.glb'
    data = source.read_bytes(); size = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+size]); binary = bytearray(data[28+size:])
    palette={doc['nodes'][node]['name']:i for i,node in enumerate(doc['skins'][0]['joints'])}
    bone_names=list(palette)
    changed = []
    def offsets(index):
        a = doc['accessors'][index]; bv = doc['bufferViews'][a['bufferView']]
        assert a['componentType']==5126 and a['type']=='VEC3'
        start = bv.get('byteOffset',0)+a.get('byteOffset',0)
        return [start+i*bv.get('byteStride',12) for i in range(a['count'])]
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            semantic = doc['materials'][primitive['material']]['name']
            if semantic not in ('Skin','Cloth','TeamHair','Eyes') or 'JOINTS_0' not in primitive['attributes']:
                continue
            pos_id = primitive['attributes']['POSITION']; norm_id = primitive['attributes']['NORMAL']
            po = offsets(pos_id); no = offsets(norm_id); new = []
            joints = doc['accessors'][primitive['attributes']['JOINTS_0']]
            jview = doc['bufferViews'][joints['bufferView']]
            jwidth={5121:1,5123:2}[joints['componentType']]
            jformat='<4'+('B' if jwidth==1 else 'H')
            jstart=jview.get('byteOffset',0)+joints.get('byteOffset',0)
            weights=doc['accessors'][primitive['attributes']['WEIGHTS_0']];wview=doc['bufferViews'][weights['bufferView']]
            wstart=wview.get('byteOffset',0)+weights.get('byteOffset',0)
            parts = [0] * len(po)
            uvs = [None] * len(po)
            if semantic == 'Cloth':
                tag = doc['accessors'][primitive['attributes']['TEXCOORD_4']]; view = doc['bufferViews'][tag['bufferView']]
                start = view.get('byteOffset',0)+tag.get('byteOffset',0)
                parts = [round(struct.unpack_from('<f',binary,start+i*view.get('byteStride',8))[0]) for i in range(tag['count'])]
                uvtag=doc['accessors'][primitive['attributes']['TEXCOORD_0']];uvview=doc['bufferViews'][uvtag['bufferView']]
                uvstart=uvview.get('byteOffset',0)+uvtag.get('byteOffset',0)
                uvs=[struct.unpack_from('<2f',binary,uvstart+i*uvview.get('byteStride',8)) for i in range(uvtag['count'])]
            elif semantic=='TeamHair':
                for i in range(len(parts)):
                    ji=struct.unpack_from(jformat,binary,jstart+i*jview.get('byteStride',4*jwidth))
                    wi=struct.unpack_from('<4f',binary,wstart+i*wview.get('byteStride',16))
                    parts[i]=int(any(bone_names[j].startswith('hair') and w>.005 for j,w in zip(ji,wi)))
            source_points=[]
            for index,(vp,vn,part,uv) in enumerate(zip(po,no,parts,uvs)):
                p = struct.unpack_from('<3f',binary,vp); n = struct.unpack_from('<3f',binary,vn)
                source_points.append(p)
                q = transform(p, semantic, profile, part, uv)
                struct.pack_into('<3f',binary,vp,*q)
                struct.pack_into('<3f',binary,vn,*normal(p,n,semantic,profile,part,uv)); new.append(q)
                repaint=garment_weights(profile,part,p,q,palette,uv) if semantic=='Cloth' else None
                if semantic=='Cloth' and part==1:
                    ji=struct.unpack_from(jformat,binary,jstart+index*jview.get('byteStride',4*jwidth))
                    wi=struct.unpack_from('<4f',binary,wstart+index*wview.get('byteStride',16))
                    if any(bone_names[j] in ['hemF','hemB'] and w>0 for j,w in zip(ji,wi)):
                        merged={}
                        for j,w in zip(ji,wi):
                            j=palette['hips'] if bone_names[j] in ['hemF','hemB'] else j
                            merged[j]=merged.get(j,0.)+w
                        pairs=sorted(merged.items(),key=lambda row:-row[1])
                        pairs+=[(0,0.)]*(4-len(pairs));repaint=([a for a,b in pairs],[b for a,b in pairs])
                if repaint:
                    ji,wi=repaint
                    struct.pack_into(jformat,binary,jstart+index*jview.get('byteStride',4*jwidth),*ji)
                    struct.pack_into('<4f',binary,wstart+index*wview.get('byteStride',16),*wi)
            if semantic=='Cloth':
                # These source rings are duplicated for separate UV islands.
                # Keep them sewn after different sleeve/seat tailoring maps.
                seams={}
                for i,p in enumerate(source_points):seams.setdefault(tuple(round(v,6) for v in p),[]).append(i)
                for group in seams.values():
                    tags={parts[i] for i in group}
                    if not any(a in tags and b in tags for a,b in [(1,2),(4,5),(5,15),(7,20)]):continue
                    anchor=min(group,key=lambda i:parts[i]);q=new[anchor]
                    for i in group:
                        new[i]=list(q);struct.pack_into('<3f',binary,po[i],*q)
            doc['accessors'][pos_id]['min'] = [min(p[k] for p in new) for k in range(3)]
            doc['accessors'][pos_id]['max'] = [max(p[k] for p in new) for k in range(3)]
            changed.append(semantic)
    lining_faces=sleeve_lining(doc,binary,profile)
    doc.setdefault('extras',{})['tideink_archetype']={'id':profile[0],'method':'local tailored garment/body derivation; garment elbow/knee weights repainted; original skin/UV/rig retained','source_file':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(data).hexdigest(),'changed_semantics':changed,'garment_cuts':CUTS[profile[0]],'lining_triangles':lining_faces}
    encoded = json.dumps(doc,separators=(',',':')).encode(); encoded += b' ' * (-len(encoded)%4)
    payload = struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary
    return struct.pack('<III',0x46546c67,2,len(payload)+12)+payload


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');args=parser.parse_args()
    target=ROOT/'assets/characters/archetypes'
    if args.write: target.mkdir(exist_ok=True)
    for profile in PROFILES:
        expected=derive(profile); path=target/(profile[0]+'.glb')
        if args.write: path.write_bytes(expected)
        else:
            assert path.read_bytes()==expected, f'{path.name}: asset differs from its local derivation'
        print('WROTE' if args.write else 'PASS',path.name,len(expected),'bytes')

if __name__=='__main__': main()
