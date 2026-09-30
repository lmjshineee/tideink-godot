// Runs in a local browser: use the ORIGINAL geometry builders and Canvas art.
import * as THREE from '/public/game/vendor/three/engine/three.module.js';
import { mergeGeometries } from '/public/game/vendor/three/jsm/utils/BufferGeometryUtils.js';
import { PropKit } from '/public/game/src/world/props.js';
import { dressingFor } from '/public/game/src/world/dressing.js';
import { Decor } from '/public/game/src/world/decor.js';
import { Environment } from '/public/game/src/world/environment.js';
import { Level } from '/public/game/src/world/level.js';
import { TIDEWATER } from '/public/game/src/world/maps.js';
import { createMuralTexture } from '/public/game/src/world/murals.js';

function base64(array) {
  const bytes = new Uint8Array(array.buffer, array.byteOffset, array.byteLength);
  let result = '';
  for (let i = 0; i < bytes.length; i += 16384) result += String.fromCharCode(...bytes.subarray(i, i + 16384));
  return btoa(result);
}

export async function exportScene() {
  const scene = new THREE.Scene();
  const kit = new PropKit(scene, { quality: 'high' });
  const items = dressingFor('tidewater');
  const colliders = items.flatMap(item => kit.add(item.type, item).colliders);
  kit.build();
  // Allow loadFonts() to finish and redraw the original sign atlas.
  await document.fonts.ready;
  await new Promise(resolve => setTimeout(resolve, 100));
  const level = new Level(TIDEWATER, colliders);
  const decor = new Decor(scene, level);
  decor.setTeamColors(kit.teamColors);

  // Export original static geometry without constructing a WebGL renderer.
  // Sea/sky and runtime GPU effects are recreated in Godot, not serialized.
  class StaticEnvironment extends Environment {
    _buildSky() {}
    _buildSea() {}
    setTheme() {}
  }
  const environment = new StaticEnvironment(null, scene, { bounds: TIDEWATER.bounds });
  scene.updateMatrixWorld(true);
  const buckets = new Map(), skipped = [];
  const textureIds = new Map(), textures = [];
  function textureId(map) {
    if (!map?.image?.toDataURL) return null;
    if (!textureIds.has(map)) {
      textureIds.set(map, textures.length);
      textures.push({ png: map.image.toDataURL('image/png').split(',')[1], repeat: map.wrapS === THREE.RepeatWrapping });
    }
    return textureIds.get(map);
  }
  scene.traverseVisible(object => {
    if (!object.isMesh) return;
    const material = object.material;
    // Original translucent blob shadows are superseded by Godot's real shadows.
    if (material.isShaderMaterial || object.name === 'props:blob') { skipped.push(object.name); return; }
    if (Array.isArray(material)) throw new Error('Unexpected multi-material geometry');
    const parentGroup = object.name.startsWith('props:') ? 'props' : object.parent === environment.root ? 'harbor' : 'decor';
    const key = parentGroup + ':' + material.uuid;
    if (!buckets.has(key)) buckets.set(key, {
      name: object.name || parentGroup, parts: [],
      material: {
        name: object.name || parentGroup, color: material.color?.toArray() || [1,1,1],
        roughness: material.roughness ?? 0.7, metallic: material.metalness ?? 0,
        doubleSided: material.side === THREE.DoubleSide,
        alphaCutoff: material.alphaTest || 0, opacity: material.opacity,
        transparent: material.transparent, unlit: !!material.isMeshBasicMaterial,
        texture: textureId(material.map),
      },
    });
    const bucket = buckets.get(key);
    const count = object.isInstancedMesh ? object.count : 1;
    for (let i = 0; i < count; i++) {
      const matrix = object.matrixWorld.clone();
      const tint = new THREE.Color(1,1,1);
      if (object.isInstancedMesh) {
        const local = new THREE.Matrix4(); object.getMatrixAt(i, local); matrix.multiply(local);
        if (object.instanceColor) object.getColorAt(i, tint);
      }
      let geometry = object.geometry.clone();
      if (!geometry.index) geometry.setIndex(Array.from({ length: geometry.attributes.position.count }, (_, n) => n));
      geometry.applyMatrix4(matrix);
      // Normalize attributes for merging while retaining original vertex colors.
      const n = geometry.attributes.position.count;
      if (!geometry.attributes.normal) geometry.computeVertexNormals();
      if (!geometry.attributes.uv) geometry.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(n * 2), 2));
      const color = new Float32Array(n * 4), source = geometry.attributes.color;
      const cloth = object.name.includes('cloth') || object.name === 'props:flags' || object.name === 'props:banners';
      for (let j = 0; j < n; j++) {
        color[j*4] = (source?.getX(j) ?? 1) * tint.r;
        color[j*4+1] = (source?.getY(j) ?? 1) * tint.g;
        color[j*4+2] = (source?.getZ(j) ?? 1) * tint.b;
        color[j*4+3] = cloth ? (geometry.attributes.flex?.getX(j) ?? object.geometry.attributes.uv?.getX(j) ?? 1) : 1;
        if (material.map?.flipY) geometry.attributes.uv.setY(j, 1 - geometry.attributes.uv.getY(j));
      }
      geometry.setAttribute('color', new THREE.BufferAttribute(color, 4));
      for (const name of Object.keys(geometry.attributes)) if (!['position','normal','uv','color'].includes(name)) geometry.deleteAttribute(name);
      if (matrix.determinant() < 0) for (let j = 0; j < geometry.index.count; j += 3) {
        const b = geometry.index.getX(j+1); geometry.index.setX(j+1, geometry.index.getX(j+2)); geometry.index.setX(j+2, b);
      }
      bucket.parts.push(geometry);
    }
  });
  const meshes = [];
  for (const bucket of buckets.values()) {
    const geometry = mergeGeometries(bucket.parts);
    if (!geometry) throw new Error('Failed to merge ' + bucket.name);
    const attributes = {};
    for (const [name, attribute] of Object.entries(geometry.attributes)) attributes[name] = { size: attribute.itemSize, count: attribute.count, data: base64(new Float32Array(attribute.array)) };
    meshes.push({ name: bucket.name, material: bucket.material, attributes, indices: base64(new Uint32Array(geometry.index.array)) });
  }
  const displayFont = new FontFace('Titan One', 'url(/public/game/assets/fonts/TitanOne-latin.woff2)');
  document.fonts.add(await displayFont.load());
  const muralTexture = await createMuralTexture();
  return { meshes, textures, murals: muralTexture.image.toDataURL('image/png').split(',')[1], items: items.length, colliders: colliders.length, skipped, sourceStats: kit.stats() };
}
