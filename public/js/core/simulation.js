/**
 * CodePlay world simulation.
 *
 * Pure logic: no DOM, no canvas, no timers. The renderer draws this state and
 * the UI layer feeds it input, which makes the whole game loop unit-testable.
 *
 * Phases: 'play' -> 'quiz' (the action freezes for a checkpoint) -> 'play'
 *         'play' -> 'cleared' (boss defeated) | 'dead' (hearts empty)
 */
import { createRng } from './rng.js';
import {
  levelConfig, chooseUpgrade, pointsForCorrect, bossPoints, levelClearPoints,
  statsFromUpgrades, perksFrom, emptyUpgrades,
} from './rules.js';
import { pickQuestion } from './quiz.js';

export const WORLD = {
  W: 360,
  H: 640,
  SCALE: 3,
  GROUND_Y: 566,
  PLAYER_MIN_X: 26,
  PLAYER_MAX_X: 334,
};

const BAT_SIZE = { w: 38, h: 24 };
const PLAYER_SIZE = { w: 26, h: 46 };
const SPEAR_SIZE = { w: 6, h: 34 };
const BOSS_SIZE = { w: 84, h: 58 };
const BUG_SIZE = { w: 12, h: 12 };

export const clamp = (v, min, max) => Math.min(max, Math.max(min, v));

