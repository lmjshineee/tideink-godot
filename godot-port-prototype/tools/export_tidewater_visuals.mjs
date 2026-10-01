// Original Three geometry + browser-generated Canvas art -> standard glTF 2 GLB.
// Build: PLAYWRIGHT_MODULE=/path/to/playwright/index.mjs node this-file.mjs
// --check validates source/output fingerprints without opening a browser.
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
const root = resolve(fileURLToPath(new URL('../../', import.meta.url)));
const mapId=process.argv.find(v=>v.startsWith('--arena='))?.split('=')[1] || (process.argv.includes('--kelpline')?'kelpline':'tidewater');
const output = new URL('../assets/scenery/', import.meta.url);
const sources = ['props.js','dressing.js','decor.js','environment.js','level.js','maps.js','murals.js'].map(n => `public/game/src/world/${n}`)
  .concat(['public/game/src/config.js','public/game/src/core/ctx.js','public/game/vendor/three/engine/three.core.js','public/game/vendor/three/engine/three.module.js','public/game/vendor/three/jsm/utils/BufferGeometryUtils.js',
    'public/game/assets/fonts/TitanOne-latin.woff2','public/game/assets/fonts/Rubik-latin.woff2',
    'godot-port-prototype/tools/lib/arena_layouts.mjs','godot-port-prototype/tools/lib/export_visual_scene.js','godot-port-prototype/tools/export_tidewater_visuals.mjs']);
