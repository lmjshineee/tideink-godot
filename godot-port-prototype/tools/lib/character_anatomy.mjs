// A focused garment/topology correction for the web rig, not a replacement character.
// Reference workflow: Julien Kaspar's Snow head retopology, and Kiel Figgins'
// Painting Weights (continuous deformation cage + range-of-motion verification).
// Upstream web meshes stay read-only; all edits are made to export-local clones.
import './runtime_level.mjs';
const THREE=await import('three');
const {BONE_INDEX, HEAD_C, EYE, headSurf}=await import('../../../public/game/src/game/character-geo.js');

const V = THREE.Vector3, tau = Math.PI * 2;
const smooth = (a,b,x) => {const t=THREE.MathUtils.clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);};
const key = p => p.toArray().map(n=>Math.round(n*1e6)).join(',');

class Garment {
  constructor(source) {
    this.source=source;this.data={};this.indices=[];
    for(const [name,a] of Object.entries(source.attributes))this.data[name]={size:a.itemSize,values:[]};
  }
  get count(){return this.data.position.values.length/3;}
  copy(i){
    const id=this.count;
    for(const [name,a] of Object.entries(this.source.attributes))for(let j=0;j<a.itemSize;j++)this.data[name].values.push(a.array[i*a.itemSize+j]);
    return id;
  }
  vertex(p,part,uv,weights,colorSource=3,param=0){
    const id=this.count, si=[0,0,0,0],sw=[0,0,0,0];
    const influences=weights.filter(([,w])=>w>1e-6).sort((a,b)=>b[1]-a[1]).slice(0,4);
    const sum=influences.reduce((s,e)=>s+e[1],0);
    influences.forEach(([name,w],i)=>{si[i]=BONE_INDEX[name];sw[i]=w/sum;});
    const values={position:p.toArray(),normal:[0,0,0],uv,color:[1,1,1],aEx:[colorSource],aCloth:[part,part===1||part===2?0:1,param],skinIndex:si,skinWeight:sw};
    for(const [name,a] of Object.entries(this.data))a.values.push(...(values[name]??Array(a.size).fill(0)));
    return id;
  }
  point(i){return new V().fromArray(this.data.position.values,i*3);}
  weights(i){const names=Object.keys(BONE_INDEX);return this.data.skinWeight.values.slice(i*4,i*4+4).map((w,k)=>[names[this.data.skinIndex.values[i*4+k]],w]);}
  quad(a,b,c,d){this.indices.push(a,b,c,a,c,d);}
  // Semantic/UV seams use duplicate vertices. Smooth only the garment surfaces
  // across equal bind positions, so sleeves and chest also share their normals.
  build(){
    const normals=new Map(), ids=[];
    for(let i=0;i<this.count;i++)ids.push(key(this.point(i)));
    for(let q=0;q<this.indices.length;q+=3){
      const [a,b,c]=this.indices.slice(q,q+3),part=this.data.aCloth.values[a*3];
      if(![1,2,4,5].includes(part))continue;
      const p=this.point(a),n=this.point(b).sub(p).cross(this.point(c).sub(p));
      for(const i of [a,b,c]){if(!normals.has(ids[i]))normals.set(ids[i],new V());normals.get(ids[i]).add(n);}
    }
    for(let i=0;i<this.count;i++)if([1,2,4,5].includes(this.data.aCloth.values[i*3])){
      const n=normals.get(ids[i]);if(n)this.data.normal.values.splice(i*3,3,...n.clone().normalize().toArray());
    }
    const g=new THREE.BufferGeometry();
    for(const [name,a] of Object.entries(this.data))g.setAttribute(name,name==='skinIndex'?new THREE.Uint16BufferAttribute(a.values,a.size):new THREE.Float32BufferAttribute(a.values,a.size));
    g.setIndex(this.indices);g.computeBoundingSphere();return g;
  }
}