/** Axis-aligned bounding box overlap. */
export function aabb(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

const rectOf = (e) => ({ x: e.x - e.w / 2, y: e.y - e.h / 2, w: e.w, h: e.h });
const playerRect = (p) => ({ x: p.x - PLAYER_SIZE.w / 2, y: p.y - PLAYER_SIZE.h / 2, w: PLAYER_SIZE.w, h: PLAYER_SIZE.h });
const batRect = (b) => rectOf({ ...b, ...BAT_SIZE });
const bossRect = (b) => rectOf({ ...b, ...BOSS_SIZE });
const spearRect = (s) => rectOf({ ...s, ...SPEAR_SIZE });
const bugRect = (b) => rectOf({ ...b, ...BUG_SIZE });

export function createSimulation(options = {}) {
  const progress = options.progress || {};
  const rng = options.rng || createRng(options.seed || 20261012);
  const cfg = levelConfig(options.module || progress.module || 1);
  const upgrades = { ...emptyUpgrades(), ...(progress.upgrades || {}) };
  const perks = perksFrom(progress);
  const stats = statsFromUpgrades(upgrades, perks);

  let idSeq = 0;

  const sim = {
    cfg,
    rng,
    progress,
    upgrades,
    perks,
    stats,
    phase: 'play',
    time: 0,
    points: 0,
    hearts: stats.startHearts,
    maxHearts: stats.maxHearts,
    shield: stats.startShield,
    revives: stats.revives,
    player: { x: WORLD.W / 2, y: WORLD.GROUND_Y, vx: 0, facing: 1, invuln: 0, hurt: 0, moveDir: 0, throwing: 0 },
    spears: [],
    bats: [],
    bugs: [],
    particles: [],
    boss: null,
    bossQueued: false,
    bossSpawnTimer: 0,
    bossFight: false,
    spawnTimer: 0.9,
    throwTimer: 0,
    cleared: 0,
    totalCheckpoints: cfg.checkpoints,
    pendingQuiz: null,
    result: null,
    quizStats: { correct: 0, wrong: 0, streak: 0, bestStreak: 0, perfect: true },
    asked: new Set(),
    answerLog: [],
    events: [],
  };

  /* ------------------------------ helpers ------------------------------- */

  const emit = (type, data) => { sim.events.push({ type, ...data }); };

  function recompute() {
    sim.stats = statsFromUpgrades(upgrades, perks);
    sim.maxHearts = sim.stats.maxHearts;
    if (sim.hearts > sim.maxHearts) sim.hearts = sim.maxHearts;
  }

  function burst(x, y, color, count = 8, speed = 80) {
    for (let i = 0; i < count; i += 1) {
      const a = rng() * Math.PI * 2;
      const s = speed * rng.range(0.4, 1.1);
      sim.particles.push({
        x, y,
        vx: Math.cos(a) * s,
        vy: Math.sin(a) * s - 20,
        life: rng.range(0.25, 0.6),
        maxLife: 0.6,
        size: rng.int(2, 3) * (WORLD.SCALE / 3),
        color,
      });
    }
  }

  function grantUpgrade(affinity) {
    const id = chooseUpgrade(rng, upgrades, affinity);
    if (!id) return null;
    upgrades[id] += 1;
    recompute();
    if (id === 'shield') sim.shield += 1;
    return { id, level: upgrades[id] };
  }

  function damagePlayer() {
    if (sim.phase !== 'play' || sim.player.invuln > 0) return;
    sim.player.invuln = 1.6;
    sim.player.hurt = 0.45;
    if (sim.shield > 0) {
      sim.shield -= 1;
      burst(sim.player.x, sim.player.y - 10, '#6bb8ff', 10, 90);
      emit('shield:used', { shield: sim.shield });
      return;
    }
    sim.hearts -= 1;
    burst(sim.player.x, sim.player.y - 20, '#ef6a5a', 10, 90);
    emit('heart:lost', { hearts: sim.hearts });
    if (sim.hearts <= 0) {
      if (sim.revives > 0) {
        sim.revives -= 1;
        sim.hearts = 1;
        sim.player.invuln = 2.6;
        emit('revive', { hearts: 1 });
      } else {
        sim.phase = 'dead';
        emit('gameover', {});
      }
    }
  }

  /* ------------------------------ spawning ------------------------------ */

  function spawnBat() {
    const fromLeft = rng.chance(0.5);
    const baseY = rng.range(cfg.batAltitudeMin, cfg.batAltitudeMax);
    const speed = cfg.batSpeed * rng.range(0.85, 1.15);
    const hp = 1 + cfg.lap;
    sim.bats.push({
      id: (idSeq += 1),
      kind: 'bat',
      x: fromLeft ? -40 : WORLD.W + 40,
      y: baseY,
      baseY,
      vx: fromLeft ? speed : -speed,
      w: BAT_SIZE.w,
      h: BAT_SIZE.h,
      hp,
      maxHp: hp,
      bob: rng.range(0, Math.PI * 2),
      mode: 'wave',
      diving: rng.chance(cfg.swoopChance),
      diveAt: sim.time + rng.range(3.5, 9),
      hitFlash: 0,
      alive: true,
    });
  }

  function spawnBoss() {
    sim.bats.length = 0;
    sim.bossQueued = false;
    sim.bossFight = true;
    const hp = cfg.bossHp;
    sim.boss = {
      id: (idSeq += 1),
      kind: 'boss',
      x: WORLD.W / 2,
      y: 150,
      vx: cfg.bossSpeed,
      w: BOSS_SIZE.w,
      h: BOSS_SIZE.h,
      hp,
      maxHp: hp,
      invuln: 1.1,
      hitFlash: 0,
      fireTimer: 1.8,
      bob: 0,
      alive: true,
    };
    emit('boss:spawn', { hp, maxHp: hp });
  }

  function fireBug(boss) {
    const shots = cfg.module >= 4 ? 3 : 1;
    for (let i = 0; i < shots; i += 1) {
      const spread = (i - (shots - 1) / 2) * 0.16;
      const dx = sim.player.x - boss.x;
      const dy = WORLD.GROUND_Y - 24 - boss.y;
      const ang = Math.atan2(dy, dx) + spread;
      sim.bugs.push({
        x: boss.x,
        y: boss.y + 26,
        vx: Math.cos(ang) * cfg.bugSpeed,
        vy: Math.sin(ang) * cfg.bugSpeed,
        w: BUG_SIZE.w,
        h: BUG_SIZE.h,
        spin: 0,
        alive: true,
      });
    }
    emit('boss:fire', {});
  }

  /* -------------------------------- actions ----------------------------- */

  sim.setMove = (dir) => { sim.player.moveDir = clamp(Math.sign(dir) || 0, -1, 1); };

  /** One press, one spear. Never a fan: holding the button down must not fire. */
  sim.throwSpear = () => {
    if (sim.phase !== 'play' || sim.throwTimer > 0) return false;
    const p = sim.player;
    sim.spears.push({
      x: p.x + 8 * p.facing,
      y: p.y - 34,
      vx: 0,
      vy: -sim.stats.spearSpeed,
      dmg: sim.stats.weaponDamage,
      alive: true,
      spin: 0,
    });
    sim.throwTimer = sim.stats.throwCooldown;
    sim.player.throwing = 0.18;
    emit('throw', {});
    return true;
  };

  function openQuiz(target, ref) {
    const question = pickQuestion(progress, cfg.lang, cfg, rng, sim.asked);
    sim.asked.add(question.id);
    sim.pendingQuiz = { question, target, ref: ref || null };
    sim.result = null;
    sim.phase = 'quiz';
    emit('quiz:open', { question, target });
  }
  sim.openQuiz = openQuiz;

  /** Lock in an answer. Returns the result object (or null when not quizzing). */
  sim.answer = (index) => {
    if (sim.phase !== 'quiz' || !sim.pendingQuiz || sim.result) return null;
    const question = sim.pendingQuiz.question;
    const correct = Number(index) === Number(question.answer);
    if (correct) {
      sim.quizStats.correct += 1;
      sim.quizStats.streak += 1;
      sim.quizStats.bestStreak = Math.max(sim.quizStats.bestStreak, sim.quizStats.streak);
      const points = pointsForCorrect(question.difficulty, sim.quizStats.streak, sim.stats.pointBonus);
      sim.points += points;
      const upgrade = grantUpgrade(question.reward);
      sim.result = { correct: true, chosen: index, question, points, upgrade, streak: sim.quizStats.streak };
    } else {
      sim.quizStats.wrong += 1;
      sim.quizStats.streak = 0;
      sim.quizStats.perfect = false;
      sim.result = { correct: false, chosen: index, question, points: 0, upgrade: null, streak: 0 };
    }
    sim.answerLog.push({ id: question.id, lang: question.lang, correct });
    emit('quiz:result', sim.result);
    return sim.result;
  };

  /** Leave the feedback panel: resume play, damage the boss, or end the module. */
  sim.continueAfterQuiz = () => {
    if (sim.phase !== 'quiz' || !sim.pendingQuiz || !sim.result) return;
    const { target, ref } = sim.pendingQuiz;
    const res = sim.result;
    const boss = sim.boss;
    if (target === 'boss' && boss && ref === boss) {
      if (res.correct) {
        boss.hp -= 1;
        boss.invuln = 1.4;
        boss.hitFlash = 0.3;
        burst(boss.x, boss.y, '#b98bff', 14, 110);
        emit('boss:hit', { hp: boss.hp, maxHp: boss.maxHp });
        if (boss.hp <= 0) {
          defeatBoss(boss);
          return;
        }
      } else {
        boss.invuln = 1.6; // grace period: the same miss is not asked again instantly
      }
    }
    sim.pendingQuiz = null;
    sim.result = null;
    sim.phase = 'play';
  };

  function defeatBoss(boss) {
    burst(boss.x, boss.y, '#f2c14e', 26, 150);
    sim.boss = null;
    sim.phase = 'cleared';
    const bonus = bossPoints(cfg.module) + levelClearPoints(cfg.module, sim.quizStats.perfect);
    sim.points += bonus;
    emit('level:cleared', {
      points: bonus,
      module: cfg.module,
      lang: cfg.lang,
      stats: { ...sim.quizStats },
      perfect: sim.quizStats.perfect,
    });
  }

  sim.drainEvents = () => {
    const out = sim.events;
    sim.events = [];
    return out;
  };

  sim.progressRatio = () => (sim.bossFight ? 1 : sim.totalCheckpoints ? sim.cleared / sim.totalCheckpoints : 0);

  /* --------------------------------- update ------------------------------ */

  function updateParticles(dt) {
    for (const p of sim.particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 160 * dt;
      p.life -= dt;
    }
    sim.particles = sim.particles.filter((p) => p.life > 0);
  }

  function updateSpears(dt) {
    for (const sp of sim.spears) {
      sp.x += sp.vx * dt;
      sp.y += sp.vy * dt;
      sp.spin += dt * 12;
      if (sp.y < -40 || sp.x < -24 || sp.x > WORLD.W + 24) { sp.alive = false; continue; }

      for (const bug of sim.bugs) {
        if (!bug.alive) continue;
        if (!aabb(spearRect(sp), bugRect(bug))) continue;
        bug.alive = false;
        burst(bug.x, bug.y, '#7ee3e3', 6, 70);
        if (sim.stats.pierce < 1) sp.alive = false;
        break;
      }
      if (!sp.alive) continue;

      for (const bat of sim.bats) {
        if (!bat.alive) continue;
        if (!aabb(spearRect(sp), batRect(bat))) continue;
        bat.hp -= sp.dmg;
        bat.hitFlash = 0.18;
        if (bat.hp <= 0) {
          bat.alive = false;
          sim.cleared += 1;
          burst(bat.x, bat.y, '#f2c14e', 12, 100);
          emit('bat:cleared', { x: bat.x, y: bat.y, cleared: sim.cleared, total: sim.totalCheckpoints });
          if (sim.stats.pierce < 1) sp.alive = false;
          // Only counted checkpoints open a question. Anything left on screen as the
          // boss approaches is a free kill and must not inflate the wave total.
          if (sim.cleared <= sim.totalCheckpoints) openQuiz('bat', bat);
        } else {
          burst(sp.x, sp.y, '#e8eef7', 4, 50);
          if (sim.stats.pierce < 1) sp.alive = false;
        }
        break;
      }
      if (sim.phase !== 'play') break;

      const boss = sim.boss;
      if (boss && boss.alive && boss.invuln <= 0 && aabb(spearRect(sp), bossRect(boss))) {
        if (sim.stats.pierce < 2) sp.alive = false;
        openQuiz('boss', boss);
        break;
      }
    }
    sim.spears = sim.spears.filter((s) => s.alive);
    sim.bugs = sim.bugs.filter((b) => b.alive);
  }

  function updateBats(dt) {
    const pr = playerRect(sim.player);
    for (const bat of sim.bats) {
      if (!bat.alive) continue;
      bat.bob += dt * 2.4;
      if (bat.hitFlash > 0) bat.hitFlash -= dt;

      if (bat.mode === 'wave') {
        bat.x += bat.vx * dt;
        bat.y = bat.baseY + Math.sin(bat.bob) * 7;
        if (bat.diving && sim.time >= bat.diveAt) bat.mode = 'dive';
      } else if (bat.mode === 'dive') {
        bat.y += 155 * dt;
        bat.x += Math.sign(sim.player.x - bat.x) * 48 * dt;
        if (bat.y > WORLD.GROUND_Y - 16) bat.mode = 'return';
      } else {
        bat.y -= 135 * dt;
        if (bat.y <= bat.baseY) {
          bat.y = bat.baseY;
          bat.mode = 'wave';
          bat.diveAt = sim.time + rng.range(4.5, 10);
        }
      }

      if (bat.x < -60) bat.x = WORLD.W + 60;
      if (bat.x > WORLD.W + 60) bat.x = -60;

      if (aabb(batRect(bat), pr)) damagePlayer();
    }
    sim.bats = sim.bats.filter((b) => b.alive);
  }

  function updateBoss(dt) {
    const boss = sim.boss;
    if (!boss || !boss.alive) return;
    boss.bob += dt * 1.6;
    boss.x += boss.vx * dt;
    if (boss.x < 72) { boss.x = 72; boss.vx = Math.abs(boss.vx); }
    if (boss.x > WORLD.W - 72) { boss.x = WORLD.W - 72; boss.vx = -Math.abs(boss.vx); }
    boss.y = 150 + Math.sin(boss.bob) * 16;
    if (boss.invuln > 0) boss.invuln -= dt;
    if (boss.hitFlash > 0) boss.hitFlash -= dt;
    boss.fireTimer -= dt;
    if (boss.fireTimer <= 0) {
      boss.fireTimer = cfg.bossFireInterval * rng.range(0.8, 1.25);
      fireBug(boss);
    }
    if (aabb(bossRect(boss), playerRect(sim.player))) damagePlayer();
  }

  function updateBugs(dt) {
    const pr = playerRect(sim.player);
    for (const bug of sim.bugs) {
      if (!bug.alive) continue;
      bug.x += bug.vx * dt;
      bug.y += bug.vy * dt;
      bug.spin += dt * 10;
      if (bug.y > WORLD.H + 20 || bug.x < -30 || bug.x > WORLD.W + 30) { bug.alive = false; continue; }
      if (aabb(bugRect(bug), pr)) {
        bug.alive = false;
        damagePlayer();
      }
    }
    sim.bugs = sim.bugs.filter((b) => b.alive);
  }

  sim.update = (rawDt) => {
    const dt = Math.min(Math.max(rawDt, 0), 0.05); // clamp so a stalled tab cannot teleport anything
    sim.time += dt;
    updateParticles(dt);

    if (sim.phase !== 'play') return;

    const p = sim.player;
    p.x = clamp(p.x + p.moveDir * sim.stats.moveSpeed * dt, WORLD.PLAYER_MIN_X, WORLD.PLAYER_MAX_X);
    if (p.moveDir !== 0) p.facing = p.moveDir;
    if (p.invuln > 0) p.invuln -= dt;
    if (p.hurt > 0) p.hurt -= dt;
    if (p.throwing > 0) p.throwing -= dt;
    if (sim.throwTimer > 0) sim.throwTimer -= dt;

    updateSpears(dt);
    if (sim.phase !== 'play') return;
    updateBats(dt);
    if (sim.phase !== 'play') return;
    updateBoss(dt);
    updateBugs(dt);
    if (sim.phase !== 'play') return;

    if (!sim.bossFight && sim.cleared < sim.totalCheckpoints) {
      sim.spawnTimer -= dt;
      if (sim.spawnTimer <= 0 && sim.bats.length < 3) {
        spawnBat();
        sim.spawnTimer = cfg.spawnInterval * rng.range(0.75, 1.25);
      }
    } else if (!sim.bossFight && !sim.bossQueued) {
      sim.bossQueued = true;
      sim.bossSpawnTimer = 1.3;
      sim.bats.length = 0; // the swarm scatters before the boss descends
      emit('boss:incoming', {});
    }
    if (sim.bossQueued && !sim.boss) {
      sim.bossSpawnTimer -= dt;
      if (sim.bossSpawnTimer <= 0) spawnBoss();
    }
  };

  /** Test/debug helper: run the world forward without input. */
  sim.step = (seconds, step = 1 / 60) => {
    for (let t = 0; t < seconds; t += step) sim.update(step);
  };

  return sim;
}
