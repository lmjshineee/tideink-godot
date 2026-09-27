// Export the source map's block definitions without copying them by hand.
// Run: node godot-port-prototype/tools/export_tidewater_map.mjs [--check]
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { registerHooks } from 'node:module';
import { TIDEWATER } from '../../public/game/src/world/maps.js';

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === 'three') {
      return { url: new URL('../../public/game/vendor/three/engine/three.module.js', import.meta.url).href, shortCircuit: true };
    }
    return nextResolve(specifier, context);
  },
});
const { Level } = await import('../../public/game/src/world/level.js');
const level = new Level(TIDEWATER);
const round = (value) => Math.round(value * 1e6) / 1e6;
const vector = (value) => [round(value.x), round(value.y), round(value.z)];

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

const blocks = [...TIDEWATER.single, ...TIDEWATER.half, ...TIDEWATER.half.map(mirror)]
  .map((def, id) => {
    const block = level.blocks[id];
    if (block.id !== id) throw new Error(`Level block order changed at ${id}`);
    return {
      id,
      ...def,
      geometry: { center: vector(block.center), half: vector(block.half), axes: block.axes.map(vector) },
    };
  });
const manifest = {
  schema: 1,
  source: 'public/game/src/world/maps.js:TIDEWATER',
  id: TIDEWATER.id,
  bounds: TIDEWATER.bounds,
  spawnPads: TIDEWATER.spawnPads,
  spawnBarrier: TIDEWATER.spawnBarrier,
  blocks,
};
const output = new URL('../assets/maps/tidewater.json', import.meta.url);
const serialized = `${JSON.stringify(manifest, null, 2)}\n`;

if (process.argv.includes('--check')) {
  const actual = readFileSync(output, 'utf8');
  if (actual !== serialized) throw new Error('tidewater.json differs from maps.js; regenerate it');
  console.log(`OK: ${blocks.length} source blocks match ${fileURLToPath(output)}`);
} else {
  mkdirSync(new URL('../assets/maps/', import.meta.url), { recursive: true });
  writeFileSync(output, serialized);
  console.log(`Exported ${blocks.length} blocks to ${fileURLToPath(output)}`);
}
