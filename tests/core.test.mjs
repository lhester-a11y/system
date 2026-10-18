/** Unit tests for the pure CodePlay core: no DOM, no canvas, no timers. */
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { QUESTIONS, LANGUAGES, LANGUAGE_IDS, questionsFor } from '../js/data/questions.js';
import {
  levelConfig, chooseUpgrade, pointsForCorrect, bossPoints, levelClearPoints,
  UPGRADES, UPGRADE_IDS, emptyUpgrades, upgradeLabel, BADGES, earnedBadges, newBadges,
  masteryPercent, accuracy, solvedIds, canBuy, buyItem, equipItem, shopItem,
  derivedStats, statsFromUpgrades, perkTotal, DEFAULT_EQUIPPED, SHOP_ITEMS,
} from '../js/core/rules.js';
import { createRng } from '../js/core/rng.js';
import { pickQuestion, checkAnswer, difficultyLabel, shuffleQuestion } from '../js/core/quiz.js';
import { defaultProgress, migrate, loadProgress, saveProgress, SAVE_KEY, resetProgress } from '../js/core/save.js';
import { createSimulation, aabb, clamp, WORLD } from '../js/core/simulation.js';

/* ------------------------------- question bank ---------------------------- */

test('every question is well formed', () => {
  assert.equal(QUESTIONS.length, 48);
  const ids = new Set();
  for (const q of QUESTIONS) {
    assert.ok(!ids.has(q.id), `duplicate id ${q.id}`);
    ids.add(q.id);
    assert.ok(LANGUAGE_IDS.includes(q.lang), `${q.id} has unknown language`);
    assert.ok([1, 2, 3].includes(q.difficulty), `${q.id} difficulty`);
    assert.ok(q.choices.length >= 2, `${q.id} needs choices`);
    assert.equal(new Set(q.choices).size, q.choices.length, `${q.id} has duplicate choices`);
    assert.ok(q.answer >= 0 && q.answer < q.choices.length, `${q.id} answer index out of range`);
    assert.ok(q.explain.length > 20, `${q.id} needs a real explanation`);
    assert.ok(q.topic && q.reward, `${q.id} needs topic and reward`);
  }
});

test('every language has questions at every difficulty used by the modules', () => {
  for (const lang of LANGUAGE_IDS) {
    const all = questionsFor(lang);
    assert.equal(all.length, 8, `${lang} question count`);
    assert.equal(questionsFor(lang, 2).length >= 6, true, `${lang} needs easy questions`);
  }
});

/* ---------------------------------- levels -------------------------------- */

test('level config escalates across modules and cycles languages', () => {
  const first = levelConfig(1);
  const last = levelConfig(LANGUAGES.length);
  assert.equal(first.lang, 'html');
  assert.equal(first.maxDifficulty, 2);
  assert.equal(last.lang, 'cpp');
  assert.equal(last.maxDifficulty, 3);
  assert.ok(last.batSpeed > first.batSpeed);
  assert.ok(last.spawnInterval < first.spawnInterval);
  assert.ok(last.bossHp >= first.bossHp);
  const lap2 = levelConfig(LANGUAGES.length + 1);
  assert.equal(lap2.lang, 'html', 'module 7 loops back to HTML');
  assert.equal(lap2.lap, 1);
  assert.ok(lap2.batSpeed > first.batSpeed, 'second lap is harder');
});

/* --------------------------------- upgrades -------------------------------- */

test('chooseUpgrade never exceeds the cap and returns null when maxed', () => {
  const rng = createRng(99);
  const upgrades = emptyUpgrades();
  for (let i = 0; i < 200; i += 1) {
    const id = chooseUpgrade(rng, upgrades, 'damage');
    if (id === null) break;
    upgrades[id] += 1;
  }
  for (const def of UPGRADES) {
    assert.ok(upgrades[def.id] <= def.max, `${def.id} over cap`);
    assert.equal(upgrades[def.id], def.max, `${def.id} should end maxed`);
  }
  assert.equal(chooseUpgrade(rng, upgrades, 'damage'), null);
});

