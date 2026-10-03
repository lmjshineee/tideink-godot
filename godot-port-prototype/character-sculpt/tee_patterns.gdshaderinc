// Eight original streetwear prints, evaluated in preserved body bind space.
uniform int tee_design = 0;
uniform vec4 graphic_color : source_color;
uniform vec4 panel_color : source_color;
uniform vec4 trim_color : source_color;

float teeStroke(float d,float w){float aa=max(fwidth(d),.0003);return 1.-smoothstep(w-aa,w+aa,abs(d));}
float teeDisk(vec2 q,float r){float aa=max(fwidth(length(q)),.001);return 1.-smoothstep(r-aa,r+aa,length(q));}
float teeRect(vec2 q,vec2 b){return iwFill(iwSdBox(q,b,.04));}
vec3 teeBody(vec3 p){
    vec3 color=shirt_color.rgb;
    float panel=0.;
    if(tee_design==1){panel=smoothstep(.905,.910,p.y-.43*p.x);}
    else if(tee_design==2){panel=iwBand(abs(p.x),.047,.071);}
    else if(tee_design==3){
        float checker=mod(floor((p.x+.13)/.019)+floor(p.y/.019),2.);
        panel=checker*iwBand(p.y,.810,.852);
    }else if(tee_design==4){panel=iwBand(p.y-.29*p.x,.735,.764);}
    else if(tee_design==5){panel=iwBand(p.y+.6*p.x,.903,.917);}
    else if(tee_design==6){panel=iwBand(p.y,.730,.756)+iwBand(p.y,.761,.771);}
    else if(tee_design==7){panel=smoothstep(.088,.095,abs(p.x));}
    color=mix(color,panel_color.rgb,clamp(panel,0.,1.));
    if(p.z<=0.){
        float tag=iwFill(iwSdBox(vec2(p.x,p.y-.766),vec2(.047,.006),.002));
        color=mix(color,graphic_color.rgb,tag);
        return color;
    }
    vec2 q=vec2(p.x,p.y-.833)/.063;
    float ink=0.,detail=0.;
    if(tee_design==0){
        for(int i=0;i<3;i++){
            float y=.16*sin(q.x*3.5+float(i)*.5)+(float(i)-1.)*.25;
            ink=max(ink,teeStroke(q.y-y,.055));
        }
        ink*=1.-smoothstep(.86,.93,abs(q.x));
        detail=teeDisk(q-vec2(.68,.55),.10);
    }else if(tee_design==1){
        vec2 r=vec2(q.x+q.y,q.y-q.x)*.7071;
        ink=teeStroke(iwSdBox(r,vec2(.41,.41),.065),.053);
        detail=teeRect(q-vec2(0.,-.60),vec2(.48,.055));
        ink=max(ink,teeStroke(iwSdSeg(q,vec2(-.19,-.11),vec2(.18,.25)),.05));
    }else if(tee_design==2){
        vec2 left=q-vec2(-.33,0.);
        ink=teeStroke((length(left/vec2(.24,.48))-1.)*.24,.055);
        vec2 right=q-vec2(.32,0.);
        ink=max(ink,teeStroke(length(right-vec2(0.,.22))-.23,.052));
        ink=max(ink,teeStroke(length(right-vec2(0.,-.22))-.23,.052));
        detail=teeRect(q-vec2(0.,-.69),vec2(.66,.04));
    }else if(tee_design==3){
        vec2 small=vec2(p.x,p.y-.781)/.032;
        ink=teeStroke(abs(small.x)+abs(small.y)-.62,.09);
        detail=teeDisk(small,.12);
    }else if(tee_design==4){
        float a=atan(q.y,q.x),r=.49+.065*sin(5.*a+.4)+.035*sin(9.*a);
        ink=1.-smoothstep(r-.025,r+.025,length(q));
        ink=max(ink,teeDisk(q-vec2(.61,.34),.095));
        ink=max(ink,teeDisk(q-vec2(-.59,-.40),.07));
        detail=teeStroke(iwSdSeg(q,vec2(-.16,-.22),vec2(.13,.23)),.065)*ink;
        detail=max(detail,teeStroke(iwSdSeg(q,vec2(.13,.23),vec2(.02,-.01)),.06)*ink);
    }else if(tee_design==5){
        ink=teeStroke(iwSdSeg(q,vec2(.24,.55),vec2(-.20,.02)),.105);
        ink=max(ink,teeStroke(iwSdSeg(q,vec2(-.20,.02),vec2(.19,-.02)),.105));
        ink=max(ink,teeStroke(iwSdSeg(q,vec2(.19,-.02),vec2(-.25,-.55)),.105));
        detail=teeRect(q-vec2(.61,-.51),vec2(.15,.055));
    }else if(tee_design==6){
        ink=teeStroke(length(q-vec2(0.,.22))-.42,.058)*smoothstep(-.12,-.08,q.y);
        for(int i=0;i<3;i++){
            float y=-.12-float(i)*.18+.045*sin(q.x*4.);
            detail=max(detail,teeStroke(q.y-y,.045)*(1.-smoothstep(.62,.70,abs(q.x))));
        }
    }else{
        ink=teeStroke((length(q/vec2(.68,.32))-1.)*.32,.047);
        ink=max(ink,teeStroke(iwSdSeg(q,vec2(-.52,-.52),vec2(.53,.52)),.035));
        detail=teeDisk(q-vec2(.36,.20),.12);
        ink=max(ink,teeStroke(length(q)-.44,.035));
    }
    color=mix(color,graphic_color.rgb,clamp(ink,0.,1.));
    color=mix(color,trim_color.rgb,clamp(detail,0.,1.));
    // Discrete woven label at the side of the hem.
    float label=iwFill(iwSdBox(vec2(p.x-.091,p.y-.745),vec2(.009,.012),.0015));
    return mix(color,graphic_color.rgb,label);
}
vec3 teeSleeve(vec3 p,vec2 uv,float length_s){
    vec3 color=shirt_color.rgb;
    if(tee_design==1 || tee_design==2 || tee_design==5)color=panel_color.rgb;
    else if(tee_design==4 && p.x<0.)color=panel_color.rgb;
    else if(tee_design==7)color=mix(color,panel_color.rgb,.35);
    float cuff=smoothstep(length_s-.017,length_s-.014,uv.y);
    color=mix(color,trim_color.rgb,cuff);
    if(tee_design==2 || tee_design==6){
        float stripe=iwBand(uv.y,length_s-.036,length_s-.028);
        color=mix(color,graphic_color.rgb,stripe);
    }
    return color;
}
