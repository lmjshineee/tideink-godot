import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {ARENAS} from './lib/arena_layouts.mjs';
const run=(name,args=[])=>process.stdout.write(execFileSync(process.execPath,[fileURLToPath(new URL(`./${name}.mjs`,import.meta.url)),...args],{encoding:'utf8',maxBuffer:4*1024*1024}));
const checking=process.argv.includes('--check');
for(const map of ARENAS){
 for(const tool of ['export_tidewater_map','export_tidewater_surfaces'])run(tool,[`--arena=${map.id}`,...(checking?['--check']:[])]);
 if(!map.layout)run('export_tidewater_visuals',[`--arena=${map.id}`,...(checking?['--check']:[])]);
}
if(!checking){
 run('export_tidewater_visuals');run('export_tidewater_visuals',['--kelpline']);
 run('export_navigation');run('export_minimap');
}
console.log('OK: seven stages including nine modular harbor compositions and four source-map variants, synchronized collision/paint/nav/minimap');
