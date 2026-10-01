// Bake the original Web Audio builders, without replacing their DSP or score.
// NODE_PATH/PLAYWRIGHT_PATH may point to an existing Playwright installation.
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { resolve, sep } from 'node:path';
import { SFX, SFX_NAMES } from '../../public/game/src/audio/audio.js';
import { getSong, SONGS } from '../../public/game/src/audio/music.js';

const hash = b => createHash('sha256').update(b).digest('hex');
const root = resolve(fileURLToPath(new URL('../../', import.meta.url)));
const out = fileURLToPath(new URL('../assets/audio/', import.meta.url));
const paths = ['public/game/src/audio/audio.js', 'public/game/src/audio/music.js', 'public/game/src/config.js', 'godot-port-prototype/tools/export_audio.mjs'];
const sources = Object.fromEntries(paths.map(p => [p, hash(readFileSync(resolve(root, p)))]));
const check = process.argv.includes('--check');
if (check) {
  const m = JSON.parse(readFileSync(resolve(out, 'manifest.json')));
  if (JSON.stringify(m.sources) !== JSON.stringify(sources)) throw Error('Stale original audio sources');
  for (const [name, item] of Object.entries(m.sounds)) {
    if (hash(readFileSync(resolve(out, item.file))) !== item.sha256) throw Error(`Audio mismatch: ${name}`);
  }
  if (SFX_NAMES.some(n => !m.sounds[n]) || Object.keys(SONGS).some(n => !m.sounds[n])) throw Error('Missing original sound');
  console.log(`OK: ${SFX_NAMES.length} original SFX and ${Object.keys(SONGS).length} complete music scores; source/output hashes`);
  process.exit(0);
}

