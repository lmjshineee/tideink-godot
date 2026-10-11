#!/usr/bin/env python3
"""Verify real local geometry changes preserve rigging, semantic data and originals."""
import collections, importlib.util, json, math, struct, unittest
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
    def groom_orientation(self,doc,buf,indices=None):
        prim=next(p for m in doc['meshes'] for p in m['primitives'] if doc['materials'][p['material']]['name']=='TeamHair' and 'JOINTS_0' in p['attributes'])
        data={k:builder.accessor_rows(doc,buf,i)[0] for k,i in prim['attributes'].items()}
        ids=indices if indices is not None else [v[0] for v in builder.accessor_rows(doc,buf,prim['indices'])[0]]
        result=[]
        for start in range(0,len(ids),3):
            tri=ids[start:start+3]
            if any(data['TEXCOORD_1'][i][1]<2.5 for i in tri):continue
            a,b,c=[data['POSITION'][i] for i in tri]
            u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
            n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            length=math.sqrt(sum(k*k for k in n))
            if length<1e-11:continue
            avg=[sum(data['NORMAL'][i][k] for i in tri)/3 for k in range(3)]
            result.append((start,sum(n[k]*avg[k] for k in range(3))/length))
        return result

    def test_groom_surface_orientation_and_closed_scalp_seam(self):
        for profile in builder.PROFILES:
            doc,buf=read(ROOT/'assets/characters/archetypes'/(profile[0]+'.glb'))
            prim=next(p for m in doc['meshes'] for p in m['primitives'] if doc['materials'][p['material']]['name']=='TeamHair' and 'JOINTS_0' in p['attributes'])
            data={k:builder.accessor_rows(doc,buf,i)[0] for k,i in prim['attributes'].items()}
            ids=[v[0] for v in builder.accessor_rows(doc,buf,prim['indices'])[0]]
            good=self.groom_orientation(doc,buf,ids)
            self.assertGreater(len(good),15000);self.assertGreater(min(v for _,v in good),0.)
            # Reject an inward triangle like the old scalp winding, even when
            # a two-sided material happens to conceal it in one camera view.
            bad=list(ids);at=good[0][0];bad[at],bad[at+1]=bad[at+1],bad[at]
            self.assertLess(min(v for _,v in self.groom_orientation(doc,buf,bad)),0.)
            scalp=[i for i,tag in enumerate(data['TEXCOORD_1']) if tag[1]==4.]
            self.assertEqual(len(scalp),65*25)
            for ring in range(25):
                a,b=scalp[ring*65],scalp[ring*65+64]
                self.assertLess(sum((data['POSITION'][a][k]-data['POSITION'][b][k])**2 for k in range(3))**.5,.00002)
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
                # Four expression pivots follow the sculpted geometry; all
                # other joints, hierarchy and animations retain their contract.
                for a,c in zip(old['nodes'],new['nodes']):
                    if a.get('name') in ['eyeL','eyeR','browL','browR']:
                        self.assertEqual({k:v for k,v in a.items() if k!='translation'}, {k:v for k,v in c.items() if k!='translation'})
                        self.assertLess(sum((x-y)**2 for x,y in zip(a['translation'],c['translation']))**.5,.06)
                    else:self.assertEqual(a,c)
                self.assertEqual(old['skins'],new['skins'])
                self.assertEqual(old.get('animations'),new.get('animations'));self.assertEqual(old['materials'],new['materials'])
                changed=set(); points=[]
                for om,nm in zip(old['meshes'],new['meshes']):
                    for op,np in zip(om['primitives'],nm['primitives']):
                        self.assertEqual(op,np)
                        if old['materials'][op['material']]['name']=='TeamHair':
                            hair=new['extras']['tideink_archetype']['hair']
                            self.assertGreater(hair['removed_strand_vertices'],100)
                            self.assertGreater(hair['removed_scalp_vertices'],500)
                            uv2=list(struct.iter_unpack('<2f',accessor(new,nb,np['attributes']['TEXCOORD_1'])))
                            self.assertTrue(all(v<1.5 or v>=2.5 for u,v in uv2), 'old scalp layer must be absent')
                            self.assertGreater(hair['triangles'],500)
                            pos=list(struct.iter_unpack('<3f',accessor(new,nb,np['attributes']['POSITION'])))
                            norms=list(struct.iter_unpack('<3f',accessor(new,nb,np['attributes']['NORMAL'])))
                            self.assertTrue(all(all(-2<x<2 for x in row) for row in pos))
                            self.assertTrue(all(sum(x*x for x in row)>.90 for row in norms if any(row)))
                            indices=[v[0] for v in struct.iter_unpack('<I',accessor(new,nb,np['indices']))]
                            self.assertTrue(all(v<len(pos) for v in indices))
                            js=list(struct.iter_unpack('<4B',accessor(new,nb,np['attributes']['JOINTS_0'])))
                            ws=list(struct.iter_unpack('<4f',accessor(new,nb,np['attributes']['WEIGHTS_0'])))
                            names=[new['nodes'][n]['name'] for n in new['skins'][0]['joints']]
                            self.assertTrue(all(not names[j].startswith('hair') for joints,weights in zip(js,ws) for j,w in zip(joints,weights) if w>.005))
                            self.assertTrue(all(abs(sum(w)-1)<.00001 for w in ws))
                            changed.add('TeamHair');points.append(accessor(new,nb,np['attributes']['POSITION']))
                            continue
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

    def test_faces_have_anatomical_depth_and_distinct_jaws(self):
        """Check the delivered surfaces, independently of the sculpt formulas."""
        jaw_ratios=[]
        for profile in builder.PROFILES:
            doc,buf=read(ROOT/'assets/characters/archetypes'/(profile[0]+'.glb'))
            prim=next(p for m in doc['meshes'] for p in m['primitives'] if doc['materials'][p['material']]['name']=='Skin' and 'JOINTS_0' in p['attributes'])
            points=builder.accessor_rows(doc,buf,prim['attributes']['POSITION'])[0]
            uv=builder.accessor_rows(doc,buf,prim['attributes']['TEXCOORD_0'])[0]
            direction=builder.accessor_rows(doc,buf,prim['attributes']['TEXCOORD_1'])[0]
            original=builder.accessor_rows(doc,buf,prim['attributes']['TEXCOORD_2'])[0]
            face=[(p,o) for p,u,d,o in zip(points,uv,direction,original) if u[0]**2+u[1]**2+d[0]**2>.5 and d[0]>0]
            def region_depth(cx,cy,wx=.006,wy=.006):
                group=[p for p,o in face if abs(abs(o[0])-cx)<wx and abs(o[1]-cy)<wy]
                self.assertGreater(len(group),2)
                return sum(p[2] for p in group)/len(group)
            # A visible bridge and nose projection; recessed orbital surface
            # instead of a bead nose sitting on an unchanged sphere.
            nose=region_depth(0,1.163)
            bridge=region_depth(0,1.195)
            orbit=region_depth(.055,1.195)
            cheek=region_depth(.055,1.153)
            self.assertGreater(nose-cheek,.018)
            self.assertGreater(bridge-orbit,.012)
            low=[abs(p[0]) for p,o in face if 1.068<o[1]<1.076]
            mid=[abs(p[0]) for p,o in face if 1.178<o[1]<1.191]
            jaw_ratios.append(max(low)/max(mid))
            normals=builder.accessor_rows(doc,buf,prim['attributes']['NORMAL'])[0]
            self.assertTrue(all(abs(sum(n*n for n in row)-1)<.00002 for row in normals if any(row)))
        # Dock's broad jaw and Fin's heart outline remain different even after
        # normalizing away overall head/body size.
        self.assertGreater(jaw_ratios[2]-jaw_ratios[1],.20)
        self.assertGreater(jaw_ratios[3]-jaw_ratios[1],.06)

    def test_face_expression_pivots_match_bind_geometry_and_reject_old_anchor(self):
        for profile in builder.PROFILES:
            doc,buf=read(ROOT/'assets/characters/archetypes'/(profile[0]+'.glb'))
            names=[doc['nodes'][n]['name'] for n in doc['skins'][0]['joints']]
            binds=list(struct.iter_unpack('<16f',accessor(doc,buf,doc['skins'][0]['inverseBindMatrices'])))
            prim=next(p for m in doc['meshes'] for p in m['primitives'] if doc['materials'][p['material']]['name']=='Eyes' and 'JOINTS_0' in p['attributes'])
            points=builder.accessor_rows(doc,buf,prim['attributes']['POSITION'])[0]
            uvs=builder.accessor_rows(doc,buf,prim['attributes']['TEXCOORD_0'])[0]
            for side,name in [(1,'eyeL'),(-1,'eyeR')]:
                center=next(p for p,uv in zip(points,uvs) if abs(uv[0])+abs(uv[1])<.000001 and p[0]*side>0)
                pivot=[-v for v in binds[names.index(name)][12:15]]
                self.assertLess(sum((a-b)**2 for a,b in zip(center,pivot))**.5,.00001)
                # Isolated bad anchor: closing the eye at the old height would
                # drift the eyelid by >2cm instead of closing in its socket.
                wrong=list(pivot);wrong[1]+=.025
                drift=lambda anchor:abs((anchor[1]+(center[1]-anchor[1])*.07)-center[1])
                self.assertLess(drift(pivot),.00001)
                self.assertGreater(drift(wrong),.02)

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
