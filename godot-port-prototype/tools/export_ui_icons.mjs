// Export the original procedural weapon SVGs as Godot-importable assets.
// Run from anywhere: node godot-port-prototype/tools/export_ui_icons.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { WEAPON_ICONS } from '../../public/game/src/ui/ui-icons.js';

const output = new URL('../assets/ui/', import.meta.url);
mkdirSync(output, { recursive: true });

for (const [name, markup] of Object.entries(WEAPON_ICONS)) {
  const icon = markup
    .replace(/<svg[^>]*viewBox="([^"]+)"[^>]*>/, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$1" width="128" height="128">')
    .replaceAll('currentColor', '#ff8a14');
  if (!icon.startsWith('<svg xmlns=') || icon.includes('currentColor')) {
    throw new Error(`Could not export ${name}`);
  }
  writeFileSync(new URL(`${name}.svg`, output), `${icon}\n`);
  console.log(fileURLToPath(new URL(`${name}.svg`, output)));
}
