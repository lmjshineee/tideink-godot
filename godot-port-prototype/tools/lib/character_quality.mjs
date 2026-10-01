// Export-local analytic tessellation. Shape functions, face proportions and rig stay unchanged.
import {registerHooks} from 'node:module';
const target=new URL('../../../public/game/src/game/character-geo.js',import.meta.url).href;
export const QUALITY={head:[96,60],ear:[28,24],roundedSurfaceScale:1.5,maxRadial:48};
registerHooks({load(url,context,next){
 const result=next(url,context);
 if(url!==target)return result;
 let source=String(result.source);
 const pairs=[['const nAz = 64, nEl = 40;','const nAz = 96, nEl = 60;'],['const L = 0.106, nU = 18, nTh = 16;','const L = 0.106, nU = 28, nTh = 24;'],['const g = finalize(new THREE.SphereGeometry(1, ws, hs));','const g = finalize(new THREE.SphereGeometry(1, Math.min(48, Math.ceil(ws*1.5)), Math.min(32, Math.ceil(hs*1.5))));']];
 for(const [before,after] of pairs){if(!source.includes(before))throw Error('Source character topology changed; review quality adapter');source=source.replace(before,after);}
 return {...result,source};
}});
