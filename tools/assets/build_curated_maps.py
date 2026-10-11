#!/usr/bin/env python3
"""Author two original arenas; collision, visible faces, CPU grids, nav and minimap
are derived from one local geometry description. Python standard library only.
No historical exporter or external checkout is involved.
"""
import argparse, hashlib, json, math, struct, zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
MAPS=('sunset_park','lantern_depot')

def add(a,b):return [x+y for x,y in zip(a,b)]
def mul(a,t):return [x*t for x in a]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def sub(a,b):return [x-y for x,y in zip(a,b)]

def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def unit(a):return mul(a,1/math.sqrt(dot(a,a)))
def polygon_contains(p,vertices,tolerance=.00001):
    signs=[(b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]) for a,b in zip(vertices,vertices[1:]+vertices[:1])]
    return min(signs)>=-tolerance or max(signs)<=tolerance

def layout(name):
    blocks=[]
    def record(kind,g,vertices,color,tag,pattern,paint):
        blocks.append({'id':len(blocks),'kind':kind,'color':color,'pattern':pattern,'tag':tag,'paint':paint,'solid':True,'min':[min(p[k] for p in vertices) for k in range(3)],'max':[max(p[k] for p in vertices) for k in range(3)],'geometry':g})
    def box(center,size,color,tag,pattern=17,angle=0,paint=True,yaw=0):
        c,s=math.cos(angle),math.sin(angle);cy,sy=math.cos(yaw),math.sin(yaw)
        rotate=lambda p:[cy*p[0]+sy*p[2],p[1],-sy*p[0]+cy*p[2]]
        axes=[rotate(p) for p in [[1,0,0],[0,c,s],[0,-s,c]]];half=[v/2 for v in size]
        corners=[add(center,add(mul(axes[0],i*half[0]),add(mul(axes[1],j*half[1]),mul(axes[2],k*half[2])))) for i in (-1,1) for j in (-1,1) for k in (-1,1)]
        record('box',{'center':center,'half':half,'axes':axes},corners,color,tag,pattern,paint)
    def ramp(x,z,width,length,height,color,reverse=False,tag='bank',base=0,yaw=0):
        angle=math.atan2(height,length)*(1 if reverse else -1);thick=.35;c=math.cos(angle);s=math.sin(angle)
        box([x-thick*s*math.sin(yaw)/2,base+height/2-thick*c/2,z-thick*s*math.cos(yaw)/2],[width,thick,math.hypot(length,height)],color,tag,angle=angle,yaw=yaw)
    def prism(poly,low,high,color,tag,pattern=17,paint=True):
        # Convex extrusions use the very same planes for mesh, hull and CPU ink.
        n=len(poly);vertices=[[x,y,z] for y in [low,high] for x,z in poly]
        faces=[list(range(n)),list(reversed(range(n,2*n)))]+[[i,n+i,n+(i+1)%n,(i+1)%n] for i in range(n)]
        record('convex',{'vertices':vertices,'polygons':faces},vertices,color,tag,pattern,paint)
    def circle(radius,low,high,color,tag,segments=24,pattern=17):
        prism([[radius*math.cos(i*math.tau/segments),radius*math.sin(i*math.tau/segments)] for i in range(segments)],low,high,color,tag,pattern)
    def arc(inner,outer,a,b,low,high,color,tag,segments=10,pattern=17,paint=True):
        for i in range(segments):
            lo=math.radians(a+(b-a)*i/segments);hi=math.radians(a+(b-a)*(i+1)/segments)
            poly=[[r*math.cos(t),r*math.sin(t)] for r,t in [(inner,lo),(outer,lo),(outer,hi),(inner,hi)]]
            prism(poly,low,high,color,tag,pattern,paint)
    park=name=='sunset_park';ground='#dbc6aa' if park else '#a4b7b6';accent='#c98569' if park else '#437d83'
    box([0,-.6,0],[40,1.2,64],ground,'arena-floor',17 if park else 18)
    for sign in (-1,1):
        # Starting decks and deliberate sight-line protection are shared rules.
        box([0,2.1,sign*27],[12,4.2,10],'#e6d6ba','spawn-deck')
        ramp(0,sign*18,8,8,4.2,'#c2b39d',sign<0,'spawn-exit')
        box([sign*4.8,4.75,sign*23.6],[2.4,1.1,1],accent,'spawn-cover')
    if park:
        # A circular forum, with two continuous crescent high lines around it.
        circle(7.5,0,1.6,'#e2cab3','round-forum',pattern=19)
        ramp(0,-10,5,5,1.6,'#d8b59d',False,'forum-bank')
        ramp(0,10,5,5,1.6,'#d8b59d',True,'forum-bank')
        for side in (-1,1):
            turn=0 if side>0 else 180
            arc(12.8,17.0,-65+turn,65+turn,0,2.2,'#cead91','crescent-highline',12,19)
            # Curved outer walls shelter approach; the middle remains exposed.
            arc(16.4,17.0,-58+turn,-23+turn,2.2,3.5,accent,'curved-windbreak',5,19)
            arc(16.4,17.0,23+turn,58+turn,2.2,3.5,accent,'curved-windbreak',5,19)
            for sign in (-1,1):
                ramp(side*6.65,sign*17.9,4.7,8,2.2,'#d8b59d',sign>0,'highline-bank')
            # Four crescent fins provide local cover with clean broad surfaces.
            for turn2 in [-48,132] if side<0 else [48,228]:
                arc(3.8,4.5,turn2-14,turn2+14,1.6,2.9,'#709ba0','forum-fin',4,19)
    else:
        # The suspended diagonal X is the station itself. Ground-level streets
        # continue beneath it; top and underpass share X/Z, but distinct nav nodes.
        angle=math.atan(.55)
        for yaw in [-angle,angle]:
            box([0,3.15,0],[4.8,.5,28],'#c7c1ad','diagonal-concourse',20,yaw=yaw)
            for sign in (-1,1):
                # Outer high end joins the diagonal deck, low end at street level.
                x=sign*18*math.sin(yaw);z=sign*18*math.cos(yaw)
                ramp(x,z,4.8,8,3.4,'#9fac9c',sign>0,'concourse-bank',yaw=yaw)
        circle(5.1,2.9,3.4,'#d1c9b2','suspended-round-junction',pattern=20)
        for side in (-1,1):
            # Rhythmic paired arches frame the sunken street rather than filling
            # it with tram props. High roofs provide a clear silhouette and shade.
            arc(12.9,17.8,-37+(180 if side<0 else 0),37+(180 if side<0 else 0),6.7,7.15,'#596b65','crescent-canopy',12,18,False)
            for sign in (-1,1):
                box([side*15.2,3.35,sign*8.7],[.42,6.7,.42],'#4c6564','canopy-column',18,paint=False)
            # A solid sculpted blade breaks long street-to-street sniper lines.
            arc(7.0,7.9,-26+(180 if side<0 else 0),26+(180 if side<0 else 0),0,2.1,'#49818a','street-screen',8,18)
            arc(3.0,3.8,55+(180 if side<0 else 0),90+(180 if side<0 else 0),3.4,4.5,'#ba806b','junction-screen',5,18)
        # Inner pillars are intentionally separate from the two street underpasses.
        for x,z in [(-3,0),(3,0),(0,-3),(0,3)]:
            box([x,1.45,z],[.45,2.9,.45],'#425b61','junction-support',18,paint=False)
    return {'schema':1,'source':'tools/assets/build_curated_maps.py','id':name,'layout':name,'bounds':{'minX':-20,'maxX':20,'minZ':-32,'maxZ':32},'spawnPads':[[0,4.2,-27],[0,4.2,27]],'spawnBarrier':4.2,'structuralBlocks':len(blocks),'dressing':{'items':0,'propColliders':0},'blocks':blocks}

