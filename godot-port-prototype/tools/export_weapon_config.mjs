// Export weapon, movement and match parameters from the web game's single source of truth.
// Run: node godot-port-prototype/tools/export_weapon_config.mjs [--check]
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  COLORBLIND_PALETTE,
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
} from '../../public/game/src/config.js';

const payload = {
  schema: 1,
  source: 'public/game/src/config.js',
  game: { title: GAME_TITLE, subtitle: GAME_SUBTITLE, version: VERSION },
  weaponOrder: WEAPON_ORDER,
  weapons: Object.fromEntries(WEAPON_ORDER.map((id) => [id, WEAPONS[id]])),
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
  teams: { palettes: TEAM_PALETTES, colorblind: COLORBLIND_PALETTE, names: TEAM_NAMES },
};
const output = new URL('../assets/weapons.json', import.meta.url);
const serialized = `${JSON.stringify(payload, null, 2)}\n`;
if (process.argv.includes('--check')) {
  if (readFileSync(output, 'utf8') !== serialized) throw new Error('weapons.json differs from config.js; regenerate it');
  console.log(`OK: ${WEAPON_ORDER.length} weapons, ${Object.keys(PLAYER).length} player fields match ${fileURLToPath(output)}`);
} else {
  mkdirSync(new URL('../assets/', import.meta.url), { recursive: true });
  writeFileSync(output, serialized);
  console.log(`Exported ${WEAPON_ORDER.length} weapons and ${Object.keys(PLAYER).length} player fields to ${fileURLToPath(output)}`);
}
