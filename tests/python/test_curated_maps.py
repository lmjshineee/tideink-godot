#!/usr/bin/env python3
"""Cross-resource checks and corrupt-mask/edge/minimap negative cases."""
import copy,importlib.util,json,math,struct,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('maps',ROOT/'tools/assets/build_curated_maps.py')
maps=importlib.util.module_from_spec(spec);spec.loader.exec_module(maps)

def validate(data,surfaces,nav,info,lookup):
    assert surfaces['blockCount']==len(data['blocks'])
    cells=sum(f['grid']['nu']*f['grid']['nv'] for f in surfaces['faces'] if f['grid'])
    assert cells==info['cells']==surfaces['gridCells']
    assert len(lookup)==info['width']*info['height']*16
    for f in surfaces['faces']:
        g=f['grid']
        if not g:continue
        count=g['nu']*g['nv'];end=0
        for start,length in g['deadRuns']:
            assert start>=end and length>0 and start+length<=count
            end=start+length
    for k,stride,u,v in struct.iter_unpack('<4f',lookup):
        assert k==-1 or (0<=k<cells and 0<=u<1 and 0<=v<1 and k+stride+1<cells)
    nodes=nav['nodes']
    for node in nodes:
        assert node['id']<len(nodes)
        for edge in node['edges']:
            assert 0<=edge['to']<len(nodes)
            q=nodes[edge['to']]['p'];p=node['p'];assert abs(p[0]-q[0])+abs(p[2]-q[2])==1
            assert q[1]-p[1]<=1.00001 and p[1]-q[1]<=3.20001
            assert edge['cost']>=math.dist(p,q)-.00001
    # Both bases reach the central engagement and both wide side lanes.
    for team,pad in enumerate(data['spawnPads']):
        start=min(nodes,key=lambda n:math.dist(pad,n['p']))['id'];seen={start};todo=[start]
        while todo:
            for e in nodes[todo.pop()]['edges']:
                target=e['to']
                if target not in seen and nodes[target]['zone']!=1-team:seen.add(target);todo.append(target)
        for x,z in [(0,0),(-15,0),(15,0)]:
            target=min(nodes,key=lambda n:(n['p'][0]-x)**2+(n['p'][2]-z)**2)['id']
            assert target in seen,(team,x,z)

class CuratedMaps(unittest.TestCase):
    def test_geometry_grid_navigation_and_minimap_are_coherent(self):
        for name in maps.MAPS:
            data=json.loads((ROOT/'assets/maps'/f'{name}.json').read_text())
            surfaces=json.loads((ROOT/'assets/maps'/f'{name}_surfaces.json').read_text())
            nav=json.loads((ROOT/'assets/maps'/f'{name}_nav.json').read_text())
            info=json.loads((ROOT/'assets/maps'/f'{name}_minimap.json').read_text())
            lookup=(ROOT/'assets/maps'/f'{name}_minimap_lookup.bin').read_bytes()
            validate(data,surfaces,nav,info,lookup)
            # Buried floor is excluded instead of generating invisible score cells.
            floor=next(f for f in surfaces['faces'] if f['block']==0 and f['n'][1]>.9)
            self.assertGreater(sum(length for start,length in floor['grid']['deadRuns']),500)
            # Each extruded polygon is a real convex hull with outward faces.
            for block in data['blocks']:
                if block['kind']!='convex':continue
                points=block['geometry']['vertices'];center=[sum(p[k] for p in points)/len(points) for k in range(3)]
                for polygon in block['geometry']['polygons']:
                    a,b,c=[points[i] for i in polygon[:3]];normal=maps.unit(maps.cross(maps.sub(b,a),maps.sub(c,a)))
                    self.assertGreater(maps.dot(maps.sub(a,center),normal),0)
            if name=='lantern_depot':
                stacked=[n for n in nav['nodes'] if n['p'][0]==0 and n['p'][2]==0]
                self.assertEqual({n['p'][1] for n in stacked},{0,3.4})
                # No edge may teleport vertically through the solid concourse.
                self.assertFalse(any(e['to'] in [n['id'] for n in stacked] for n in stacked for e in n['edges']))
            for face in surfaces['faces']:
                if 'polygon' not in face or not face['grid']:continue
                g=face['grid'];dead={i for start,length in g['deadRuns'] for i in range(start,start+length)}
                for j in range(g['nv']):
                    for i in range(g['nu']):
                        if not maps.polygon_contains([(i+.5)*g['cu'],(j+.5)*g['cv']],face['polygon']):self.assertIn(j*g['nu']+i,dead)
            bad=copy.deepcopy(surfaces);next(f for f in bad['faces'] if f['grid'])['grid']['deadRuns']=[[0,10**9]]
            with self.assertRaises(AssertionError):validate(data,bad,nav,info,lookup)
            bad=copy.deepcopy(nav);bad['nodes'][0]['edges'].append({'to':len(bad['nodes']),'cost':1})
            with self.assertRaises(AssertionError):validate(data,surfaces,bad,info,lookup)
            bad=bytearray(lookup);struct.pack_into('<f',bad,0,float(info['cells']+1))
            with self.assertRaises(AssertionError):validate(data,surfaces,nav,info,bad)

if __name__=='__main__':unittest.main()
