/**
 * DOM interface: lobby, HUD, learning-checkpoint modal, shop, progress tracker.
 * All text lives in the DOM rather than the canvas so it stays crisp on phones
 * and readable by screen readers.
 */
import { renderSpriteToCanvas } from './render/sprites.js';
import { BADGES, UPGRADES, SHOP_CATEGORIES, itemsInCategory, shopItem, canBuy, derivedStats, masteryPercent, accuracy, solvedIds } from './core/rules.js';
import { LANGUAGES, questionsFor } from './data/questions.js';
import { questionMeta } from './core/quiz.js';

const $ = (id) => document.getElementById(id);

const GARMENT_PALETTES = {
  'garment-tapis': { r: '#3f6b9e', y: '#8fc6d8', w: '#dbeaf7' },
  'garment-blank': { r: '#8a5c3c', y: '#b8871c', w: '#d9c9a8' },
  'garment-crown': { r: '#5f3f8e', y: '#f2c14e', w: '#efe3ff' },
};

const EFFECT_COLORS = {
  'effect-none': ['#3c4a63'],
  'effect-fly': ['#e8f77a', '#b7ffd2'],
  'effect-ember': ['#f2a65a', '#ef6a5a'],
  'effect-leaf': ['#86b566', '#d9c9a8'],
  'effect-spark': ['#7ee3e3', '#6bb8ff'],
};

export const SCREENS = ['screen-lobby', 'screen-howto', 'screen-quiz', 'screen-shop', 'screen-progress', 'screen-review', 'screen-pause', 'screen-banner'];

/** Question text is authored with markup in it (<h1>, <p>), so it must not be
 *  dropped into innerHTML raw. */
const escapeHtml = (value) => String(value)
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;');

