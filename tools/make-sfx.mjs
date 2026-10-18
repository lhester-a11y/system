/**
 * Bakes the game's sound effects into godot/assets/sfx/*.wav.
 *
 * The web build synthesises its blips with the Web Audio API (js/audio.js); the
 * Godot build has no such API, so the same recipes are rendered offline here
 * into plain 16-bit mono WAV files that Godot imports as AudioStreamWAV.
 *
 *   npm run sfx          regenerate every file
 *
 * Everything is deterministic and generated from a handful of oscillators, so
 * the repo carries a small generator instead of a folder of opaque binaries.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT_DIR = join(dirname(fileURLToPath(import.meta.url)), '..', 'godot', 'assets', 'sfx');
const RATE = 22050;

/* --------------------------------- helpers -------------------------------- */

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

/** A note from an oscillator family, with an attack/release envelope. */
function tone(freq, dur, { type = 'square', gain = 0.5, decay = 3.0, slide = 0, attack = 0.004 } = {}) {
  const frames = Math.max(1, Math.round(dur * RATE));
  const out = new Float32Array(frames);
  let phase = 0;
  for (let i = 0; i < frames; i += 1) {
    const t = i / RATE;
    const p = i / frames;
    const f = freq * (1 + slide * p);
    phase += f / RATE;
    const cycle = phase % 1;
    let v;
    if (type === 'sine') v = Math.sin(cycle * Math.PI * 2);
    else if (type === 'triangle') v = 4 * Math.abs(cycle - 0.5) - 1;
    else if (type === 'saw') v = cycle * 2 - 1;
    else v = cycle < 0.5 ? 1 : -1;
    const rise = Math.min(1, t / Math.max(attack, 1e-4));
    out[i] = v * rise * Math.exp(-decay * p) * gain;
  }
  return out;
}

/** Deterministic white noise, filtered one pole, for hits and impacts. */
function noise(dur, { gain = 0.4, decay = 6.0, smooth = 0.5, seed = 1 } = {}) {
  const frames = Math.max(1, Math.round(dur * RATE));
  const out = new Float32Array(frames);
  let state = seed * 9301 + 49297;
  let last = 0;
  for (let i = 0; i < frames; i += 1) {
    state = (state * 9301 + 49297) % 233280;
    const white = (state / 233280) * 2 - 1;
    last += (white - last) * clamp(1 - smooth, 0.02, 1);
    const p = i / frames;
    out[i] = last * Math.exp(-decay * p) * gain;
  }
  return out;
}

/** Lay tracks on top of each other, each at an offset in seconds. */
function mix(...tracks) {
  let length = 0;
  for (const { samples, at = 0 } of tracks) {
    length = Math.max(length, Math.round(at * RATE) + samples.length);
  }
  const out = new Float32Array(length);
  for (const { samples, at = 0 } of tracks) {
    const start = Math.round(at * RATE);
    for (let i = 0; i < samples.length; i += 1) out[start + i] += samples[i];
  }
  return out;
}

/** Note sequence: [[freq, at, dur, options], ...]. */
function arpeggio(notes) {
  return mix(...notes.map(([freq, at, dur, options]) => ({ samples: tone(freq, dur, options), at })));
}

/** Soft-clip and normalise so every file peaks at the same comfortable level. */
function master(samples, peak = 0.72) {
  let max = 0;
  for (const v of samples) max = Math.max(max, Math.abs(v));
  const k = max > 0 ? peak / max : 1;
  const out = new Float32Array(samples.length);
  for (let i = 0; i < samples.length; i += 1) {
    const v = samples[i] * k;
    // tanh-style saturation keeps the square waves chunky without harsh clips
    out[i] = Math.tanh(v * 1.25) * 0.92;
  }
  // 6 ms fade out so nothing ends on a click
  const fade = Math.min(out.length, Math.round(0.006 * RATE));
  for (let i = 0; i < fade; i += 1) out[out.length - 1 - i] *= i / fade;
  return out;
}

