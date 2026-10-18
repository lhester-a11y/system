/**
 * World renderer: turns the simulation state into pixels.
 * Reads the sim, never mutates it.
 */
import { WORLD } from '../core/simulation.js';
import { createBackground } from './background.js';
import { drawSprite } from './sprites.js';

/** Cloth colour overrides so a bought garment is visible on the sprite. */
const GARMENT_PALETTES = {
  'garment-tapis': { r: '#3f6b9e', y: '#8fc6d8', w: '#dbeaf7' },
  'garment-blank': { r: '#8a5c3c', y: '#b8871c', w: '#d9c9a8' },
  'garment-crown': { r: '#5f3f8e', y: '#f2c14e', w: '#efe3ff' },
};

const EFFECT_STYLES = {
  'effect-fly':   { colors: ['#e8f77a', '#b7ffd2'], count: 10, radius: 26, life: 1.4, gravity: -4 },
  'effect-ember': { colors: ['#f2a65a', '#ef6a5a'], count: 8, radius: 20, life: 1.0, gravity: -18 },
  'effect-leaf':  { colors: ['#86b566', '#d9c9a8'], count: 7, radius: 30, life: 1.8, gravity: 12 },
  'effect-spark': { colors: ['#7ee3e3', '#6bb8ff'], count: 9, radius: 24, life: 0.9, gravity: 6 },
};

