// Independent art candidate. No Blender, downloads, or writes to production assets.
import './lib/runtime_level.mjs';
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
const THREE = await import('three');
const {headSurf, EYE} = await import('../../public/game/src/game/character-geo.js');
const {headPoint} = await import('./lib/character_anatomy.mjs');
const V = THREE.Vector3;
const source = new URL('../assets/characters/kid_0.glb', import.meta.url);
const out = new URL('../character-sample/', import.meta.url);
const hash = b => createHash('sha256').update(b).digest('hex');
const sourceBytes = readFileSync(source);
const selfBytes = readFileSync(new URL(import.meta.url));
if (process.argv.includes('--check')) {
  const manifest = JSON.parse(readFileSync(new URL('manifest.json', out)));
  if (manifest.source !== hash(sourceBytes) || manifest.generator !== hash(selfBytes)) throw Error('Stale sample source');
  if (manifest.output !== hash(readFileSync(new URL('wave.glb', out)))) throw Error('Stale sample asset');
  console.log('PASS: independent sample source, generator and GLB hashes match');
  process.exit(0);
}
const jsonSize = sourceBytes.readUInt32LE(12);
const gltf = JSON.parse(sourceBytes.subarray(20, 20 + jsonSize).toString());
const binOffset = 28 + jsonSize;
const bin = Buffer.from(sourceBytes.subarray(binOffset));
const chunks = [bin];
let byteLength = bin.length;
const typeSizes = {SCALAR:1, VEC2:2, VEC3:3, VEC4:4, MAT4:16};
const arrays = new Map();
function accessor(id) {
  if (arrays.has(id)) return arrays.get(id);
  const a = gltf.accessors[id], view = gltf.bufferViews[a.bufferView];
  const C = {5126:Float32Array, 5125:Uint32Array, 5123:Uint16Array}[a.componentType];
  if (!C || view.byteStride) throw Error('Unsupported source accessor');
  const result = new C(bin.buffer, bin.byteOffset + (view.byteOffset ?? 0) + (a.byteOffset ?? 0), a.count * typeSizes[a.type]);
  arrays.set(id, result);
  return result;
}
function bounds(id) {
  const a = gltf.accessors[id], p = accessor(id);
  a.min = [Infinity,Infinity,Infinity]; a.max = [-Infinity,-Infinity,-Infinity];
  for (let i=0; i<p.length; i++) {
    if (!Number.isFinite(p[i])) throw Error('Nonfinite vertex');
    a.min[i%3] = Math.min(a.min[i%3],p[i]); a.max[i%3] = Math.max(a.max[i%3],p[i]);
  }
}
function append(values, size, componentType=5126, target=34962) {
  const data = Buffer.from(values.buffer, values.byteOffset, values.byteLength);
  const index = gltf.bufferViews.length;
  gltf.bufferViews.push({buffer:0, byteOffset:byteLength, byteLength:data.length, target});
  const padding = (4 - data.length%4)%4;
  chunks.push(data, Buffer.alloc(padding)); byteLength += data.length + padding;
  const a = {bufferView:index,componentType,count:values.length/size,type:Object.keys(typeSizes).find(k=>typeSizes[k]===size)};
  if (size===3) {
    a.min=[Infinity,Infinity,Infinity]; a.max=[-Infinity,-Infinity,-Infinity];
    for(let i=0;i<values.length;i++){a.min[i%3]=Math.min(a.min[i%3],values[i]);a.max[i%3]=Math.max(a.max[i%3],values[i]);}
  }
  gltf.accessors.push(a); return gltf.accessors.length-1;
}
const skin = gltf.skins[0];
const parents = new Map();
gltf.nodes.forEach((n,i)=>(n.children??[]).forEach(child=>parents.set(child,i)));
const jointNames = skin.joints.map(i=>gltf.nodes[i].name);
const jointIndex = new Map(jointNames.map((name,i)=>[name,i]));
const headId = skin.joints[jointIndex.get('head')];
const headJoints = new Set();
function collect(id) {if (skin.joints.includes(id)) headJoints.add(skin.joints.indexOf(id)); for(const child of gltf.nodes[id].children??[])collect(child);}
collect(headId);
const oldWorld = new Map();
function world(id) {
  if (oldWorld.has(id)) return oldWorld.get(id);
  const n=gltf.nodes[id],m=new THREE.Matrix4().compose(new V(...(n.translation??[0,0,0])),new THREE.Quaternion(...(n.rotation??[0,0,0,1])),new V(...(n.scale??[1,1,1])));
  if(parents.has(id))m.premultiply(world(parents.get(id)));
  oldWorld.set(id,m);return m;
}
gltf.nodes.forEach((_,i)=>world(i));
const centre = new V(0,1.175,0.012);
function sculptHead(point) {
  const q=point.clone().sub(centre);
  const lower=THREE.MathUtils.smoothstep(-q.y,0.04,0.17);
  q.x *= .96*(1+.035*lower);
  q.y = q.y*.91-.059;
  q.z *= .97;
  return q.add(centre);
}
function deform(point, weight, semantic) {
  const p=point.clone().lerp(sculptHead(point),weight);
  // Slightly oversized tee silhouette, with the stitched armholes retained.
  if(semantic==='Cloth') {
    const chest=THREE.MathUtils.smoothstep(point.y,.73,.89)*(1-THREE.MathUtils.smoothstep(point.y,.99,1.04));
    p.x*=1+.13*chest; p.z*=1+.055*chest;
  }
  return p;
}
let hairPrimitive;
for(const node of gltf.nodes) {
  if(node.skin!==0 || node.mesh===undefined)continue;
  for(const primitive of gltf.meshes[node.mesh].primitives) {
    const attrs=primitive.attributes, semantic=gltf.materials[primitive.material].name;
    const p=accessor(attrs.POSITION),n=accessor(attrs.NORMAL),j=accessor(attrs.JOINTS_0),w=accessor(attrs.WEIGHTS_0);
    const uv=accessor(attrs.TEXCOORD_0),uv2=accessor(attrs.TEXCOORD_1);
    for(let i=0;i<p.length/3;i++) {
      let weight=0;for(let k=0;k<4;k++)if(headJoints.has(j[i*4+k]))weight+=w[i*4+k];
      const original=new V().fromArray(p,i*3);
      let mapped=deform(original,weight,semantic);
      if(semantic==='Eyes') {
        const u=uv[i*2],v=uv[i*2+1],sx=uv2[i*2],almond=v*(1-.38*Math.abs(u));
        const angle=.19*sx, uu=u*Math.cos(angle)-almond*Math.sin(angle), vv=u*Math.sin(angle)+almond*Math.cos(angle);
        mapped=sculptHead(headPoint(headSurf(sx*EYE.az+uu*EYE.daz*1.38,EYE.el+vv*EYE.del*.90,.0032+.004*(1-u*u-v*v),new V())));
      }
      const e=.00001, columns=[0,1,2].map(k=>{const q=original.clone();q.setComponent(k,q.getComponent(k)+e);return deform(q,weight,semantic).sub(deform(original,weight,semantic)).divideScalar(e);});
      const jacobian=new THREE.Matrix3().set(columns[0].x,columns[1].x,columns[2].x,columns[0].y,columns[1].y,columns[2].y,columns[0].z,columns[1].z,columns[2].z);
      const normal=new V().fromArray(n,i*3).applyMatrix3(jacobian.invert().transpose()).normalize();
      mapped.toArray(p,i*3); normal.toArray(n,i*3);
    }
    bounds(attrs.POSITION);
    if(semantic==='TeamHair') {
      hairPrimitive=primitive;
      const index=accessor(primitive.indices), kept=[];
      for(let q=0;q<index.length;q+=3) {
        const triangle=Array.from(index.slice(q,q+3));
        const strand=triangle.some(i=>[0,1,2,3].some(k=>w[i*4+k]>.001&&/^hair(?:\d|Tip)/.test(jointNames[j[i*4+k]])));
        if(!strand)kept.push(...triangle);
      }
      primitive.indices=append(new Uint32Array(kept),1,5125,34963);
    }
  }
}
// Reauthor five broad tentacle ribbons rather than stretch the old thin strands.
const curves=[
 [[.08,1.325,.04],[.03,1.34,.13],[-.075,1.31,.18],[-.155,1.25,.163],[-.185,1.205,.11]],
 [[.125,1.30,-.005],[.165,1.23,.006],[.179,1.12,.022],[.198,1.045,.045],[.228,1.035,.06]],
 [[-.135,1.29,-.025],[-.165,1.22,-.008],[-.183,1.105,.0],[-.185,1.03,.014],[-.211,1.02,.045]],
 [[.055,1.32,-.065],[.115,1.27,-.139],[.15,1.15,-.169],[.156,1.055,-.16],[.177,1.018,-.118]],
 [[-.055,1.32,-.065],[-.085,1.25,-.157],[-.118,1.14,-.188],[-.127,1.045,-.177],[-.15,1.015,-.135]]
].map(points=>new THREE.CatmullRomCurve3(points.map(p=>new V(...p)),false,'centripetal'));
const newJointWorld=new Map();
for(const index of headJoints) {
  const id=skin.joints[index],p=new V().setFromMatrixPosition(oldWorld.get(id));
  newJointWorld.set(id,sculptHead(p));
}
const positions=[], normals=[], colors=[], uv0=[], uv1=[], joints=[], weights=[], indices=[];
for(let strand=0;strand<curves.length;strand++) {
  const curve=curves[strand],steps=44,radial=18,offset=positions.length/3;
  for(let k=0;k<3;k++)newJointWorld.set(skin.joints[jointIndex.get(`hair${strand}_${k}`)],sculptHead(curve.getPointAt([.16,.46,.76][k])));
  newJointWorld.set(skin.joints[jointIndex.get(`hairTip${strand}`)],sculptHead(curve.getPointAt(1)));
  for(let row=0;row<=steps;row++) {
    const t=row/steps,center=curve.getPointAt(t),tangent=curve.getTangentAt(t).normalize();
    const outward=center.clone().sub(centre).normalize();
    const width=new V().crossVectors(tangent,outward).normalize();
    const up=new V().crossVectors(width,tangent).normalize();
    const taper=Math.pow(Math.sin(Math.PI*(.10+.895*t)),.62);
    const radius=(strand===0?.06:.041)*taper;
    const along=t*2,base=Math.min(1,Math.floor(along)),blend=along-base;
    for(let col=0;col<=radial;col++) {
      const angle=col/radial*Math.PI*2,cs=Math.cos(angle),sn=Math.sin(angle);
      const p=center.clone().addScaledVector(width,cs*radius).addScaledVector(up,sn*radius*.38);
      sculptHead(p).toArray(positions,positions.length);
      // Normal of the elliptical ribbon section, transformed with its head cage.
      const n=width.clone().multiplyScalar(cs).addScaledVector(up,sn/.38).normalize();n.y/=.91;n.normalize();n.toArray(normals,normals.length);
      colors.push(t,strand===0?0:1,0,1);uv0.push(t*.32,sn);uv1.push(0,(cs+1)*.5);
      joints.push(jointIndex.get(`hair${strand}_${base}`),jointIndex.get(`hair${strand}_${base+1}`),0,0);
      weights.push(1-blend,blend,0,0);
      if(row&&col) {const a=offset+(row-1)*(radial+1)+col-1,b=a+1,c=offset+row*(radial+1)+col,d=c-1;indices.push(a,c,b,a,d,c);}
    }
  }
}
const hairMesh=gltf.meshes.find(m=>m.primitives.includes(hairPrimitive));
hairMesh.primitives.push({material:hairPrimitive.material,indices:append(new Uint32Array(indices),1,5125,34963),attributes:{
 POSITION:append(new Float32Array(positions),3),NORMAL:append(new Float32Array(normals),3),COLOR_0:append(new Float32Array(colors),4),
 TEXCOORD_0:append(new Float32Array(uv0),2),TEXCOORD_1:append(new Float32Array(uv1),2),JOINTS_0:append(new Uint16Array(joints),4,5123),WEIGHTS_0:append(new Float32Array(weights),4)
}});
for(const [id,next] of newJointWorld) {
  const parent=parents.get(id),parentPos=newJointWorld.get(parent)??new V().setFromMatrixPosition(oldWorld.get(parent));
  gltf.nodes[id].translation=next.clone().sub(parentPos).toArray();
}
oldWorld.clear();gltf.nodes.forEach((_,i)=>world(i));
const inverse=accessor(skin.inverseBindMatrices);
skin.joints.forEach((id,i)=>world(id).clone().invert().toArray(inverse,i*16));
gltf.buffers[0].byteLength=byteLength;
gltf.asset.generator='INKWAVE independent Wave character study';
let json=Buffer.from(JSON.stringify(gltf));json=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);
const binary=Buffer.concat(chunks),header=Buffer.alloc(12),jheader=Buffer.alloc(8),bheader=Buffer.alloc(8);
header.writeUInt32LE(0x46546c67);header.writeUInt32LE(2,4);header.writeUInt32LE(28+json.length+binary.length,8);
jheader.writeUInt32LE(json.length);jheader.writeUInt32LE(0x4e4f534a,4);bheader.writeUInt32LE(binary.length);bheader.writeUInt32LE(0x004e4942,4);
const output=Buffer.concat([header,jheader,json,bheader,binary]);
mkdirSync(out,{recursive:true});writeFileSync(new URL('wave.glb',out),output);
writeFileSync(new URL('manifest.json',out),JSON.stringify({source:hash(sourceBytes),generator:hash(selfBytes),output:hash(output),bones:jointNames.length,ribbons:curves.length,scope:'Independent prototype; body/weapon meshes and animation data derive from the project web original. Reauthored hair, head cage, eyes and materials; no gameplay integration.'},null,2)+'\n');
console.log(`PASS: Wave sample exported (${jointNames.length} bones, ${curves.length} reauthored tentacle ribbons); production assets unchanged`);