function correctGarments(source){
  const part=source.attributes.aCloth, tee=[];
  for(let i=0;i<part.count;i++)if(part.getX(i)===1)tee.push(i);
  const cols=41, rows=[];
  if(tee.length%cols)throw Error('Web tee grid changed: recheck armhole boundaries');
  for(let j=0;j<tee.length/cols;j++)rows.push(tee.slice(j*cols,(j+1)*cols));
  const y=j=>source.attributes.uv.getY(rows[j][10]);
  const lo=rows.findIndex((_,j)=>y(j)>=.888),hi=rows.findIndex((_,j)=>y(j)>=.975);
  if(lo<0||hi<=lo)throw Error('Missing shoulder rows');
  const local=new Map(tee.map((i,k)=>[i,[Math.floor(k/cols),k%cols]]));
  const holes=[{start:7,end:13,side:'L',sx:1},{start:27,end:33,side:'R',sx:-1}];
  const mesh=new Garment(source), mapped=new Map();
  const copy=i=>{if(!mapped.has(i))mapped.set(i,mesh.copy(i));return mapped.get(i);};
  const old=source.index.array;
  for(let q=0;q<old.length;q+=3){
    const triangle=Array.from(old.slice(q,q+3)),p=part.getX(triangle[0]);
    if([2,4,5].includes(p))continue; // remove the capped shoulder balls and sealed pelvis pouch
    if(p===1&&holes.some(h=>triangle.every(i=>{const [r,c]=local.get(i);return r>=lo&&r<=hi&&c>=h.start&&c<=h.end;})))continue;
    mesh.indices.push(...triangle.map(copy));
  }
  for(const h of holes){
    // Follow the actual armhole edge on the chest, rather than intersecting a
    // separate sphere with it. Duplicate only the UV/part seam; weights match.
    const boundary=[];
    for(let i=h.start;i<=h.end;i++)boundary.push(rows[hi][i]);
    for(let j=hi-1;j>=lo;j--)boundary.push(rows[j][h.end]);
    for(let i=h.end-1;i>=h.start;i--)boundary.push(rows[lo][i]);
    for(let j=lo+1;j<hi;j++)boundary.push(rows[j][h.start]);
    const points=boundary.map(i=>new V().fromBufferAttribute(source.attributes.position,i));
    const center=points.reduce((s,p)=>s.add(p),new V()).multiplyScalar(1/points.length);
    const sh=new V(.146*h.sx,.946,-.014), el=new V(.17*h.sx,.736,-.022);
    const axis=el.sub(sh).normalize(),lateral=new V(h.sx,0,0).addScaledVector(axis,-axis.x*h.sx).normalize();
    const forward=new V().crossVectors(axis,lateral).normalize().multiplyScalar(h.sx);
    const angles=points.map(p=>Math.atan2((p.z-center.z)/.049,(p.y-center.y)/.044));
    const bodyWeights=boundary.map(i=>mesh.weights(copy(i)));
    let previous=[];
    // The first ring is the stitched armhole. The following rings bend into
    // the upper arm, ending at the original cuff/skin position.
    const rings=[null,-.026,-.016,0,.02,.045,.07,.1,.1016,.0988,.091];
    for(let j=0;j<rings.length;j++){
      const distance=rings[j],ring=[];
      for(let i=0;i<boundary.length;i++){
        const a=angles[i],d=distance??-.035;
        const radius=(d<0?.048*Math.sqrt(1-(d/.036)**2):THREE.MathUtils.lerp(.048,.0468,d/.1))+(j===8?.0006:j===9?-.0024:j===10?-.0034:0);
        const p=distance===null?points[i].clone():sh.clone().addScaledVector(axis,d).addScaledVector(lateral,radius*Math.cos(a)).addScaledVector(forward,radius*.93*Math.sin(a));
        const w=distance===null?0:smooth(-.033,.017,d);
        const weights=bodyWeights[i].map(([n,k])=>[n,k*(1-w)]).concat([['uArm'+h.side,w]]);
        ring.push(mesh.vertex(p,2,[((a/tau)%1+1)%1,d+.035],weights,2,.135));
      }
      if(j){for(let i=0;i<ring.length;i++){
        const k=(i+1)%ring.length;
        // Oppose the existing chest boundary's winding on both armholes.
        mesh.quad(previous[k],previous[i],ring[i],ring[k]);
      }}
      previous=ring;
    }
  }
  addConnectedShorts(mesh);
  return mesh.build();
}

