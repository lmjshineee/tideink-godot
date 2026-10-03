// Export weapon, movement and match parameters from the web game's single source of truth.
// Run: node godot-port-prototype/tools/exporters/export_weapon_config.mjs [--check]
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  COLORBLIND_PALETTE,
  BOT_NAMES,
  GAME_SUBTITLE,
  GAME_TITLE,
  MATCH,
  PLAYER,
  SPECIALS,
  SUB,
  TEAM_NAMES,
  TEAM_PALETTES,
  VERSION,
  WEAPONS,
  WEAPON_ORDER,
} from '../../../public/game/src/config.js';

// The demo UI is Chinese, and the web reaches those labels through its own i18n table
// rather than through config.js. public/game/src/i18n.js keeps that table in a
// module-private `const ZH = {...}` with no export of its own, so it is scanned textually
// here — and only for the names this export actually carries, so the JSON stays small.
// Without this the port had to hand-copy the translations, which it did: two of the four
// weapon labels disagreed with the web (射手/滚筒 against 喷溅枪/滚筒刷).
function chineseFor(names) {
  const src = readFileSync(new URL('../../../public/game/src/i18n.js', import.meta.url), 'utf8');
  const start = src.indexOf('const ZH = {');
  const end = src.indexOf('\n};', start);
  if (start < 0 || end < 0) throw new Error('i18n.js: could not find the ZH table');
  const table = new Map();
  // Single-quoted JS string literals, with escapes; entry values may span lines.
  const pair = /'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)'/g;
  const unescape = (text) => text.replace(/\\'/g, "'").replace(/\\\\/g, '\\');
  for (const [, en, zh] of src.slice(start, end).matchAll(pair)) table.set(unescape(en), unescape(zh));
  const missing = names.filter((name) => !table.has(name));
  if (missing.length) throw new Error(`i18n.js has no Chinese text for: ${missing.join(', ')}`);
  return Object.fromEntries(names.map((name) => [name, table.get(name)]));
}

// Chinese labels for every name this export carries, grouped like the export itself so a
// reader in Godot looks them up with the same id it already has.
const TEXT = (() => {
  const groups = {
    weapons: WEAPON_ORDER.map((id) => [id, WEAPONS[id].name]),
    specials: Object.keys(SPECIALS).map((id) => [id, SPECIALS[id].name]),
    sub: [['bomb', SUB.bomb.name]],
  };
  const chinese = chineseFor(Object.values(groups).flat().map(([, name]) => name));
  return {
    ...Object.fromEntries(Object.entries(groups).map(([group, entries]) => [
      group, Object.fromEntries(entries.map(([id, name]) => [id, chinese[name]])),
    ])),
    // Palette labels, keyed by palette id: menus.js shows a palette's own names and only
    // falls back to TEAM_NAMES, and i18n translates those English names.
    teams: Object.fromEntries([...TEAM_PALETTES, COLORBLIND_PALETTE].map((palette) => [
      palette.id, palette.names.map((name) => chineseFor([name])[name]),
    ])),
  };
})();

const payload = {
  schema: 1,
  source: 'public/game/src/config.js',
  game: { title: GAME_TITLE, subtitle: GAME_SUBTITLE, version: VERSION },
  weaponOrder: WEAPON_ORDER,
  // Display text for the ids above, from the web's i18n table. Keyed by id, so the port
  // never needs the English brand name to reach the Chinese label.
  text: TEXT,
  // Effective spread inputs. weapons.js:57-64 keeps the blaster's cone and all the
  // bloom constants as code defaults instead of config.js values, so a port that
  // only reads config.js has nowhere to get them; the effective numbers are exported
  // here so assets/weapons.json stays the single source on the Godot side.
  weapons: Object.fromEntries(WEAPON_ORDER.map((id) => {
    const w = WEAPONS[id];
    return [id, {
      ...w,
      spreadBaseGround: w.kind === 'shooter' ? w.spreadGround : (w.kind === 'blaster' ? (w.spread ?? 1.2) : 0),
      spreadBaseAir: w.kind === 'shooter' ? w.spreadAir : (w.kind === 'blaster' ? (w.spreadAir ?? 4) : 0),
      spreadFirst: w.spreadFirst ?? 0.45,
      bloomPerShot: w.bloomPerShot ?? 0.3,
      bloomRecover: w.bloomRecover ?? 0.28,
    }];
  })),
  sub: { bomb: SUB.bomb },
  specials: SPECIALS,
  // Whole objects are spread rather than hand-listing keys. The previous whitelist
  // silently dropped 25 of PLAYER's 88 fields (stepUp, stepDown, footRadius,
  // ledgeAssist, squidBodyLift, squidStepUp, hardLand*, the twelve facing-spring
  // values, emergeDelay, fireBuffer, waterY) and nothing could detect it: the port
  // looked complete while whole systems had no parameters to read.
  //
  // accelGround/accelAir/accelSwim are exported for completeness but are unused by
  // the web game itself (superseded by runAccel/airAccel/swimAccel).
  player: { ...PLAYER },
  match: { ...MATCH },
  bots: { names: BOT_NAMES },
  teams: { palettes: TEAM_PALETTES, colorblind: COLORBLIND_PALETTE, names: TEAM_NAMES },
};
const output = new URL('../../assets/weapons.json', import.meta.url);
const serialized = `${JSON.stringify(payload, null, 2)}\n`;
if (process.argv.includes('--check')) {
  if (readFileSync(output, 'utf8') !== serialized) throw new Error('weapons.json differs from config.js; regenerate it');
  console.log(`OK: ${WEAPON_ORDER.length} weapons, ${Object.keys(PLAYER).length} player fields, `
      + `${Object.keys(TEXT.weapons).length} Chinese labels match ${fileURLToPath(output)}`);
} else {
  mkdirSync(new URL('../../assets/', import.meta.url), { recursive: true });
  writeFileSync(output, serialized);
  console.log(`Exported ${WEAPON_ORDER.length} weapons and ${Object.keys(PLAYER).length} player fields to ${fileURLToPath(output)}`);
}
