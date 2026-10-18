/**
 * Hand-authored pixel art. Every sprite is a small grid of palette characters,
 * baked once into an offscreen canvas and then blitted with integer scaling so
 * the art stays crisp. No external image files, no network requests.
 */

const dot = { '.': null };

/* ------------------------------- warriors ------------------------------- */
// 16 wide, 18 tall. s = skin, h = hair, e = eye, w/y/r = woven cloth, W = foot
const WARRIOR_BOY_ART = [
  '......hrh.......',
  '....hhhrhhh.....',
  '....hhssshh.....',
  '....hyyyyh......',
  '....hsesesh.....',
  '....hsssssh.....',
  '.....hsssh......',
  '......sss.......',
  '.....wwyyww.....',
  '.....wrrrrw.....',
  '.....wrryrw.....',
  '.....rrrrrr.....',
  '.....rrrr.......',
  '.....s..s.......',
  '.....s..s.......',
  '.....s..s.......',
  '.....W..W.......',
  '....WW..WW......',
];

const WARRIOR_GIRL_ART = [
  '......hrh.......',
  '....hhhrhhh.....',
  '....hyyyyh......',
  '...hhhsssshh....',
  '...hhsesehhh....',
  '...hhhssshhh....',
  '...h.hsssh.h....',
  '......sss.......',
  '.....wwyyww.....',
  '.....wrrrrw.....',
  '.....wryyrw.....',
  '.....rrrrrr.....',
  '.....ywwwwy.....',
  '...yrrwwrry.....',
  '...yrrwwrry.....',
  '....rrrrrr......',
  '.....s..s.......',
  '....WW..WW......',
];

/* --------------------------------- enemies ------------------------------- */
// 16x16 bat carrying a glowing syntax box
const BAT_ART = [
  '................',
  '..f..........f..',
  '.fwf........fwf.',
  'fwwwf......fwwwf',
  'fwwwwf....fwwwwf',
  '.fwwwwf..fwwwwf.',
  '..fwwwfbbfwwwf..',
  '...fwwfbbfwwf...',
  '....ff1bb1ff....',
  '......bbbb......',
  '...gggggggggg...',
  '..gGGGGGGGGGGg..',
  '..gG10110110Gg..',
  '..gG01101011Gg..',
  '..gGGGGGGGGGGg..',
  '...gggggggggg...',
];

// 8x8 corruption projectile fired by the boss
const BUG_ART = [
  '..gggg..',
  '.gGGGGg.',
  'gGG00GGg',
  'gG0110Gg',
  'gG1001Gg',
  'gGG00GGg',
  '.gGGGGg.',
  '..gggg..',
];

const CROWN_ART = [
  '..y..y..y...',
  '.yyy.yyy.yy.',
  '.yyyyyyyyy..',
  '..yryryry...',
];

/* ---------------------------------- spears ------------------------------- */
// 6x16, drawn pointing up. T = head, W = shaft, B = binding
const SPEAR_ART = [
  '..TT..',
  '.TTTT.',
  '.TTTT.',
  '..TT..',
  '..BW..',
  '..WW..',
  '..WW..',
  '..WW..',
  '..WW..',
  '..WW..',
  '..WB..',
  '..WW..',
  '..WW..',
  '..WW..',
  '..WW..',
  '..WW..',
];

/* --------------------------------- palettes ------------------------------ */
export const SKIN = { s: '#a9703f', e: '#0d0a14' };