const hash = data => createHash('sha256').update(data).digest('hex');
const fingerprints = Object.fromEntries(sources.map(p => [p, hash(readFileSync(resolve(root, p)))]));
if (process.argv.includes('--check')) {
  const manifest = JSON.parse(readFileSync(new URL(`${mapId}_visuals.json`, output)));
  if (JSON.stringify(manifest.sources) !== JSON.stringify(fingerprints)) throw new Error('Visual source changed; regenerate tidewater visuals');
  for (const [name, checksum] of Object.entries(manifest.outputs)) if (hash(readFileSync(new URL(name, output))) !== checksum) throw new Error(`Visual output differs: ${name}`);
  if (manifest.items <= 0 || manifest.colliders <= 0) throw new Error('Original placement/collision count changed');
  console.log(`OK: ${manifest.items} original props, ${manifest.meshes} merged visual meshes; source/output hashes match`);
  process.exit(0);
}

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const server = createServer((req, res) => {
  if (req.url === '/') {
    res.setHeader('Content-Type','text/html');
    res.end('<script type="importmap">{"imports":{"three":"/public/game/vendor/three/engine/three.module.js","three/addons/":"/public/game/vendor/three/jsm/"}}</script>');
    return;
  }
  const path = resolve(root, '.' + decodeURIComponent(req.url.split('?')[0]));
  if (!path.startsWith(root + '/') || !existsSync(path)) { res.writeHead(404).end(); return; }
  res.setHeader('Content-Type', ({'.js':'text/javascript','.mjs':'text/javascript','.woff2':'font/woff2'})[extname(path)] || 'application/octet-stream');
  res.end(readFileSync(path));
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ executablePath: process.env.CHROME_BIN || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  const page = await browser.newPage();
  page.on('pageerror', error => console.error(error));
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  const exported = await page.evaluate(async id => (await import('/godot-port-prototype/tools/lib/export_visual_scene.js')).exportScene(id), mapId);
  mkdirSync(output, { recursive: true });
  const gltf = { asset:{version:'2.0',generator:'INKWAVE original scene exporter'},scene:0,scenes:[{nodes:[]}],nodes:[],meshes:[],materials:[],buffers:[{byteLength:0}],bufferViews:[],accessors:[],images:[],textures:[],samplers:[],extensionsUsed:['KHR_materials_unlit'] };
  const chunks = [];
  let byteLength = 0;
  function bufferView(buffer, target) {
    const padding = (4 - buffer.length % 4) % 4;
    const id = gltf.bufferViews.length;
    gltf.bufferViews.push({buffer:0,byteOffset:byteLength,byteLength:buffer.length,...(target?{target}:{})});
    chunks.push(buffer,Buffer.alloc(padding)); byteLength += buffer.length + padding;
    return id;
  }
  function accessor(buffer, size, componentType, positions = false) {
    const count = buffer.length / 4 / size;
    const result = {bufferView:bufferView(buffer, componentType===5125?34963:34962),componentType,count,type:({1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4'})[size]};
    if (positions) {
      result.min = [Infinity,Infinity,Infinity]; result.max = [-Infinity,-Infinity,-Infinity];
      for(let i=0;i<buffer.length/4;i++){const value=buffer.readFloatLE(i*4);if(!Number.isFinite(value))throw new Error('Nonfinite vertex');result.min[i%3]=Math.min(result.min[i%3],value);result.max[i%3]=Math.max(result.max[i%3],value);}
    }
    gltf.accessors.push(result);return gltf.accessors.length-1;
  }
  for (const texture of exported.textures) {
    const id=gltf.images.length;
    gltf.images.push({bufferView:bufferView(Buffer.from(texture.png,'base64')),mimeType:'image/png'});
    gltf.samplers.push({magFilter:9729,minFilter:9987,wrapS:texture.repeat?10497:33071,wrapT:texture.repeat?10497:33071});
    gltf.textures.push({source:id,sampler:id});
  }
  for(const mesh of exported.meshes){
    const m=mesh.material;
    const material={name:m.name,pbrMetallicRoughness:{baseColorFactor:[...m.color,m.opacity??1],metallicFactor:m.metallic,roughnessFactor:m.roughness},doubleSided:m.doubleSided};
    if(m.texture!==null)material.pbrMetallicRoughness.baseColorTexture={index:m.texture};
    if(m.alphaCutoff>0){material.alphaMode='MASK';material.alphaCutoff=m.alphaCutoff;}else if(m.transparent)material.alphaMode='BLEND';
    if(m.unlit)material.extensions={KHR_materials_unlit:{}};
    const materialId=gltf.materials.length;gltf.materials.push(material);
    const attributes={};
    for(const [name,a] of Object.entries(mesh.attributes))attributes[({position:'POSITION',normal:'NORMAL',uv:'TEXCOORD_0',color:'COLOR_0'})[name]]=accessor(Buffer.from(a.data,'base64'),a.size,5126,name==='position');
    const indices=accessor(Buffer.from(mesh.indices,'base64'),1,5125);
    const id=gltf.meshes.length;gltf.meshes.push({name:mesh.name,primitives:[{attributes,indices,material:materialId}]});
    gltf.nodes.push({name:mesh.name,mesh:id});gltf.scenes[0].nodes.push(id);
  }
  gltf.buffers[0].byteLength=byteLength;
  let json=Buffer.from(JSON.stringify(gltf)); json=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,0x20)]);
  const binary=Buffer.concat(chunks),header=Buffer.alloc(12),jh=Buffer.alloc(8),bh=Buffer.alloc(8);
  header.writeUInt32LE(0x46546c67);header.writeUInt32LE(2,4);header.writeUInt32LE(12+8+json.length+8+binary.length,8);
  jh.writeUInt32LE(json.length);jh.writeUInt32LE(0x4e4f534a,4);bh.writeUInt32LE(binary.length);bh.writeUInt32LE(0x004e4942,4);
  const glb=Buffer.concat([header,jh,json,bh,binary]);
  writeFileSync(new URL(`${mapId}_visuals.glb`,output),glb);
  const murals=Buffer.from(exported.murals,'base64');
  writeFileSync(new URL('murals.png',output),murals);
  const manifest={schema:1,items:exported.items,colliders:exported.colliders,meshes:exported.meshes.length,sourceStats:exported.sourceStats,skippedGPUVisuals:exported.skipped,sources:fingerprints,outputs:{[`${mapId}_visuals.glb`]:hash(glb),'murals.png':hash(murals)}};
  writeFileSync(new URL(`${mapId}_visuals.json`,output),JSON.stringify(manifest,null,2)+'\n');
  console.log(`Exported ${exported.items} original props + decor + harbor as ${exported.meshes.length} merged meshes (${(glb.length/1048576).toFixed(1)} MiB)`);
} finally { await browser?.close(); await new Promise(resolve => server.close(resolve)); }
