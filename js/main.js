/**
 * CodePlay bootstrap: owns the requestAnimationFrame loop, input, persistence
 * and the routing between the DOM screens and the pure simulation.
 */
import { createSimulation } from './core/simulation.js';
import { createRenderer } from './render/renderer.js';
import { createUI } from './ui.js';
import { loadProgress, saveProgress } from './core/save.js';
import {
  levelConfig, buyItem, equipItem, newBadges, badgeById,
  pointsForCorrect, derivedStats, accuracy,
} from './core/rules.js';
import { LANGUAGES } from './data/questions.js';
import { playSfx, setSoundEnabled as setAudioEnabled, unlockAudio } from './audio.js';

const canvas = document.getElementById('game');
const renderer = createRenderer(canvas);

let progress = loadProgress();
let sim = null;
let raf = 0;
let lastTime = 0;
let hudClock = 0;

const state = { mode: 'lobby', paused: false, bannerAction: 'next' };
const held = { left: false, right: false };

/* --------------------------------- helpers -------------------------------- */

const save = () => saveProgress(progress);

function checkBadges() {
  const fresh = newBadges(progress, progress.badges);
  for (const id of fresh) {
    progress.badges.push(id);
    const badge = badgeById(id);
    if (badge) {
      playSfx('badge');
      ui.toast(`${badge.icon} Badge unlocked — ${badge.name}`, 'good');
    }
  }
  return fresh;
}

function langRecord(id) {
  return LANGUAGES.find((l) => l.id === id) || LANGUAGES[0];
}

/* ------------------------------- lifecycle -------------------------------- */

function startModule(module) {
  const cfg = levelConfig(module);
  progress.module = module;
  sim = createSimulation({ progress, module, seed: (Date.now() ^ (module * 2654435761)) >>> 0 });
  state.mode = 'play';
  state.paused = false;
  held.left = false;
  held.right = false;
  renderer.setSky(cfg.sky, module * 7919);
  ui.setGameVisible(true);
  ui.hideScreens();
  ui.updateHUD(sim, progress);
  const lang = langRecord(cfg.lang);
  ui.toast(`Module ${module} · ${lang.name} — ${lang.blurb}`, 'good');
  save();
}

function toLobby() {
  sim = null;
  state.mode = 'lobby';
  state.paused = false;
  ui.setGameVisible(false);
  ui.renderLobby(progress);
  ui.show('screen-lobby');
  save();
}

/* --------------------------- progress bookkeeping ------------------------- */

function applyAnswer(result) {
  const question = result.question;
  const lang = question.lang;
  progress.mastery[lang] = progress.mastery[lang] || { correct: 0, wrong: 0 };
  if (result.correct) {
    progress.correct += 1;
    progress.streak = result.streak;
    progress.bestStreak = Math.max(progress.bestStreak, result.streak);
    progress.points += result.points;
    progress.answered[question.id] = true;
    progress.mastery[lang].correct += 1;
    if (result.upgrade) progress.upgrades[result.upgrade.id] = result.upgrade.level;
  } else {
    progress.wrong += 1;
    progress.streak = 0;
    progress.mastery[lang].wrong += 1;
  }
  checkBadges();
  save();
}

/* --------------------------------- events --------------------------------- */

function pumpEvents() {
  if (!sim) return;
  for (const ev of sim.drainEvents()) {
    switch (ev.type) {
      case 'throw':
        playSfx('throw');
        break;
      case 'bat:cleared':
        playSfx('absorb');
        renderer.addPopup('CODE ABSORBED', ev.x, ev.y - 24, '#5fe08a');
        break;
      case 'quiz:open': {
        state.mode = 'quiz';
        const preview = pointsForCorrect(ev.question.difficulty, sim.quizStats.streak + 1, sim.stats.pointBonus);
        ui.showQuiz(ev.question, ev.target, `+${preview} ◈`);
        break;
      }
      case 'quiz:result':
        playSfx(ev.correct ? 'correct' : 'wrong');
        applyAnswer(ev);
        ui.showQuizResult(ev, null);
        break;
      case 'boss:incoming':
        ui.toast('⚠ Something large is flying in…', 'bad');
        break;
      case 'boss:spawn':
        playSfx('boss');
        ui.toast('👑 Syntax Overlord — every correct answer is a wound', 'bad');
        break;
      case 'boss:hit':
        renderer.addPopup(`${ev.hp} HP LEFT`, sim.boss ? sim.boss.x : 180, (sim.boss ? sim.boss.y : 150) - 54, '#e0455f');
        break;
      case 'heart:lost':
        playSfx('hurt');
        ui.toast('♥ Heart lost', 'bad');
        break;
      case 'shield:used':
        playSfx('shield');
        ui.toast('✦ Shield absorbed the hit', '');
        break;
      case 'revive':
        playSfx('badge');
        ui.toast('✧ The Elder Headdress pulls you back up', 'good');
        break;
      case 'level:cleared':
        playSfx('clear');
        onLevelCleared(ev);
        break;
      case 'gameover':
        onGameOver();
        break;
      default:
        break;
    }
  }
}

