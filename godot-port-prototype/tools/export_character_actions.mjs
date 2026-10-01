// Full-body and facial poses sampled from the original Character, including IK.
import './lib/runtime_level.mjs';
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
const { Character } = await import('../../public/game/src/game/character.js');
const out = new URL('../assets/characters/actions.json', import.meta.url);
const paths = ['./export_character_actions.mjs', '../../public/game/src/game/character.js', '../../public/game/src/game/character-weapons.js', '../../public/game/src/config.js'];
const sources = Object.fromEntries(paths.map(p => [p, createHash('sha256').update(readFileSync(new URL(p, import.meta.url))).digest('hex')]));
if (process.argv.includes('--check')) {
  const d = JSON.parse(readFileSync(out));
  if (JSON.stringify(d.sources) !== JSON.stringify(sources)) throw Error('Stale original full-body actions');
  console.log('OK: original jump/land/hit/spawn and three victory/defeat dances, bone/face poses'); process.exit(0);
}
const round = a => a.map(n => Math.round(n * 1e6) / 1e6);
const faceNames=['eyeL','eyeR','browL','browR','jaw','cheekL','cheekR','earL','earR'];
const gaitNames=['hips','thighL','shinL','footL','thighR','shinR','footR'];
const restCharacter=new Character({style:{hair:0,skin:0,outfit:0,eyes:0}});
const result = { schema: 3, fps: 30, sources, bones: [], rest:restCharacter.skeleton.bones.map(b=>[...round(b.position.toArray()),...round(b.quaternion.toArray()),...round(b.scale.toArray())]), gaitBones:gaitNames,gaits:{}, clips: {}, faceBones:faceNames, expressions:{} };
for (const weapon of ['shooter', 'roller', 'charger', 'blaster']) {
  const gaits={};
  for(const mode of ['idle','walk','run']) {
    const c=new Character({style:{hair:0,skin:0,outfit:0,eyes:0},weapon});
    c.nextFidget=999;c.blinkT=999;c.lookT=999;c.saccT=999;
    const speed=mode==='idle'?0:mode==='walk'?1.8:6;
    const state={form:'kid',grounded:true,speed,localMove:{x:0,z:speed?1:0},firing:false,rolling:weapon==='roller'&&speed>0,ink:1,hp:1};
    for(let i=0;i<240;i++)c.update(1/30,state);
    const frames=[],count=mode==='idle'?1:60,dt=1/(c.cad*60);
    for(let i=0;i<count;i++) {
      frames.push({bones:gaitNames.map(n=>{const b=c.bones[n];return [...round(b.position.toArray()),...round(b.quaternion.toArray()),...round(b.scale.toArray())];}),kid:[...round(c.kid.position.toArray()),...round(c.kid.quaternion.toArray()),...round(c.kid.scale.toArray())]});
      c.update(dt,state);
    }
    gaits[mode]={speed,cadence:c.cad,frames};
  }
  result.gaits[weapon]=gaits;
  const expressions={};
  for(const name of ['idle','focus','fire','charge','low','tired','special']) {
    const c=new Character({seed:1,weapon});
    c.nextFidget=999;c.blinkT=999;c.lookT=999;c.saccT=999;
    const state={form:'kid',grounded:true,speed:0,localMove:{x:0,z:0},firing:['focus','fire','charge'].includes(name),charge:name==='charge'?1:0,lowInk:name==='low',ink:name==='low'?0.05:1,hp:name==='tired'?0.15:1,special:name==='special'?1:0};
    for(let i=0;i<120;i++){if(name==='fire')c.trigger('shoot');c.update(1/30,state);}
    expressions[name]={bones:faceNames.map(n=>{const b=c.skeleton.bones.find(b=>b.name===n);if(!b)throw Error('Missing facial bone '+n);return [...round(b.position.toArray()),...round(b.quaternion.toArray()),...round(b.scale.toArray())];}),mouth:round(c.u.uMouth.value.toArray()),look:round(c.u.uLook.value.toArray())};
  }
  result.expressions[weapon]=expressions;
  const clips = {};
  for (const name of ['jump', 'land', 'hit', 'spawn', 'victory_0', 'victory_1', 'victory_2', 'defeat_0', 'defeat_1', 'defeat_2']) {
    const c = new Character({ seed: 1, style: { hair: 0, skin: 0, outfit: 0, eyes: 0 }, weapon });
    c.nextFidget = 999;
    const state = { form: 'kid', grounded: true, speed: 0, localMove: { x: 0, z: 0 }, firing: false, charge: 0, rolling: false, aimPitch: 0, ink: 1, hp: 1 };
    for (let i = 0; i < 120; i++) c.update(1 / 30, state);
    if (name.includes('_')) { c.setDance(name.split('_')[0]); c.danceVar = +name.split('_')[1]; c.danceOfs = 0; }
    else { c.trigger(name, name === 'land' ? 10 : undefined); if (name === 'jump') { state.grounded = false; state.vy = 7; } }
    const bones = c.skeleton.bones;
    result.bones = bones.map(b => b.name);
    const frames = [];
    for (let i = 0; i < (name.includes('_') ? 120 : 36); i++) {
      c.update(1 / 30, state);
      frames.push({ bones: bones.map(b => [...round(b.position.toArray()), ...round(b.quaternion.toArray()), ...round(b.scale.toArray())]), kid: [...round(c.kid.position.toArray()), ...round(c.kid.quaternion.toArray()), ...round(c.kid.scale.toArray())],mouth:round(c.u.uMouth.value.toArray()),look:round(c.u.uLook.value.toArray()) });
    }
    clips[name] = frames;
  }
  result.clips[weapon] = clips;
}
writeFileSync(out, JSON.stringify(result) + '\n');
console.log('Exported original full-body/face one-shots and six result dances for all four weapons');