test('chooseUpgrade is biased towards the topic family of the question', () => {
  const rng = createRng(4);
  const counts = {};
  for (let i = 0; i < 400; i += 1) {
    const id = chooseUpgrade(rng, emptyUpgrades(), 'speed');
    counts[id] = (counts[id] || 0) + 1;
  }
  const best = Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
  assert.equal(best, 'speed');
});

test('upgradeLabel is human readable', () => {
  assert.match(upgradeLabel('damage', 2), /Sharpened Spear Lv2/);
  assert.equal(upgradeLabel('nope', 1), 'Upgrade');
});

/* ---------------------------------- scoring -------------------------------- */

test('points reward difficulty and streaks, never participation', () => {
  assert.equal(pointsForCorrect(1, 0), 10);
  assert.equal(pointsForCorrect(2, 0), 15);
  assert.equal(pointsForCorrect(3, 0), 25);
  assert.equal(pointsForCorrect(1, 5), 20);
  assert.ok(pointsForCorrect(3, 5, 1) > pointsForCorrect(3, 0));
  assert.ok(bossPoints(3) > bossPoints(1));
  assert.ok(levelClearPoints(1, true) > levelClearPoints(1, false));
});

/* -------------------------------- progression ------------------------------ */

test('mastery and accuracy track real performance', () => {
  const progress = { ...defaultProgress() };
  assert.equal(masteryPercent(progress, 'html'), 0);
  progress.answered['html-01'] = true;
  progress.answered['html-02'] = true;
  assert.equal(solvedIds(progress, 'html').length, 2);
  assert.equal(masteryPercent(progress, 'html'), 25);
  progress.correct = 3;
  progress.wrong = 1;
  assert.equal(accuracy(progress), 75);
  assert.equal(accuracy({ correct: 0, wrong: 0 }), 0);
});

test('badges unlock from real milestones and only report once', () => {
  const progress = { ...defaultProgress(), correct: 10, bestStreak: 5 };
  const earned = earnedBadges(progress);
  assert.ok(earned.includes('first-spear'));
  assert.ok(earned.includes('streak-5'));
  assert.ok(earned.includes('ten-check'));

  progress.answered['html-01'] = true;
  progress.answered['html-02'] = true;
  progress.answered['html-03'] = true;
  assert.ok(earnedBadges(progress).includes('html-trainee'));

  const fresh = newBadges(progress, progress.badges).sort();
  assert.deepEqual(fresh, ['first-spear', 'html-trainee', 'streak-5', 'ten-check', 'tradepost']);
  assert.deepEqual(newBadges(progress, fresh), [], 'a badge is only announced once');

  const master = { ...defaultProgress(), answered: Object.fromEntries(questionsFor('css').map((q) => [q.id, true])) };
  assert.ok(earnedBadges(master).includes('css-master'));
  assert.equal(BADGES.length, 19);
});

/* ----------------------------------- shop --------------------------------- */

test('shopping debits points, is immutable, and equips only owned items', () => {
  const progress = { ...defaultProgress(), points: 200 };
  const iron = shopItem('spear-iron');

  const poor = buyItem(progress, 'spear-crystal');
  assert.equal(poor.ok, false);
  assert.equal(poor.reason, 'Not enough points');
  assert.equal(poor.progress, progress, 'a failed purchase must not mutate anything');

  const bought = buyItem(progress, 'spear-iron');
  assert.equal(bought.ok, true);
  assert.equal(bought.progress.points, 200 - iron.cost);
  assert.ok(bought.progress.owned.includes('spear-iron'));
  assert.equal(progress.points, 200, 'original progress untouched');
  assert.equal(progress.owned.includes('spear-iron'), false);

  assert.equal(canBuy(bought.progress, 'spear-iron').ok, false);
  assert.equal(canBuy(bought.progress, 'spear-iron').reason, 'Already owned');

  const equipped = equipItem(bought.progress, 'spear-iron');
  assert.equal(equipped.ok, true);
  assert.equal(equipped.progress.equipped.spear, 'spear-iron');
  assert.equal(equipItem(progress, 'spear-iron').ok, false, 'cannot equip what is not owned');
  assert.equal(equipItem(progress, 'effect-none').ok, true, 'defaults count as owned');
});

