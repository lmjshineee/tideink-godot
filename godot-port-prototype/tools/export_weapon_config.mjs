// Export weapon and movement parameters from the web game's single source of truth.
// Run: node godot-port-prototype/tools/export_weapon_config.mjs [--check]
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { PLAYER, WEAPONS, WEAPON_ORDER, SUB, SPECIALS, MATCH } from '../../public/game/src/config.js';

const payload = {
  schema: 1,
  source: 'public/game/src/config.js',
  weaponOrder: WEAPON_ORDER,
  weapons: Object.fromEntries(WEAPON_ORDER.map((id) => [id, WEAPONS[id]])),
  sub: { bomb: SUB.bomb },
  specials: SPECIALS,
  player: {
    hp: PLAYER.hp,
    inkMax: PLAYER.inkMax,
    inkRefillSwim: PLAYER.inkRefillSwim,
    inkRefillKid: PLAYER.inkRefillKid,
    inkRefillDelay: PLAYER.inkRefillDelay,
    enemyInkDps: PLAYER.enemyInkDps,
    enemyInkDamageCap: PLAYER.enemyInkDamageCap,
    regenDelay: PLAYER.regenDelay,
    regenRate: PLAYER.regenRate,
    regenRateSwim: PLAYER.regenRateSwim,
    respawnTime: PLAYER.respawnTime,
    spawnInvuln: PLAYER.spawnInvuln,
    fallDeathY: PLAYER.fallDeathY,
    radius: PLAYER.radius,
    height: PLAYER.height,
    squidHeight: PLAYER.squidHeight,
    runSpeed: PLAYER.runSpeed,
    squidDrySpeed: PLAYER.squidDrySpeed,
    swimSpeed: PLAYER.swimSpeed,
    enemyInkSpeed: PLAYER.enemyInkSpeed,
    runAccel: PLAYER.runAccel,
    runAccelIn: PLAYER.runAccelIn,
    runInKnee: PLAYER.runInKnee,
    runOutKnee: PLAYER.runOutKnee,
    runOutMin: PLAYER.runOutMin,
    runDecel: PLAYER.runDecel,
    runDecelMin: PLAYER.runDecelMin,
    runDecelKnee: PLAYER.runDecelKnee,
    reverseDecel: PLAYER.reverseDecel,
    reverseAngle: PLAYER.reverseAngle,
    turnRate: PLAYER.turnRate,
    turnRateSlow: PLAYER.turnRateSlow,
    airAccel: PLAYER.airAccel,
    airDecel: PLAYER.airDecel,
    airMinSpeed: PLAYER.airMinSpeed,
    squidAccel: PLAYER.squidAccel,
    squidDecel: PLAYER.squidDecel,
    squidTurn: PLAYER.squidTurn,
    swimAccel: PLAYER.swimAccel,
    swimAccelIn: PLAYER.swimAccelIn,
    swimDecel: PLAYER.swimDecel,
    swimTurn: PLAYER.swimTurn,
    swimOutKnee: PLAYER.swimOutKnee,
    squidAirAccel: PLAYER.squidAirAccel,
    squidAirDecel: PLAYER.squidAirDecel,
    enemyInkDecel: PLAYER.enemyInkDecel,
    enemyInkAccel: PLAYER.enemyInkAccel,
    jumpVel: PLAYER.jumpVel,
    swimJumpVel: PLAYER.swimJumpVel,
    jumpBuffer: PLAYER.jumpBuffer,
    coyoteTime: PLAYER.coyoteTime,
    gravity: PLAYER.gravity,
    fallGravityMul: PLAYER.fallGravityMul,
    apexBand: PLAYER.apexBand,
    maxFall: PLAYER.maxFall,
    climbSpeed: PLAYER.climbSpeed,
    climbAccel: PLAYER.climbAccel,
    climbSideSpeed: PLAYER.climbSideSpeed,
    climbAttachDot: PLAYER.climbAttachDot,
    climbDetachDot: PLAYER.climbDetachDot,
    ledgePopClear: PLAYER.ledgePopClear,
    ledgePopCarry: PLAYER.ledgePopCarry,
    apexGravityMul: PLAYER.apexGravityMul,
  },
  match: {
    durations: MATCH.durations,
    defaultDuration: MATCH.defaultDuration,
    finalCountdown: MATCH.finalCountdown,
  },
};
const output = new URL('../assets/weapons.json', import.meta.url);
const serialized = `${JSON.stringify(payload, null, 2)}\n`;
if (process.argv.includes('--check')) {
  if (readFileSync(output, 'utf8') !== serialized) throw new Error('weapons.json differs from config.js; regenerate it');
  console.log(`OK: ${WEAPON_ORDER.length} weapons match ${fileURLToPath(output)}`);
} else {
  mkdirSync(new URL('../assets/', import.meta.url), { recursive: true });
  writeFileSync(output, serialized);
  console.log(`Exported ${WEAPON_ORDER.length} weapons to ${fileURLToPath(output)}`);
}
