"""Original non-tentacle hair locks for the preserved local head joint.
Each style has authored centre lines, tapered elliptical sections and smooth
normals. Source eyebrows/accessories remain; scalp, strand and cup triangles are replaced.
"""
import math,struct,bisect

STYLES=('swept_crop','soft_bob','cloud_curls','tied_waves')
def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)));return t*t*(3-2*t)

def replace_hair(doc,binary,profile,rows):
    primitive=next(p for m in doc['meshes'] for p in m['primitives'] if doc['materials'][p['material']]['name']=='TeamHair' and 'JOINTS_0' in p['attributes'])
    names=[doc['nodes'][n]['name'] for n in doc['skins'][0]['joints']]
    head=names.index('head')
    values={name:list(rows(doc,binary,index)[0]) for name,index in primitive['attributes'].items()}
    old_indices=[row[0] for row in rows(doc,binary,primitive['indices'])[0]]
    strand={i for i,(js,ws) in enumerate(zip(values['JOINTS_0'],values['WEIGHTS_0'])) if any(names[j].startswith('hair') and w>.005 for j,w in zip(js,ws))}
    scalp={i for i,uv in enumerate(values['TEXCOORD_1']) if uv[1]>=1.5}
    removed=strand|scalp
    kept=[old_indices[i:i+3] for i in range(0,len(old_indices),3) if not any(v in removed for v in old_indices[i:i+3])]
    used=sorted({v for face in kept for v in face});mapping={v:i for i,v in enumerate(used)}
    values={name:[vs[v] for v in used] for name,vs in values.items()}
    indices=[mapping[v] for face in kept for v in face]
    # The complete source head grid survives even where its triangles were cut
    # for the old haircut. Fit to these NOW SCULPTED points, not a second, larger
    # ellipsoid that can cut through the temples or leave a stepped nape edge.
    skin=next(p for m in doc['meshes'] for p in m['primitives'] if doc['materials'][p['material']]['name']=='Skin' and 'JOINTS_0' in p['attributes'])
    ps=rows(doc,binary,skin['attributes']['POSITION'])[0]
    uv=rows(doc,binary,skin['attributes']['TEXCOORD_0'])[0]
    uv2=rows(doc,binary,skin['attributes']['TEXCOORD_1'])[0]
    grid={}
    for p,(dx,dy),(dz,tag) in zip(ps,uv,uv2):
        if p[1]>1.0 and dx*dx+dy*dy+dz*dz>.5:
            grid[(round(math.asin(max(-1.,min(1.,dy))),4),round(math.atan2(dx,dz),4))]=p
    els=sorted({k[0] for k in grid});azs=sorted({k[1] for k in grid})
    # Source +pi/-pi seam shares one float direction. Recreate its second UV
    # endpoint before interpolating, so the back scalp closes without a crack.
    if azs[0]>-3.14 and azs[-1]>3.14:
        for el in els:grid[(el,-azs[-1])]=grid[(el,azs[-1])]
        azs=sorted({k[1] for k in grid})
    assert len(grid)==len(els)*len(azs) and len(grid)>5000,'complete local head grid required'
    def surface(az,el):
        y=max(els[0],min(els[-1],el));x=max(azs[0],min(azs[-1],az))
        j=max(0,min(len(els)-2,bisect.bisect_right(els,y)-1));i=max(0,min(len(azs)-2,bisect.bisect_right(azs,x)-1))
        u=(x-azs[i])/(azs[i+1]-azs[i]);v=(y-els[j])/(els[j+1]-els[j])
        p=[sum(grid[(els[j+b],azs[i+a])][k]*([1-u,u][a])*([1-v,v][b]) for a in range(2) for b in range(2)) for k in range(3)]
        if el>els[-1]:
            center=[sum(grid[(els[-1],a)][k] for a in azs)/len(azs) for k in range(3)]
            f=max(0.,math.cos(el)/math.cos(els[-1]))
            p=[center[k]+(p[k]-center[k])*f for k in range(3)];p[1]+=.001*(1-f)
        return p
    def surface_normal(az,el):
        e=.001;a=surface(min(math.pi,az+e),el);b=surface(max(-math.pi,az-e),el)
        c=surface(az,min(math.pi/2-.0001,el+e));d=surface(az,el-e)
        u=[a[k]-b[k] for k in range(3)];v=[c[k]-d[k] for k in range(3)]
        n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        length=math.sqrt(sum(k*k for k in n))
        return [k/length for k in n] if length>1e-12 else [0.,1.,0.]
    def root_point(p):
        d=[p[0]/.163,(p[1]-1.18)/.145,p[2]/.150];length=math.sqrt(sum(k*k for k in d));d=[k/length for k in d]
        az=math.atan2(d[0],d[2]);el=math.asin(d[1]);q=surface(az,el);n=surface_normal(az,el)
        q=[q[k]+n[k]*.001 for k in range(3)]
        return [q[0]/profile[3],1.17+(q[1]+.025-1.17)/profile[4],q[2]/.925]
    def vertex(p,n,u,v,kind=3.,color=(.85,.75,.6,0.),fit=True):
        # New geometry uses exactly the same head-space fit as the face.
        if fit:
            p=(p[0]*profile[3],1.17+(p[1]-1.17)*profile[4]-.025,p[2]*.925)
            n=(n[0]/profile[3],n[1]/profile[4],n[2]/.925)
        length=math.sqrt(sum(k*k for k in n));n=tuple(k/length for k in n)
        index=len(values['POSITION'])
        for name,vs in values.items():
            template={'POSITION':p,'NORMAL':n,'TEXCOORD_0':(u,v),'TEXCOORD_1':((-4.,0.) if kind==0 else (0.,kind)),'COLOR_0':color,'JOINTS_0':(head,0,0,0),'WEIGHTS_0':(1.,0.,0.,0.)}
            vs.append(template.get(name,tuple(0. for _ in vs[0])))
        return index
    def lock(points,width,depth,curve=None):
        # Parallel transport avoids the old reference-axis flip through a curl.
        # True surface normals include taper/curvature. Both poles are closed.
        count=24;sides=20;start=len(values['POSITION'])
        if curve is None:points=[root_point(points[0]),*points[1:]]
        def center(t):
            if curve is not None:return curve(t)
            return [sum(points[j][k]*[ (1-t)**3,3*(1-t)**2*t,3*(1-t)*t*t,t**3 ][j] for j in range(4)) for k in range(3)]
        dot=lambda a,b:sum(x*y for x,y in zip(a,b))
        cross=lambda a,b:[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
        unit=lambda a:[x/math.sqrt(dot(a,a)) for x in a]
        prev_side=None;local=[]
        for ring in range(count+1):
            t=ring/count;p=center(t);a=center(max(0,t-.001));b=center(min(1,t+.001))
            tangent=[b[k]-a[k] for k in range(3)];length=math.sqrt(sum(x*x for x in tangent));tangent=[x/length for x in tangent]
            if prev_side is None:
                ref=[0,0,1] if abs(tangent[2])<.85 else [0,1,0]
                side=unit(cross(tangent,ref))
            else:
                side=unit([prev_side[k]-tangent[k]*dot(prev_side,tangent) for k in range(3)])
            prev_side=side;up=cross(tangent,side)
            taper=max(.008,(math.sin(math.pi*t)**.46)*(1-.35*t))
            for segment in range(sides):
                angle=segment*2*math.pi/sides;c=math.cos(angle);s=math.sin(angle)
                q=[p[k]+taper*(side[k]*c*width+up[k]*s*depth) for k in range(3)]
                local.append(q)
                n=unit([side[k]*c/width+up[k]*s/depth for k in range(3)])
                vertex(q,n,segment/sides,t)
        for ring in range(count):
            for segment in range(sides):
                a=start+ring*sides+segment;b=start+ring*sides+(segment+1)%sides;c=a+sides;d=b+sides
                indices.extend([a,b,c,b,d,c])
        # Tiny polar rings are sealed, without an exposed flat fan-cut end.
        for ring in (0,count):
            base=start+ring*sides;normal=unit([center(.001)[k]-center(0.)[k] for k in range(3)] if ring==0 else [center(1.)[k]-center(.999)[k] for k in range(3)])
            if ring==0:normal=[-k for k in normal]
            pole=vertex(center(ring/count),normal,.5,ring/count)
            for segment in range(sides):
                a=base+segment;b=base+(segment+1)%sides
                indices.extend([pole,b,a] if ring==0 else [pole,a,b])
        # Finite differences of the actual swept surface include shrinking tips.
        for ring in range(count+1):
            for segment in range(sides):
                a=local[ring*sides+(segment+1)%sides];b=local[ring*sides+(segment-1)%sides]
                c=local[min(count,ring+1)*sides+segment];d=local[max(0,ring-1)*sides+segment]
                n=unit(cross([a[k]-b[k] for k in range(3)],[c[k]-d[k] for k in range(3)]))
                n=unit([n[0]/profile[3],n[1]/profile[4],n[2]/.925])
                values['NORMAL'][start+ring*sides+segment]=tuple(n)
    # One authored scalp shell meets the roots of the new locks. The old scalp
    # mesh and skin-painted hairline are gone, so there is no second hairstyle.
    start=len(values['POSITION']);columns=64;rings=24
    for j in range(rings+1):
        for i in range(columns+1):
            az=(i/columns-.5)*2*math.pi;a=abs(az)/math.pi
            # Follow the source skin's actual hairline, including its low nape.
            # Extra crown volume blends in above it, rather than raising the
            # whole scalp and exposing the clipped skin edge underneath.
            edge=.58-.28*smooth(.10,.42,a)-1.10*smooth(.50,.96,a)+.012*math.sin(az*13)
            el=edge+(math.pi/2-edge)*j/rings
            n=surface_normal(az,min(el,math.pi/2-.0001));p=surface(az,el)
            p=[p[k]+n[k]*.0045 for k in range(3)]
            vertex(p,n,i/columns,j/rings,4.,fit=False)
    # The source grid's two seam derivatives differ slightly. Weld the final
    # offset surface as well as its normals, rather than leaving a 0.6mm crack.
    for j in range(rings+1):
        a=start+j*(columns+1);b=a+columns
        p=tuple((values['POSITION'][a][k]+values['POSITION'][b][k])*.5 for k in range(3))
        n=[values['NORMAL'][a][k]+values['NORMAL'][b][k] for k in range(3)];length=math.sqrt(sum(k*k for k in n));n=tuple(k/length for k in n)
        values['POSITION'][a]=p;values['POSITION'][b]=p;values['NORMAL'][a]=n;values['NORMAL'][b]=n
    pole=start+rings*(columns+1)
    top=tuple(sum(values['POSITION'][pole+i][k] for i in range(columns))/columns for k in range(3))
    for i in range(columns+1):values['POSITION'][pole+i]=top;values['NORMAL'][pole+i]=(0.,1.,0.)
    for j in range(rings):
        for i in range(columns):
            a=start+j*(columns+1)+i;b=a+1;c=a+columns+1;d=c+1
            indices.extend([a,b,c,b,d,c])
    style=profile[0]
    # Front sweep, distinct silhouette from the retained fitted scalp.
    if style=='reef_runner':
        for i in range(7):
            x=-.12+i*.036
            end_y=1.242+.012*math.sin(i*1.7)
            lock([(x-.025,1.315,-.035),(x+.024,1.345,.025),(x+.058,1.295,.12),(x+.040,end_y-.012,.143)],.034,.013)
        for sign in (-1,1):
            lock([(sign*.12,1.28,-.02),(sign*.15,1.29,-.005),(sign*.16,1.23,.015),(sign*.137,1.18,.045)],.024,.014)
        for i in range(7):
            x=-.12+i*.04
            lock([(x*.5,1.32,-.08),(x,1.28,-.14),(x,1.13,-.16),(x*.80,1.070+.01*math.sin(i*2),-.110)],.026,.016)
        for i in range(3):
            x=-.07+i*.07
            lock([(x,1.325,-.01),(x+.020,1.348,-.065),(x+.025,1.285,-.13),(x+.012,1.16,-.141)],.038,.012)
    elif style=='fin_drifter':
        # A real crown part fans into the side layers, covering the formerly
        # flat disk between their roots without introducing another scalp.
        for sign in (-1,1):
            for i in range(6):
                z=-.10+i*.040
                lock([(-.009,1.327,z*.35),(sign*.045,1.349,z*.55),(sign*.110,1.316,z),(sign*.149,1.246,z+.008)],.031,.013)
        for sign in (-1,1):
            for i in range(6):
                z=.095-i*.039
                lock([(sign*.075,1.32,z*.3),(sign*.17,1.31,z),(sign*.177,1.09,z),(sign*.130,1.035+.008*math.sin(i*1.8),z+.025)],.043,.021)
        for i in range(5):
            x=-.105+i*.047
            lock([(x,1.32,.035),(x-.018,1.34,.12),(x-.015,1.265,.154),(x-.005,1.236+.009*math.sin(i*1.9),.147)],.030,.017)
        for i in range(9):
            x=-.13+i*.0325
            lock([(x*.60,1.31,-.07),(x,1.30,-.155),(x,1.11,-.177),(x*.85,1.055,-.128)],.032,.021)
    elif style=='dock_worker':
        # Each curl grows along the local scalp normal, including the temples
        # and forehead. Angular rows cover the fitted shell rather than leaving
        # a broad, flat band beneath a handful of curls on top.
        for row in range(9):
            count=[30,30,28,26,22,18,14,10,5][row]
            for i in range(count):
                angle=(i/count)*2*math.pi+row*.32
                az=(angle+math.pi)%(2*math.pi)-math.pi;a=abs(az)/math.pi
                edge=.58-.28*smooth(.10,.42,a)-1.10*smooth(.50,.96,a)+.012*math.sin(az*13)
                fraction=[.055,.14,.25,.36,.48,.60,.72,.84,.95][row]+.008*math.sin(i*1.97+row*2.3)
                el=edge+(math.pi/2-edge)*fraction
                p=surface(az,el);n=surface_normal(az,el)
                p=[p[k]+n[k]*.001 for k in range(3)]
                p=[p[0]/profile[3],1.17+(p[1]+.025-1.17)/profile[4],p[2]/.925]
                n=[n[0]/profile[3],n[1]/profile[4],n[2]/.925]
                length=math.sqrt(sum(k*k for k in n));n=[k/length for k in n]
                tangent=[math.cos(az),0.,-math.sin(az)]
                projection=sum(tangent[k]*n[k] for k in range(3))
                tangent=[tangent[k]-n[k]*projection for k in range(3)]
                length=math.sqrt(sum(k*k for k in tangent));tangent=[k/length for k in tangent]
                side=[n[1]*tangent[2]-n[2]*tangent[1],n[2]*tangent[0]-n[0]*tangent[2],n[0]*tangent[1]-n[1]*tangent[0]]
                twist=.40*math.sin(i*2.27+row*1.7)
                tangent=[tangent[k]*math.cos(twist)+side[k]*math.sin(twist) for k in range(3)]
                def coil(t,p=p,n=n,tangent=tangent,i=i):
                    phi=t*math.pi*(1.78+.08*math.sin(i));radius=.020+.0015*math.sin(i*2.3)
                    return [p[k]+tangent[k]*radius*math.sin(phi)+n[k]*radius*(1-math.cos(phi))*.9 for k in range(3)]
                lock(None,.017*(.96+.04*math.sin(i*.97+row*1.41)),.014,coil)
    else:
        for i in range(7):
            x=-.12+i*.04
            lock([(x,1.29,.10),(x+.04,1.38,.12),(x+.085,1.34,-.08),(x*.40,1.29,-.15)],.037,.020)
        for i in range(5):
            angle=i*2*math.pi/5;x=math.sin(angle)*.048;y=1.31+math.cos(angle)*.037
            lock([(x,y,-.13),(x*1.3,y+.01,-.23),(x*1.8,y-.12,-.25),(x*.7,y-.20,-.16)],.039,.029)
        lock([(-.105,1.31,.05),(-.15,1.27,.17),(-.12,1.22,.18),(-.06,1.205,.145)],.041,.018)
        # A visible cloth tie connects the gathered waves to the ponytail.
        start=len(values['POSITION']);major=40;minor=12
        for i in range(major):
            a=i*2*math.pi/major
            for j in range(minor):
                b=j*2*math.pi/minor;r=.048+.007*math.cos(b)
                vertex((math.sin(a)*r,1.30+math.cos(a)*r,-.170+.007*math.sin(b)),(math.sin(a)*math.cos(b),math.cos(a)*math.cos(b),math.sin(b)),i/major,j/minor,0.,(.10,.17,.22,0.))
        for i in range(major):
            for j in range(minor):
                a=start+i*minor+j;b=start+i*minor+(j+1)%minor;c=start+((i+1)%major)*minor+j;d=start+((i+1)%major)*minor+(j+1)%minor
                indices.extend([a,b,c,b,d,c])
    for name,index in primitive['attributes'].items():
        old,fmt=rows(doc,binary,index);store(doc,binary,index,values[name],fmt)
    old,fmt=rows(doc,binary,primitive['indices']);store(doc,binary,primitive['indices'],[(v,) for v in indices],fmt)
    doc['buffers'][0]['byteLength']=len(binary)
    return {'style':STYLES[['reef_runner','fin_drifter','dock_worker','spark_writer'].index(style)],'method':'parallel-transport groom; closed tapered poles; surface-derived normals; one scalp fitted to sculpted head','triangles':len(indices)//3,'removed_strand_vertices':len(strand),'removed_scalp_vertices':len(scalp),'head_joint':head,'scalp_grid_points':len(grid)}

def store(doc,binary,index,values,fmt):
    while len(binary)%4:binary.append(0)
    start=len(binary);raw=b''.join(struct.pack(fmt,*row) for row in values);binary.extend(raw)
    doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(raw)})
    a=doc['accessors'][index];a['bufferView']=len(doc['bufferViews'])-1;a['byteOffset']=0;a['count']=len(values)
    if a['type']=='VEC3' and 'min' in a:
        a['min']=[min(p[k] for p in values) for k in range(3)];a['max']=[max(p[k] for p in values) for k in range(3)]
