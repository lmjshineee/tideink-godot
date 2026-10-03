// Export original web weapon SVGs and local INKWAVE ability SVGs for Godot.
// Run from anywhere:
//   node godot-port-prototype/tools/export_ui_icons.mjs           # 写入 assets/ui/*.svg
//   node godot-port-prototype/tools/export_ui_icons.mjs --check   # 只校验，不写文件
//
// --check：生成物与网页武器／本地图标生成器不一致时输出差异并非 0 退出。
// 该模式存在的原因是这个脚本过去总是写盘，任何把 --check 当作只读的调用方
// 都会意外改动素材（mtime 变了但内容未变）。现在 --check 保证不碰文件系统。
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { WEAPON_ICONS } from '../../public/game/src/ui/ui-icons.js';
import { ABILITY_ICONS } from './ui_ability_icons.mjs';

const checkOnly = process.argv.includes('--check');
const output = new URL('../assets/ui/', import.meta.url);
if (!checkOnly) mkdirSync(output, { recursive: true });

const inner=svg=>svg.replace(/<svg[^>]*>/,'').replace('</svg>','');
const derived={
 bow:`<svg viewBox="0 0 64 64"><path d="M18 5 Q45 32 18 59 M18 5 L27 32 L18 59 M7 32 H58 M48 24 L59 32 L48 40" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round"/></svg>`,
 canopy:`<svg viewBox="0 0 64 64"><path d="M6 28 Q32 1 58 28 L47 30 L37 27 L27 31 L17 27 Z" fill="currentColor"/><path d="M32 29 V48 Q32 60 20 52" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round"/></svg>`,
 disc:`<svg viewBox="0 0 64 64"><defs><path id="blade" d="M29 27 L46 8 L42 27 L58 36 L38 37 L32 33 Z"/></defs><g fill="currentColor"><use href="#blade"/><use href="#blade" transform="rotate(90 32 32)"/><use href="#blade" transform="rotate(180 32 32)"/><use href="#blade" transform="rotate(270 32 32)"/></g><circle cx="32" cy="32" r="6" stroke="currentColor" stroke-width="4" fill="none"/></svg>`,
 dualie:`<svg viewBox="0 0 64 64"><g transform="translate(2 0) scale(.72)">${inner(WEAPON_ICONS.shooter)}</g><g transform="translate(17 17) scale(.72)">${inner(WEAPON_ICONS.shooter)}</g></svg>`,
 heavy:WEAPON_ICONS.shooter.replace('</svg>','<path d="M 44 22 L 60 22 L 60 29 L 44 29 Z" fill="currentColor"/></svg>'),
 rapid:WEAPON_ICONS.blaster.replace('</svg>','<path d="M 5 48 L 14 48 M 3 54 L 13 54" fill="none" stroke="currentColor" stroke-width="3"/></svg>')
};
const sources = Object.entries({...WEAPON_ICONS,...derived,...ABILITY_ICONS});
let mismatched = 0;

for (const [name, markup] of sources) {
  const icon = markup
    .replace(/<svg[^>]*viewBox="([^"]+)"[^>]*>/, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$1" width="128" height="128">')
    .replaceAll('currentColor', name in ABILITY_ICONS ? '#ffffff' : '#ff8a14');
  if (!icon.startsWith('<svg xmlns=') || icon.includes('currentColor')) {
    throw new Error(`Could not export ${name}`);
  }
  const target = new URL(`${name}.svg`, output);
  const expected = `${icon}\n`;
  if (checkOnly) {
    let actual = null;
    try {
      actual = readFileSync(target, 'utf8');
    } catch {
      actual = null;
    }
    if (actual !== expected) {
      console.error(`MISMATCH: ${fileURLToPath(target)}`);
      mismatched++;
    }
    continue;
  }
  writeFileSync(target, expected);
  console.log(fileURLToPath(target));
}

if (checkOnly) {
  if (mismatched > 0) {
    console.error(`FAIL: ${mismatched}/${sources.length} icons differ from their source generators`);
    process.exit(1);
  }
  console.log(`OK: ${sources.length} weapon and ability icons match assets/ui/*.svg`);
}