def inside(point,b,margin=0):
    g=b['geometry']
    if b['kind']=='convex':
        return b['min'][1]+margin<point[1]<b['max'][1]-margin and polygon_contains([point[0],point[2]],[[p[0],p[2]] for p in g['vertices'][:len(g['vertices'])//2]],-margin)
    q=sub(point,g['center'])
    return all(abs(dot(q,axis))<h-margin for axis,h in zip(g['axes'],g['half']))

def runs(indices):
    out=[]
    for index in indices:
        if out and out[-1][0]+out[-1][1]==index:out[-1][1]+=1
        else:out.append([index,1])
    return out

def surface_data(data):
    faces=[];cells=0;turf=0
    for b in data['blocks']:
        g=b['geometry'];planes=[]
        if b['kind']=='convex':
            for indices in g['polygons']:
                poly=[g['vertices'][i] for i in indices];u=unit(sub(poly[1],poly[0]));n=unit(cross(u,sub(poly[2],poly[0])));v=cross(n,u)
                pu=[dot(p,u) for p in poly];pv=[dot(p,v) for p in poly];su=max(pu)-min(pu);sv=max(pv)-min(pv)
                origin=add(mul(n,dot(poly[0],n)),add(mul(u,min(pu)),mul(v,min(pv))))
                planes.append((n,u,v,origin,su,sv,poly))
        else:
            axes=g['axes'];half=g['half']
            for axis,sign,ua,us,va,vs in [(0,1,2,-1,1,1),(0,-1,2,1,1,1),(1,1,0,1,2,-1),(1,-1,0,1,2,1),(2,1,0,1,1,1),(2,-1,0,-1,1,1)]:
                n=mul(axes[axis],sign);u=mul(axes[ua],us);v=mul(axes[va],vs)
                origin=add(g['center'],sub(mul(n,half[axis]),add(mul(u,half[ua]),mul(v,half[va]))))
                planes.append((n,u,v,origin,2*half[ua],2*half[va],None))
        for n,u,v,origin,su,sv,poly in planes:
            paint=b['paint'] and n[1]>-.3;grid=None
            uvpoly=[[dot(sub(p,origin),u),dot(sub(p,origin),v)] for p in poly] if poly else None
            if paint:
                nu=math.ceil(su/.25);nv=math.ceil(sv/.25);cu=su/nu;cv=sv/nv;dead=[]
                candidates=[other for other in data['blocks'] if other['id']!=b['id'] and all(other['max'][k]>=b['min'][k]-.01 and other['min'][k]<=b['max'][k]+.01 for k in range(3))]
                for j in range(nv):
                    for i in range(nu):
                        uv=[(i+.5)*cu,(j+.5)*cv];p=add(origin,add(mul(u,uv[0]),mul(v,uv[1])));p=add(p,mul(n,.012))
                        if (uvpoly and not polygon_contains(uv,uvpoly)) or any(inside(p,other) for other in candidates):dead.append(j*nu+i)
                grid={'nu':nu,'nv':nv,'cu':cu,'cv':cv,'deadRuns':runs(dead)};cells+=nu*nv
                if n[1]>.5:turf+=nu*nv-len(dead)
            face={'id':len(faces),'block':b['id'],'n':n,'u':u,'v':v,'origin':origin,'su':su,'sv':sv,'paintable':paint,'turf':paint and n[1]>.5,'wall':paint and n[1]<=.5,'grid':grid}
            if uvpoly:face['polygon']=uvpoly
            faces.append(face)
    return {'schema':1,'source':'tools/assets/build_curated_maps.py','id':data['id'],'layout':data['id'],'blockCount':len(data['blocks']),'cellSize':.25,'gridCells':cells,'turfCells':turf,'faces':faces}

def at_xz(x,z,face):
    n=face['n'];o=face['origin']
    y=o[1]-(n[0]*(x-o[0])+n[2]*(z-o[2]))/n[1]
    p=[x,y,z];q=sub(p,o);u=dot(q,face['u']);v=dot(q,face['v'])
    return (y,u,v) if -.00001<=u<=face['su']+.00001 and -.00001<=v<=face['sv']+.00001 and ('polygon' not in face or polygon_contains([u,v],face['polygon'])) else None

def top_at(x,z,tops):
    best=None
    for face in tops:
        hit=at_xz(x,z,face)
        if hit and (best is None or hit[0]>best[0]):best=(*hit,face)
    return best

def navigation(data,surfaces):
    tops=[f for f in surfaces['faces'] if f['n'][1]>.7 and f['paintable']]
    nodes=[];lookup={}
    def clearance(x,y,z):
        return not any(inside([x+dx,y+h,z+dz],b,.001) for b in data['blocks'] for dx,dz in [(0,0),(.23,0),(-.23,0),(0,.23),(0,-.23)] for h in [.35,1.45])
    for iz in range(-31,32):
        for ix in range(-19,20):
            heights=sorted(set(round(hit[0],6) for f in tops if (hit:=at_xz(ix,iz,f))))
            for y in heights:
                if not clearance(ix,y,iz):continue
                lookup.setdefault((ix,iz),[]).append(len(nodes));zone=0 if iz<-23 and y>4 else 1 if iz>23 and y>4 else -1
                nodes.append({'id':len(nodes),'p':[ix,y,iz],'zone':zone,'edges':[]})
    for (ix,iz),indices in lookup.items():
        for index in indices:
            a=nodes[index];y=a['p'][1]
            for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
                for to in lookup.get((ix+dx,iz+dz),[]):
                    dy=nodes[to]['p'][1]-y
                    if dy>1.0 or dy < -3.2:continue
                    if not clearance(ix+dx*.5,y+dy*.5,iz+dz*.5):continue
                    kind='walk' if abs(dy)<=.65 else 'jump' if dy>0 else 'drop'
                    a['edges'].append({'to':to,'cost':round(math.hypot(1,dy)+(1.0 if kind!='walk' else 0),6),'type':kind})
    return {'schema':1,'id':data['id'],'source':'tools/assets/build_curated_maps.py','nodes':nodes}

def png(width,height,pixels):
    def chunk(kind,payload):return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
    rows=b''.join(b'\0'+pixels[i*width*4:(i+1)*width*4] for i in range(height))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows,9))+chunk(b'IEND',b'')

def minimap(data,surfaces):
    width,height=240,384;pixels=bytearray();lookup=bytearray();offsets={};offset=0
    tops=[f for f in surfaces['faces'] if f['n'][1]>.5]
    for f in surfaces['faces']:
        if f['grid']:offsets[f['id']]=offset;offset+=f['grid']['nu']*f['grid']['nv']
    blocks=data['blocks'];paint_pixels=0
    for j in range(height):
        z=32-(j+.5)*64/height
        for i in range(width):
            x=20-(i+.5)*40/width;hit=top_at(x,z,tops)
            if not hit:pixels.extend((0,0,0,0));lookup.extend(struct.pack('<4f',-1,0,0,0));continue
            y,u,v,face=hit;b=blocks[face['block']];color=tuple(bytes.fromhex(b['color'][1:]))
            shade=.86+.12*max(0,min(1,y/4.2));pixels.extend((*[int(c*shade) for c in color],255))
            g=face['grid']
            if not g:lookup.extend(struct.pack('<4f',-1,0,0,0));continue
            fx=max(0,min(g['nu']-1.001,u/g['cu']-.5));fy=max(0,min(g['nv']-1.001,v/g['cv']-.5))
            index=offsets[face['id']]+int(fy)*g['nu']+int(fx)
            lookup.extend(struct.pack('<4f',index,g['nu'],fx%1,fy%1));paint_pixels+=1
    image=png(width,height,pixels)
    return {'schema':1,'id':data['id'],'width':width,'height':height,'cells':offset,'paintPixels':paint_pixels,'source':'tools/assets/build_curated_maps.py','outputs':{data['id']+'_minimap.png':hashlib.sha256(image).hexdigest(),data['id']+'_minimap_lookup.bin':hashlib.sha256(lookup).hexdigest()}},image,lookup

def build(name):
    data=layout(name);surfaces=surface_data(data);nav=navigation(data,surfaces);info,image,lookup=minimap(data,surfaces)
    encode=lambda d:(json.dumps(d,separators=(',',':'))+'\n').encode()
    return {name+'.json':encode(data),name+'_surfaces.json':encode(surfaces),name+'_nav.json':encode(nav),name+'_minimap.json':encode(info),name+'_minimap.png':image,name+'_minimap_lookup.bin':bytes(lookup)}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');args=parser.parse_args()
    for name in MAPS:
        for file,data in build(name).items():
            path=ROOT/'assets/maps'/file
            if args.write:path.write_bytes(data)
            else:assert path.read_bytes()==data,file+' differs from authored source'
        print('WROTE' if args.write else 'PASS',name,flush=True)
if __name__=='__main__':main()