function wav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i += 1) {
    data.writeInt16LE(Math.round(clamp(samples[i], -1, 1) * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);           // PCM
  header.writeUInt16LE(1, 22);           // mono
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);    // byte rate
  header.writeUInt16LE(2, 32);           // block align
  header.writeUInt16LE(16, 34);          // bits per sample
  header.write('data', 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

/* --------------------------------- recipes -------------------------------- */

const SFX = {
  // A spear leaving the hand: a quick upward whoosh.
  throw: () => mix(
    { samples: noise(0.11, { gain: 0.35, decay: 5, smooth: 0.25, seed: 7 }) },
    { samples: tone(760, 0.1, { type: 'triangle', gain: 0.3, decay: 5, slide: -0.55 }) },
  ),

  // A spear biting into a bat.
  hit: () => mix(
    { samples: noise(0.07, { gain: 0.5, decay: 9, smooth: 0.6, seed: 3 }) },
    { samples: tone(240, 0.07, { type: 'square', gain: 0.2, decay: 9, slide: -0.5 }) },
  ),

  // The code box is absorbed: a bright three-step rise.
  absorb: () => arpeggio([
    [523, 0, 0.09, { type: 'square', gain: 0.3, decay: 2.5 }],
    [784, 0.055, 0.09, { type: 'square', gain: 0.3, decay: 2.5 }],
    [1175, 0.11, 0.16, { type: 'triangle', gain: 0.32, decay: 3.2 }],
  ]),

  // Right answer: the little victory motif.
  correct: () => arpeggio([
    [523, 0, 0.1, { type: 'triangle', gain: 0.38, decay: 2.0 }],
    [659, 0.07, 0.1, { type: 'triangle', gain: 0.38, decay: 2.0 }],
    [784, 0.14, 0.12, { type: 'triangle', gain: 0.38, decay: 2.2 }],
    [1047, 0.21, 0.26, { type: 'triangle', gain: 0.42, decay: 2.6 }],
  ]),

  // Wrong answer: a flat, downward "not quite".
  wrong: () => mix(
    { samples: tone(300, 0.3, { type: 'saw', gain: 0.34, decay: 3.4, slide: -0.42 }) },
    { samples: tone(198, 0.3, { type: 'square', gain: 0.16, decay: 3.4, slide: -0.4 }), at: 0.02 },
  ),

  // A heart lost: dull thud plus a falling tone.
  hurt: () => mix(
    { samples: noise(0.22, { gain: 0.45, decay: 6, smooth: 0.7, seed: 11 }) },
    { samples: tone(230, 0.28, { type: 'saw', gain: 0.32, decay: 4.2, slide: -0.62 }) },
  ),

  // A shield eating the hit: metallic ping.
  shield: () => mix(
    { samples: tone(1320, 0.26, { type: 'sine', gain: 0.4, decay: 5.5 }) },
    { samples: tone(1980, 0.2, { type: 'sine', gain: 0.22, decay: 7.0 }), at: 0.01 },
    { samples: noise(0.12, { gain: 0.16, decay: 12, smooth: 0.15, seed: 5 }) },
  ),

  // A badge lands: two sparkles.
  badge: () => arpeggio([
    [1319, 0, 0.12, { type: 'triangle', gain: 0.3, decay: 3.0 }],
    [1760, 0.09, 0.14, { type: 'triangle', gain: 0.3, decay: 3.0 }],
    [2637, 0.18, 0.2, { type: 'sine', gain: 0.24, decay: 4.0 }],
  ]),

  // The Syntax Overlord arrives: low rumble under a horn.
  boss: () => mix(
    { samples: noise(0.9, { gain: 0.3, decay: 2.6, smooth: 0.88, seed: 17 }) },
    { samples: tone(74, 0.85, { type: 'saw', gain: 0.42, decay: 2.2 }) },
    { samples: tone(111, 0.7, { type: 'square', gain: 0.16, decay: 2.6 }), at: 0.12 },
  ),

  // Module cleared: fanfare that resolves upward.
  clear: () => arpeggio([
    [523, 0, 0.14, { type: 'square', gain: 0.3, decay: 1.8 }],
    [659, 0.12, 0.14, { type: 'square', gain: 0.3, decay: 1.8 }],
    [784, 0.24, 0.14, { type: 'square', gain: 0.3, decay: 1.8 }],
    [1047, 0.36, 0.16, { type: 'triangle', gain: 0.36, decay: 2.0 }],
    [1319, 0.5, 0.42, { type: 'triangle', gain: 0.4, decay: 2.4 }],
    [784, 0.5, 0.42, { type: 'square', gain: 0.16, decay: 2.4 }],
  ]),

  // A button or a menu opening.
  click: () => tone(660, 0.055, { type: 'square', gain: 0.22, decay: 8 }),
};

/* ---------------------------------- main ---------------------------------- */

mkdirSync(OUT_DIR, { recursive: true });
for (const [name, recipe] of Object.entries(SFX)) {
  const file = join(OUT_DIR, `${name}.wav`);
  writeFileSync(file, wav(master(recipe())));
  console.log(`  ${name}.wav`);
}
console.log(`\n${Object.keys(SFX).length} sound effects written to godot/assets/sfx/`);