const require = createRequire(import.meta.url);
let chromium;
for (const p of [process.env.PLAYWRIGHT_PATH, 'playwright', '/Users/yunni/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'].filter(Boolean)) {
  try { ({ chromium } = require(p)); break; } catch {}
}
if (!chromium) throw Error('Set PLAYWRIGHT_PATH to an installed playwright package');
mkdirSync(out, { recursive: true });
const server = createServer((req, res) => {
  if (req.url === '/') { res.setHeader('Content-Type', 'text/html'); res.end('<!doctype html><title>INKWAVE offline audio export</title>'); return; }
  const path = resolve(root, '.' + decodeURIComponent(req.url.split('?')[0]));
  if (!path.startsWith(root + sep)) { res.writeHead(403).end(); return; }
  try { res.setHeader('Content-Type', 'text/javascript'); res.end(readFileSync(path)); }
  catch { res.writeHead(404).end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
let browser;
try {
  browser = await chromium.launch({ executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  const manifest = { schema: 1, sampleRate: 22050, renderer: 'Chromium OfflineAudioContext', sources, sounds: {} };
  const jobs = [
    ...SFX_NAMES.map(name => ({ name, music: false, loop: !!SFX[name].loop })),
    ...Object.keys(SONGS).map(name => {
      const s = getSong(name), bar = 240 / s.bpm;
      return { name, music: true, loop: true, duration: s.bars.length * bar, loopStart: s.loopFrom * bar };
    }),
  ];
  for (const job of jobs) {
    const result = await page.evaluate(async job => {
      const { SFX } = await import('/public/game/src/audio/audio.js');
      const { V, mulberry32, MusicEngine } = await import('/public/game/src/audio/music.js');
      const sr = 22050, seconds = job.music ? job.duration + 3.06 : 8;
      const ctx = new OfflineAudioContext(job.music ? 2 : 1, Math.ceil(seconds * sr), sr);
      let start = 0, end, loopStart = 0;
      if (job.music) {
        const engine = new MusicEngine();
        engine._init(ctx, ctx.destination, { offline: true });
        engine.play(job.name, { fade: 0 });
        // Advance within the source scheduler's look-ahead. A single large jump
        // would invoke its background-tab skip logic and omit the middle score.
        for (let t = 0; t <= job.duration + 0.06; t += 0.08) engine.advance(t);
        start = Math.round(0.06 * sr); end = start + Math.round(job.duration * sr);
        loopStart = Math.round(job.loopStart * sr);
      } else {
        const d = SFX[job.name], g = ctx.createGain();
        g.gain.value = d.gain ?? 0.5; g.connect(ctx.destination);
        const v = new V(ctx, g, 0, mulberry32(1901));
        if (job.loop) { d.loop(v, 1, {}); start = sr; end = sr * 4; }
        else { d.build(v, 1, {}); end = Math.min(ctx.length, Math.ceil((v.end + 0.12) * sr)); }
      }
      const b = await ctx.startRendering(), channels = b.numberOfChannels, frames = end - start;
      const bytes = new Uint8Array(frames * channels * 2), dv = new DataView(bytes.buffer);
      let rawPeak = 0;
      for (let ch = 0; ch < channels; ch++) for (let i = start; i < end; i++) rawPeak = Math.max(rawPeak, Math.abs(b.getChannelData(ch)[i]));
      const headroomGain = Math.min(1, 0.98 / (rawPeak || 1));
      if (job.music) {
        for (let begin = start; begin + sr * 2 < end; begin += sr * 2) {
          let energy = 0;
          for (let i = begin; i < begin + sr * 2; i++) energy += b.getChannelData(0)[i] ** 2;
          if (energy < 0.00001) throw Error('Music score contains a missing two-second block: ' + job.name);
        }
      }
      let peak = 0, power = 0;
      for (let i = 0; i < frames; i++) for (let ch = 0; ch < channels; ch++) {
        let x = b.getChannelData(ch)[start + i] * headroomGain;
        if (!Number.isFinite(x)) throw Error('Nonfinite audio');
        // Only wet continuous SFX need a short seam fade; music keeps the complete source score.
        if (job.loop && !job.music) x *= Math.min(1, i / 220, (frames - 1 - i) / 220);
        peak = Math.max(peak, Math.abs(x)); power += x * x;
        dv.setInt16((i * channels + ch) * 2, Math.round(Math.max(-1, Math.min(1, x)) * 32767), true);
      }
      let base64 = ''; for (let i = 0; i < bytes.length; i += 32768) base64 += String.fromCharCode(...bytes.subarray(i, i + 32768));
      return { pcm: btoa(base64), channels, frames, loopStart, peak, headroomGain, rms: Math.sqrt(power / (frames * channels)) };
    }, job);
    if (result.peak > 1 || result.rms < 0.00001) throw Error(`Invalid levels ${job.name}: ${result.peak}/${result.rms}`);
    const pcm = Buffer.from(result.pcm, 'base64'), wav = Buffer.alloc(44 + pcm.length);
    wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8); wav.writeUInt32LE(16, 16);
    wav.writeUInt16LE(1, 20); wav.writeUInt16LE(result.channels, 22); wav.writeUInt32LE(22050, 24);
    wav.writeUInt32LE(22050 * result.channels * 2, 28); wav.writeUInt16LE(result.channels * 2, 32); wav.writeUInt16LE(16, 34);
    wav.write('data', 36); wav.writeUInt32LE(pcm.length, 40); pcm.copy(wav, 44);
    const file = `${job.name}.wav`; writeFileSync(resolve(out, file), wav);
    manifest.sounds[job.name] = { file, music: job.music, loop: job.loop, loopStart: result.loopStart, frames: result.frames, channels: result.channels, peak: result.peak, headroomGain: result.headroomGain, rms: result.rms, sha256: hash(wav) };
    console.log(`Rendered ${job.name} (${(result.frames / 22050).toFixed(2)} s)`);
  }
  if (errors.length) throw Error(errors.join('\n'));
  writeFileSync(resolve(out, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
} finally { await browser?.close(); await new Promise(r => server.close(r)); }
