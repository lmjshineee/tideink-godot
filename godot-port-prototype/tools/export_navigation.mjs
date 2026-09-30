// Original NavGraph, with source Physics and original prop collision: no hand-authored routes.
import {createRuntimeLevel, vector3} from './lib/runtime_level.mjs';
import {TIDEWATER, KELPLINE} from '../../public/game/src/world/maps.js';
const {NavGraph} = await import('../../public/game/src/game/nav.js');
const {Physics} = await import('../../public/game/src/game/physics.js');
import {readFileSync, writeFileSync} from 'node:fs';
for(const map of [TIDEWATER,KELPLINE]) {
 const {level} = await createRuntimeLevel(map);
 const nav = new NavGraph(level, new Physics(level));
 const payload={schema:1,id:map.id,source:'public/game/src/game/nav.js:NavGraph',nodes:nav.nodes.filter(n=>nav.valid[n.id]).map(n=>({id:n.id,p:[n.x,n.y,n.z],zone:n.zone,edges:n.nb.filter(e=>nav.valid[e.to])}))};
 const out=new URL(`../assets/maps/${map.id}_nav.json`,import.meta.url), data=JSON.stringify(payload)+'\n';
 if(process.argv.includes('--check')) {if(readFileSync(out,'utf8')!==data)throw Error(`Stale ${map.id} navigation`);} else writeFileSync(out,data);
 console.log(`OK: ${map.id} ${payload.nodes.length} original navigation nodes`);
}
