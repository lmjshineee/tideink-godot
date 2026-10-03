// Bake the web minimap's static drawing and exact pixel-to-ownership lookup.
import {createRuntimeLevel} from '../lib/runtime_level.mjs';
import {TIDEWATER,KELPLINE} from '../../../public/game/src/world/maps.js';
import {createRequire} from 'node:module';
import {createServer} from 'node:http';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {resolve,sep} from 'node:path';
const root=resolve(fileURLToPath(new URL('../../../',import.meta.url)));
const out=fileURLToPath(new URL('../../assets/maps/',import.meta.url));
const hash=b=>createHash('sha256').update(b).digest('hex');
const paths=['public/game/src/game/minimap.js','public/game/src/world/maps.js','public/game/src/world/level.js','public/game/src/world/props.js','public/game/src/world/dressing.js','godot-port-prototype/tools/exporters/export_minimap.mjs',...['tidewater','kelpline'].map(id=>`godot-port-prototype/assets/maps/${id}_surfaces.json`)];
const {ALL_MAPS}=await import('../lib/arena_layouts.mjs');
paths.push('godot-port-prototype/tools/lib/arena_layouts.mjs');
const sources=Object.fromEntries(paths.map(p=>[p,hash(readFileSync(resolve(root,p)))]));
if(process.argv.includes('--check')){
 for(const id of ALL_MAPS.map(m=>m.id)){
  const meta=JSON.parse(readFileSync(resolve(out,`${id}_minimap.json`)));
  if(JSON.stringify(meta.sources)!==JSON.stringify(sources))throw Error(`Stale ${id} minimap sources`);
  for(const [f,h] of Object.entries(meta.outputs))if(hash(readFileSync(resolve(out,f)))!==h)throw Error(`Stale ${f}`);
 }
 console.log('OK: both original web minimap bases, occlusion and bilinear cell lookups');process.exit(0);
}
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_PATH||'/Users/yunni/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const server=createServer((req,res)=>{
 if(req.url==='/'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><title>Minimap export</title>');return;}
 const p=resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));
 if(!p.startsWith(root+sep)){res.writeHead(403).end();return;}
 try{res.setHeader('Content-Type','text/javascript');res.end(readFileSync(p));}catch{res.writeHead(404).end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
let browser;
try{
 browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 const page=await browser.newPage();
 await page.goto(`http://127.0.0.1:${server.address().port}/`);
 for(const map of ALL_MAPS){
  const {level}=await createRuntimeLevel(map);
  const blocks=level.blocks.map(b=>({id:b.id,solid:b.solid,hidden:b.hidden,grate:b.grate,center:b.center,half:b.half,axes:b.axes,aabbMin:b.aabbMin,aabbMax:b.aabbMax,color:{r:b.color.r,g:b.color.g,b:b.color.b}}));
  const data=JSON.parse(readFileSync(resolve(out,`${map.id}_surfaces.json`)));
  const result=await page.evaluate(async({blocks,bounds,data})=>{
   const {Minimap}=await import('/public/game/src/game/minimap.js');
   let offset=0;const paintFaces=[],dead=new Uint8Array(data.gridCells);
   const vec=a=>({x:a[0],y:a[1],z:a[2]});
   for(const f of data.faces){
    if(!f.grid)continue;
    for(const [start,n] of f.grid.deadRuns)dead.fill(1,offset+start,offset+start+n);
    paintFaces.push({...f,...f.grid,origin:vec(f.origin),n:vec(f.n),u:vec(f.u),v:vec(f.v),grid:offset});
    offset+=f.grid.nu*f.grid.nv;
   }
   if(offset!==data.gridCells)throw Error('Ownership atlas size mismatch');
   const m=new Minimap({blocks,bounds},{paintFaces,dead},7);m.ensure();
   const lookup=new Float32Array(m.w*m.h*4);
   for(let i=0;i<m.w*m.h;i++)lookup.set([m.pixCell[i],m.pixSy[i],m.pixSx[i]?m.pixFx[i]/255:0,m.pixFy[i]/255],i*4);
   const bytes=new Uint8Array(lookup.buffer);let binary='';
   for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));
   return {w:m.w,h:m.h,cells:offset,png:m.base.toDataURL('image/png').split(',')[1],lookup:btoa(binary),paintPixels:Array.from(m.pixCell).filter(k=>k>=0).length};
  },{blocks,bounds:level.bounds,data});
  const outputs={};
  for(const [suffix,key] of [['minimap.png','png'],['minimap_lookup.bin','lookup']]){
   const f=`${map.id}_${suffix}`,bytes=Buffer.from(result[key],'base64');writeFileSync(resolve(out,f),bytes);outputs[f]=hash(bytes);
  }
  writeFileSync(resolve(out,`${map.id}_minimap.json`),JSON.stringify({schema:1,id:map.id,width:result.w,height:result.h,cells:result.cells,paintPixels:result.paintPixels,sources,outputs},null,2)+'\n');
  console.log(`OK: ${map.id} web base ${result.w}x${result.h}, ${result.paintPixels} visible paint pixels`);
 }
}finally{await browser?.close();await new Promise(r=>server.close(r));}
