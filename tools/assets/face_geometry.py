"""Bind-space facial sculpture. Upper skull/rig stay fixed for the authored hair.

The jaw silhouettes are designed separately from the five facial planes. Eyes
are conformed to the same surface, rather than translated onto a sphere. Source
direction UVs, cheek/jaw weights and expression anchors remain intact.
"""
import math

FACES = {
    # width at jaw/cheek/temple, chin lift, bridge/tip, cheek plane, eye height
    'reef_runner': ((.62,.68,.78,.88,.96,1.), .020,.011,.022,.006,.70),
    'fin_drifter': ((.52,.57,.72,.94,1.02,1.), .023,.010,.020,.009,.75),
    'dock_worker': ((1.13,1.05,.93,.92,.95,1.), .022,.013,.025,.004,.57),
    'spark_writer': ((.72,.71,.76,.84,.91,1.), .011,.012,.023,.005,.65),
}
LEVELS = (1.042,1.070,1.100,1.140,1.185,1.245)

def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)));return t*t*(3-2*t)

def gaussian(x,y,cx,cy,wx,wy):
    return math.exp(-((x-cx)/wx)**2-((y-cy)/wy)**2)

def width_at(y,profile):
    widths=FACES[profile[0]][0]
    slopes=[(widths[i+1]-widths[i])/(LEVELS[i+1]-LEVELS[i]) for i in range(5)]
    tangents=[0.]+[(0. if slopes[i-1]*slopes[i]<=0 else 2*slopes[i-1]*slopes[i]/(slopes[i-1]+slopes[i])) for i in range(1,5)]+[0.]
    for i in range(len(LEVELS)-1):
        if y<LEVELS[i+1]:
            h=LEVELS[i+1]-LEVELS[i];t=max(0.,(y-LEVELS[i])/h)
            return (2*t**3-3*t*t+1)*widths[i]+(t**3-2*t*t+t)*h*tangents[i]+(-2*t**3+3*t*t)*widths[i+1]+(t**3-t*t)*h*tangents[i+1]
    return widths[-1]

def face_y(y,profile):
    lift=FACES[profile[0]][1]
    return 1.17+(y-1.17)*profile[4]-.025+lift*(1-smooth(1.035,1.170,y))

def front_depth(x,y,profile):
    """Continuous facial surface before the profile's global head fit."""
    _,_,bridge,tip,cheek,_=FACES[profile[0]]
    ax=abs(x)
    # Flatter midface; lower jaw recedes behind a distinct forward chin pad.
    z=.156*math.sqrt(max(.001,1-(x/.169)**2-((y-1.180)/.151)**2))+.003
    z-=.004*(1-smooth(1.075,1.150,y))
    z+=cheek*gaussian(ax,y,.085,1.156,.042,.025)
    z-=.010*gaussian(ax,y,.054,1.197,.033,.022) # orbital recess
    z+=.006*gaussian(ax,y,.055,1.228,.042,.012) # supraorbital plane
    z+=bridge*gaussian(x,y,0,1.190,.018,.038)
    z+=tip*gaussian(x,y,0,1.163,.017,.016)
    z+=.009*gaussian(ax,y,.019,1.157,.010,.010) # nose wings
    z-=.003*gaussian(ax,y,.012,1.151,.005,.005) # nostril turn
    z+=.0035*gaussian(x,y,0,1.125,.034,.026) # soft muzzle / lips
    z-=.001*gaussian(x,y,0,1.099,.032,.018) # labiomental turn
    z+=.006*gaussian(x,y,0,1.075,.037,.034) # broad chin transition
    return z

def sculpt(p,profile):
    x,y,z=p
    front=smooth(.025,.105,z)
    width=width_at(y,profile)
    qx=x*width*profile[3]
    # Lift the chin, not the nape hidden under the fitted scalp.
    qy=1.17+(y-1.17)*profile[4]-.025+FACES[profile[0]][1]*(1-smooth(1.035,1.170,y))*smooth(-.030,.100,z)
    # Preserve the back skull and blend around the temples; no seam at the ears.
    qz=(z*(1-front)+front_depth(x,y,profile)*front)*.925
    return [qx,qy,qz]

def eye_point(p,uv,profile):
    side=1 if p[0]>0 else -1
    u,v=uv
    # Almond contour with a lifted outer corner. The lower lid has less volume.
    cx=side*.055
    x=cx+u*.035
    height=FACES[profile[0]][5]*.036
    y=1.197+v*height*(1-.22*abs(u))+(side*u)*.003
    return [x*width_at(y,profile)*profile[3],face_y(y,profile),
            (front_depth(x,y,profile)+.0022+.0018*(1-u*u-v*v))*.925]

def eye_normal(p,uv,profile):
    e=.0001;u,v=uv
    a=eye_point(p,(u+e,v),profile);b=eye_point(p,(u-e,v),profile)
    c=eye_point(p,(u,v+e),profile);d=eye_point(p,(u,v-e),profile)
    x=[a[k]-b[k] for k in range(3)];y=[c[k]-d[k] for k in range(3)]
    n=[x[1]*y[2]-x[2]*y[1],x[2]*y[0]-x[0]*y[2],x[0]*y[1]-x[1]*y[0]]
    length=math.sqrt(sum(k*k for k in n));return [k/length for k in n]

def brow_point(p,profile):
    # Sculpted brow sits above the eye, with a thinner tail and smaller arch.
    side=1 if p[0]>0 else -1
    x=side*.055+(p[0]-side*.051)*.92
    y=1.231+(p[1]-1.248)*.62
    return [x*width_at(y,profile)*profile[3],face_y(y,profile),
            (front_depth(x,y,profile)+.003+(p[2]-.140)*.45)*.925]