test('perks from shop items change derived stats', () => {
  const base = derivedStats(defaultProgress());
  const kitted = derivedStats({
    ...defaultProgress(),
    owned: [...defaultProgress().owned, 'spear-iron', 'garment-blank', 'spear-gold', 'garment-crown'],
  });
  assert.ok(kitted.spearSpeed > base.spearSpeed);
  assert.equal(kitted.pointBonus, 1);
  assert.equal(kitted.maxHearts, base.maxHearts + 1);
  assert.equal(kitted.revives, 1);
  assert.equal(perkTotal({ owned: ['spear-iron', 'spear-iron'] }, 'spearSpeed') > 0, true);
});

test('statsFromUpgrades respects the heart cap', () => {
  const stats = statsFromUpgrades({}, { maxHearts: 9 });
  assert.ok(stats.maxHearts <= 5);
  assert.equal(stats.startHearts, stats.maxHearts);
});

/* --------------------------------- selection ------------------------------- */

test('pickQuestion prefers unsolved questions and never repeats inside a run', () => {
  const progress = defaultProgress();
  const rng = createRng(11);
  const cfg = { module: 3, maxDifficulty: 3 };
  const asked = new Set();
  const order = [];
  for (let i = 0; i < questionsFor('js').length; i += 1) {
    const q = pickQuestion(progress, 'js', cfg, rng, asked);
    asked.add(q.id);
    order.push(q.id);
  }
  assert.equal(new Set(order).size, order.length, 'all eight JS questions asked exactly once');

  // now every question is solved: selection still returns a valid question
  const reviewed = pickQuestion(progress, 'js', cfg, rng, new Set());
  assert.ok(questionsFor('js').some((q) => q.id === reviewed.id));
});

test('pickQuestion widens difficulty rather than repeating a module', () => {
  const cfg = { module: 1, maxDifficulty: 2 };
  const asked = new Set(questionsFor('css', 2).map((q) => q.id));
  const q = pickQuestion(defaultProgress(), 'css', cfg, createRng(3), asked);
  assert.equal(q.difficulty, 3);
});

test('checkAnswer matches only the stored index', () => {
  const q = { choices: ['a', 'b', 'c'], answer: 1 };
  assert.equal(checkAnswer(q, 1), true);
  assert.equal(checkAnswer(q, 0), false);
  assert.equal(checkAnswer(q, '1'), true);
  assert.equal(checkAnswer(null, 0), false);
  assert.equal(difficultyLabel(3), 'Apply');
});

/* ----------------------------------- save --------------------------------- */

test('save round-trips and repairs corrupt data', () => {
  const progress = { ...defaultProgress(), points: 123, module: 4, hero: 'girl', name: 'Dangwa' };
  const store = { data: {}, getItem(k) { return this.data[k] ?? null; }, setItem(k, v) { this.data[k] = v; }, removeItem(k) { delete this.data[k]; } };
  assert.equal(saveProgress(progress, store), true);
  const loaded = loadProgress(store);
  assert.equal(loaded.points, 123);
  assert.equal(loaded.module, 4);
  assert.equal(loaded.hero, 'girl');

  store.data[SAVE_KEY] = '{not json';
  assert.equal(loadProgress(store).points, 0, 'corrupt save falls back to defaults');

  const junk = migrate({ points: -50, module: 'x', hero: 'dragon', owned: 'nope', upgrades: null, name: 'a'.repeat(40) });
  assert.equal(junk.points, 0);
  assert.equal(junk.module, 1);
  assert.equal(junk.hero, 'boy');
  assert.equal(junk.name.length, 12);
  assert.deepEqual(junk.upgrades, emptyUpgrades());
  assert.ok(junk.owned.includes('spear-bamboo'), 'default gear is restored');
  assert.deepEqual(Object.keys(junk.equipped).sort(), ['effect', 'garment', 'spear']);

  const fresh = resetProgress(store);
  assert.equal(fresh.points, 0);
  assert.equal(store.data[SAVE_KEY], undefined);
});

