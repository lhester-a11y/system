/**
 * Parallax pixel-art Kalinga landscape.
 *
 * Layer 0 is the Sleeping Beauty (Mt. Mating-oy) silhouette, then rolling
 * ridges, then the rice terraces the warrior stands on. The sky and lighting
 * are driven by the current language module: day -> sunset -> night.
 *
 * Everything is generated from a seed and quantised to 3px steps so the
 * background matches the chunkiness of the character sprites.
 */
import { createRng } from '../core/rng.js';

export const STEP = 3;
export const HORIZON = 600;

export const SKIES = {
  day: {
    bands: ['#4e9fd8', '#6cb6e8', '#8fcdf1', '#b3dff7', '#d6eefc', '#eaf7fd'],
    far: '#9dbfe0', mid: '#7ba6cd', near: '#5b87b4', hill: '#3f6b52',
    terrace: '#5f8f4c', terraceTop: '#86b566', paddy: '#8fc6d8',
    cloud: '#ffffff', sun: 'sun', sunColor: '#ffeaa8', halo: '#fff4cf',
    stars: 0, mist: 'rgba(226,244,252,0.55)',
  },
  sunset: {
    bands: ['#2f2350', '#5a3466', '#8f4468', '#c05a5c', '#e8865a', '#f4b26a'],
    far: '#96637f', mid: '#70496a', near: '#4e3350', hill: '#3b2a3c',
    terrace: '#5e4450', terraceTop: '#8a5c58', paddy: '#d98b5e',
    cloud: '#ffb37a', sun: 'sunset', sunColor: '#ffd08a', halo: '#ff9d5c',
    stars: 0, mist: 'rgba(240,170,120,0.4)',
  },
  night: {
    bands: ['#04081a', '#080f28', '#0d1636', '#131e45', '#1a2752', '#22305f'],
    far: '#2b3c66', mid: '#1f2b4b', near: '#16203a', hill: '#131c2e',
    terrace: '#1b2c46', terraceTop: '#2b4468', paddy: '#3d6291',
    cloud: '#33456f', sun: 'moon', sunColor: '#f2f6ff', halo: '#9fb4e8',
    stars: 1, mist: 'rgba(52,74,124,0.5)',
  },
};

/** Hand-placed profile of the sleeping woman, read left (head) to right (feet). */
const SLEEPING_BEAUTY = [
  [-90, 300], [-60, 268], [-34, 224], [-12, 198], [8, 188], [26, 200],
  [36, 222], [46, 236], [62, 244], [88, 240], [112, 252], [134, 272],
  [158, 282], [176, 268], [196, 288], [222, 296], [250, 292], [282, 300],
  [318, 296], [360, 302], [440, 300],
];

function quantise(v) {
  return Math.round(v / STEP) * STEP;
}

function ridgeFrom(seed, baseY, amp, from, to) {
  const rng = createRng(seed);
  const points = [];
  let y = baseY;
  for (let x = from; x <= to; x += STEP) {
    y += rng.range(-amp * 0.45, amp * 0.45);
    const wave = Math.sin((x + seed) * 0.017) * amp * 0.5;
    const clamped = Math.min(baseY - amp, Math.max(baseY + amp, y));
    points.push([x, quantise(Math.min(clamped, baseY + amp) * 0.6 + (baseY + wave) * 0.4)]);
  }
  return points;
}

/** Closed polygon path for a ridge, extended down to the horizon. */
function ridgePath(ctx, points, offsetX, bottom) {
  ctx.beginPath();
  ctx.moveTo(points[0][0] + offsetX, bottom);
  for (const [x, y] of points) ctx.lineTo(x + offsetX, y);
  ctx.lineTo(points[points.length - 1][0] + offsetX, bottom);
  ctx.closePath();
}