function onLevelCleared(ev) {
  progress.modulesCleared += 1;
  progress.bossesDefeated += 1;
  progress.points += ev.points;
  progress.module = Math.min(99, ev.module + 1);
  progress.highestModule = Math.max(progress.highestModule, progress.module);
  checkBadges();
  save();

  const lang = langRecord(ev.lang);
  const next = levelConfig(progress.module);
  const nextLang = langRecord(next.lang);
  const attempts = ev.stats.correct + ev.stats.wrong;
  state.mode = 'banner';
  state.bannerAction = 'next';
  ui.setGameVisible(false);
  ui.showBanner({
    emoji: '👑',
    title: `Module ${ev.module} cleared`,
    body: `Every ${lang.name} checkpoint absorbed and the Syntax Overlord defeated.${ev.perfect ? ' Flawless run — no wrong answers!' : ''} Next up: ${nextLang.name} — ${nextLang.blurb}.`,
    stats: [
      ['Checkpoints cleared', `${ev.stats.correct}/${attempts}`],
      ['Accuracy this module', `${attempts ? Math.round((ev.stats.correct / attempts) * 100) : 0}%`],
      ['Best streak', ev.stats.bestStreak],
      ['Clear bonus', `+${ev.points} ◈`],
      ['Total points', progress.points],
    ],
    primary: `Start Module ${progress.module} ▶`,
    secondary: 'Back to lobby',
  });
}

function onGameOver() {
  save();
  state.mode = 'banner';
  state.bannerAction = 'retry';
  ui.setGameVisible(false);
  ui.showBanner({
    emoji: '💀',
    title: 'The bats won this round',
    body: `You cleared ${sim.cleared} of ${sim.totalCheckpoints} checkpoints in the ${langRecord(sim.cfg.lang).name} module. Your points, badges and mastery are all saved — try again.`,
    stats: [
      ['Checkpoints cleared', `${sim.cleared}/${sim.totalCheckpoints}`],
      ['Correct answers', sim.quizStats.correct],
      ['Wrong answers', sim.quizStats.wrong],
      ['Points this run', sim.points],
      ['Total points', progress.points],
    ],
    primary: 'Retry this module ▶',
    secondary: 'Back to lobby',
  });
}

/* ---------------------------------- input --------------------------------- */

function syncMove() {
  if (!sim) return;
  sim.setMove((held.right ? 1 : 0) - (held.left ? 1 : 0));
}

function bindHoldButton(id, onDown, onUp) {
  const node = document.getElementById(id);
  if (!node) return;
  const down = (e) => {
    e.preventDefault();
    node.classList.add('held');
    onDown();
  };
  const up = () => {
    node.classList.remove('held');
    onUp();
  };
  node.addEventListener('pointerdown', down);
  node.addEventListener('pointerup', up);
  node.addEventListener('pointercancel', up);
  node.addEventListener('pointerleave', up);
  node.addEventListener('contextmenu', (e) => e.preventDefault());
}

function bindInput() {
  bindHoldButton('btn-left', () => { held.left = true; syncMove(); }, () => { held.left = false; syncMove(); });
  bindHoldButton('btn-right', () => { held.right = true; syncMove(); }, () => { held.right = false; syncMove(); });
  // Single shot: the press throws, and holding the button down throws nothing
  // more - there is no auto-repeat.
  bindHoldButton('btn-throw', () => { if (sim) sim.throwSpear(); }, () => {});

  window.addEventListener('keydown', (e) => {
    if (e.repeat) return;
    switch (e.key) {
      case 'ArrowLeft': case 'a': case 'A': held.left = true; syncMove(); break;
      case 'ArrowRight': case 'd': case 'D': held.right = true; syncMove(); break;
      case ' ': case 'ArrowUp': case 'w': case 'W':
        e.preventDefault();
        if (sim) sim.throwSpear();
        break;
      case 'Escape': case 'p': case 'P':
        if (state.mode === 'play') togglePause(true);
        else if (state.paused) togglePause(false);
        break;
      case '1': case '2': case '3': case '4':
        if (state.mode === 'quiz' && sim && !sim.result) {
          const index = Number(e.key) - 1;
          if (sim.pendingQuiz && index < sim.pendingQuiz.question.choices.length) onAnswer(index);
        }
        break;
      case 'Enter':
        if (state.mode === 'quiz' && sim && sim.result) onQuizContinue();
        break;
      default: break;
    }
  });

  window.addEventListener('keyup', (e) => {
    switch (e.key) {
      case 'ArrowLeft': case 'a': case 'A': held.left = false; syncMove(); break;
      case 'ArrowRight': case 'd': case 'D': held.right = false; syncMove(); break;
      default: break;
    }
  });

  window.addEventListener('blur', () => {
    held.left = false; held.right = false;
    if (sim) sim.setMove(0);
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && state.mode === 'play') togglePause(true);
  });
  window.addEventListener('pagehide', save);
}