export const PALETTES = {
  boy: { ...dot, h: '#1b1210', ...SKIN, w: '#e8dcc0', r: '#b23a2e', y: '#e0a72c', W: '#4a3220' },
  girl: { ...dot, h: '#2a1a14', ...SKIN, w: '#f2e8d4', r: '#8e2f4a', y: '#e0a72c', W: '#3c2818' },
  bat: { ...dot, f: '#3a3050', w: '#57496f', b: '#241d33', g: '#14603a', G: '#2fa85e', 0: '#070c14', 1: '#b7ffd2' },
  batBoss: { ...dot, f: '#4a2b52', w: '#6d3f74', b: '#2a1330', g: '#7a1f3d', G: '#e0455f', 0: '#100610', 1: '#ffd9e0' },
  bug: { ...dot, f: '#3a3050', w: '#57496f', b: '#241d33', g: '#7a1f3d', G: '#e0455f', 0: '#100610', 1: '#ffd9e0' },
  crown: { ...dot, y: '#f2c14e', r: '#b23a2e' },
  'spear-bamboo': { ...dot, T: '#6d5333', W: '#a98545', B: '#4a3220' },
  'spear-iron': { ...dot, T: '#cfd8dc', W: '#6b7280', B: '#3f4652' },
  'spear-gold': { ...dot, T: '#ffe08a', W: '#b8871c', B: '#6d4c0d' },
  'spear-crystal': { ...dot, T: '#9ff5f0', W: '#4a6fa5', B: '#2b4a7a' },
};

export const SPRITE_ART = {
  boy: WARRIOR_BOY_ART,
  girl: WARRIOR_GIRL_ART,
  bat: BAT_ART,
  bug: BUG_ART,
  crown: CROWN_ART,
  'spear-bamboo': SPEAR_ART,
  'spear-iron': SPEAR_ART,
  'spear-gold': SPEAR_ART,
  'spear-crystal': SPEAR_ART,
};

const cache = new Map();

/** Build a derived palette by overriding a few entries (used for garments). */
function withOverride(name, override) {
  if (!override) return PALETTES[name];
  return { ...PALETTES[name], ...override };
}

function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  return c;
}

/** Bake a sprite into an offscreen canvas at an integer scale (cached). */
export function bakeSprite(name, scale = 1, override) {
  const sig = override ? JSON.stringify(override) : '';
  const key = `${name}@${scale}@${sig}`;
  if (cache.has(key)) return cache.get(key);
  const art = SPRITE_ART[name];
  const pal = withOverride(name, override);
  if (!art || !pal) return null;

  const w = art[0].length;
  const h = art.length;
  const canvas = makeCanvas(w * scale, h * scale);
  const ctx = canvas.getContext('2d');
  for (let y = 0; y < h; y += 1) {
    const row = art[y];
    for (let x = 0; x < row.length; x += 1) {
      const color = pal[row[x]];
      if (!color) continue;
      ctx.fillStyle = color;
      ctx.fillRect(x * scale, y * scale, scale, scale);
    }
  }
  cache.set(key, canvas);
  return canvas;
}

/**
 * Blit a sprite centred on (x, y). `flip` mirrors it horizontally, which is how
 * the bats and the warrior face their direction of travel. Sub-pixel positions
 * are rounded so the art never blurs.
 */
export function drawSprite(ctx, name, x, y, scale = 3, options = {}) {
  const art = SPRITE_ART[name];
  if (!art) return;
  const canvas = bakeSprite(name, scale, options.palette);
  const w = canvas.width;
  const h = canvas.height;
  const dx = Math.round(x - w / 2);
  const dy = Math.round(y - h / 2);
  if (options.alpha !== undefined) ctx.globalAlpha = options.alpha;
  if (options.flip) {
    ctx.save();
    ctx.translate(dx + w, dy);
    ctx.scale(-1, 1);
    ctx.drawImage(canvas, 0, 0);
    ctx.restore();
  } else {
    ctx.drawImage(canvas, dx, dy);
  }
  if (options.alpha !== undefined) ctx.globalAlpha = 1;
}

/** Draw a sprite into a caller-supplied canvas element (used by the lobby preview). */
export function renderSpriteToCanvas(target, name, scale, override) {
  const src = bakeSprite(name, scale, override);
  if (!src) return;
  target.width = src.width;
  target.height = src.height;
  const ctx = target.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, target.width, target.height);
  ctx.drawImage(src, 0, 0);
}

export function spriteSize(name, scale = 3) {
  const art = SPRITE_ART[name];
  if (!art) return { w: 0, h: 0 };
  return { w: art[0].length * scale, h: art.length * scale };
}
