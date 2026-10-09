#!/usr/bin/env python3
"""Derive four bind-space silhouettes from local licensed rigs, preserving skinning.

No external checkout or DCC runtime is required. Original kid_*.glb are read-only.
Positions and inverse-transpose normals change; topology, joints, weights, semantic
UVs, source license metadata, weapons and the squid remain unchanged.
"""
import argparse, copy, hashlib, json, math, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILES = (
    ('reef_runner', 0, .92, 1.03, .94, .32, 1.00, 1.00),
    ('fin_drifter', 2, .88, .94, 1.06, 1.12, .92, 1.07),
    ('dock_worker', 3, 1.32, 1.10, .95, .72, 1.28, 1.18),
    ('spark_writer', 1, 1.08, .98, 1.00, .60, 1.08, 1.00),
)


def smooth(a, b, x):
    t = max(0., min(1., (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def transform(p, semantic, profile, part=0):
    _, _, torso, face_x, face_y, hair_length, shoe_x, shoe_z = profile
    x, y, z = p
    if semantic in ('Skin', 'Eyes', 'TeamHair') and y > 1.0:
        t = smooth(1.0, 1.1, y)
        x *= 1 + (face_x - 1) * t
        y = 1.17 + (y - 1.17) * (1 + (face_y - 1) * t)
    if semantic == 'Skin' and profile[0] == 'dock_worker' and y > 1.02:
        x += (1 if x > 0 else -1) * .018 * smooth(.01,.08,abs(x)) * smooth(1.02,1.10,y) * (1-smooth(1.15,1.23,y))
    if semantic == 'Eyes' and profile[0] in ('dock_worker','spark_writer'):
        y = 1.19 + (y-1.19) * (.84 if profile[0]=='dock_worker' else .92)
    if semantic == 'Cloth':
        # Build different garment cuts from the fully skinned, detailed source cloth.
        if part == 1 and profile[0] == 'fin_drifter':
            y = .998 - (.998 - y) * 1.40
            x *= 1 + .50 * (1 - smooth(.63, .97, y))
            z *= 1 + .35 * (1 - smooth(.63, .97, y))
        if part in (5, 15) and profile[0] == 'dock_worker':
            y = .645 - (.645 - y) * 1.55
            center = .078 if x > 0 else -.078
            x = center + (x - center) * 1.15
        if part == 2 and (profile[0] == 'dock_worker' or (profile[0] == 'spark_writer' and x > 0)):
            y = .99 - (.99 - y) * 1.45
    if semantic == 'TeamHair':
        if y < 1.14:
            y = 1.14 + (y - 1.14) * hair_length
        return [x, y, z]
    if semantic in ('Skin', 'Cloth'):
        # Chest and hips change proportion without shifting hand/weapon anchors.
        w = smooth(.62, .74, y) * (1 - smooth(.98, 1.03, y)) * (1 - smooth(.12, .19, abs(x)))
        x *= 1 + (torso - 1) * w
        z *= 1 + (torso - 1) * w * .5
        if semantic == 'Cloth' and y < .19:
            foot = .084 if x > 0 else -.084
            x = foot + (x - foot) * shoe_x
            z = .03 + (z - .03) * shoe_z
    return [x, y, z]


def normal(p, n, semantic, profile, part=0):
    eps = .00001
    cols = []
    for k in range(3):
        a = list(p); b = list(p); a[k] += eps; b[k] -= eps
        ta = transform(a, semantic, profile, part); tb = transform(b, semantic, profile, part)
        cols.append([(ta[i] - tb[i]) / (2 * eps) for i in range(3)])
    # J^-T n from column cofactors.
    cross = lambda a,b: [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
    c = [cross(cols[1],cols[2]),cross(cols[2],cols[0]),cross(cols[0],cols[1])]
    v = [sum(c[k][i]*n[k] for k in range(3)) for i in range(3)]
    length = math.sqrt(sum(a*a for a in v))
    if length < 1e-12: return list(n)  # Source degenerate triangles carry zero normals.
    return [a / length for a in v]


def derive(profile):
    source = ROOT / 'assets/characters' / f'kid_{profile[1]}.glb'
    data = source.read_bytes(); size = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+size]); binary = bytearray(data[28+size:])
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
            parts = [0] * len(po)
            if semantic == 'Cloth':
                tag = doc['accessors'][primitive['attributes']['TEXCOORD_4']]; view = doc['bufferViews'][tag['bufferView']]
                start = view.get('byteOffset',0)+tag.get('byteOffset',0)
                parts = [round(struct.unpack_from('<f',binary,start+i*view.get('byteStride',8))[0]) for i in range(tag['count'])]
            for vp, vn, part in zip(po,no,parts):
                p = struct.unpack_from('<3f',binary,vp); n = struct.unpack_from('<3f',binary,vn)
                q = transform(p, semantic, profile, part)
                struct.pack_into('<3f',binary,vp,*q)
                struct.pack_into('<3f',binary,vn,*normal(p,n,semantic,profile,part)); new.append(q)
            doc['accessors'][pos_id]['min'] = [min(p[k] for p in new) for k in range(3)]
            doc['accessors'][pos_id]['max'] = [max(p[k] for p in new) for k in range(3)]
            changed.append(semantic)
    doc.setdefault('extras',{})['tideink_archetype']={'id':profile[0],'method':'local bind-space silhouette derivation; original skin/UV/rig retained','source_file':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(data).hexdigest(),'changed_semantics':changed}
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
