/**
 * Sound effects, synthesised with the Web Audio API.
 *
 * There are no audio files: each clip is a handful of oscillators and a noise
 * burst, which keeps the game a single folder of text and works from file://
 * in the offline build. The Godot build bakes the same recipes offline with
 * tools/make-sfx.mjs, so both ports sound alike.
 *
 * Everything here is a no-op when there is no AudioContext (jsdom, an old
 * browser, or before the first user gesture), so callers never guard the call.
 */

export const SFX_IDS = [
  'throw', 'hit', 'absorb', 'correct', 'wrong', 'hurt', 'shield', 'badge', 'boss', 'clear', 'click',
];

const MASTER_GAIN = 0.5;
const MIN_GAP_MS = 25;

let ctx = null;
let master = null;
let noiseBuffer = null;
let enabled = true;
let lastPlayed = new Map();

function audioContextClass() {
  if (typeof window === 'undefined') return null;
  return window.AudioContext || window.webkitAudioContext || null;
}

/** Lazily build the context: browsers only allow it after a user gesture. */
function ensureContext() {
  if (ctx) return ctx;
  const Ctor = audioContextClass();
  if (!Ctor) return null;
  try {
    ctx = new Ctor();
    master = ctx.createGain();
    master.gain.value = MASTER_GAIN;
    master.connect(ctx.destination);
  } catch {
    ctx = null;
    master = null;
  }
  return ctx;
}

/** A short low-passed noise bed, generated once and reused by every hit. */
function noiseSource() {
  const context = ensureContext();
  if (!noiseBuffer) {
    noiseBuffer = context.createBuffer(1, Math.floor(context.sampleRate * 0.4), context.sampleRate);
    const data = noiseBuffer.getChannelData(0);
    let state = 12345;
    let smooth = 0;
    for (let i = 0; i < data.length; i += 1) {
      state = (state * 9301 + 49297) % 233280;
      const white = (state / 233280) * 2 - 1;
      smooth += (white - smooth) * 0.5;
      data[i] = smooth;
    }
  }
  const source = context.createBufferSource();
  source.buffer = noiseBuffer;
  source.loop = true;
  return source;
}

function envelope(context, start, duration, peak, decay, attack = 0.004) {
  const gain = context.createGain();
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.linearRampToValueAtTime(peak, start + attack);
  // exponential decay to silence, kept off zero because exp ramps cannot hit it
  gain.gain.exponentialRampToValueAtTime(0.0001, start + Math.max(duration, attack + decay));
  gain.connect(master);
  return gain;
}

function tone({ freq, at = 0, dur = 0.12, wave = 'square', gain = 0.3, decay = 0.1, slide = 0 }) {
  const context = ensureContext();
  if (!context) return;
  const start = context.currentTime + at;
  const osc = context.createOscillator();
  osc.type = wave;
  osc.frequency.setValueAtTime(freq, start);
  if (slide !== 0) {
    osc.frequency.exponentialRampToValueAtTime(Math.max(30, freq * (1 + slide)), start + dur);
  }
  const amp = envelope(context, start, dur, gain, decay);
  osc.connect(amp);
  osc.start(start);
  osc.stop(start + dur + 0.02);
}

function noise({ at = 0, dur = 0.1, gain = 0.3, decay = 0.08, cutoff = 2200 }) {
  const context = ensureContext();
  if (!context) return;
  const start = context.currentTime + at;
  const source = noiseSource();
  const filter = context.createBiquadFilter();
  filter.type = 'lowpass';
  filter.frequency.setValueAtTime(cutoff, start);
  const amp = envelope(context, start, dur, gain, decay, 0.002);
  source.connect(filter);
  filter.connect(amp);
  source.start(start);
  source.stop(start + dur + 0.02);
}

const arp = (notes) => notes.forEach((note) => tone(note));

/* --------------------------------- recipes -------------------------------- */