test('an old save gains sound and the one-time tutorial flag', () => {
  const merged = migrate({ points: 42 });
  assert.equal(merged.sound, true, 'sound defaults on for saves written before it existed');
  assert.equal(merged.tutorialSeen, false, 'the tutorial is still to come');
  assert.equal(migrate({ sound: false, tutorialSeen: true }).sound, false, 'a muted choice is kept');
  assert.equal(migrate({ tutorialSeen: 'yes' }).tutorialSeen, false, 'a junk flag is not trusted');
});

test('migrate keeps a newer module index honest', () => {
  const merged = migrate({ module: 3, highestModule: 1 });
  assert.equal(merged.highestModule, 3);
});

/* -------------------------------- simulation ------------------------------ */

function batUnderPlayer(sim, distance = 200, hp = 1) {
  const p = sim.player;
  sim.bats.push({
    id: 999, kind: 'bat', x: p.x, y: p.y - distance, baseY: p.y - distance,
    vx: 0, vy: 0, w: 38, h: 24, hp, maxHp: hp, bob: 0,
    mode: 'wave', diving: false, diveAt: 9999, hitFlash: 0, alive: true,
  });
  return sim.bats[sim.bats.length - 1];
}

function hitPlayer(sim) {
  const p = sim.player;
  sim.bugs.push({ x: p.x, y: p.y, vx: 0, vy: 0, w: 12, h: 12, spin: 0, alive: true });
  sim.update(1 / 60);
}

test('aabb and clamp behave', () => {
  assert.equal(aabb({ x: 0, y: 0, w: 10, h: 10 }, { x: 5, y: 5, w: 10, h: 10 }), true);
  assert.equal(aabb({ x: 0, y: 0, w: 10, h: 10 }, { x: 20, y: 0, w: 10, h: 10 }), false);
  assert.equal(clamp(99, 0, 10), 10);
  assert.equal(clamp(-5, 0, 10), 0);
});

test('hitting a bat absorbs its code box and freezes the world for a checkpoint', () => {
  const sim = createSimulation({ module: 1, seed: 1 });
  const bat = batUnderPlayer(sim);
  sim.throwSpear();
  assert.equal(sim.spears.length, 1);
  for (let i = 0; i < 60 && sim.phase === 'play'; i += 1) sim.update(1 / 60);

  assert.equal(sim.phase, 'quiz', 'the action pauses for the question');
  assert.equal(sim.cleared, 1);
  assert.equal(bat.alive, false);
  assert.ok(sim.pendingQuiz, 'a question is queued');
  assert.equal(sim.pendingQuiz.target, 'bat');
  assert.ok(sim.pendingQuiz.question.prompt.length > 5);

  const events = sim.drainEvents().map((e) => e.type);
  assert.ok(events.includes('bat:cleared'));
  assert.ok(events.includes('quiz:open'));

  // world is frozen while the modal is up
  const before = { x: sim.player.x, batX: 0, time: sim.time };
  sim.setMove(1);
  assert.equal(sim.throwSpear(), false, 'cannot throw while answering');
  sim.update(1);
  assert.equal(sim.player.x, before.x, 'the warrior does not move during a checkpoint');
  assert.ok(sim.time > before.time, 'the clock still advances so animations keep running');
});

test('a correct answer pays out and grants an upgrade', () => {
  const sim = createSimulation({ module: 1, seed: 2 });
  batUnderPlayer(sim);
  sim.throwSpear();
  for (let i = 0; i < 60 && sim.phase === 'play'; i += 1) sim.update(1 / 60);

  const question = sim.pendingQuiz.question;
  const result = sim.answer(question.answer);
  assert.equal(result.correct, true);
  assert.ok(result.points >= 10);
  assert.ok(result.upgrade, 'an upgrade is granted');
  assert.equal(sim.points, result.points);
  assert.equal(sim.upgrades[result.upgrade.id], result.upgrade.level);
  assert.equal(sim.answerLog.at(-1).correct, true);

  sim.continueAfterQuiz();
  assert.equal(sim.phase, 'play');
  assert.equal(sim.pendingQuiz, null);
  assert.equal(sim.result, null);
});

