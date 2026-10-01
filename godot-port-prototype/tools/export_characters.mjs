// Original procedural rig/geometry -> skinned GLB; Godot uses its own lit material and animation.
import './lib/runtime_level.mjs';
import {QUALITY} from './lib/character_quality.mjs';
const THREE = await import('three');
const {Character, SKIN_TONES, OUTFITS} = await import('../../public/game/src/game/character.js');
import {createHash} from 'node:crypto';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {correctCharacterAnatomy} from './lib/character_anatomy.mjs';
const output=new URL('../assets/characters/',import.meta.url);
const sourcePaths=['character.js','character-geo.js','character-mats.js','character-weapons.js'].map(n=>`../../public/game/src/game/${n}`).concat(['../../public/game/src/config.js','./export_characters.mjs','./lib/character_anatomy.mjs','./lib/character_quality.mjs']);
const hash=b=>createHash('sha256').update(b).digest('hex');
const sources=Object.fromEntries(sourcePaths.map(p=>[p,hash(readFileSync(new URL(p,import.meta.url)))]));
if(process.argv.includes('--check')) {
 const m=JSON.parse(readFileSync(new URL('manifest.json',output)));
 if(JSON.stringify(m.sources)!==JSON.stringify(sources))throw Error('Character source changed');
 for(const [p,h] of Object.entries(m.outputs))if(hash(readFileSync(new URL(p,output)))!==h)throw Error(`Stale character ${p}`);
 console.log('OK: four original skinned characters, source/output hashes match');process.exit(0);
}
mkdirSync(output,{recursive:true});const outputs={},stats=[];
for(let style=0;style<4;style++) {
 const c=new Character({seed:style+1,style:{hair:style,skin:style,outfit:style,eyes:style},weapon:'shooter'});
 const anatomy=correctCharacterAnatomy(c);
 c.root.name='OriginalCharacter';c.kid.name='KidRig';c.squidRoot.name='SquidRig';
 c.bomb?.group?.removeFromParent();
 c.tank.fill.scale.y=c.tank.h;
 c.tank.fill.name='TankFill';c.tank.glass.name='TankGlass';
 for(const id of ['shooter','roller','charger','blaster']){c.setWeapon(id);c.weapons[id].pivot.name='Weapon_'+id;c.weapons[id].pivot.visible=true;}
 for(const w of Object.values(c.weapons))c.bones.handR.add(w.pivot);
 c.squid.ghost.removeFromParent();
 // Keep the source's signed eye coordinates and semantic shader attributes.
 // Eyes are patches in [-1,1], not discs centered at (.5,.5). Decals must be
 // evaluated per fragment; vertex-baking erased the visor/mouth/iris details.
 const cloth=[0xffffff,0xffffff,OUTFITS[style].shirt,OUTFITS[style].shorts,OUTFITS[style].shoe,OUTFITS[style].sock,OUTFITS[style].sole,OUTFITS[style].strap,0x506080,0x20283a,0xa6b3c8,0x27304a,0xe8edef,0xffffff,0xffffff];
 const gltf={asset:{version:'2.0',generator:'INKWAVE original rig exporter'},scene:0,scenes:[{nodes:[]}],nodes:[],meshes:[],materials:[],skins:[],buffers:[{byteLength:0}],bufferViews:[],accessors:[]};
 let total=0;const chunks=[];const nodeIds=new Map();let triangles=0;
 const view=(b,target)=>{const id=gltf.bufferViews.length;gltf.bufferViews.push({buffer:0,byteOffset:total,byteLength:b.length,...(target?{target}:{})});const pad=(4-b.length%4)%4;chunks.push(b,Buffer.alloc(pad));total+=b.length+pad;return id;};
 const acc=(a,size,type,position=false)=>{const bytes=Buffer.from(a.buffer,a.byteOffset,a.byteLength),d={bufferView:view(bytes,type===5125?34963:34962),componentType:type,count:a.length/size,type:({1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4',16:'MAT4'})[size]};if(position){d.min=[Infinity,Infinity,Infinity];d.max=[-Infinity,-Infinity,-Infinity];for(let i=0;i<a.length;i++){d.min[i%3]=Math.min(d.min[i%3],a[i]);d.max[i%3]=Math.max(d.max[i%3],a[i]);}}gltf.accessors.push(d);return gltf.accessors.length-1;};
 c.root.updateMatrixWorld(true);
 function addNode(o){const id=gltf.nodes.length;nodeIds.set(o,id);const n={name:o.name||'Part',translation:o.position.toArray(),rotation:o.quaternion.toArray(),scale:o.scale.toArray()};gltf.nodes.push(n);if(o.children.length)n.children=o.children.map(addNode);return id;}
 gltf.scenes[0].nodes=[addNode(c.root)];
 const inverse=new Float32Array(c.skeleton.boneInverses.length*16);c.skeleton.boneInverses.forEach((m,i)=>inverse.set(m.elements,i*16));
 gltf.skins.push({name:'SquidkidSkeleton',joints:c.skeleton.bones.map(b=>nodeIds.get(b)),inverseBindMatrices:acc(inverse,16,5126),skeleton:nodeIds.get(c.bones.hips)});
 c.root.traverse(o=>{
  if(!o.isMesh)return;
  if(o===c.squid?.ghost){return;}
  const g=o.geometry,mat=o.material, count=g.attributes.position.count;
  const isSkin=mat===c.mats.skin,isCloth=mat===c.mats.cloth,isHair=mat===c.mats.hair,isEye=mat===c.mats.eye,isSquid=mat===c.mats.squid;
  const isInk=mat===c.mats.fill||mat===c.mats.glow||isSquid||Object.values(c.weapons).some(w=>o===w.ink||o===w.drum?.userData.ink);
  const col=new Float32Array(count*4),uv0=new Float32Array(count*2),uv1=new Float32Array(count*2),custom0a=new Float32Array(count*2),custom0b=new Float32Array(count*2),custom1a=new Float32Array(count*2),custom1b=new Float32Array(count*2),base=new THREE.Color();
  for(let i=0;i<count;i++){
   let team=0; const ex=g.attributes.aEx?.getX(i)??0,uv=g.attributes.uv;
   if(isSkin){base.set(SKIN_TONES[style]);if(g.attributes.color)base.multiply(new THREE.Color().fromBufferAttribute(g.attributes.color,i));}
   else if(isCloth){base.setRGB(g.attributes.color?.getX(i)??1,g.attributes.color?.getY(i)??1,g.attributes.color?.getZ(i)??1);}
   else if(isHair){
    const tint=g.attributes.aTint?.getX(i)??0, r=g.attributes.color.getX(i), k=g.attributes.color.getY(i);
    if(tint<=-1.5){base.setRGB(r,k,g.attributes.color.getZ(i));if(r<-.5){base.set([-1,-2,-3,-4].includes(Math.round(r))?({1:0xffffff,2:OUTFITS[style].shirt,3:OUTFITS[style].strap,4:OUTFITS[style].shorts})[Math.round(-r)]:0xffffff).multiplyScalar(k);team=Math.round(-r)===1?1:0;}}
    else {base.setRGB(Math.max(0,Math.min(1,r)),Math.max(0,Math.min(1,k)),0);team=1;}
   }
   else if(isInk){base.setRGB(1,1,1);team=1;}
   else if(isEye)base.setRGB(1,1,1);
   else {base.copy(mat.color??new THREE.Color(0xffffff));if(g.attributes.color)base.multiply(new THREE.Color().fromBufferAttribute(g.attributes.color,i));}
   col.set([base.r,base.g,base.b,team],i*4);
   custom0a.set([g.attributes.position.getX(i),g.attributes.position.getY(i)],i*2);
   custom0b.set([g.attributes.position.getZ(i),ex],i*2);
   custom1a.set([g.attributes.aCloth?.getX(i)??0,g.attributes.aCloth?.getY(i)??0],i*2);
   custom1b.set([g.attributes.aCloth?.getZ(i)??0,0],i*2);
   uv0.set([uv?.getX(i)??0,uv?.getY(i)??0],i*2);
   if(isSkin){uv0.set([g.attributes.aHead?.getX(i)??0,g.attributes.aHead?.getY(i)??0],i*2);uv1.set([g.attributes.aHead?.getZ(i)??0,ex],i*2);}
   else if(isEye)uv1.set([ex,0],i*2);
   else if(isHair)uv1.set([g.attributes.aTint?.getX(i)??0,g.attributes.color.getZ(i)],i*2);
   else if(isCloth)uv1.set([g.attributes.aCloth?.getX(i)??0,g.attributes.aCloth?.getY(i)??0],i*2);
  }
  const attrs={POSITION:acc(new Float32Array(g.attributes.position.array),3,5126,true),NORMAL:acc(new Float32Array(g.attributes.normal.array),3,5126),COLOR_0:acc(col,4,5126)};
  attrs.TEXCOORD_0=acc(uv0,2,5126);
  attrs.TEXCOORD_1=acc(uv1,2,5126);
  // Godot imports TEXCOORD_2/3 and 4/5 as CUSTOM0/1. Keep bind-space
  // coordinates and all source clothing parameters after GPU skinning.
  if(isCloth||isSkin){attrs.TEXCOORD_2=acc(custom0a,2,5126);attrs.TEXCOORD_3=acc(custom0b,2,5126);attrs.TEXCOORD_4=acc(custom1a,2,5126);attrs.TEXCOORD_5=acc(custom1b,2,5126);}
  if(o.isSkinnedMesh){attrs.JOINTS_0=acc(new Uint16Array(g.attributes.skinIndex.array),4,5123);attrs.WEIGHTS_0=acc(new Float32Array(g.attributes.skinWeight.array),4,5126);}
  const index=g.index?new Uint32Array(g.index.array):Uint32Array.from({length:count},(_,i)=>i);triangles+=index.length/3;
  const m=gltf.materials.length;gltf.materials.push({name:isHair?'TeamHair':isInk?'TeamInk':isSkin?'Skin':isEye?'Eyes':isCloth?'Cloth':'Equipment',pbrMetallicRoughness:{baseColorFactor:[1,1,1,1],metallicFactor:0,roughnessFactor:.5},doubleSided:true});
  const mesh=gltf.meshes.length;gltf.meshes.push({name:o.name||gltf.materials[m].name,primitives:[{attributes:attrs,indices:acc(index,1,5125),material:m}]});
  gltf.nodes[nodeIds.get(o)].mesh=mesh;if(o.isSkinnedMesh)gltf.nodes[nodeIds.get(o)].skin=0;
 });
 gltf.buffers[0].byteLength=total;let json=Buffer.from(JSON.stringify(gltf));json=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);const bin=Buffer.concat(chunks),h=Buffer.alloc(12),j=Buffer.alloc(8),b=Buffer.alloc(8);h.writeUInt32LE(0x46546c67);h.writeUInt32LE(2,4);h.writeUInt32LE(28+json.length+bin.length,8);j.writeUInt32LE(json.length);j.writeUInt32LE(0x4e4f534a,4);b.writeUInt32LE(bin.length);b.writeUInt32LE(0x004e4942,4);const glb=Buffer.concat([h,j,json,b,bin]);const name=`kid_${style}.glb`;writeFileSync(new URL(name,output),glb);outputs[name]=hash(glb);stats.push({style,bones:c.skeleton.bones.length,meshes:gltf.meshes.length,triangles});
 stats[stats.length-1].anatomy=anatomy;stats[stats.length-1].quality=QUALITY;
 console.log(`Exported ${name}: ${c.skeleton.bones.length} bones, ${triangles} triangles (connected garments + corrected head; all four weapons + squid included)`);
}
writeFileSync(new URL('manifest.json',output),JSON.stringify({schema:4,sources,outputs,stats,attributes:{Skin:'UV=head.xy; UV2=(head.z,submaterial); COLOR=source tint; CUSTOM0=(bind position,submaterial)',Eyes:'UV=signed patch coordinates; UV2.x=side',TeamHair:'UV=source strand coordinates; UV2=(tint,cap/angle); COLOR.rg=strand data',Cloth:'UV=source part coordinates; UV2=(part,material class); CUSTOM0=(bind position,color source); CUSTOM1=(part,class,param,0); COLOR=original vertex tint'},limitations:'Original rig/style with export-local garment topology, weights and head cage corrections; upstream web sources unmodified; source fragment details and offline poses adapted for Godot; realtime terrain foot IK remains separate'},null,2)+'\n');