const RECIPES = {
  // A spear leaving the hand: a quick upward whoosh.
  throw: () => {
    noise({ dur: 0.11, gain: 0.22, decay: 0.09, cutoff: 2600 });
    tone({ freq: 760, dur: 0.1, wave: 'triangle', gain: 0.18, decay: 0.09, slide: -0.55 });
  },

  // A spear biting into a bat.
  hit: () => {
    noise({ dur: 0.07, gain: 0.3, decay: 0.06, cutoff: 3200 });
    tone({ freq: 240, dur: 0.07, wave: 'square', gain: 0.12, decay: 0.06, slide: -0.5 });
  },

  // The code box is absorbed: a bright three-step rise.
  absorb: () => arp([
    { freq: 523, at: 0, dur: 0.09, gain: 0.2, decay: 0.08 },
    { freq: 784, at: 0.055, dur: 0.09, gain: 0.2, decay: 0.08 },
    { freq: 1175, at: 0.11, dur: 0.16, wave: 'triangle', gain: 0.22, decay: 0.14 },
  ]),

  // Right answer: the little victory motif.
  correct: () => arp([
    { freq: 523, at: 0, dur: 0.1, wave: 'triangle', gain: 0.26, decay: 0.08 },
    { freq: 659, at: 0.07, dur: 0.1, wave: 'triangle', gain: 0.26, decay: 0.08 },
    { freq: 784, at: 0.14, dur: 0.12, wave: 'triangle', gain: 0.26, decay: 0.1 },
    { freq: 1047, at: 0.21, dur: 0.26, wave: 'triangle', gain: 0.3, decay: 0.22 },
  ]),

  // Wrong answer: a flat, downward "not quite".
  wrong: () => {
    tone({ freq: 300, dur: 0.3, wave: 'sawtooth', gain: 0.22, decay: 0.26, slide: -0.42 });
    tone({ freq: 198, at: 0.02, dur: 0.3, wave: 'square', gain: 0.11, decay: 0.26, slide: -0.4 });
  },

  // A heart lost: dull thud plus a falling tone.
  hurt: () => {
    noise({ dur: 0.22, gain: 0.3, decay: 0.2, cutoff: 900 });
    tone({ freq: 230, dur: 0.28, wave: 'sawtooth', gain: 0.22, decay: 0.24, slide: -0.62 });
  },

  // A shield eating the hit: metallic ping.
  shield: () => {
    tone({ freq: 1320, dur: 0.26, wave: 'sine', gain: 0.28, decay: 0.24 });
    tone({ freq: 1980, at: 0.01, dur: 0.2, wave: 'sine', gain: 0.15, decay: 0.18 });
    noise({ dur: 0.12, gain: 0.1, decay: 0.1, cutoff: 5000 });
  },

  // A badge lands: two sparkles.
  badge: () => arp([
    { freq: 1319, at: 0, dur: 0.12, wave: 'triangle', gain: 0.2, decay: 0.1 },
    { freq: 1760, at: 0.09, dur: 0.14, wave: 'triangle', gain: 0.2, decay: 0.12 },
    { freq: 2637, at: 0.18, dur: 0.2, wave: 'sine', gain: 0.16, decay: 0.18 },
  ]),

  // The Syntax Overlord arrives: low rumble under a horn.
  boss: () => {
    noise({ dur: 0.9, gain: 0.2, decay: 0.8, cutoff: 400 });
    tone({ freq: 74, dur: 0.85, wave: 'sawtooth', gain: 0.3, decay: 0.7 });
    tone({ freq: 111, at: 0.12, dur: 0.7, wave: 'square', gain: 0.12, decay: 0.6 });
  },

  // Module cleared: fanfare that resolves upward.
  clear: () => arp([
    { freq: 523, at: 0, dur: 0.14, gain: 0.2, decay: 0.12 },
    { freq: 659, at: 0.12, dur: 0.14, gain: 0.2, decay: 0.12 },
    { freq: 784, at: 0.24, dur: 0.14, gain: 0.2, decay: 0.12 },
    { freq: 1047, at: 0.36, dur: 0.16, wave: 'triangle', gain: 0.24, decay: 0.14 },
    { freq: 1319, at: 0.5, dur: 0.42, wave: 'triangle', gain: 0.26, decay: 0.38 },
    { freq: 784, at: 0.5, dur: 0.42, gain: 0.1, decay: 0.38 },
  ]),

  // A button or a menu opening.
  click: () => tone({ freq: 660, dur: 0.055, gain: 0.14, decay: 0.05 }),
};

/* --------------------------------- public --------------------------------- */

export function setSoundEnabled(value) {
  enabled = Boolean(value);
  if (!enabled && master && ctx) {
    master.gain.cancelScheduledValues(ctx.currentTime);
    master.gain.setValueAtTime(0.0001, ctx.currentTime);
  } else if (master && ctx) {
    master.gain.setValueAtTime(MASTER_GAIN, ctx.currentTime);
  }
}

export function isSoundEnabled() {
  return enabled;
}

/** Play a clip. Unknown ids, muted audio and missing APIs are silent no-ops. */
export function playSfx(id) {
  if (!enabled) return;
  const recipe = RECIPES[id];
  if (!recipe) return;
  const now = typeof performance !== 'undefined' ? performance.now() : Date.now();
  if (now - (lastPlayed.get(id) || -1000) < MIN_GAP_MS) return;
  lastPlayed.set(id, now);

  const context = ensureContext();
  if (!context) return;
  if (context.state === 'suspended') context.resume().catch(() => {});
  try {
    recipe();
  } catch {
    /* a browser refusing a node must never break the game loop */
  }
}

/** Warm the audio graph up on the first real gesture (mobile browsers). */
export function unlockAudio() {
  const context = ensureContext();
  if (context && context.state === 'suspended') context.resume().catch(() => {});
}
