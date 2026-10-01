// Export the source map's block definitions without copying them by hand.
// Run: node godot-port-prototype/tools/export_tidewater_map.mjs [--check]
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createRuntimeLevel, vector3 } from './lib/runtime_level.mjs';

const {cliMap}=await import('./lib/arena_layouts.mjs');
const MAP=cliMap();
const mapId=MAP.id;

// Same construction as the running game, so the block list (and the set-dressing
// prop colliders that follow the structural blocks) can never disagree with the
// surfaces export.
const { level, layoutId, dressingItems, colliders } = await createRuntimeLevel(MAP);
const vector = vector3;

function mirror(def) {
  const mirrored = { ...def };
  if (def.kind === 'box') {
    mirrored.min = [-def.max[0], def.min[1], -def.max[2]];
    mirrored.max = [-def.min[0], def.max[1], -def.min[2]];
  } else if (def.kind === 'ramp') {
    mirrored.low = [-def.low[0], def.low[1], -def.low[2]];
    mirrored.high = [-def.high[0], def.high[1], -def.high[2]];
  } else {
    throw new Error(`Unsupported map block: ${def.kind}`);
  }
  if (def.mural) mirrored.mural = def.mural.map((item) => ({ ...item, n: [-item.n[0], item.n[1], -item.n[2]] }));
  if (def.noPaint) mirrored.noPaint = def.noPaint.map((n) => [-n[0], n[1], -n[2]]);
  return mirrored;
}

const structural = [...MAP.single, ...MAP.half, ...MAP.half.map(mirror)];
const blocks = level.blocks.map((block, id) => {
  if (block.id !== id) throw new Error(`Level block order changed at ${id}`);
  const geometry = { center: vector(block.center), half: vector(block.half), axes: block.axes.map(vector) };
  if (id < structural.length) return { id, ...structural[id], geometry };
  // Set-dressing prop collider: hidden and unpaintable, but solid, exactly as
  // level.js:27 builds it. Godot needs these as collision or players walk through
  // benches, crates and pilings that the web game collides with.
  return { id, kind: 'box', hidden: true, solid: true, paint: false, color: '#888888', geometry };
});
const manifest = {
  schema: 1,
  source: ["tidewater","kelpline"].includes(mapId) ? `public/game/src/world/maps.js:${mapId.toUpperCase()}` : `godot-port-prototype/tools/lib/arena_layouts.mjs:${mapId}`,
  id: MAP.id,
  ...(MAP.modulePlan ? {modulePlan:MAP.modulePlan} : {}),
  layout: layoutId,
  bounds: MAP.bounds,
  spawnPads: MAP.spawnPads,
  spawnBarrier: MAP.spawnBarrier,
  dressing: { items: dressingItems, propColliders: colliders.length },
  structuralBlocks: structural.length,
  blocks,
};
const output = new URL(`../assets/maps/${mapId}.json`, import.meta.url);
const serialized = `${JSON.stringify(manifest, null, 2)}\n`;

if (process.argv.includes('--check')) {
  const actual = readFileSync(output, 'utf8');
  if (actual !== serialized) throw new Error('tidewater.json differs from maps.js; regenerate it');
  console.log(`OK: ${structural.length} structural blocks + ${colliders.length} prop colliders match ${fileURLToPath(output)}`);
} else {
  mkdirSync(new URL('../assets/maps/', import.meta.url), { recursive: true });
  writeFileSync(output, serialized);
  console.log(`Exported ${blocks.length} blocks (${structural.length} structural + ${colliders.length} props) to ${fileURLToPath(output)}`);
}