function addConnectedShorts(mesh){
  const n=28,half=n/2, split=[];
  // One waist loop, splitting at the groin into two leg loops. The inner halves
  // share a front-to-back saddle, not a pole closing the whole pelvis.
  const hipRing=a=>new V(.139*Math.sin(a),.622+.023*Math.sin(a)**2,-.006+.081*Math.cos(a));
  const weights=p=>{
    const upper=smooth(.70,.77,p.y),leg=smooth(.64,.535,p.y)*(1-upper);
    const side=THREE.MathUtils.clamp(.5+p.x/.035,0,1);
    return [['hips',1-upper-leg],['spine',upper],['thighL',leg*side],['thighR',leg*(1-side)]];
  };
  for(let i=0;i<n;i++)split.push(hipRing(i/n*tau));
  let previous=[];
  for(let j=0;j<=9;j++){
    const t=j/9,ring=[];
    for(let i=0;i<=n;i++){
      const a=i/n*tau,bottom=split[i%n],p=bottom.clone();
      // A modest, garment-shaped pelvis under the tee; keep its front flatter.
      p.x=THREE.MathUtils.lerp(bottom.x,.099*Math.sin(a),t);
      p.z=THREE.MathUtils.lerp(bottom.z,-.011+.072*Math.cos(a),t);
      p.y=THREE.MathUtils.lerp(bottom.y,.775,t);
      ring.push(mesh.vertex(p,4,[i/n,p.y],weights(p)));
    }
    if(j)for(let i=0;i<n;i++)mesh.quad(previous[i],previous[i+1],ring[i+1],ring[i]);
    previous=ring;
  }
  for(const [s,sx] of [['L',1],['R',-1]]){
    const hp=new V(.078*sx,.622,0),axis=new V(.003*sx,-.275,.012).normalize();
    const lateral=new V(sx,0,0).addScaledVector(axis,-axis.x*sx).normalize();
    const forward=new V(0,0,1).addScaledVector(axis,-axis.z).normalize();
    let prev=[];
    for(let j=0;j<=9;j++){
      const t=j/9,ring=[],distance=THREE.MathUtils.lerp(.018,.15,t);
      const center=hp.clone().addScaledVector(axis,distance).addScaledVector(lateral,.004);
      const radius=.0685+.0065*smooth(0,.158,distance);
      for(let i=0;i<=n;i++){
        const a=i/n*tau;
        let root;
        if(i<=half){root=hipRing(a);root.x*=sx;}
        else {root=new V(0,.622-.029*Math.sin(a)**2,-.006+.081*Math.cos(a));}
        const leg=center.clone().addScaledVector(forward,radius*.95*Math.cos(a)).addScaledVector(lateral,radius*Math.sin(a));
        const p=root.lerp(leg,smooth(0,1,t));
        // UV y remains physical bind height on the pelvis. Leg details use
        // distance down the thigh. Semantic seams occupy the same vertices.
        ring.push(mesh.vertex(p,5,[i/n,distance],weights(p),3,.158));
      }
      if(j)for(let i=0;i<n;i++){
        if(sx>0)mesh.quad(prev[i],ring[i],ring[i+1],prev[i+1]);
        else mesh.quad(prev[i+1],ring[i+1],ring[i],prev[i]);
      }
      prev=ring;
    }
  }
}

// Continuous cage for the original humanoid head and its facial anchors.
export function headPoint(p){
  const q=p.clone().sub(HEAD_C), lower=smooth(.015,-.15,q.y);
  q.x*=.9*(1-.13*lower);
  q.y=q.y*.89+.014*lower;
  q.z*=.92;
  const front=smooth(.055,.14,q.z);
  q.z-=.008*lower*front;
  q.z+=.005*front*Math.exp(-((q.x/.014)**2)-(((q.y+.014)/.012)**2));
  return q.add(HEAD_C).add(new V(0,-.039,0));
}

