// Render the unmodified web Character in Chromium as the visual source reference.
import {createServer} from 'node:http';
import {readFileSync, mkdirSync, writeFileSync} from 'node:fs';
import {resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_PATH || '/Users/yunni/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root = resolve(fileURLToPath(new URL('../../../',import.meta.url)));
const output = resolve(root,'output/playwright/character-reference');
mkdirSync(output,{recursive:true});
const html = `<!doctype html><html><head><title>Original INKWAVE character reference</title><style>body{margin:0;background:#202735}canvas{display:block}</style>
<script type="importmap">{"imports":{"three":"/public/game/vendor/three/engine/three.module.js","three/addons/":"/public/game/vendor/three/jsm/"}}</script></head><body>
<script type="module">
import * as THREE from 'three';
import {Character} from '/public/game/src/game/character.js';
const scene=new THREE.Scene();scene.background=new THREE.Color('#202735');
const renderer=new THREE.WebGLRenderer({antialias:true,preserveDrawingBuffer:true});renderer.setSize(1280,720);renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.NeutralToneMapping;document.body.appendChild(renderer.domElement);
const camera=new THREE.OrthographicCamera(-1.6,1.6,.9,-.9,.01,30);camera.position.set(0,1.15,5);camera.lookAt(0,.7,0);
const ambient=new THREE.AmbientLight('#cad8ec',.55);scene.add(ambient);
const key=new THREE.DirectionalLight('white',3.14);key.position.set(-2,3,4);scene.add(key);
const rim=new THREE.DirectionalLight('#7dbeec',1.57);rim.position.set(2,2,-4);scene.add(rim);
const weapons=['shooter','roller','charger','blaster'],characters=[];
const state={form:'kid',grounded:true,speed:0,localMove:{x:0,z:0},firing:false,aimPitch:0,rolling:false,ink:1,hp:1};
for(let i=0;i<4;i++){const c=new Character({name:'Reference'+i,style:{hair:i,skin:i,outfit:i,eyes:i},color:i%2?'#2f5bff':'#ff8a14',weapon:weapons[i]});c.nextFidget=999;c.blinkT=999;c.lookT=999;c.saccT=999;scene.add(c.root);c.root.position.x=(i-1.5)*.72;for(let t=0;t<120;t++)c.update(1/30,state);characters.push(c);}
window.reference={characters,camera,scene,renderer,state};
window.captureReference=(kind)=>{for(const c of characters){c.root.visible=true;c.root.rotation.y=kind==='three-quarter'?-.38:0;}
if(kind==='face'){characters.forEach((c,i)=>{c.root.visible=i===0;});characters[0].root.position.x=0;camera.left=-.57778;camera.right=.57778;camera.top=.325;camera.bottom=-.325;camera.position.set(0,1.22,5);camera.lookAt(0,1.22,0);camera.updateProjectionMatrix();}
renderer.render(scene,camera);return {calls:renderer.info.render.calls,triangles:renderer.info.render.triangles};};
window.captureReference('lineup');window.ready=true;
</script></body></html>`;
const server=createServer((req,res)=>{
 if(req.url==='/'){res.setHeader('Content-Type','text/html');res.end(html);return;}
 const path=resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));
 if(!path.startsWith(root+sep)){res.writeHead(403).end();return;}
 try{res.setHeader('Content-Type',path.endsWith('.js')?'text/javascript':'application/octet-stream');res.end(readFileSync(path));}catch{res.writeHead(404).end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
let browser;
try{
 browser=await chromium.launch({executablePath:process.env.CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:'+server.address().port+'/');
 try{await page.waitForFunction(()=>window.ready,{},{timeout:15000});}catch(error){throw Error(errors.join('\n') || error.message);}
 writeFileSync(resolve(output,'page-snapshot.txt'),await page.locator('body').ariaSnapshot());
 const captures={};
 for(const kind of ['lineup','three-quarter','face']){captures[kind]=await page.evaluate(kind=>window.captureReference(kind),kind);await page.screenshot({path:resolve(output,'web-'+kind+'.png')});}
 if(errors.length)throw Error(errors.join('\n'));
 writeFileSync(resolve(output,'capture.json'),JSON.stringify({source:'Unmodified local public/game/src/game/character.js and its geometry/material modules',renderer:'Chromium WebGL / Three.js NeutralToneMapping',captures},null,2)+'\n');
 console.log('PASS: original web character geometry, shaders and animation rendered; '+output);
}finally{await browser?.close();server.close();}
