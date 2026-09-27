// Export the original Level's exposed face IDs and local coordinates verbatim.
// Run: node godot-port-prototype/tools/export_tidewater_surfaces.mjs [--check]
import { registerHooks } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === 'three') {
      return { url: new URL('../../public/game/vendor/three/engine/three.module.js', import.meta.url).href, shortCircuit: true };
    }
    return nextResolve(specifier, context);
  },
});

const [{ Level }, { TIDEWATER }] = await Promise.all([
  import('../../public/game/src/world/level.js'),
  import('../../public/game/src/world/maps.js'),
]);
const level = new Level(TIDEWATER);
const round = (value) => Math.round(value * 1e6) / 1e6;
const vector = (v) => [round(v.x), round(v.y), round(v.z)];
const cellSize = 0.25;
let turfCells = 0;
let gridCells = 0;
const faces = level.faces.map((face) => {
  let grid = null;
  if (face.paintable) {
    const nu = Math.max(1, Math.round(face.su / cellSize));
    const nv = Math.max(1, Math.round(face.sv / cellSize));
    const cu = face.su / nu;
    const cv = face.sv / nv;
    const deadRuns = [];
    const point = face.origin.clone();
    let runStart = -1;
    let runLength = 0;
    for (let j = 0; j < nv; j++) for (let i = 0; i < nu; i++) {
      const index = j * nu + i;
      point.copy(face.origin).addScaledVector(face.u, (i + 0.5) * cu)
        .addScaledVector(face.v, (j + 0.5) * cv).addScaledVector(face.n, 0.06);
      const dead = level.pointInside(point, 0, face.block);
      if (face.turf && !dead) turfCells++;
      if (dead) {
        if (runStart < 0) runStart = index;
        runLength++;
      } else if (runStart >= 0) {
        deadRuns.push([runStart, runLength]);
        runStart = -1;
        runLength = 0;
      }
    }
    if (runStart >= 0) deadRuns.push([runStart, runLength]);
    gridCells += nu * nv;
    grid = { nu, nv, cu: round(cu), cv: round(cv), deadRuns };
  }
  return {
    id: face.id,
    block: face.block,
    n: vector(face.n),
    u: vector(face.u),
    v: vector(face.v),
    origin: vector(face.origin),
    su: round(face.su),
    sv: round(face.sv),
    paintable: face.paintable,
    turf: face.turf,
    wall: face.wall,
    grid,
  };
});
const payload = {
  schema: 1,
  source: 'public/game/src/world/level.js:Level._buildFaces',
  id: TIDEWATER.id,
  blockCount: level.blocks.length,
  cellSize,
  gridCells,
  turfCells,
  faces,
};
const output = new URL('../assets/maps/tidewater_surfaces.json', import.meta.url);
const serialized = `${JSON.stringify(payload, null, 2)}\n`;

if (process.argv.includes('--check')) {
  if (readFileSync(output, 'utf8') !== serialized) throw new Error('tidewater_surfaces.json differs from Level; regenerate it');
  console.log(`OK: ${faces.length} source faces match ${fileURLToPath(output)}`);
} else {
  mkdirSync(new URL('../assets/maps/', import.meta.url), { recursive: true });
  writeFileSync(output, serialized);
  console.log(`Exported ${faces.length} faces to ${fileURLToPath(output)}`);
}
