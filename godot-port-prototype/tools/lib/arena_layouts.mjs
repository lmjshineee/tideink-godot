// Original INKWAVE stages inspired by market / gallery / bridge lane structures.
// All geometry uses the existing Level / Physics / Paint / NavGraph adapters.
import {TIDEWATER,KELPLINE,PATTERN} from '../../../public/game/src/world/maps.js';
const B=(x0,x1,y0,y1,z0,z1,o={})=>({kind:'box',min:[x0,y0,z0],max:[x1,y1,z1],color:'#d9dfe0',pattern:PATTERN.tiles,...o});
const R=(low,high,width,o={})=>({kind:'ramp',low,high,width,thickness:.6,color:'#c7c2b8',pattern:PATTERN.hazard,...o});
function props(items){return items.flatMap(item=>[item,{...item,pos:[-item.pos[0],item.pos[1],-item.pos[2]],rotY:(item.rotY||0)+Math.PI,team:1}]);}
function arena(id,w,l,ground,extraSingle,extraHalf,dressing){
 return {id,bounds:{minX:-w,maxX:w,minZ:-l,maxZ:l},spawnPads:[[0,ground+2,-l+5],[0,ground+2,l-5]],spawnBarrier:4.2,
 single:[B(-w,w,ground-1.2,ground,-l,l),...extraSingle],
 half:[B(-w,w,ground,ground+3.6,-l,-l+.6,{color:'#ece4d4',pattern:PATTERN.concrete}),B(-7,7,ground,ground+2,-l+.6,-l+10,{pattern:PATTERN.spawn}),R([0,ground,-l+15],[0,ground+2,-l+10],5.2),R([-13,ground,-l+5],[-7,ground+2,-l+5],4),R([13,ground,-l+5],[7,ground+2,-l+5],4),B(-w,-w+.5,ground,ground+.8,-l+.6,l-.6,{pattern:PATTERN.metal}),...extraHalf],
 decor:{lamps:[[-w+1,-l+2],[-w+1,-12],[w-1,-12]],palms:[],flags:[[-6,ground+2,-l+3],[6,ground+2,-l+3]]},
 dressing:props([{type:'banner',pos:[-7.5,ground+2,-l+8],team:0},{type:'speaker',pos:[6,ground+2,-l+3]},{type:'bunting',pos:[-7,ground+5,-l+1],length:14,team:0},...dressing])};
}
// Market: staggered stalls interrupt the ground lane; a one-storey rooftop
// flank enters from the back and exits sideways into the centre. No generic
// centre mound: close combat and roof-to-alley crossfire are the defining play.
export const MARKET=arena('coral_market',22,38,0,[
 B(-3.2,-.6,0,2.2,-4.4,-1.5,{pattern:PATTERN.wood,color:'#b98f66'}),
 B(.6,3.2,0,2.2,1.5,4.4,{pattern:PATTERN.wood,color:'#b98f66'})
],[
 B(-18,-9,0,3.4,-16,-6,{color:'#dcc48e',pattern:PATTERN.concrete}),
 R([-13.5,0,-28],[-13.5,3.4,-16],4.4,{color:'#dcc48e'}),
 R([-3,0,-6],[-9,3.4,-6],4,{color:'#dcc48e'}),
 B(-16,-14,3.4,4.4,-11,-9,{pattern:PATTERN.metalpanel,color:'#68989b'}),
 B(6,11,0,2.2,-22,-18,{color:'#8fb3b1',pattern:PATTERN.tiles}),
 B(12,17,0,1.25,-11,-7,{pattern:PATTERN.wood,color:'#b98f66'}),
 B(3,5,0,1.1,-15,-13,{pattern:PATTERN.wood,color:'#dc8760'})
],[{type:'awning',pos:[-8.85,2.9,-13],rotY:Math.PI/2,width:6},{type:'vending',pos:[-8.4,0,-16],rotY:Math.PI/2},{type:'sign',pos:[-13.5,3.55,-6],width:6,variant:1},{type:'awning',pos:[5.85,2,-20],rotY:-Math.PI/2,width:4},{type:'barrel',pos:[19,0,-20]},{type:'bench',pos:[19,0,-9],rotY:-Math.PI/2},{type:'stringlights',pos:[-18,0,-21],length:36,height:5.7,sag:.65}]);
Object.assign(MARKET.single[0],{pattern:PATTERN.pavers,color:'#c0b3a1'});
export const GALLERY=arena('prism_gallery',25,36,0,[B(-6,6,0,3,-8,8),B(-11,11,5.45,6,-6,6,{color:'#b3abd0',pattern:PATTERN.glasstile}),B(-1.2,1.2,6,7.2,-1.2,1.2,{color:'#8fb3b1',pattern:PATTERN.glasstile})],[
 R([0,0,-18],[0,3,-8],4.5),B(-11,-6,0,3,-22,-14,{color:'#ece4d4'}),R([-8.5,0,-30],[-8.5,3,-22],4),R([-8.5,3,-14],[-8.5,6,-6],4),B(-19,-11,0,.8,-18,-8,{color:'#ece4d4'}),R([-15,0,-23],[-15,.8,-18],4),B(8,9,0,2.8,-18,-8,{color:'#8fb3b1',pattern:PATTERN.concrete}),B(13,18,0,1.2,-5,1,{color:'#dcc48e'}),B(-8,-6.5,0,1.3,-23,-21,{pattern:PATTERN.wood})
],[{type:'planter',pos:[20,0,-13],variant:1},{type:'bench',pos:[-22,0,-15],rotY:Math.PI/2},{type:'poster',pos:[8,1.5,-13],rotY:-Math.PI/2,count:3,variant:8},{type:'sign',pos:[0,3.4,-35.3],width:7,variant:0},{type:'vending',pos:[20,0,-23],rotY:-Math.PI/2}]);
// Viaduct: a genuinely hollow six-metre deck. The protected ground shortcut
// trades away sight of the bridge; exposed side ramps let a flank retake it.
export const BRIDGE=arena('viaduct',18,46,0,[
 B(-6,6,5.5,6,-10,10,{pattern:PATTERN.asphalt,color:'#778694'}),
 ...[-1,1].flatMap(s=>[B(-6,-4.6,0,5.5,s*8-1,s*8+1,{pattern:PATTERN.concrete,color:'#b2bfca'}),B(4.6,6,0,5.5,s*8-1,s*8+1,{pattern:PATTERN.concrete,color:'#b2bfca'})]),
 B(-1.1,1.1,0,1.4,-1,1,{pattern:PATTERN.container,color:'#c47a5e'})
],[
 R([0,2,-36],[0,3,-24],6),B(-4,4,0,3,-24,-20,{pattern:PATTERN.asphalt,color:'#778694'}),
 R([0,3,-20],[0,6,-10],5.5,{color:'#a0b1c1'}),
 R([12,0,-30],[12,6,-10],4.2,{color:'#a0b1c1'}),
 B(6,14,5.5,6,-10,-5,{pattern:PATTERN.metalpanel,color:'#849aaf'}),
 B(-6,-5.4,6,7.1,-6,0,{pattern:PATTERN.metalpanel,color:'#5f7592'}),
 B(.7,3,6,6.9,-4.8,-3.6,{pattern:PATTERN.metalpanel,color:'#5f7592'}),
 B(-15,-13,0,1.2,-22,-20,{pattern:PATTERN.container,color:'#c47a5e'}),
 B(9,11,0,1.4,-27,-24,{pattern:PATTERN.container,color:'#5f7592'})
],[{type:'lightpole',pos:[-16.7,0,-22]},{type:'pipes',pos:[-16,0,-10],length:8,rotY:Math.PI/2},{type:'barrel',pos:[15,0,-16]},{type:'sign',pos:[0,3.5,-45.3],width:7,variant:1},{type:'cone',pos:[3,3,-22]},{type:'bunting',pos:[-6,8,-8],length:12,team:0}]);
Object.assign(BRIDGE.single[0],{pattern:PATTERN.concrete,color:'#b2b8be'});
// Centre access now leaves the 2m spawn apron directly for the long approach.
BRIDGE.half.splice(2,1);
function variant(source,index){
 const map=structuredClone(source);map.id=`${source.id}_v${index}`;map.layout=source.id;
 const cover=index===1?[B(-4,-2,0,1.0,-19,-17,{pattern:PATTERN.wood,color:'#c9a27c'}),B(2,4,0,1.0,-12,-10,{pattern:PATTERN.wood,color:'#c9a27c'})]:[B(-7,-6,0,.85,-11,-7,{pattern:PATTERN.concrete,color:'#b3abd0'}),B(10,12,0,1.1,-25,-23,{pattern:PATTERN.wood,color:'#c9a27c'})];
 map.half.push(...cover);return map;
}
// Connector envelope is fixed: spawn apron -> three approaches -> central zone.
// Central and paired side modules are independently composed, with a continuous ground fallback.
export const MODULES={
 central:[
  {name:'低掩体广场',blocks:[B(-2,2,0,1.2,-2,2,{pattern:PATTERN.wood})]},
  {name:'三米双坡台',blocks:[B(-6,6,0,3,-6,6,{pattern:PATTERN.glasstile}),R([0,0,-17],[0,3,-6],5),R([0,0,17],[0,3,6],5)]},
  {name:'双翼高台',blocks:[B(-10,-4,0,2,-7,7),B(4,10,0,2,-7,7),R([-7,0,-16],[-7,2,-7],4),R([7,0,16],[7,2,7],4)]}
 ],
 flank:[
  {name:'货箱侧路',blocks:[B(-18,-15,0,1.1,-23,-20,{pattern:PATTERN.wood}),B(14,17,0,1.1,-19,-16,{pattern:PATTERN.wood})]},
  {name:'二米观景台',blocks:[B(-22,-16,0,2,-23,-13,{color:'#b3abd0'}),R([-19,0,-31],[-19,2,-23],4),B(14,18,0,1.2,-18,-12)]},
  {name:'回廊与矮墙',blocks:[B(-19,-13,0,1.4,-24,-15),R([-16,0,-31],[-16,1.4,-24],4),B(15,15.8,0,1.5,-24,-13),B(12,15.8,0,.8,-13,-12)]}
 ]
};
function harbor(index){
 const central=Math.floor(index/3),flank=index%3;
 const map=arena('modular_harbor',26,42,0,MODULES.central[central].blocks,MODULES.flank[flank].blocks,[
  {type:'barrel',pos:[23,0,-26]},{type:'bench',pos:[-23,0,-12],rotY:Math.PI/2},{type:'sign',pos:[0,3.8,-41.3],width:8,variant:1},{type:'stringlights',pos:[-23,0,-34],length:46,height:5,sag:1}]);
 map.modulePlan={central,flank,seedSlot:index,connectorWidth:4,mirrored:true};
 if(index){map.id=`modular_harbor_v${index}`;map.layout='modular_harbor';}
 return map;
}
export const HARBOR=harbor(0);
export const GARDEN=arena('terrace_garden',27,40,0,[B(-7,7,0,3,-8,8,{color:'#bccca7'}),B(-9,9,5.4,6,-5,5,{color:'#c7bcdd',pattern:PATTERN.glasstile})],[
 R([0,0,-20],[0,3,-8],5),B(-17,-10,0,3,-24,-15,{color:'#b3c5aa'}),R([-13.5,0,-33],[-13.5,3,-24],4),R([-13.5,3,-15],[-8,6,-5],4),B(14,21,0,1.5,-23,-13,{color:'#e1d2ae'}),R([17.5,0,-31],[17.5,1.5,-23],4),B(-24,-22,0,1.2,-12,-10)
],[{type:'planter',pos:[23,0,-15],variant:1},{type:'bench',pos:[-24,0,-18],rotY:Math.PI/2},{type:'sign',pos:[0,3.8,-39.3],width:8,variant:0},{type:'vending',pos:[23,0,-27],rotY:-Math.PI/2}]);
export const MODULAR_MAPS=[HARBOR,...Array.from({length:8},(_,i)=>harbor(i+1))];
export const ARENAS=[MARKET,GALLERY,BRIDGE,variant(TIDEWATER,1),variant(TIDEWATER,2),variant(KELPLINE,1),variant(KELPLINE,2),...MODULAR_MAPS,GARDEN];
export const ALL_MAPS=[TIDEWATER,KELPLINE,...ARENAS];
export const getMap=id=>ALL_MAPS.find(map=>map.id===id);
export function cliMap(args=process.argv){const id=args.find(v=>v.startsWith('--arena='))?.split('=')[1];return id?getMap(id):(args.includes('--kelpline')?KELPLINE:TIDEWATER);}