export function createUI(handlers = {}) {
  const el = {
    hud: $('hud'),
    controls: $('controls'),
    hearts: $('hud-hearts'),
    level: $('hud-level'),
    points: $('hud-points'),
    pips: $('hud-pips'),
    mastery: $('hud-mastery'),
    masteryLabel: $('hud-mastery-label'),
    upgrades: $('hud-upgrades'),
    heroPicker: $('hero-picker'),
    preview: $('lobby-preview'),
    name: $('input-name'),
    lobbyStats: $('lobby-stats'),
    shopGrid: $('shop-grid'),
    shopTabs: $('shop-tabs'),
    shopPoints: $('shop-points'),
    progressSummary: $('progress-summary'),
    masteryList: $('mastery-list'),
    badgeGrid: $('badge-grid'),
    badgeCount: $('badge-count'),
    upgradeList: $('upgrade-list'),
    progressLevel: $('progress-level'),
    reviewTabs: $('review-tabs'),
    reviewList: $('review-list'),
    reviewCount: $('review-count'),
    toasts: $('toast-stack'),
    quizLang: $('quiz-lang'),
    quizKind: $('quiz-kind'),
    quizPts: $('quiz-pts'),
    quizPrompt: $('quiz-prompt'),
    quizCode: $('quiz-code'),
    quizChoices: $('quiz-choices'),
    quizFeedback: $('quiz-feedback'),
    quizFbHead: $('quiz-fb-head'),
    quizFbBody: $('quiz-fb-body'),
    quizReward: $('quiz-reward'),
    bannerEmoji: $('banner-emoji'),
    bannerTitle: $('banner-title'),
    bannerBody: $('banner-body'),
    bannerStats: $('banner-stats'),
    bannerPrimary: $('btn-banner-primary'),
    bannerSecondary: $('btn-banner-secondary'),
    pauseStats: $('pause-stats'),
    shopTab: 'spear',
    reviewLang: null,
  };

  function show(screenId) {
    for (const id of SCREENS) {
      const node = $(id);
      if (node) node.hidden = id !== screenId;
    }
  }

  function hideScreens() {
    for (const id of SCREENS) {
      const node = $(id);
      if (node) node.hidden = true;
    }
  }

  function toast(text, kind = '') {
    const node = document.createElement('div');
    node.className = `toast ${kind}`.trim();
    node.textContent = text;
    el.toasts.appendChild(node);
    setTimeout(() => node.remove(), 2500);
  }

  /* ------------------------------- HUD -------------------------------- */

  function updateHUD(sim, progress) {
    const stats = derivedStats(progress);
    const hearts = Math.max(sim.maxHearts, stats.startHearts);
    let html = '';
    for (let i = 0; i < hearts; i += 1) {
      html += `<span class="heart${i < sim.hearts ? '' : ' off'}">♥</span>`;
    }
    if (sim.shield > 0) html += `<span class="heart shield" title="Shield charges">✦${sim.shield}</span>`;
    el.hearts.innerHTML = html;

    el.level.textContent = `Module ${sim.cfg.module} · ${sim.cfg.langName}`;
    el.points.textContent = String(progress.points);

    let pips = '';
    for (let i = 0; i < sim.totalCheckpoints; i += 1) {
      pips += `<i class="${i < sim.cleared ? 'done' : ''}"></i>`;
    }
    pips += `<i class="${sim.bossFight ? 'boss' : ''}"></i>`;
    el.pips.innerHTML = pips;

    const pct = masteryPercent(progress, sim.cfg.lang);
    el.mastery.style.width = `${pct}%`;
    el.masteryLabel.textContent = `${pct}%`;

    let badges = '';
    if (sim.stats.pierce) badges += `<span>➹ Pierce ${sim.stats.pierce}</span>`;
    if (sim.stats.pointBonus) badges += '<span>◈ +1/answer</span>';
    for (const u of UPGRADES) {
      const lv = sim.upgrades[u.id] || 0;
      if (lv > 0 && u.id !== 'pierce') badges += `<span>${u.icon} ${u.name} ${lv}</span>`;
    }
    if (sim.shield > 0) badges += `<span class="shield">✦ Shield ${sim.shield}</span>`;
    el.upgrades.innerHTML = badges;
  }

  /* ------------------------------- lobby ------------------------------ */

  function renderLobby(progress) {
    el.name.value = progress.name;
    const stats = derivedStats(progress);
    el.lobbyStats.textContent = `Module ${progress.module} · ${progress.points} ◈ · ${stats.maxHearts} ♥ · ${progress.correct} correct`;
    renderSpriteToCanvas(el.preview, progress.hero === 'girl' ? 'girl' : 'boy', 5, GARMENT_PALETTES[progress.equipped.garment]);

    el.heroPicker.innerHTML = '';
    [['boy', 'Boy Warrior'], ['girl', 'Girl Warrior']].forEach(([id, label]) => {
      const card = document.createElement('button');
      card.type = 'button';
      card.className = `hero-opt${progress.hero === id ? ' selected' : ''}`;
      card.setAttribute('role', 'radio');
      card.setAttribute('aria-checked', String(progress.hero === id));
      const canvas = document.createElement('canvas');
      card.appendChild(canvas);
      const span = document.createElement('span');
      span.textContent = label;
      card.appendChild(span);
      renderSpriteToCanvas(canvas, id, 4, GARMENT_PALETTES[progress.equipped.garment]);
      card.addEventListener('click', () => handlers.selectHero && handlers.selectHero(id));
      el.heroPicker.appendChild(card);
    });
  }

  /* -------------------------------- quiz ------------------------------ */

  function showQuiz(question, target, pointsLabel) {
    const meta = questionMeta(question);
    el.quizPrompt.textContent = String(question.prompt).replace('__BLANK__', '____');
    el.quizLang.textContent = meta.langName;
    el.quizLang.style.color = meta.langColor;
    el.quizKind.textContent = target === 'boss' ? 'Boss checkpoint' : `Checkpoint · ${meta.difficulty}`;
    el.quizKind.classList.toggle('chip-boss', target === 'boss');
    el.quizPts.textContent = pointsLabel;

    if (question.code) {
      el.quizCode.hidden = false;
      el.quizCode.firstElementChild.textContent = question.code;
      el.quizCode.style.display = '';
    } else {
      el.quizCode.hidden = true;
      el.quizCode.style.display = 'none';
    }

    el.quizChoices.innerHTML = '';
    el.quizFeedback.hidden = true;
    el.quizFeedback.style.display = 'none';
    question.choices.forEach((choice, i) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'choice';
      btn.dataset.index = String(i);
      const key = document.createElement('span');
      key.className = 'key';
      key.textContent = question.choices.length === 2 ? (i === 0 ? 'T' : 'F') : String.fromCharCode(65 + i);
      const text = document.createElement('span');
      text.textContent = choice;
      btn.appendChild(key);
      btn.appendChild(text);
      btn.addEventListener('click', () => handlers.answer && handlers.answer(i));
      el.quizChoices.appendChild(btn);
    });
    el.quizCode.parentElement.scrollTop = 0;
    show('screen-quiz');
  }

  function showQuizResult(result, meta) {
    const options = Array.from(el.quizChoices.querySelectorAll('.choice'));
    options.forEach((btn, i) => {
      btn.disabled = true;
      if (i === result.question.answer) btn.classList.add('correct');
      else if (i === result.chosen) btn.classList.add('wrong');
    });

    const fb = el.quizFeedback;
    fb.hidden = false;
    fb.style.display = 'flex';
    el.quizFbHead.className = `fb-head ${result.correct ? 'ok' : 'no'}`;
    el.quizFbHead.textContent = result.correct ? '✔ Correct — checkpoint cleared' : '✘ Not quite — checkpoint cleared, upgrade lost';
    el.quizFbBody.textContent = result.question.explain;

    if (result.correct && result.upgrade) {
      const def = UPGRADES.find((u) => u.id === result.upgrade.id);
      const nextText = def ? def.describe(result.upgrade.level) : '';
      el.quizReward.className = 'reward-card';
      el.quizReward.innerHTML = `<b>UPGRADE EARNED</b> · ${def.icon} ${def.name} Lv${result.upgrade.level}<br>${nextText}<br>+${result.points} ◈${result.streak >= 3 ? ` · ${result.streak} in a row!` : ''}`;
    } else if (result.correct) {
      el.quizReward.className = 'reward-card';
      el.quizReward.innerHTML = `<b>+${result.points} ◈</b> · every upgrade is already maxed — the mountain has nothing left to teach you here.`;
    } else {
      el.quizReward.className = 'reward-card lost';
      el.quizReward.innerHTML = `<b>UPGRADE LOST</b> · no points this time. Read the explanation above, then take the next bat.`;
    }
    handlers.afterResult && handlers.afterResult(result, meta);
  }

  /* ------------------------------- banner ----------------------------- */

  function showBanner({ emoji, title, body, stats = [], primary = 'Continue ▶', secondary = null }) {
    el.bannerEmoji.textContent = emoji;
    el.bannerTitle.textContent = title;
    el.bannerBody.textContent = body;
    el.bannerStats.innerHTML = stats.map(([k, v]) => `<div><span>${k}</span><b>${v}</b></div>`).join('');
    el.bannerPrimary.textContent = primary;
    if (secondary) {
      el.bannerSecondary.hidden = false;
      el.bannerSecondary.textContent = secondary;
    } else {
      el.bannerSecondary.hidden = true;
    }
    show('screen-banner');
  }

  /* -------------------------------- shop ------------------------------ */

  function renderShop(progress) {
    el.shopPoints.textContent = String(progress.points);
    el.shopTabs.innerHTML = '';
    SHOP_CATEGORIES.forEach((cat) => {
      const tab = document.createElement('button');
      tab.type = 'button';
      tab.className = `tab${el.shopTab === cat.id ? ' active' : ''}`;
      tab.textContent = cat.name;
      tab.addEventListener('click', () => { el.shopTab = cat.id; renderShop(progress); });
      el.shopTabs.appendChild(tab);
    });

    el.shopGrid.innerHTML = '';
    itemsInCategory(el.shopTab).forEach((item) => {
      const card = document.createElement('div');
      card.className = 'item-card';
      const owned = progress.owned.includes(item.id);
      const equipped = progress.equipped[item.cat] === item.id;
      if (equipped) card.classList.add('equipped');
      else if (owned) card.classList.add('owned');

      const canvas = document.createElement('canvas');
      card.appendChild(canvas);
      paintItemPreview(canvas, item, progress);

      const info = document.createElement('div');
      info.className = 'item-info';
      info.innerHTML = `<span class="item-name">${item.name}</span>
        <span class="item-desc">${item.desc}</span>
        ${item.perkText ? `<span class="item-perk">${item.perkText}</span>` : ''}`;
      card.appendChild(info);

      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'item-btn';
      if (equipped) { btn.classList.add('equipped'); btn.textContent = 'Equipped'; btn.disabled = true; }
      else if (owned) { btn.classList.add('owned'); btn.textContent = 'Equip'; btn.addEventListener('click', () => handlers.equip && handlers.equip(item.id)); }
      else if (canBuy(progress, item.id).ok) {
        btn.textContent = `${item.cost} ◈`;
        btn.addEventListener('click', () => handlers.buy && handlers.buy(item.id));
      } else {
        btn.classList.add('locked');
        btn.textContent = `${item.cost} ◈`;
        btn.disabled = true;
      }
      card.appendChild(btn);
      el.shopGrid.appendChild(card);
    });
  }

  function paintItemPreview(canvas, item, progress) {
    if (item.cat === 'spear') {
      renderSpriteToCanvas(canvas, item.id, 4);
      return;
    }
    if (item.cat === 'garment') {
      renderSpriteToCanvas(canvas, progress.hero === 'girl' ? 'girl' : 'boy', 3, GARMENT_PALETTES[item.id]);
      return;
    }
    const ctx = canvas.getContext('2d');
    const colors = EFFECT_COLORS[item.id] || ['#3c4a63'];
    canvas.width = 56;
    canvas.height = 56;
    ctx.fillStyle = '#0f1524';
    ctx.fillRect(0, 0, 56, 56);
    const spots = [[12, 36], [24, 20], [36, 32], [44, 16], [18, 14], [30, 42]];
    spots.forEach(([x, y], i) => {
      ctx.fillStyle = colors[i % colors.length];
      ctx.fillRect(x, y, item.id === 'effect-none' ? 2 : 4, item.id === 'effect-none' ? 2 : 4);
    });
  }

  /* ----------------------------- progress ----------------------------- */

  function renderProgress(progress) {
    const stats = derivedStats(progress);
    el.progressLevel.textContent = `Module ${progress.module}`;
    const done = BADGES.filter((b) => progress.badges.includes(b.id)).length;
    el.progressSummary.innerHTML = [
      ['Points', progress.points],
      ['Correct answers', progress.correct],
      ['Accuracy', `${accuracy(progress)}%`],
      ['Best streak', progress.bestStreak],
      ['Bosses beaten', progress.bossesDefeated],
      ['Modules cleared', progress.modulesCleared],
      ['Hearts', stats.maxHearts],
      ['Badges', `${done}/${BADGES.length}`],
    ].map(([k, v]) => `<div class="stat-box"><b>${v}</b><span>${k}</span></div>`).join('');

    el.masteryList.innerHTML = LANGUAGES.map((lang) => {
      const pct = masteryPercent(progress, lang.id);
      const solved = solvedIds(progress, lang.id).length;
      const total = questionsFor(lang.id).length;
      const m = progress.mastery[lang.id] || { correct: 0, wrong: 0 };
      return `<div class="mastery-row">
        <span style="color:${lang.color}">${lang.name}</span>
        <span class="mastery-track"><span class="mastery-fill" style="width:${pct}%;display:block"></span></span>
        <span class="mastery-pct">${solved}/${total}</span>
      </div>
      <div class="mastery-row" style="grid-template-columns:74px 1fr 40px;margin-top:-2px">
        <span></span>
        <span class="muted" style="font-size:9px">${m.correct} right · ${m.wrong} wrong · ${lang.blurb}</span>
        <span></span>
      </div>`;
    }).join('');

    el.badgeCount.textContent = `${done}/${BADGES.length}`;
    el.badgeGrid.innerHTML = BADGES.map((b) => {
      const earned = progress.badges.includes(b.id);
      return `<div class="badge${earned ? ' earned' : ''}" title="${b.desc}">
        <span class="badge-ico">${b.icon}</span>
        <span class="badge-txt"><b>${b.name}</b><span>${b.desc}</span></span>
      </div>`;
    }).join('');

    const up = progress.upgrades || {};
    const owned = UPGRADES.filter((u) => (up[u.id] || 0) > 0);
    el.upgradeList.innerHTML = owned.length
      ? owned.map((u) => `<span>${u.icon} ${u.name} Lv${up[u.id]}</span>`).join('')
      : '<span class="muted">Answer checkpoints correctly to earn upgrades.</span>';
  }

  /* ------------------------------ review ------------------------------ */

  /**
   * Every checkpoint in the bank, the right answer marked, the explanation
   * shown. The questions come from the same bank the game asks, so this screen
   * can never drift from what the player is tested on.
   */
  function renderReview(progress) {
    const moduleLang = LANGUAGES.find((l) => l.module === ((progress.module - 1) % LANGUAGES.length) + 1) || LANGUAGES[0];
    if (!el.reviewLang) el.reviewLang = moduleLang.id;

    el.reviewTabs.innerHTML = '';
    [{ id: 'all', label: 'All' }, ...LANGUAGES.map((l) => ({ id: l.id, label: l.label }))].forEach((tab) => {
      const node = document.createElement('button');
      node.type = 'button';
      node.className = `tab${el.reviewLang === tab.id ? ' active' : ''}`;
      node.textContent = tab.label;
      node.addEventListener('click', () => { el.reviewLang = tab.id; renderReview(progress); });
      el.reviewTabs.appendChild(node);
    });

    const listed = el.reviewLang === 'all'
      ? LANGUAGES.flatMap((l) => questionsFor(l.id))
      : questionsFor(el.reviewLang);
    el.reviewCount.textContent = String(listed.length);

    const answered = progress.answered || {};
    el.reviewList.innerHTML = listed.map((question) => {
      const meta = questionMeta(question);
      const solved = Boolean(answered[question.id]);
      const choices = question.choices.map((choice, i) => {
        const correct = i === Number(question.answer);
        return `<li class="${correct ? 'correct' : ''}">${correct ? '✔' : '·'} ${escapeHtml(choice)}</li>`;
      }).join('');
      return `<div class="review-card${solved ? ' solved' : ''}">
        <div class="review-head">
          <span class="review-tick">${solved ? '✔' : '·'}</span>
          <span class="muted">${escapeHtml(meta.langName)} · ${meta.difficulty} · ${escapeHtml(question.topic || '')}</span>
        </div>
        <p class="review-prompt">${escapeHtml(String(question.prompt).replace('__BLANK__', '____'))}</p>
        ${question.code ? `<pre class="quiz-code"><code>${escapeHtml(question.code)}</code></pre>` : ''}
        <ul class="review-choices">${choices}</ul>
        <p class="muted review-explain">${escapeHtml(question.explain || '')}</p>
      </div>`;
    }).join('');
  }

  /* ------------------------------ pause ------------------------------- */

  function showPause(sim, progress) {
    el.pauseStats.innerHTML = `Module ${sim.cfg.module} · ${sim.cfg.langName}<br>
      Checkpoints ${sim.cleared}/${sim.totalCheckpoints}<br>
      Answer streak ${sim.quizStats.streak} · ${progress.points} ◈`;
    show('screen-pause');
  }

  /* ------------------------------ wiring ------------------------------ */

  function wire() {
    $('btn-start').addEventListener('click', () => handlers.start && handlers.start());
    $('btn-shop').addEventListener('click', () => handlers.openShop && handlers.openShop());
    $('btn-progress').addEventListener('click', () => handlers.openProgress && handlers.openProgress());
    $('btn-review').addEventListener('click', () => handlers.openReview && handlers.openReview());
    $('btn-howto').addEventListener('click', () => show('screen-howto'));
    $('btn-pause').addEventListener('click', () => handlers.pause && handlers.pause());
    $('btn-resume').addEventListener('click', () => handlers.resume && handlers.resume());
    $('btn-restart').addEventListener('click', () => handlers.restart && handlers.restart());
    $('btn-quit').addEventListener('click', () => handlers.quit && handlers.quit());
    $('btn-quiz-continue').addEventListener('click', () => handlers.quizContinue && handlers.quizContinue());
    el.bannerPrimary.addEventListener('click', () => handlers.bannerPrimary && handlers.bannerPrimary());
    el.bannerSecondary.addEventListener('click', () => handlers.bannerSecondary && handlers.bannerSecondary());
    document.querySelectorAll('[data-back]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const target = btn.getAttribute('data-back');
        if (target === 'screen-lobby') handlers.openLobby && handlers.openLobby();
      });
    });
    el.name.addEventListener('input', () => handlers.rename && handlers.rename(el.name.value));
  }

  wire();

  return {
    el, show, hideScreens, toast, updateHUD, renderLobby, showQuiz, showQuizResult,
    showBanner, renderShop, renderProgress, renderReview, showPause,
    setGameVisible(visible) {
      el.hud.hidden = !visible;
      el.controls.hidden = !visible;
    },
  };
}
