// Translate the original cloth's procedural fragment details, not a replacement design.
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {withOrnaments} from './lib/character_ornaments.mjs';
const sourcePath = '../../public/game/src/game/character-mats.js';
const source = readFileSync(new URL(sourcePath,import.meta.url),'utf8');
const hash = b=>createHash('sha256').update(b).digest('hex');
const sources = Object.fromEntries([sourcePath,'./export_character_materials.mjs','./lib/character_ornaments.mjs'].map(p=>[p,hash(readFileSync(new URL(p,import.meta.url)))]));
const output = new URL('../character_cloth.gdshader',import.meta.url);
const manifest = new URL('../assets/characters/materials.json',import.meta.url);
if(process.argv.includes('--check')){
 const m=JSON.parse(readFileSync(manifest));
 if(JSON.stringify(m.sources)!==JSON.stringify(sources))throw Error('Stale source character materials');
 for(const [file,digest] of Object.entries(m.outputs))if(digest!==hash(readFileSync(new URL('../'+file,import.meta.url))))throw Error('Stale '+file);
 console.log('OK: original cloth/skin/eye plus reproducible cheek-ornament adaptation and per-class PBR; source/output hashes');process.exit(0);
}
function constant(name){const match=source.match(new RegExp('const '+name+' =[^`]*`([\\s\\S]*?)`;'));if(!match)throw Error(name);return match[1];}
const cloth=source.slice(source.indexOf('export function makeClothMaterial'),source.indexOf('// HAIR'));
function block(name){const match=cloth.match(new RegExp(name+': /\\* glsl \\*/`([\\s\\S]*?)`'));if(!match)throw Error(name);return match[1];}
function fragmentScope(functionName){const start=source.indexOf('export function '+functionName);const end=source.indexOf('\nexport function ',start+1);return source.slice(start,end<0?source.length:end);}
function fragmentColor(functionName){const s=fragmentScope(functionName);const match=s.match(/fColor: \/\* glsl \*\/`([\s\S]*?)`/);if(!match)throw Error(functionName);return match[1];}
function adapt(s){
 return s.replace(/uniform vec3 uTeam; uniform vec3 uShirt; uniform vec3 uShorts; uniform vec3 uShoe; uniform vec3 uSole; uniform vec3 uSock; uniform vec3 uStrap; uniform float uPattern;/,'')
 .replace(/varying vec3 vCloth; varying vec2 vIwUv;/,'')
 .replace(/\buTeam\b/g,'team_color.rgb').replace(/\buShirt\b/g,'shirt_color.rgb').replace(/\buShorts\b/g,'shorts_color.rgb').replace(/\buShoe\b/g,'shoe_color.rgb').replace(/\buSole\b/g,'sole_color.rgb').replace(/\buSock\b/g,'sock_color.rgb').replace(/\buStrap\b/g,'strap_color.rgb').replace(/\buPattern\b/g,'float(pattern)')
 .replace(/roughnessFactor/g,'ROUGHNESS');
}
const shader=`shader_type spatial;
render_mode cull_disabled;
// Generated from unmodified character-mats.js; CUSTOM0/1 retain bind-space data.
uniform vec4 team_color : source_color;
uniform vec4 shirt_color : source_color;
uniform vec4 shorts_color : source_color;
uniform vec4 shoe_color : source_color;
uniform vec4 sole_color : source_color;
uniform vec4 sock_color : source_color;
uniform vec4 strap_color : source_color;
uniform int pattern = 0;
varying vec3 vBindPos;
varying float vEx;
varying vec3 vCloth;
varying vec2 vIwUv;
${constant('NOISE')}
${constant('BUMP')}
${adapt(constant('CLOTH_GLSL'))}
void vertex(){vBindPos=CUSTOM0.xyz;vEx=CUSTOM0.w;vCloth=CUSTOM1.xyz;vIwUv=UV;}
void fragment(){
 vec4 diffuseColor=COLOR;
 float iwHurtM=0.0;
 ${adapt(block('fColor'))}
 ${adapt(block('fRough'))}
 METALLIC=iwCls==7.0?1.0:0.0;
 NORMAL=iwBumpN(NORMAL,iwH,VERTEX);
 float cc=iwCls==3.0?0.35:iwCls==4.0?0.05:iwCls==6.0?1.0:iwCls==7.0?0.4:0.0;
 CLEARCOAT=max(cc,iwShine*0.6);
 CLEARCOAT_ROUGHNESS=iwCls==6.0?0.12:0.3;
 AO=iwAO;
 ALBEDO=diffuseColor.rgb;
}
`;
writeFileSync(output,shader);
const skinBody=fragmentColor('makeSkinMaterial').replace(/\buTeam\b/g,'team_color.rgb').replace(/\buMouth\b/g,'mouth').replace(/\buFreckle\b/g,'(freckles?1.0:0.0)')
 .replaceAll('(el + 0.45)','(el + 0.38)').replace('float mhw = 0.11 * width;','float mhw = 0.145 * width;')
 .replace('vec3(0.075, 0.08, 0.11) * lip','vec3(0.016, 0.019, 0.025) * lip').replace('iwVisorH * 0.0022','iwVisorH * 0.0005');