function togglePause(next) {
  if (!sim) return;
  state.paused = next;
  if (next) ui.showPause(sim, progress);
  else ui.hideScreens();
}

/* ------------------------------- interactions ----------------------------- */

function onAnswer(index) {
  if (!sim || sim.phase !== 'quiz' || sim.result) return;
  sim.answer(index);
  pumpEvents();
}

function onQuizContinue() {
  if (!sim || sim.phase !== 'quiz' || !sim.result) return;
  sim.continueAfterQuiz();
  pumpEvents();
  if (state.mode === 'quiz') {
    state.mode = 'play';
    ui.hideScreens();
  }
}

const ui = createUI({
  start: () => { playSfx('click'); startModule(progress.module); },
  selectHero: (hero) => {
    progress.hero = hero === 'girl' ? 'girl' : 'boy';
    save();
    ui.renderLobby(progress);
  },
  rename: (name) => {
    progress.name = String(name || '').slice(0, 12);
    save();
  },
  openShop: () => { playSfx('click'); ui.renderShop(progress); ui.show('screen-shop'); },
  openProgress: () => { playSfx('click'); ui.renderProgress(progress); ui.show('screen-progress'); },
  openReview: () => { playSfx('click'); ui.renderReview(progress); ui.show('screen-review'); },
  openLobby: () => toLobby(),
  howtoDone: () => {
    if (!progress.tutorialSeen) {
      progress.tutorialSeen = true;
      save();
    }
  },
  sound: () => toggleSound(),
  answer: onAnswer,
  quizContinue: onQuizContinue,
  afterResult: () => {},
  buy: (itemId) => {
    const outcome = buyItem(progress, itemId);
    if (!outcome.ok) {
      ui.toast(`Can't buy: ${outcome.reason}`, 'bad');
    } else {
      progress = outcome.progress;
      checkBadges();
      save();
      ui.toast(`Bought ${outcome.item.name}`, 'good');
    }
    ui.renderShop(progress);
  },
  equip: (itemId) => {
    const outcome = equipItem(progress, itemId);
    if (outcome.ok) {
      progress = outcome.progress;
      save();
      ui.toast(`Equipped ${itemId.split('-').slice(1).join(' ')}`, 'good');
    }
    ui.renderShop(progress);
  },
  pause: () => { playSfx('click'); togglePause(true); },
  resume: () => { playSfx('click'); togglePause(false); },
  restart: () => startModule(progress.module),
  quit: () => toLobby(),
  bannerPrimary: () => startModule(progress.module),
  bannerSecondary: () => toLobby(),
});

/* --------------------------------- sound ---------------------------------- */

/** Mute/unmute, and remember the choice in the save file. */
function toggleSound() {
  progress.sound = progress.sound === false;
  setAudioEnabled(progress.sound);
  ui.setSoundEnabled(progress.sound);
  save();
  if (progress.sound) playSfx('click');
  ui.toast(progress.sound ? 'Sound on' : 'Sound muted', '');
}

/* ---------------------------------- loop ---------------------------------- */

/** One tick of the world. Kept separate from the rAF wrapper so it can be driven by tests. */
function step(dt) {
  if (!sim) return;
  sim.update(dt);
  pumpEvents();

  hudClock += dt;
  if (hudClock > 0.12) {
    hudClock = 0;
    ui.updateHUD(sim, progress);
  }

  renderer.draw(sim, {
    dt,
    time: sim.time,
    hero: progress.hero,
    equipped: progress.equipped,
  });
}

function frame(now) {
  raf = requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - lastTime) / 1000 || 0);
  lastTime = now;
  step(dt);
}

/* ---------------------------------- boot ---------------------------------- */

bindInput();
setAudioEnabled(progress.sound !== false);
ui.setSoundEnabled(progress.sound !== false);
ui.setGameVisible(false);
ui.renderLobby(progress);
ui.renderShop(progress);
ui.renderProgress(progress);
ui.renderReview(progress);
syncMove();
// The tutorial interrupts the first run only; after that the lobby button opens it.
if (!progress.tutorialSeen) ui.showHowTo(true);

document.addEventListener('pointerdown', unlockAudio, { once: true });
document.addEventListener('keydown', unlockAudio, { once: true });
lastTime = performance.now();
raf = requestAnimationFrame(frame);

// exposed for debugging and for the automated smoke test
window.CodePlay = {
  get progress() { return progress; },
  get sim() { return sim; },
  get state() { return state; },
  startModule,
  toLobby,
  onAnswer,
  onQuizContinue,
  tick: step,
  start: () => startModule(progress.module),
  stats: () => derivedStats(progress),
  accuracy: () => accuracy(progress),
  reload: () => { progress = loadProgress(); },
};
