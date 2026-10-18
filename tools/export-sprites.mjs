/**
 * Renders every CodePlay sprite into assets/sprites/*.png plus one contact sheet.
 * Run with: npm run sprites
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { encodePng, parseHex } from './png.mjs';
import { SPRITE_ART, PALETTES } from '../js/render/sprites.js';

const OUT = 'assets/sprites';
mkdirSync(OUT, { recursive: true });

/** Draw one sprite scaled up into its own RGBA tile. */
function tile(name, scale) {
  const art = SPRITE_ART[name];
  const pal = PALETTES[name];
  const w = art[0].length * scale;
  const h = art.length * scale;
  const px = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y += 1) {
    for (let x = 0; x < w; x += 1) {
      const color = pal[art[Math.floor(y / scale)][Math.floor(x / scale)]];
      const o = (y * w + x) * 4;
      if (!color) continue;
      const [r, g, b, a] = parseHex(color);
      px[o] = r; px[o + 1] = g; px[o + 2] = b; px[o + 3] = a;
    }
  }
  return { w, h, px };
}

const names = Object.keys(SPRITE_ART);
const SCALE = 8;
const PAD = 8;
let sheetW = PAD;
let sheetH = 0;
const tiles = names.map((n) => {
  const t = tile(n, SCALE);
  sheetW += t.w + PAD;
  sheetH = Math.max(sheetH, t.h);
  return { name: n, ...t };
});
sheetH += PAD * 2;

const sheet = new Uint8Array(sheetW * sheetH * 4);
// checkerboard backdrop so transparent art stays readable
for (let y = 0; y < sheetH; y += 1) {
  for (let x = 0; x < sheetW; x += 1) {
    const o = (y * sheetW + x) * 4;
    const on = (Math.floor(x / 8) + Math.floor(y / 8)) % 2 === 0;
    sheet[o] = on ? 30 : 20;
    sheet[o + 1] = on ? 34 : 24;
    sheet[o + 2] = on ? 44 : 32;
    sheet[o + 3] = 255;
  }
}

let cursorX = PAD;
for (const t of tiles) {
  for (let y = 0; y < t.h; y += 1) {
    for (let x = 0; x < t.w; x += 1) {
      const src = (y * t.w + x) * 4;
      if (t.px[src + 3] === 0) continue;
      const dst = ((y + PAD) * sheetW + cursorX + x) * 4;
      sheet[dst] = t.px[src];
      sheet[dst + 1] = t.px[src + 1];
      sheet[dst + 2] = t.px[src + 2];
      sheet[dst + 3] = 255;
    }
  }
  writeFileSync(`${OUT}/${t.name}.png`, encodePng(t.w, t.h, t.px));
  cursorX += t.w + PAD;
}

writeFileSync(`${OUT}/_sheet.png`, encodePng(sheetW, sheetH, sheet));
console.log(`wrote ${names.length} sprites + _sheet.png (${sheetW}x${sheetH}) to ${OUT}`);
names.forEach((n) => {
  const a = SPRITE_ART[n];
  console.log(`  ${n.padEnd(14)} ${a[0].length}x${a.length}`);
});
