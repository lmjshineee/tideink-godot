// Shared builder for the Level that the *running* game uses.
//
// Why this exists: the runtime builds its Level with the set-dressing prop
// colliders (public/game/src/main.js:188-199). Solid props hand back collision
// boxes; level.js turns them into hidden solid blocks (level.js:27). They are
// invisible and have no faces, but physics/nav/paint all see them, and the cells
// they bury are excluded from the turf denominator.
//
// export_tidewater_surfaces.mjs used to build `new Level(TIDEWATER)` with no
// colliders. That inflated turfCells from 69,366 to 70,180 (+1.16 %), so the
// port's coverage% disagreed with the game in every match, and it also silently
// dropped the 82 solid prop boxes from the level. Every exporter must therefore
// go through this function; if the two ever disagree again, add an assertion
// here rather than duplicating the construction.
import { registerHooks } from 'node:module';

const VENDOR = new URL('../../../public/game/vendor/three/', import.meta.url);

// The web game imports the vendored three build (and one addon, from props.js).
registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === 'three') {
      return { url: new URL('engine/three.module.js', VENDOR).href, shortCircuit: true };
    }
    if (specifier.startsWith('three/addons/')) {
      return {
        url: new URL(`jsm/${specifier.slice('three/addons/'.length)}`, VENDOR).href,
        shortCircuit: true,
      };
    }
    return nextResolve(specifier, context);
  },
});

/**
 * @param {object} layoutDef one entry of public/game/src/world/maps.js (e.g. TIDEWATER)
 * @returns {Promise<{level: object, layoutId: string, dressingItems: number, colliders: Array}>}
 */
export async function createRuntimeLevel(layoutDef) {
  const [{ Level }, { dressingFor }, { PropKit }, THREE] = await Promise.all([
    import('../../../public/game/src/world/level.js'),
    import('../../../public/game/src/world/dressing.js'),
    import('../../../public/game/src/world/props.js'),
    import('three'),
  ]);

  // main.js uses `map.layout || map.id`; the tidewater layout also backs "sunset".
  const layoutId = layoutDef.layout || layoutDef.id;

  const items = layoutDef.dressing || dressingFor(layoutId);
  const propKit = new PropKit(new THREE.Scene(), { castShadow: true, quality: 'high' });
  const colliders = [];
  for (const item of items) {
    const result = propKit.add(item.type, item);
    if (result && result.colliders) colliders.push(...result.colliders);
  }
  propKit.dispose?.();

  if (items.length === 0 || colliders.length === 0) {
    // Failing loudly is the point: exporting a level without the prop colliders is
    // the exact defect this module replaced, and it is invisible in the output.
    throw new Error(`No set dressing colliders for layout "${layoutId}"; the exported level would not match the game`);
  }

  return { level: new Level(layoutDef, colliders), layoutId, dressingItems: items.length, colliders };
}

/** Rounds to the precision used in every exported JSON coordinate. */
export function round6(value) {
  return Math.round(value * 1e6) / 1e6;
}

/** three.js Vector3 -> [x, y, z] at export precision. */
export function vector3(value) {
  return [round6(value.x), round6(value.y), round6(value.z)];
}
