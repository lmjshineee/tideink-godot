shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 skin_color : source_color = vec4(1.,.84,.72,1.);
uniform bool clay = false;
varying vec2 face_point;
varying float front_side;

vec2 cubic(vec2 a,vec2 b,vec2 c,vec2 d,float t){float s=1.-t;return a*s*s*s+b*3.*s*s*t+c*3.*s*t*t+d*t*t*t;}
float segment(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.,1.));}
float eye_arc(vec2 p,bool upper){
    float dist=1.;
    vec2 a=vec2(.031,1.194),b=upper?vec2(.055,1.224):vec2(.058,1.173);
    vec2 c=upper?vec2(.090,1.231):vec2(.094,1.182),d=vec2(.123,1.227);
    for(int i=0;i<12;i++){float t=float(i)/12.;dist=min(dist,segment(p,cubic(a,b,c,d,t),cubic(a,b,c,d,t+1./12.)));}
    return dist;
}
float triangle(vec2 p,vec2 a,vec2 b,vec2 c){
    vec2 e0=b-a,e1=c-b,e2=a-c;vec2 v0=p-a,v1=p-b,v2=p-c;
    vec2 pq0=v0-e0*clamp(dot(v0,e0)/dot(e0,e0),0.,1.);
    vec2 pq1=v1-e1*clamp(dot(v1,e1)/dot(e1,e1),0.,1.);
    vec2 pq2=v2-e2*clamp(dot(v2,e2)/dot(e2,e2),0.,1.);
    float s=sign(e0.x*e2.y-e0.y*e2.x);
    vec2 d=min(min(vec2(dot(pq0,pq0),s*(v0.x*e0.y-v0.y*e0.x)),vec2(dot(pq1,pq1),s*(v1.x*e1.y-v1.y*e1.x))),vec2(dot(pq2,pq2),s*(v2.x*e2.y-v2.y*e2.x)));
    return -sqrt(d.x)*sign(d.y);
}
void vertex(){face_point=vec2(UV.x,1.-UV.y);front_side=VERTEX.z;}
void fragment(){
    vec3 col=skin_color.rgb;
    vec2 p=vec2(abs(face_point.x)/.88,face_point.y);
    if(front_side>.060 && !clay){
        float upper=1.-smoothstep(.0029,.0048,eye_arc(p,true));
        float lower=1.-smoothstep(.0015,.0032,eye_arc(p,false));
        float outer=1.-smoothstep(.0033,.0048,segment(p,vec2(.122,1.207),vec2(.137,1.210)));
        outer=max(outer,1.-smoothstep(.0055,.0065,length(p-vec2(.137,1.210))));
        float drop=1.-smoothstep(.0045,.0055,length(p-vec2(.132,1.188)));
        drop=max(drop,1.-smoothstep(.0025,.0040,segment(p,vec2(.119,1.195),vec2(.132,1.188))));
        col=mix(col,vec3(.009,.014,.022),max(max(upper,lower),max(outer,drop)));
        float cheek=exp(-pow((p.x-.110)/.039,2.)-pow((p.y-1.140)/.029,2.));
        col=mix(col,col*vec3(1.,.88,.86),cheek*.13);
        // Short, symmetric closed mouth, with a softly tapered seam and lip tint.
        float x=face_point.x;
        float mouth_y=1.105+.0035*pow(x/.032,2.);
        float ends=1.-smoothstep(.025,.033,abs(x));
        float seam=(1.-smoothstep(.00055,.00165,abs(face_point.y-mouth_y)))*ends;
        float lip=exp(-pow(x/.027,4.)-pow((face_point.y-(mouth_y-.0028))/.0029,2.));
        col=mix(col,col*vec3(.94,.86,.84),lip*.30);
        col=mix(col,skin_color.rgb*vec3(.52,.37,.34),seam*.83);
    }
    ALBEDO=clay?vec3(.46,.49,.51):col;ROUGHNESS=.78;SPECULAR=.21;
}
void light(){float wrapped=clamp((dot(NORMAL,LIGHT)+.30)/1.30,0.,1.);DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*wrapped/3.14159265;}