test('a wrong answer loses the upgrade but still clears the checkpoint', () => {
  const sim = createSimulation({ module: 1, seed: 3 });
  batUnderPlayer(sim);
  sim.throwSpear();
  for (let i = 0; i < 60 && sim.phase === 'play'; i += 1) sim.update(1 / 60);

  const question = sim.pendingQuiz.question;
  const wrong = (question.answer + 1) % question.choices.length;
  const result = sim.answer(wrong);
  assert.equal(result.correct, false);
  assert.equal(result.points, 0);
  assert.equal(result.upgrade, null);
  assert.equal(sim.points, 0);
  assert.deepEqual(sim.upgrades, emptyUpgrades());
  assert.equal(sim.quizStats.wrong, 1);
  assert.equal(sim.quizStats.perfect, false);
  assert.equal(sim.cleared, 1, 'the bat is still beaten');
  sim.continueAfterQuiz();
  assert.equal(sim.phase, 'play');
});

test('answering twice is ignored', () => {
  const sim = createSimulation({ module: 1, seed: 4 });
  batUnderPlayer(sim);
  sim.throwSpear();
  for (let i = 0; i < 60 && sim.phase === 'play'; i += 1) sim.update(1 / 60);
  sim.answer(0);
  const points = sim.points;
  assert.equal(sim.answer(1), null);
  assert.equal(sim.points, points);
});

test('the boss arrives only after every checkpoint is cleared', () => {
  const progress = defaultProgress();
  const sim = createSimulation({ progress, module: 1, seed: 5 });
  const total = sim.totalCheckpoints;
  assert.equal(sim.boss, null);
  assert.equal(total, 5);
  sim.player.invuln = 9999; // this test is about wave pacing, not survival

  for (let n = 0; n < total; n += 1) {
    batUnderPlayer(sim);
    for (let i = 0; i < 300 && sim.phase === 'play'; i += 1) {
      sim.throwSpear();
      sim.update(1 / 60);
    }
    assert.equal(sim.phase, 'quiz', `checkpoint ${n + 1} asks a question`);
    if (sim.boss) assert.fail('boss must not exist yet');
    sim.answer(sim.pendingQuiz.question.answer);
    sim.continueAfterQuiz();
    assert.equal(sim.boss, null, 'still no boss after clearing');
  }

  assert.equal(sim.cleared, total);
  for (let i = 0; i < 200 && !sim.boss; i += 1) sim.update(1 / 60);
  assert.ok(sim.boss, 'boss spawns after the last checkpoint');
  assert.equal(sim.boss.hp, sim.cfg.bossHp);
  assert.equal(sim.bossFight, true);
  assert.equal(sim.bats.length, 0, 'the arena is cleared for the boss');
});

test('the boss only takes damage from correct answers, and clearing it ends the module', () => {
  const sim = createSimulation({ module: 1, seed: 6 });
  sim.cleared = sim.totalCheckpoints;
  for (let i = 0; i < 200 && !sim.boss; i += 1) sim.update(1 / 60);
  assert.ok(sim.boss);
  sim.boss.invuln = 0;

  const hp = sim.boss.hp;
  sim.openQuiz('boss', sim.boss);
  sim.answer((sim.pendingQuiz.question.answer + 1) % sim.pendingQuiz.question.choices.length);
  sim.continueAfterQuiz();
  assert.equal(sim.boss.hp, hp, 'a wrong answer does not hurt the boss');
  assert.ok(sim.boss.invuln > 0, 'grace period prevents an instant re-ask');
  assert.equal(sim.phase, 'play');

  for (let i = 0; i < hp; i += 1) {
    sim.boss.invuln = 0;
    sim.openQuiz('boss', sim.boss);
    sim.answer(sim.pendingQuiz.question.answer);
    sim.continueAfterQuiz();
  }
  assert.equal(sim.phase, 'cleared');
  assert.equal(sim.boss, null);
  const cleared = sim.drainEvents().find((e) => e.type === 'level:cleared');
  assert.ok(cleared, 'a level:cleared event fires');
  assert.ok(cleared.points >= 100);
  assert.equal(cleared.stats.perfect, false, 'this run answered one question wrong on purpose');
});

