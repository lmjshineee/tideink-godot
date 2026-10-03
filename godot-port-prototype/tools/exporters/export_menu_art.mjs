// Exact original web logo silhouettes and navigation glyphs, without DOM layout.
import {logoMarkup,GLYPHS} from '../../../public/game/src/ui/ui-icons.js';
import {writeFileSync,readFileSync} from 'node:fs';
const svg=logoMarkup().match(/<svg class="iw-logo__splat"[\s\S]*?<\/svg>/)[0];
const outputs={};
for(const side of ['a','b'])outputs[`logo-${side}.svg`]=svg.replace(/<svg[^>]*>/,'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 240" width="600" height="240">').replace(/class="iw-f([ab])[^\"]*"/g,(_,part)=>`fill="${part===side?'white':'none'}"`).replace(/class="[^"]*"/g,'');
for(const name of ['play','gear','star','question'])outputs[`nav-${name}.svg`]=GLYPHS[name].replace(/<svg[^>]*viewBox="([^"]+)"[^>]*>/,'<svg xmlns="http://www.w3.org/2000/svg" viewBox="$1" width="64" height="64">').replaceAll('currentColor','white');
for(const [name,data] of Object.entries(outputs)){const out=new URL(`../../assets/ui/${name}`,import.meta.url);if(process.argv.includes('--check')){if(readFileSync(out,'utf8')!==data+'\n')throw Error(`Stale ${name}`);}else writeFileSync(out,data+'\n');}
console.log('OK: original web two-color logo and navigation SVGs');