const faceFunctions=constant('FACE_GLSL').replace('(ax - 0.355) / 0.3, (el - 0.15) / 0.29','(ax - 0.355) / 0.36, (el - 0.15) / 0.35');
const skinShader=withOrnaments(`shader_type spatial;
render_mode cull_disabled;
// Source face decals, pores, nose/blush, visor bevel, nails, mouth and shading.
uniform vec4 team_color : source_color;
uniform vec4 mouth=vec4(0.75,1.0,0.0,0.0);
uniform bool freckles=false;
varying vec3 vBindPos;
varying float vEx;
varying vec3 vHead;
${constant('NOISE')}
${constant('BUMP')}
${faceFunctions}
void vertex(){vBindPos=CUSTOM0.xyz;vEx=CUSTOM0.w;vHead=vec3(UV,UV2.x);}
void fragment(){
 vec4 diffuseColor=COLOR;
 ${skinBody}
 ALBEDO=diffuseColor.rgb;
 ROUGHNESS=mix(0.58,0.44,iwVisor);
 ROUGHNESS=mix(ROUGHNESS,0.35,iwHairP);
 ROUGHNESS=mix(ROUGHNESS,0.22,iwNail);
 ROUGHNESS=mix(ROUGHNESS,0.3,iwMouthIn);
 CLEARCOAT=mix(0.04,0.12,iwVisor)+iwNail*0.15;
 CLEARCOAT_ROUGHNESS=0.4;
 NORMAL=iwBumpN(NORMAL,iwH,VERTEX);
 AO=iwAO;
}
`);
const eyeBody=fragmentColor('makeEyeMaterial').replace(/\buLook\b/g,'look').replace(/\buIris2\b/g,'iris_dark.rgb').replace(/\buIris\b/g,'iris_color.rgb');
const eyeShader=`shader_type spatial;
render_mode cull_disabled;
// Source layered iris, capsule pupil, lid/lash, three catchlights and emission.
uniform vec4 iris_color : source_color;
uniform vec4 iris_dark : source_color;
uniform vec2 look=vec2(0.0);
varying vec2 vEyeUv;
varying float vSide;
float iwCircle(vec2 p,vec2 c,float r){float d=length(p-c)-r;float w=max(fwidth(d),1e-4);return 1.0-smoothstep(-w,w,d);}
void vertex(){vEyeUv=UV;vSide=UV2.x;}
void fragment(){
 vec4 diffuseColor=COLOR;
 ${eyeBody}
 ALBEDO=diffuseColor.rgb;
 EMISSION=iwEyeEmit*0.25;
 ROUGHNESS=mix(0.28,0.45,iwEyeRim);
 CLEARCOAT=0.25;
 CLEARCOAT_ROUGHNESS=0.2;
}
`;
writeFileSync(new URL('../character_skin.gdshader',import.meta.url),skinShader);
writeFileSync(new URL('../character_eyes.gdshader',import.meta.url),eyeShader);
writeFileSync(manifest,JSON.stringify({sources,outputs:{'character_cloth.gdshader':hash(shader),'character_skin.gdshader':hash(skinShader),'character_eyes.gdshader':hash(eyeShader)},limitations:'Original skin/eye/cloth and micro-normal height field, with local randomized cheek ornaments replacing the visor; Godot PBR lighting does not duplicate Three.js sheen/neutral tone mapping; hurt/flash/glow remain separate'},null,2)+'\n');
console.log('Exported original cloth, skin and eye fragment details to Godot');