export function createBackground(skyName = 'day', seed = 1337) {
  const sky = SKIES[skyName] || SKIES.day;
  const rng = createRng(seed);
  const from = -120;
  const to = 480;

  const layers = [
    { points: SLEEPING_BEAUTY.map(([x, y]) => [x, quantise(y)]), color: sky.far, parallax: 0.035, bottom: HORIZON },
    { points: ridgeFrom(seed + 11, 250, 26, from, to), color: sky.far, parallax: 0.08, bottom: HORIZON, alpha: 0.92 },
    { points: ridgeFrom(seed + 29, 296, 22, from, to), color: sky.mid, parallax: 0.16, bottom: HORIZON },
    { points: ridgeFrom(seed + 47, 372, 26, from, to), color: sky.near, parallax: 0.28, bottom: HORIZON },
    { points: ridgeFrom(seed + 61, 452, 20, from, to), color: sky.hill, parallax: 0.42, bottom: 640 },
  ];

  const stars = sky.stars
    ? Array.from({ length: 46 }, () => ({
      x: quantise(rng.range(0, 360)),
      y: quantise(rng.range(4, 300)),
      phase: rng.range(0, Math.PI * 2),
      size: rng() > 0.85 ? 3 : 2,
    }))
    : [];

  const clouds = Array.from({ length: 4 }, (_, i) => ({
    x: rng.range(-40, 400),
    y: quantise(40 + i * 46 + rng.range(-10, 10)),
    w: quantise(rng.range(40, 90)),
    drift: rng.range(2.5, 7),
  }));

  /* --------------------------- terrace bands ---------------------------- */
  const terraces = [];
  for (let i = 0; i < 9; i += 1) {
    const y = quantise(468 + i * 15);
    terraces.push({ y, inset: quantise(8 + i * 9), wobble: rng.range(-1, 1) * STEP });
  }

  function drawSky(ctx) {
    const bandH = 108;
    for (let i = 0; i < sky.bands.length; i += 1) {
      ctx.fillStyle = sky.bands[i];
      ctx.fillRect(0, i * bandH, 360, bandH + 1);
    }
  }

  function drawStars(ctx, t) {
    for (const s of stars) {
      const twinkle = 0.55 + 0.45 * Math.sin(t * 1.6 + s.phase);
      ctx.globalAlpha = Math.max(0.12, twinkle);
      ctx.fillStyle = '#eaf2ff';
      ctx.fillRect(s.x, s.y, s.size, s.size);
    }
    ctx.globalAlpha = 1;
  }

  function drawSun(ctx, t) {
    const isMoon = sky.sun === 'moon';
    const cx = isMoon ? 282 : sky.sun === 'sunset' ? 296 : 268;
    const cy = isMoon ? 74 : sky.sun === 'sunset' ? 244 : 92;
    const r = isMoon ? 21 : sky.sun === 'sunset' ? 30 : 26;

    ctx.globalAlpha = 0.32;
    ctx.fillStyle = sky.halo;
    for (let i = 0; i < 5; i += 1) {
      const rr = quantise(r + 8 + i * 9);
      if (Math.sin(t * 0.7 + i) < -0.85) continue;
      ctx.fillRect(cx - rr, cy - rr, rr * 2, rr * 2);
    }
    ctx.globalAlpha = 1;

    ctx.fillStyle = sky.sunColor;
    for (let y = -r; y < r; y += STEP) {
      for (let x = -r; x < r; x += STEP) {
        if (x * x + y * y > r * r) continue;
        ctx.fillRect(cx + quantise(x), cy + quantise(y), STEP, STEP);
      }
    }
    if (isMoon) {
      ctx.fillStyle = '#c9d6f2';
      ctx.fillRect(cx - 6, cy - 6, 6, 6);
      ctx.fillRect(cx + 3, cy + 3, 6, 6);
      ctx.fillRect(cx + 6, cy - 9, 3, 3);
    }
  }

  function drawClouds(ctx, t) {
    ctx.fillStyle = sky.cloud;
    ctx.globalAlpha = skyName === 'night' ? 0.35 : 0.7;
    for (const c of clouds) {
      const x = quantise(((c.x + t * c.drift) % 440) - 40);
      const puff = [
        [0, 8, c.w, 8],
        [8, 0, c.w - 20, 8],
        [-6, 16, c.w + 12, 6],
      ];
      for (const [dx, dy, w, h] of puff) {
        if (w <= 0) continue;
        ctx.fillRect(x + dx, c.y + dy, quantise(w), h);
      }
    }
    ctx.globalAlpha = 1;
  }

  function drawTerrace(ctx, offsetX) {
    for (const t of terraces) {
      const x0 = Math.max(0, t.inset + offsetX * 0.5);
      ctx.fillStyle = sky.terraceTop;
      ctx.fillRect(x0, t.y, 360 - x0, STEP);
      ctx.fillStyle = sky.terrace;
      ctx.fillRect(x0, t.y + STEP, 360 - x0, 12);
    }
    // flooded paddies catch the light
    ctx.fillStyle = sky.paddy;
    ctx.globalAlpha = 0.35;
    for (let i = 0; i < 7; i += 1) {
      const y = 486 + i * 15;
      const w = 26 + ((i * 37) % 40);
      const x = 24 + ((i * 61) % 250);
      ctx.fillRect(quantise(x), quantise(y), quantise(w), 3);
    }
    ctx.globalAlpha = 1;
  }

  function drawGround(ctx) {
    ctx.fillStyle = sky.terrace;
    ctx.fillRect(0, HORIZON, 360, 640 - HORIZON);
    ctx.fillStyle = sky.terraceTop;
    ctx.fillRect(0, HORIZON, 360, 3);
    ctx.fillStyle = sky.hill;
    for (let x = 0; x < 360; x += 9) {
      const h = 3 + ((x * 7) % 6);
      ctx.fillRect(x, HORIZON + 6, 3, h);
    }
    ctx.fillStyle = sky.paddy;
    ctx.globalAlpha = 0.22;
    ctx.fillRect(0, 620, 360, 20);
    ctx.globalAlpha = 1;
  }

  function drawMist(ctx, t) {
    ctx.fillStyle = sky.mist;
    for (let i = 0; i < 3; i += 1) {
      const y = quantise(388 + i * 40 + Math.sin(t * 0.4 + i) * 3);
      ctx.globalAlpha = 0.35;
      ctx.fillRect(0, y, 360, 9);
    }
    ctx.globalAlpha = 1;
  }

  /**
   * @param {CanvasRenderingContext2D} ctx
   * @param {number} cameraX player x, used to slide each layer
   * @param {number} t seconds, for clouds, twinkle and shimmer
   */
  function draw(ctx, cameraX = 180, t = 0) {
    drawSky(ctx);
    if (stars.length) drawStars(ctx, t);
    drawSun(ctx, t);
    drawClouds(ctx, t);

    for (const layer of layers) {
      const offsetX = -(cameraX - 180) * layer.parallax;
      ctx.globalAlpha = layer.alpha === undefined ? 1 : layer.alpha;
      ctx.fillStyle = layer.color;
      ridgePath(ctx, layer.points, offsetX, layer.bottom);
      ctx.fill();
      ctx.globalAlpha = 1;
      if (layer.parallax > 0.25) {
        // rim light along the ridge crest
        ctx.strokeStyle = sky.terraceTop;
        ctx.globalAlpha = 0.35;
        ctx.lineWidth = 1;
        ctx.beginPath();
        layer.points.forEach(([x, y], i) => (i ? ctx.lineTo(x + offsetX, y) : ctx.moveTo(x + offsetX, y)));
        ctx.stroke();
        ctx.globalAlpha = 1;
      }
    }

    drawTerrace(ctx, -(cameraX - 180) * 0.5);
    drawMist(ctx, t);
    drawGround(ctx);
  }

  return { draw, sky, layers, terraces, skyName };
}