export function correctCharacterAnatomy(c){
  const headBones=new Set();c.bones.head.traverse(b=>{if(b.isBone)headBones.add(b);});
  const indices=new Set(c.skeleton.bones.map((b,i)=>headBones.has(b)?i:-1).filter(i=>i>=0));
  c.root.updateMatrixWorld(true);
  const oldPositions=new Map(c.skeleton.bones.map(b=>[b,b.getWorldPosition(new V())]));
  const headPositions=new Map([...headBones].map(b=>[b,headPoint(oldPositions.get(b))]));
  c.root.traverse(o=>{
    if(!o.isSkinnedMesh)return;
    const isCloth=o.material===c.mats.cloth;
    const g=isCloth?correctGarments(o.geometry):o.geometry.clone();
    const p=g.attributes.position,normal=g.attributes.normal,sw=g.attributes.skinWeight,si=g.attributes.skinIndex;
    if(o.material===c.mats.skin){
      // Strip the hidden base-body faces beneath the opaque sleeves/shorts.
      // Their different shoulder/hip weights otherwise push them through the
      // garment during arm raises or knee lifts. Keep overlap inside each cuff.
      const covered=i=>{
        const point=new V().fromBufferAttribute(p,i),influences=[];
        for(let j=0;j<4;j++)if(sw.array[i*4+j]>1e-5)influences.push(c.skeleton.bones[si.array[i*4+j]].name);
        for(const [s,sx] of [['L',1],['R',-1]]){
          if(influences.every(n=>['uArm'+s,'fArm'+s].includes(n))){
            const sh=new V(.146*sx,.946,-.014),axis=new V(.024*sx,-.210,-.008).normalize();
            if(point.clone().sub(sh).dot(axis)<.082)return true;
          }
        }
        return point.y>.495&&point.y<.70&&influences.every(n=>['hips','thighL','thighR','shinL','shinR'].includes(n));
      };
      const kept=[];
      for(let q=0;q<g.index.count;q+=3){const triangle=Array.from(g.index.array.slice(q,q+3));if(!triangle.every(covered))kept.push(...triangle);}
      g.setIndex(kept);
    }
    if(o.material===c.mats.eye){
      // Fit larger, wider eye patches to the analytic face. UVs and blink bones
      // stay intact; stretching a flat patch would make it float off the skin.
      for(let i=0;i<p.count;i++){
        const sx=g.attributes.aEx.getX(i),u=g.attributes.uv.getX(i),v=g.attributes.uv.getY(i);
        const almond=v*(1-.3*Math.abs(u));
        const angle=.16*sx,uu=u*Math.cos(angle)-almond*Math.sin(angle),vv=u*Math.sin(angle)+almond*Math.cos(angle),r=Math.hypot(u,v);
        const n=new V(),point=headSurf(sx*EYE.az+uu*EYE.daz*1.45,EYE.el+vv*EYE.del*1.12,.0026+.0036*(1-r*r),new V(),n);
        p.setXYZ(i,point.x,point.y,point.z);normal.setXYZ(i,n.x,n.y,n.z);
      }
    }
    for(let i=0;i<p.count;i++){
      let w=0;for(let j=0;j<4;j++)if(indices.has(si.array[i*4+j]))w+=sw.array[i*4+j];
      if(w<1e-6)continue;
      const old=new V().fromBufferAttribute(p,i),next=headPoint(old),n=new V().fromBufferAttribute(normal,i);
      // Inverse-transpose of the cage Jacobian keeps the existing smooth normals.
      const e=1e-5,cols=[0,1,2].map(k=>{const q=old.clone();q.setComponent(k,q.getComponent(k)+e);return headPoint(q).sub(next).divideScalar(e);});
      const matrix=new THREE.Matrix3().set(cols[0].x,cols[1].x,cols[2].x,cols[0].y,cols[1].y,cols[2].y,cols[0].z,cols[1].z,cols[2].z);
      n.lerp(n.clone().applyMatrix3(matrix.invert().transpose()).normalize(),w).normalize();
      old.lerp(next,w);p.setXYZ(i,old.x,old.y,old.z);normal.setXYZ(i,n.x,n.y,n.z);
    }
    o.geometry=g;g.computeBoundingSphere();
  });
  for(const b of headBones){
    const parent=headPositions.get(b.parent)??oldPositions.get(b.parent);
    b.position.copy(headPositions.get(b)).sub(parent);
  }
  c.root.updateMatrixWorld(true);c.skeleton.calculateInverses();
  return {shoulders:'tee armholes sewn to open sleeves with matching boundary weights',shorts:'one waist and two legs sharing a saddle-shaped crotch',head:'continuous cage for shorter lower face, tapered jaw, smaller cranium and attached face/hair anchors'};
}
