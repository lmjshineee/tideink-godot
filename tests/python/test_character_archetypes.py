#!/usr/bin/env python3
"""Verify real local geometry changes preserve rigging, semantic data and originals."""
import collections, importlib.util, json, struct, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('builder',ROOT/'tools/assets/build_character_archetypes.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)

def read(path):
    data=path.read_bytes();length=struct.unpack_from('<I',data,12)[0]
    return json.loads(data[20:20+length]),data[28+length:]

def accessor(doc,buf,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16};width=sizes[a['type']]*{5126:4,5123:2,5125:4,5121:1}[a['componentType']]
    start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',width)
    return b''.join(buf[start+i*stride:start+i*stride+width] for i in range(a['count']))

class Archetypes(unittest.TestCase):
    def test_mixed_garments_share_their_active_skeletal_bindings(self):
        reference=None;reference_names=None
        for profile in builder.PROFILES:
            doc,buf=read(ROOT/'assets/characters/archetypes'/(profile[0]+'.glb'))
            names=[doc['nodes'][n]['name'] for n in doc['skins'][0]['joints']]
            bindings=list(struct.iter_unpack('<16f',accessor(doc,buf,doc['skins'][0]['inverseBindMatrices'])))
            if reference is None:reference=bindings;reference_names=names
            self.assertEqual(names,reference_names)
            for mesh in doc['meshes']:
                for p in mesh['primitives']:
                    if doc['materials'][p['material']]['name']!='Cloth':continue
                    index=p['attributes']['JOINTS_0'];fmt='<4'+('B' if doc['accessors'][index]['componentType']==5121 else 'H')
                    joints=list(struct.iter_unpack(fmt,accessor(doc,buf,index)))
                    weights=list(struct.iter_unpack('<4f',accessor(doc,buf,p['attributes']['WEIGHTS_0'])))
                    active={j for js,ws in zip(joints,weights) for j,w in zip(js,ws) if w>.000001}
                    for j in active:self.assertLess(max(abs(a-b) for a,b in zip(bindings[j],reference[j])),.00001,names[j])
                    # Isolated wrong bind matrix would shift a mixed sleeve by 2cm.
                    bad=list(reference[next(iter(active))]);bad[12]+=.02
                    self.assertGreater(max(abs(a-b) for a,b in zip(bad,reference[next(iter(active))])),.019)

    def seam_distances(self,old,ob,new,nb,primitive):
        idx=primitive['attributes']['POSITION'];tag=primitive['attributes']['TEXCOORD_4']
        before=list(struct.iter_unpack('<3f',accessor(old,ob,idx)))
        after=list(struct.iter_unpack('<3f',accessor(new,nb,idx)))
        parts=list(struct.iter_unpack('<2f',accessor(old,ob,tag)))
        groups=collections.defaultdict(list);result=[]
        for i,p in enumerate(before):groups[tuple(round(v,6) for v in p)].append(i)
        for group in groups.values():
            for i in group:
                for j in group:
                    a,c=round(parts[i][0]),round(parts[j][0])
                    if (a,c) in [(1,2),(4,5)]:result.append((i,j,sum((after[i][k]-after[j][k])**2 for k in range(3))**.5))
        return result

    def test_tailored_panel_seams_remain_sewn_and_reject_a_gap(self):
        for profile in builder.PROFILES:
            old,ob=read(ROOT/'assets/characters'/f'kid_{profile[1]}.glb')
            new,nb=read(ROOT/'assets/characters/archetypes'/(profile[0]+'.glb'))
            primitive=next(p for m in old['meshes'] for p in m['primitives'] if old['materials'][p['material']]['name']=='Cloth')
            seams=self.seam_distances(old,ob,new,nb,primitive)
            self.assertGreater(len(seams),50);self.assertLess(max(row[2] for row in seams),.000002)
            # Isolated malformed copy proves the continuity oracle catches a 2cm tear.
            bad=bytearray(nb);a=new['accessors'][primitive['attributes']['POSITION']];view=new['bufferViews'][a['bufferView']]
            offset=view.get('byteOffset',0)+a.get('byteOffset',0)+seams[0][0]*view.get('byteStride',12)
            struct.pack_into('<f',bad,offset,struct.unpack_from('<f',bad,offset)[0]+.02)
            self.assertGreater(max(row[2] for row in self.seam_distances(old,ob,new,bad,primitive)),.019)

    def test_production_meshes_preserve_animation_contract(self):
        distinct=[]
        for profile in builder.PROFILES:
            with self.subTest(profile=profile[0]):
                source=ROOT/'assets/characters'/f'kid_{profile[1]}.glb';target=ROOT/'assets/characters/archetypes'/(profile[0]+'.glb')
                old,ob=read(source);new,nb=read(target)
                self.assertEqual(target.read_bytes(),builder.derive(profile))
                self.assertEqual(old['nodes'],new['nodes']);self.assertEqual(old['skins'],new['skins'])
                self.assertEqual(old.get('animations'),new.get('animations'));self.assertEqual(old['materials'],new['materials'])
                changed=set(); points=[]
                for om,nm in zip(old['meshes'],new['meshes']):
                    for op,np in zip(om['primitives'],nm['primitives']):
                        self.assertEqual(op,np)
                        skinned='JOINTS_0' in op['attributes'];semantic=old['materials'][op['material']]['name']
                        for name,index in op['attributes'].items():
                            a=accessor(old,ob,index);b=accessor(new,nb,index)
                            if skinned and semantic in ['Skin','Cloth','Eyes','TeamHair'] and name in ['POSITION','NORMAL']:
                                if a!=b:changed.add(semantic)
                                floats=struct.unpack('<'+'f'*(len(b)//4),b)
                                self.assertTrue(all(-10<x<10 for x in floats))
                                if name=='POSITION':points.append(b)
                            elif skinned and semantic=='Cloth' and name in ['JOINTS_0','WEIGHTS_0']:
                                if name=='WEIGHTS_0':
                                    for weights in struct.iter_unpack('<4f',b):
                                        self.assertAlmostEqual(sum(weights),1.0,places=5)
                                        self.assertTrue(all(0<=weight<=1 for weight in weights))
                                else:
                                    width=new['accessors'][index]['componentType']
                                    for joints in struct.iter_unpack('<4'+('B' if width==5121 else 'H'),b):
                                        self.assertTrue(all(joint<87 for joint in joints))
                            elif skinned and semantic=='Cloth':
                                self.assertEqual(a,b[:len(a)], f'{profile[0]} changed existing {semantic}/{name}')
                                tags=list(struct.iter_unpack('<2f',accessor(new,nb,np['attributes']['TEXCOORD_4'])))
                                previous_count=old['accessors'][index]['count']
                                self.assertTrue(all(round(tag[0])==21 for tag in tags[previous_count:]))
                            else:self.assertEqual(a,b, f'{profile[0]} changed {semantic}/{name}')
                        old_indices=accessor(old,ob,op['indices']);new_indices=accessor(new,nb,np['indices'])
                        self.assertEqual(old_indices,new_indices[:len(old_indices)])
                        if len(new_indices)>len(old_indices):
                            old_count=old['accessors'][op['attributes']['POSITION']]['count']
                            extra=list(struct.iter_unpack('<I',new_indices[len(old_indices):]))
                            self.assertTrue(all(row[0]>=old_count for row in extra))
                            self.assertEqual(len(extra)//3,594)
                self.assertEqual(changed,{'Skin','Cloth','Eyes','TeamHair'})
                self.assertEqual(new['extras']['tideink_archetype']['id'],profile[0]);distinct.append(b''.join(points))
        self.assertEqual(len(set(distinct)),4)

    def test_tailored_long_cloth_follows_elbows_and_knees(self):
        for profile in builder.PROFILES:
            doc,buf=read(ROOT/'assets/characters/archetypes'/(profile[0]+'.glb'))
            names=[doc['nodes'][node]['name'] for node in doc['skins'][0]['joints']]
            lower_pants=[];low_sleeves=[]
            for mesh in doc['meshes']:
                for p in mesh['primitives']:
                    if doc['materials'][p['material']]['name']!='Cloth' or 'JOINTS_0' not in p['attributes']:continue
                    positions=list(struct.iter_unpack('<3f',accessor(doc,buf,p['attributes']['POSITION'])))
                    parts=list(struct.iter_unpack('<2f',accessor(doc,buf,p['attributes']['TEXCOORD_4'])))
                    idx=p['attributes']['JOINTS_0'];fmt='<4'+('B' if doc['accessors'][idx]['componentType']==5121 else 'H')
                    joints=list(struct.iter_unpack(fmt,accessor(doc,buf,idx)))
                    weights=list(struct.iter_unpack('<4f',accessor(doc,buf,p['attributes']['WEIGHTS_0'])))
                    for pos,part,joint,weight in zip(positions,parts,joints,weights):
                        active={names[index]:w for index,w in zip(joint,weight) if w>.001}
                        if round(part[0]) in [5,15] and pos[1]<.28:
                            self.assertTrue(any(n.startswith('shin') and w>.99 for n,w in active.items()))
                            lower_pants.append(pos)
                        if round(part[0])==2 and pos[1]<.705:
                            self.assertTrue(any(n.startswith('fArm') and w>.99 for n,w in active.items()))
                            low_sleeves.append(pos)
            if profile[0] in ['fin_drifter','dock_worker']:
                self.assertGreater(len(lower_pants),30);self.assertGreater(len(low_sleeves),30)
                self.assertLess(min(pos[1] for pos in lower_pants),.10)

if __name__=='__main__':unittest.main()