test('hearts, shields and revives absorb damage in the right order', () => {
  const sim = createSimulation({ module: 1, seed: 7 });

  hitPlayer(sim);
  assert.equal(sim.hearts, 2);
  assert.ok(sim.player.invuln > 0);
  assert.ok(sim.drainEvents().some((e) => e.type === 'heart:lost'));

  // invulnerable: the next hit is ignored
  hitPlayer(sim);
  assert.equal(sim.hearts, 2);

  sim.player.invuln = 0;
  sim.shield = 1;
  hitPlayer(sim);
  assert.equal(sim.hearts, 2, 'shield takes the hit before a heart');
  assert.equal(sim.shield, 0);
  assert.ok(sim.drainEvents().some((e) => e.type === 'shield:used'));

  sim.player.invuln = 0;
  sim.hearts = 1;
  hitPlayer(sim);
  assert.equal(sim.phase, 'dead');
  assert.ok(sim.drainEvents().some((e) => e.type === 'gameover'));
});

test('the elder headdress revive keeps a run alive', () => {
  const progress = { ...defaultProgress(), owned: [...defaultProgress().owned, 'garment-crown'] };
  const sim = createSimulation({ progress, module: 1, seed: 8 });
  assert.equal(sim.revives, 1);
  sim.hearts = 1;
  hitPlayer(sim);
  assert.equal(sim.hearts, 1, 'revives with one heart');
  assert.equal(sim.revives, 0);
  assert.equal(sim.phase, 'play');
  assert.ok(sim.drainEvents().some((e) => e.type === 'revive'));

  sim.player.invuln = 0;
  hitPlayer(sim);
  assert.equal(sim.phase, 'dead', 'the second fatal hit is fatal');
});

test('upgrades change how the warrior fights, but throwing stays single', () => {
  const progress = { ...defaultProgress(), upgrades: { damage: 2, speed: 3, cooldown: 3, pierce: 2, shield: 1 } };
  const sim = createSimulation({ progress, module: 3, seed: 9 });
  assert.equal(sim.stats.weaponDamage, 3);
  assert.equal(sim.shield, 1, 'shield upgrade grants a charge at the start');
  assert.equal('multishot' in sim.stats, false, 'no upgrade family can fan the spear out');

  sim.throwSpear();
  assert.equal(sim.spears.length, 1, 'one press throws exactly one spear');
  assert.ok(sim.spears[0].vy < 0, 'the spear flies upward');
  assert.equal(sim.throwSpear(), false, 'the cooldown blocks an immediate second throw');

  // a piercing spear survives a bat and keeps flying
  const bat = batUnderPlayer(sim, 120, 1);
  sim.spears.length = 0;
  sim.throwTimer = 0;
  sim.throwSpear();
  for (let i = 0; i < 120 && sim.phase === 'play'; i += 1) sim.update(1 / 60);
  assert.equal(bat.alive, false);
  assert.ok(sim.phase === 'quiz');

  const bigBat = createSimulation({ progress, module: 1, seed: 10 });
  bigBat.spears.length = 0;
  batUnderPlayer(bigBat, 150, 3);
  bigBat.throwSpear();
  bigBat.spears[0].dmg = 3;
  for (let i = 0; i < 120 && bigBat.phase === 'play'; i += 1) bigBat.update(1 / 60);
  assert.equal(bigBat.bats[0] ? bigBat.bats[0].alive : false, false, 'three damage kills a three health bat');
});

