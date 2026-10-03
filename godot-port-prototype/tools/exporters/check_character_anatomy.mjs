// Geometric regression: actual connected garments and seam deformation,
// including imported/exported skinning conventions rather than parameter tests.
import '../lib/runtime_level.mjs';
import '../lib/character_quality.mjs';
import {correctCharacterAnatomy} from '../lib/character_anatomy.mjs';
const THREE=await import('three');
const {Character}=await import('../../../public/game/src/game/character.js');
const key=p=>p.toArray().map(n=>Math.round(n*1e6)).join(',');
const assert=(condition,message)=>{if(!condition)throw Error(message);};
function topology(g,parts){
  const positions=g.attributes.position,part=g.attributes.aCloth,edges=new Map(),faces=[],vertices=new Map();
  const point=i=>new THREE.Vector3().fromBufferAttribute(positions,i);
  for(let q=0;q<g.index.count;q+=3){
    const ids=Array.from(g.index.array.slice(q,q+3));
    if(!ids.every(i=>parts.includes(part.getX(i))))continue;
    const keys=ids.map(i=>key(point(i)));
    assert(new THREE.Vector3().subVectors(point(ids[1]),point(ids[0])).cross(new THREE.Vector3().subVectors(point(ids[2]),point(ids[0]))).length()>1e-10,'Degenerate garment triangle');
    faces.push(keys);
    for(let j=0;j<3;j++){
      const a=keys[j],b=keys[(j+1)%3],k=[a,b].sort().join('|');
      if(!edges.has(k))edges.set(k,[]);edges.get(k).push([a,b]);
      if(!vertices.has(a))vertices.set(a,[]);vertices.get(a).push(ids[j]);
    }
  }
  const adjacency=new Map(),boundaries=new Map();
  for(const occurrences of edges.values()){
    assert(occurrences.length<=2,'Garment has a non-manifold edge');
    const [a,b]=occurrences[0];
    for(const [x,y] of [[a,b],[b,a]]){if(!adjacency.has(x))adjacency.set(x,new Set());adjacency.get(x).add(y);}
    if(occurrences.length===2)assert(occurrences[1][0]===b&&occurrences[1][1]===a,'Adjacent garment faces have inconsistent winding');
    else for(const [x,y] of [[a,b],[b,a]]){if(!boundaries.has(x))boundaries.set(x,new Set());boundaries.get(x).add(y);}
  }
  const components=map=>{const seen=new Set();let count=0;for(const first of map.keys())if(!seen.has(first)){count++;const queue=[first];while(queue.length){const v=queue.pop();if(seen.has(v))continue;seen.add(v);for(const n of map.get(v)??[])queue.push(n);}}return count;};
  assert(components(adjacency)===1,'Garment has disconnected body/limb pieces');
  for(const neighbors of boundaries.values())assert(neighbors.size===2,'Unsewn garment seam or branched boundary');
  return {loops:components(boundaries),vertices};
}
for(let style=0;style<4;style++){
  const c=new Character({style:{hair:style,skin:style,outfit:style,eyes:style}});
  correctCharacterAnatomy(c);
  const mesh=[];c.root.traverse(o=>{if(o.isSkinnedMesh&&o.material===c.mats.cloth)mesh.push(o);});
  assert(mesh.length===1,'Expected one cloth mesh');const g=mesh[0].geometry;
  const shirt=topology(g,[1,2]),pants=topology(g,[4,5]);
  assert(shirt.loops===4,'Shirt must have one neck, one hem and two sleeve openings');
  assert(pants.loops===3,'Shorts must have one waist and two leg openings');
  for(const group of [...shirt.vertices.values(),...pants.vertices.values()]){
    const i=group[0],weights=new Map();
    for(let k=0;k<4;k++)weights.set(g.attributes.skinIndex.getComponent(i,k),(weights.get(g.attributes.skinIndex.getComponent(i,k))??0)+g.attributes.skinWeight.getComponent(i,k));
    for(const j of group)for(let k=0;k<4;k++){
      const bone=g.attributes.skinIndex.getComponent(j,k),weight=g.attributes.skinWeight.getComponent(j,k);
      if(weight>1e-6)assert(Math.abs((weights.get(bone)??0)-weight)<1e-5,'Stitched seam separates under skinning');
    }
  }
  for(const mode of ['idle','run','focus','jump','throw']){
    const state={form:'kid',grounded:mode!=='jump',speed:mode==='run'?6:0,localMove:{x:0,z:mode==='run'?1:0},firing:mode==='focus',aimPitch:.65,hp:1,ink:1};
    if(mode==='jump'||mode==='throw')c.trigger(mode);
    for(let i=0;i<45;i++)c.update(1/30,state);
    c.root.updateMatrixWorld(true);c.skeleton.update();
    for(let i=0;i<g.attributes.position.count;i+=7){
      const p=mesh[0].applyBoneTransform(i,new THREE.Vector3().fromBufferAttribute(g.attributes.position,i));
      assert(p.toArray().every(Number.isFinite),'Nonfinite animated garment vertex');
    }
  }
}
console.log('OK: four styles; manifold connected shirt/shorts, 4/3 intended openings, matching seam weights; idle/run/aim/jump/throw skinning is finite');
