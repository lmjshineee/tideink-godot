#!/usr/bin/env python3
"""Verify real local geometry changes preserve rigging, semantic data and originals."""
import importlib.util, json, struct, unittest
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
                            else:self.assertEqual(a,b, f'{profile[0]} changed {semantic}/{name}')
                        self.assertEqual(accessor(old,ob,op['indices']),accessor(new,nb,np['indices']))
                self.assertEqual(changed,{'Skin','Cloth','Eyes','TeamHair'})
                self.assertEqual(new['extras']['tideink_archetype']['id'],profile[0]);distinct.append(b''.join(points))
        self.assertEqual(len(set(distinct)),4)

if __name__=='__main__':unittest.main()