test('shuffling moves the answer without losing a choice', () => {
  const rng = createRng(21);
  const sample = { id: 'sample', lang: 'html', difficulty: 1, choices: ['first', 'second', 'third'], answer: 0 };
  const positions = new Set();
  for (let i = 0; i < 60; i += 1) {
    const question = shuffleQuestion(sample, rng);
    assert.equal(question.choices[question.answer], 'first', 'the moved index still points at the right choice');
    assert.deepEqual(question.choices.slice().sort(), ['first', 'second', 'third'], 'every choice survives');
    positions.add(question.answer);
  }
  assert.deepEqual([...positions].sort(), [0, 1, 2], 'the right answer lands in every position over time');
  assert.equal(sample.answer, 0, 'the source answer index is not mutated');
  assert.equal(sample.choices[0], 'first', 'the source order is not mutated');
  assert.deepEqual(shuffleQuestion({ id: 'x', choices: ['only'], answer: 0 }, rng).choices, ['only'], 'a one-choice question is left alone');
});

test('the authored bank keeps the right answer first, the served questions do not', () => {
  const authoredFirst = QUESTIONS.filter((q) => q.answer === 0).length;
  assert.ok(authoredFirst >= 40, `${authoredFirst} of ${QUESTIONS.length} questions are authored A-first`);

  const byId = new Map(QUESTIONS.map((q) => [q.id, q]));
  const cfg = levelConfig(3);
  const rng = createRng(11);
  const progress = defaultProgress();
  let onA = 0;
  let correct = 0;
  const positions = new Set();
  for (let i = 0; i < 30; i += 1) {
    const question = pickQuestion(progress, 'js', cfg, rng, new Set());
    const original = byId.get(question.id);
    assert.equal(question.choices.length, original.choices.length);
    assert.equal(new Set(question.choices).size, question.choices.length, 'no choice is duplicated');
    if (question.answer === 0) onA += 1;
    positions.add(question.answer);
    if (question.choices[question.answer] === original.choices[original.answer]) correct += 1;
  }
  assert.equal(correct, 30, 'every served question still grades the right text');
  assert.ok(positions.size >= 3, `the answer moves around (${positions.size} positions seen)`);
  assert.ok(onA <= 18, `the answer is not always A (${onA} of 30 landed on A)`);
});

test('bats stay on screen by wrapping instead of escaping', () => {
  const sim = createSimulation({ module: 2, seed: 12 });
  sim.step(30);
  assert.ok(sim.bats.length > 0);
  for (const bat of sim.bats) {
    assert.ok(bat.x > -80 && bat.x < WORLD.W + 80, `bat x ${bat.x} wrapped`);
  }
  assert.equal(sim.phase, 'play');
});

test('the simulation is deterministic for a given seed', () => {
  const run = () => {
    const sim = createSimulation({ module: 2, seed: 4242 });
    sim.step(12);
    return sim.bats.map((b) => `${b.id}:${b.x.toFixed(3)}:${b.y.toFixed(3)}`).join('|');
  };
  assert.equal(run(), run());
});

test('a full module can be cleared by answering correctly', () => {
  const sim = createSimulation({ module: 1, seed: 77 });
  let guard = 0;
  while (sim.phase !== 'cleared' && sim.phase !== 'dead' && guard < 60 * 400) {
    guard += 1;
    if (sim.phase === 'quiz') {
      assert.equal(sim.answer(sim.pendingQuiz.question.answer).correct, true);
      sim.continueAfterQuiz();
      continue;
    }
    const target = sim.boss || sim.bats.slice().sort((a, b) => a.y - b.y)[0];
    if (target) sim.setMove(Math.abs(target.x - sim.player.x) < 6 ? 0 : Math.sign(target.x - sim.player.x));
    sim.throwSpear();
    sim.update(1 / 60);
  }
  assert.equal(sim.phase, 'cleared');
  assert.ok(sim.points > 150);
  assert.equal(sim.quizStats.correct, sim.totalCheckpoints + sim.cfg.bossHp);
  assert.equal(sim.quizStats.perfect, true);
});