export function createRenderer(canvas) {
  const ctx = canvas.getContext('2d', { alpha: false });
  ctx.imageSmoothingEnabled = false;

  let background = createBackground('day', 1337);
  let skyName = 'day';
  let ambient = [];
  const popups = [];
  let seedCounter = 1;

  function setSky(next, seed) {
    if (next === skyName && seed === undefined) return;
    skyName = next;
    background = createBackground(next, seed === undefined ? (seedCounter += 1) * 977 : seed);
  }

  function addPopup(text, x, y, color = '#f2c14e') {
    popups.push({ text, x, y, color, life: 1.1, maxLife: 1.1 });
  }

  function updateAmbient(dt, effectId, player) {
    const style = EFFECT_STYLES[effectId];
    ambient = ambient.filter((p) => p.life > 0);
    if (!style) {
      ambient.length = 0;
      return;
    }
    if (ambient.length < style.count) {
      const a = Math.random() * Math.PI * 2;
      const r = style.radius * (0.5 + Math.random() * 0.6);
      ambient.push({
        x: player.x + Math.cos(a) * r,
        y: player.y - 10 + Math.sin(a) * r * 0.6,
        vx: (Math.random() - 0.5) * 12,
        vy: style.gravity * Math.random(),
        life: style.life,
        maxLife: style.life,
        size: Math.random() > 0.6 ? 3 : 2,
        color: style.colors[Math.floor(Math.random() * style.colors.length)],
      });
    }
    for (const p of ambient) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
    }
  }

  function drawPopups(dt) {
    for (const p of popups) {
      p.y -= 26 * dt;
      p.life -= dt;
      if (p.life <= 0) continue;
      ctx.globalAlpha = Math.min(1, p.life / 0.5);
      ctx.font = 'bold 11px ui-monospace, monospace';
      ctx.textAlign = 'center';
      ctx.fillStyle = '#05070d';
      ctx.fillText(p.text, Math.round(p.x) + 1, Math.round(p.y) + 1);
      ctx.fillStyle = p.color;
      ctx.fillText(p.text, Math.round(p.x), Math.round(p.y));
      ctx.globalAlpha = 1;
    }
    ctx.textAlign = 'left';
    for (let i = popups.length - 1; i >= 0; i -= 1) if (popups[i].life <= 0) popups.splice(i, 1);
  }

  function drawSpear(sp, design) {
    ctx.save();
    ctx.translate(Math.round(sp.x), Math.round(sp.y));
    if (Math.abs(sp.vx) > 6) ctx.rotate(Math.atan2(sp.vy, sp.vx) + Math.PI / 2);
    drawSprite(ctx, `spear-${design || 'bamboo'}`, 0, 0, 3);
    ctx.restore();
  }

  function drawBats(sim, view) {
    for (const bat of sim.bats) {
      const flap = Math.sin(bat.bob * 2.2 + bat.id) * 1.5;
      const alpha = bat.mode === 'dive' ? 1 : 0.96;
      drawSprite(ctx, 'bat', bat.x, bat.y + flap, 3, {
        flip: bat.vx > 0,
        palette: bat.hitFlash > 0 ? { f: '#ffffff', w: '#ffe0e0', b: '#ffffff' } : undefined,
        alpha,
      });
      if (bat.maxHp > 1 && bat.hp < bat.maxHp) {
        ctx.fillStyle = '#0a0e18';
        ctx.fillRect(Math.round(bat.x) - 16, Math.round(bat.y) - 26, 32, 5);
        ctx.fillStyle = '#5fe08a';
        ctx.fillRect(Math.round(bat.x) - 15, Math.round(bat.y) - 25, Math.round(30 * (bat.hp / bat.maxHp)), 3);
      }
      if (bat.mode === 'dive') {
        ctx.globalAlpha = 0.4 + 0.3 * Math.sin(view.time * 18);
        ctx.fillStyle = '#ef6a5a';
        ctx.fillRect(Math.round(bat.x) - 3, Math.round(bat.y) + 20, 6, 6);
        ctx.globalAlpha = 1;
      }
    }
  }

  function drawBoss(sim, view) {
    const boss = sim.boss;
    if (!boss) return;
    const flap = Math.sin(boss.bob * 1.9) * 2;
    drawSprite(ctx, 'bat', boss.x, boss.y + flap, 6, {
      flip: boss.vx > 0,
      palette: boss.hitFlash > 0 ? { f: '#ffd9e0', w: '#ffffff', b: '#ffffff', G: '#ff9db0' } : undefined,
      alpha: boss.invuln > 0 ? 0.62 + 0.3 * Math.sin(view.time * 22) : 1,
    });
    drawSprite(ctx, 'crown', boss.x, boss.y - 46 + flap, 3);
    // health bar
    // Kept clear of the DOM HUD at the top of the stage.
    const w = 128;
    const x = Math.round(WORLD.W / 2 - w / 2);
    ctx.fillStyle = '#05070d';
    ctx.fillRect(x - 2, 74, w + 4, 12);
    ctx.fillStyle = '#2a1330';
    ctx.fillRect(x, 76, w, 8);
    ctx.fillStyle = '#e0455f';
    ctx.fillRect(x, 76, Math.round(w * (boss.hp / boss.maxHp)), 8);
    ctx.fillStyle = '#ffd9e0';
    ctx.font = 'bold 9px ui-monospace, monospace';
    ctx.textAlign = 'center';
    ctx.fillText('SYNTAX OVERLORD', WORLD.W / 2, 70);
    ctx.textAlign = 'left';
  }

  function drawPlayer(sim, view) {
    const p = sim.player;
    const gear = view.equipped || {};
    const palette = GARMENT_PALETTES[gear.garment];
    if (p.invuln > 0 && Math.floor(view.time * 14) % 2 === 0) return;
    drawSprite(ctx, view.hero === 'girl' ? 'girl' : 'boy', p.x, p.y, 3, { flip: p.facing < 0, palette });
    if (gear.garment === 'garment-crown') {
      drawSprite(ctx, 'crown', p.x, p.y - 32, 2, { flip: p.facing < 0 });
    }
    if (sim.shield > 0) {
      ctx.globalAlpha = 0.28 + 0.12 * Math.sin(view.time * 6);
      ctx.fillStyle = '#6bb8ff';
      ctx.fillRect(Math.round(p.x) - 20, Math.round(p.y) - 30, 40, 6);
      ctx.fillRect(Math.round(p.x) - 20, Math.round(p.y) + 24, 40, 6);
      ctx.fillRect(Math.round(p.x) - 22, Math.round(p.y) - 24, 4, 48);
      ctx.fillRect(Math.round(p.x) + 18, Math.round(p.y) - 24, 4, 48);
      ctx.globalAlpha = 1;
    }
  }

  function draw(sim, view = {}) {
    const dt = view.dt || 0;
    const time = view.time || 0;
    ctx.fillStyle = '#05070d';
    ctx.fillRect(0, 0, WORLD.W, WORLD.H);

    background.draw(ctx, sim.player.x, time);

    updateAmbient(dt, (view.equipped || {}).effect, sim.player);

    for (const bug of sim.bugs) {
      drawSprite(ctx, 'bug', bug.x, bug.y, 3, { alpha: 0.95 });
    }
    drawBats(sim, view);
    drawBoss(sim, view);
    const design = ((view.equipped || {}).spear || 'spear-bamboo').replace('spear-', '');
    for (const sp of sim.spears) drawSpear(sp, design);
    drawPlayer(sim, view);

    for (const p of sim.particles) {
      ctx.globalAlpha = Math.max(0, Math.min(1, p.life / p.maxLife));
      ctx.fillStyle = p.color;
      ctx.fillRect(Math.round(p.x), Math.round(p.y), p.size, p.size);
    }
    ctx.globalAlpha = 1;

    for (const p of ambient) {
      ctx.globalAlpha = Math.max(0, Math.min(1, p.life / p.maxLife)) * 0.9;
      ctx.fillStyle = p.color;
      ctx.fillRect(Math.round(p.x), Math.round(p.y), p.size, p.size);
    }
    ctx.globalAlpha = 1;

    drawPopups(dt);

    // vignette so the sprites read against the bright sky
    const grad = ctx.createLinearGradient(0, 0, 0, WORLD.H);
    grad.addColorStop(0, 'rgba(4,7,15,0.34)');
    grad.addColorStop(0.22, 'rgba(4,7,15,0)');
    grad.addColorStop(0.82, 'rgba(4,7,15,0)');
    grad.addColorStop(1, 'rgba(4,7,15,0.38)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, WORLD.W, WORLD.H);
  }

  return { draw, setSky, addPopup, get skyName() { return skyName; } };
}
