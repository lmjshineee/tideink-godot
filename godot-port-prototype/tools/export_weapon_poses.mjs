// Evaluate the original animation + two-arm IK offline; runtime blends the resulting holds.
import './lib/runtime_level.mjs';
const {Character}=await import('../../public/game/src/game/character.js');
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const out=new URL('../assets/characters/weapon_poses.json',import.meta.url);
const paths=['./export_weapon_poses.mjs','../../public/game/src/game/character.js','../../public/game/src/game/character-weapons.js','../../public/game/src/config.js'];
const hash=b=>createHash('sha256').update(b).digest('hex');
const sources=Object.fromEntries(paths.map(p=>[p,hash(readFileSync(new URL(p,import.meta.url)))]));
if(process.argv.includes('--check')){const d=JSON.parse(readFileSync(out));if(JSON.stringify(d.sources)!==JSON.stringify(sources))throw Error('Stale weapon poses');console.log('OK: original weapon holds / two-arm IK / recoil / flick source hashes');process.exit(0);}
const bones=['spine','chest','neck','head','clavL','clavR','uArmL','uArmR','fArmL','fArmR','handL','handR'];
const result={schema:1,fps:30,sources,bones,weapons:{}};
const round=a=>a.map(n=>Math.round(n*1e6)/1e6);
for(const id of ['shooter','charger','roller','blaster']){
 const clips={};
 for(const name of ['carry','aim_low','aim','aim_high','roll','shoot','flick','throw']){
  const c=new Character({seed:1,style:{hair:0,skin:0,outfit:0,eyes:0},weapon:id});
  c.nextFidget=999;
  const aiming=name.startsWith('aim')||name==='shoot';
  const state={form:'kid',grounded:true,speed:0,localMove:{x:0,z:0},firing:aiming,charge:id==='charger'&&aiming?1:0,rolling:name==='roll',aimPitch:name==='aim_low'?-.8:name==='aim_high'?.8:0,ink:1,hp:1};
  for(let i=0;i<120;i++)c.update(1/30,state);
  if(name==='shoot')c.trigger(id==='charger'?'charge_release':'shoot');
  if(name==='flick')c.trigger('shoot');
  if(name==='throw')c.trigger('throw');
  const count=['shoot','flick','throw'].includes(name)?25:1;
  const frames=[];
  for(let i=0;i<count;i++){
   if(i)c.update(1/30,state);
   frames.push(bones.map(n=>[...round(c.bones[n].position.toArray()),...round(c.bones[n].quaternion.toArray())]));
  }
  clips[name]=frames;
 }
 result.weapons[id]=clips;
}
writeFileSync(out,JSON.stringify(result)+'\n');console.log('Exported original upper-body holds and action clips for four weapons');
