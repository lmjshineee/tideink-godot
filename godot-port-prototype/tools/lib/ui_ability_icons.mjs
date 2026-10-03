// Original INKWAVE symbols. A 64px grid and generous gaps keep them legible at 24px.
const icon = body => `<svg viewBox="0 0 64 64"><g fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">${body}</g></svg>`;
const drop = '<path d="M32 8 C29 15 18 25 18 34 A14 14 0 0 0 46 34 C46 25 35 15 32 8 Z"/>';
const disc = '<path d="M29 26 L43 9 L40 26 L56 36 L38 37 L26 55 L26 38 L9 28 L26 28 Z"/><circle cx="32" cy="32" r="5"/>';
const items = {
  bomb: '<path d="M27 9 H40 V17 H27 Z M35 9 V5 H45 L48 11 M26 19 L20 28 V48 Q20 55 28 55 H39 Q47 55 47 48 V28 L40 19 Z"/><path d="M26 33 H41 M26 42 H41"/>',
  intel_mist: '<path d="M12 36 A9 9 0 0 1 16 19 A12 12 0 0 1 39 18 A9 9 0 0 1 52 32 M12 39 H47 M18 47 H55 M9 55 H41"/><path d="M29 24 H37 L33 31"/>',
  beacon: '<path d="M22 56 H42 L38 45 H26 Z M28 45 V23 H36 V45 M32 23 V12 M20 20 Q11 12 20 5 M44 20 Q53 12 44 5"/><path d="M25 32 L32 25 L39 32"/>',
  recall: '<path d="M32 51 V13 L46 17 L32 25 M24 53 H40 M17 20 A21 21 0 1 0 53 35 M17 20 V9 M17 20 H7"/>',
  sonar: '<circle cx="32" cy="32" r="23"/><circle cx="32" cy="32" r="15"/><circle cx="32" cy="32" r="6" fill="currentColor"/><path d="M32 32 L48 16"/>',
  mine: '<path d="M12 40 L18 30 H46 L52 40 V51 H12 Z M19 51 V56 M45 51 V56"/><circle cx="32" cy="38" r="5"/><path d="M22 22 L18 17 M42 22 L46 17 M32 19 V8"/>',
  echo_decoy: '<circle cx="24" cy="16" r="7"/><path d="M11 47 V34 Q11 27 18 27 H30 Q37 27 37 34 V47 M20 47 V57 M28 47 V57 M38 8 Q53 16 38 24 M44 4 Q64 16 44 28"/><path d="M15 37 H33" stroke-dasharray="3 5"/>',
  supply_box: '<path d="M10 23 H54 V53 H10 Z M21 23 V14 H43 V23 M10 33 H54 M26 39 H38 M32 36 V48"/><path d="M6 17 L11 11 M58 17 L53 11"/>',
  ink_wings: '<path d="M25 18 H39 V50 H25 Z M25 24 L6 13 L10 33 L25 42 M39 24 L58 13 L54 33 L39 42 M25 32 L12 27 M39 32 L52 27 M29 12 H35 M28 56 L32 52 L36 56"/>',
};
const perks = {
  balanced: '<path d="M32 9 V52 M18 54 H46 M13 21 H51 M15 21 L7 38 H23 Z M49 21 L41 38 H57 Z"/><circle cx="32" cy="13" r="4" fill="currentColor"/>',
  adrenaline: '<path d="M32 51 L12 32 C-1 15 16 3 30 17 C44 3 62 15 49 32 Z"/><path d="M35 19 L24 33 H34 L29 46 L43 29 H33 Z" fill="currentColor" stroke-width="2"/>',
  leech: '<path d="M26 8 C23 14 13 24 13 34 A13 13 0 0 0 39 34 C39 24 29 14 26 8 Z M18 27 L22 34 L26 27 M38 47 H56 M47 38 V56"/>',
  enemy_swim: '<path d="M8 38 Q23 18 43 30 L56 22 V49 L43 40 Q23 52 8 38 Z M12 11 Q18 7 24 11 Q30 15 36 11 Q42 7 49 11 M12 56 Q18 52 24 56 Q30 60 36 56"/><circle cx="23" cy="34" r="2" fill="currentColor"/>',
  vault_runner: '<path d="M8 55 H28 V24 H43 V55 H55 M20 40 L39 11 M39 11 L27 13 M39 11 L42 24"/><path d="M33 35 H40 M33 45 H40"/>',
  last_ink: '<path d="M31 17 C17 4 4 16 13 30 L25 42 L37 28 C49 16 40 6 31 17 Z M28 19 L24 27 L31 31 L26 40 M39 35 L54 29 L50 41 L60 48 L47 50 L43 59 L36 47 L27 52"/>',
  dry_focus: `${drop}<path d="M8 23 V15 H16 M48 15 H56 V23 M8 45 V53 H16 M48 53 H56 V45 M27 34 H37 M32 29 V39"/>`,
  turf_engine: '<path d="M11 35 L24 27 L51 43 L38 51 Z M11 35 V43 L38 59 L51 51 V43 M34 5 L23 22 H33 L28 35 L45 16 H34 Z"/>',
};
const specials = {
  slam: '<path d="M32 6 V31 M22 23 L32 33 L42 23 M13 36 L22 43 L12 48 M51 36 L42 43 L52 48"/><ellipse cx="32" cy="47" rx="16" ry="8"/>',
  storm: '<path d="M14 32 A10 10 0 0 1 16 13 A14 14 0 0 1 42 15 A9 9 0 0 1 51 32 Z M18 40 L13 51 M34 40 L28 57 M49 40 L44 51"/>',
  twin_discs: `<g transform="translate(-2 -2) scale(.72)">${disc}</g><g transform="translate(19 19) scale(.72)">${disc}</g>`,
  rain_arrows: '<path d="M13 23 A8 8 0 0 1 16 8 A12 12 0 0 1 39 11 A8 8 0 0 1 49 23 Z M15 31 V50 L9 43 M15 50 L21 43 M32 31 V58 L26 51 M32 58 L38 51 M49 31 V50 L43 43 M49 50 L55 43"/>',
  absorb_counter: '<path d="M8 14 L17 26 L8 38 M17 26 H31 M56 14 L47 26 L56 38 M47 26 H33 M32 8 V22 M24 40 A12 12 0 1 0 43 47 M24 40 H35 M24 40 V51"/>',
};
export const ABILITY_ICONS = Object.fromEntries(
  [['item', items], ['perk', perks], ['special', specials]]
    .flatMap(([kind, values]) => Object.entries(values).map(([id, body]) => [`${kind}-${id}`, icon(body)]))
);
