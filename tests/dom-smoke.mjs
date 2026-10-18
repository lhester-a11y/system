/**
 * End-to-end smoke test: loads index.html in jsdom with a stub 2D context,
 * boots js/main.js, then plays a whole module through the real UI handlers.
 *
 *   node tests/dom-smoke.mjs
 */
import { readFileSync } from 'node:fs';
import { JSDOM } from 'jsdom';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const dom = new JSDOM(html, { pretendToBeVisual: true, url: 'http://localhost:3000/' });

/* ------------------------- canvas 2D context stub ------------------------- */
const ctxCalls = [];
const CTX_METHODS = [
  'fillRect', 'clearRect', 'drawImage', 'save', 'restore', 'translate', 'scale',
  'rotate', 'beginPath', 'moveTo', 'lineTo', 'closePath', 'fill', 'stroke',
  'fillText', 'arc', 'rect', 'strokeRect', 'setTransform',
];

/** Records every context call so the test can prove the render path really ran. */
function makeCtx() {
  const base = {
    canvas: { width: 360, height: 640 },
    measureText: () => ({ width: 10 }),
    createLinearGradient: () => ({ addColorStop() {} }),
    imageSmoothingEnabled: false,
    globalAlpha: 1,
    fillStyle: '#000',
    strokeStyle: '#000',
    lineWidth: 1,
    font: '10px monospace',
    textAlign: 'left',
  };
  for (const name of CTX_METHODS) base[name] = (...args) => { ctxCalls.push({ name, args }); };
  return base;
}

dom.window.HTMLCanvasElement.prototype.getContext = function getContext() { return makeCtx(); };

/* ----------------------------- global wiring ----------------------------- */
global.window = dom.window;
global.document = dom.window.document;
// Node already provides a global `performance`; overriding it makes jsdom recurse.
global.requestAnimationFrame = () => 0; // the test drives frames itself
global.cancelAnimationFrame = () => {};
global.HTMLElement = dom.window.HTMLElement;
global.Node = dom.window.Node;
global.localStorage = dom.window.localStorage;

const failures = [];
function check(label, condition) {
  if (condition) console.log(`  ok   ${label}`);
  else { console.log(`  FAIL ${label}`); failures.push(label); }
}

const APP = '../js/main.js';
await import(APP);
const game = dom.window.CodePlay;
const $ = (id) => dom.window.document.getElementById(id);

console.log('\n[1] boot');
check('CodePlay debug handle exposed', Boolean(game));
// First run: the tutorial is a one-time gate over the lobby.
check('tutorial shown on the first boot', $('screen-howto').hidden === false);
check('lobby waiting behind the tutorial', $('screen-lobby').hidden === true);
check('tutorial button reads like a start', $('btn-howto-done').textContent.startsWith('Got it'));
check('HUD hidden on boot', $('hud').hidden === true);
$('btn-howto-done').dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
check('dismissing the tutorial records it', game.progress.tutorialSeen === true);
check('lobby screen visible after the tutorial', $('screen-lobby').hidden === false);
check('tutorial closes', $('screen-howto').hidden === true);
check('save carries the tutorial flag', JSON.parse(dom.window.localStorage.getItem('codeplay.save.v1')).tutorialSeen === true);
// Sound starts on, and the HUD button toggles it into the save.
check('sound button rendered', $('btn-sound').textContent === 'SFX');
$('btn-sound').dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
check('SFX button mutes', $('btn-sound').textContent === 'MUTE' && game.progress.sound === false);
check('mute written to the save', JSON.parse(dom.window.localStorage.getItem('codeplay.save.v1')).sound === false);
$('btn-sound').dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
check('SFX button unmutes', $('btn-sound').textContent === 'SFX' && game.progress.sound === true);
check('hero picker rendered 2 options', $('hero-picker').children.length === 2);
check('shop grid populated', $('shop-grid').children.length > 0);
check('badge grid populated', $('badge-grid').children.length > 0);

console.log('\n[2] module start');
game.startModule(1);
check('sim created', Boolean(game.sim));
check('HUD visible while playing', $('hud').hidden === false);
check('controls visible while playing', $('controls').hidden === false);
check('all screens hidden while playing', ['screen-lobby', 'screen-quiz', 'screen-shop', 'screen-progress'].every((id) => $(id).hidden));
check('sky matches HTML module (day)', game.sim.cfg.sky === 'day');

console.log('\n[3] play a full module through the real UI');
let frames = 0;
let answered = 0;
let sawQuiz = 0;
let sawBoss = false;
while (game.state.mode !== 'banner' && frames < 60 * 400) {
  frames += 1;
  const sim = game.sim;
  if (sim && sim.boss) sawBoss = true;
  if (sim && sim.phase === 'quiz' && !sim.result) {
    sawQuiz += 1;
    check(`quiz ${sawQuiz}: modal is on screen`, $('screen-quiz').hidden === false);
    check(`quiz ${sawQuiz}: choices rendered`, $('quiz-choices').children.length >= 2);
    check(`quiz ${sawQuiz}: code block toggled`, (sim.pendingQuiz.question.code ? $('quiz-code').hidden === false : $('quiz-code').hidden === true));
    // click the correct answer the way a player would
    const index = sim.pendingQuiz.question.answer;
    const button = $('quiz-choices').children[index];
    button.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
    answered += 1;
    check(`quiz ${sawQuiz}: feedback panel shown`, $('quiz-feedback').hidden === false);
    check(`quiz ${sawQuiz}: explanation present`, $('quiz-fb-body').textContent.length > 10);
    game.onQuizContinue();
    check(`quiz ${sawQuiz}: modal dismissed`, $('screen-quiz').hidden === true);
    continue;
  }
  // aim and fire like a player
  const target = sim.boss || sim.bats.slice().sort((a, b) => a.y - b.y)[0];
  if (target) sim.setMove(Math.abs(target.x - sim.player.x) < 6 ? 0 : Math.sign(target.x - sim.player.x));
  sim.throwSpear();
  game.tick(1 / 60);
}

console.log('\n[4] module result');
check('module completed (banner shown)', game.state.mode === 'banner');
check('banner screen visible', $('screen-banner').hidden === false);
check('boss actually appeared', sawBoss);
check('checkpoint modal was shown for every bat', sawQuiz === answered && sawQuiz >= game.sim.totalCheckpoints);
check('progress module advanced to 2', game.progress.module === 2);
check('module recorded as cleared', game.progress.modulesCleared === 1);
check('points were awarded', game.progress.points > 0);
check('badges unlocked', game.progress.badges.length > 0);
check('mastery recorded for html', game.progress.mastery.html.correct >= 1);
check('answered questions persisted', Object.keys(game.progress.answered).length >= 3);
check('upgrades granted to progress', Object.values(game.progress.upgrades).some((v) => v > 0));
check('banner lists bonus points', $('banner-stats').textContent.includes('Clear bonus'));

console.log('\n[5] persistence');
const raw = dom.window.localStorage.getItem('codeplay.save.v1');
check('save written to storage', typeof raw === 'string' && raw.length > 50);
const parsed = JSON.parse(raw);
check('saved module is 2', parsed.module === 2);
check('saved points match live progress', parsed.points === game.progress.points);

console.log('\n[6] shop purchase flow');
const shopGame = game.progress;
shopGame.points = 500;
dom.window.CodePlay.toLobby();
$('btn-shop').dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
check('shop screen opens', $('screen-shop').hidden === false);
const cards = $('shop-grid').children;
const buyable = Array.from(cards).find((c) => c.querySelector('.item-btn') && !c.querySelector('.item-btn').disabled && c.querySelector('.item-btn').textContent.includes('◈'));
if (buyable) {
  const before = game.progress.points;
  buyable.querySelector('.item-btn').dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
  check('points deducted after purchase', game.progress.points < before);
  check('item added to owned list', game.progress.owned.length > 3);
} else {
  check('a buyable item was found', false);
}

console.log('\n[7] wrong answer keeps the game honest');
game.startModule(2);
let guard = 0;
while (game.sim.phase !== 'quiz' && guard < 60 * 60) { game.sim.throwSpear(); game.tick(1 / 60); guard += 1; }
const sim2 = game.sim;
const wrongIndex = (sim2.pendingQuiz.question.answer + 1) % sim2.pendingQuiz.question.choices.length;
const pointsBefore = game.progress.points;
const upgradesBefore = JSON.stringify(game.progress.upgrades);
const wrongButton = $('quiz-choices').children[wrongIndex];
wrongButton.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
check('wrong choice is marked wrong', wrongButton.classList.contains('wrong'));
check('correct choice is revealed', Array.from($('quiz-choices').children).some((b) => b.classList.contains('correct')));
check('no points for a wrong answer', game.progress.points === pointsBefore);
check('no upgrade for a wrong answer', JSON.stringify(game.progress.upgrades) === upgradesBefore);
check('wrong count incremented', game.progress.wrong >= 1);
game.onQuizContinue();
check('game resumes after a wrong answer', game.sim.phase === 'play');
check('world kept running', game.state.mode === 'play');

console.log('\n[8] throwing is single');
game.startModule(1);
{
  const sim = game.sim;
  let throws = 0;
  const realThrow = sim.throwSpear;
  sim.throwSpear = () => { throws += 1; return realThrow(); };
  $('btn-throw').dispatchEvent(new dom.window.MouseEvent('pointerdown', { bubbles: true }));
  check('a press on THROW throws once', throws === 1);
  check('only one spear is in the air', game.sim.spears.length === 1);
  // Hold it down for two seconds. The cooldown is 0.62s, so an auto-repeating
  // control would have fired several more times by now.
  for (let i = 0; i < 120; i += 1) game.tick(1 / 60);
  check('holding THROW does not keep firing', throws === 1);
  $('btn-throw').dispatchEvent(new dom.window.MouseEvent('pointerup', { bubbles: true }));
  $('btn-throw').dispatchEvent(new dom.window.MouseEvent('pointerdown', { bubbles: true }));
  check('release and press again throws once more', throws === 2);
  sim.throwSpear = realThrow;
}

console.log('\n[9] review screen');
game.toLobby();
$('btn-review').dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
check('the lobby opens the review screen', $('screen-review').hidden === false);
check('lobby stepped aside', $('screen-lobby').hidden === true);
check('tabs list All plus every language', $('review-tabs').children.length === 7);
check('the module language is listed', $('review-list').children.length === 8);
check('every question marks exactly one right answer',
  $('review-list').querySelectorAll('.review-choices li.correct').length === 8);
const reviewText = $('review-list').textContent;
check('markup in a question survives as text', reviewText.includes('<h1>Sleeping Beauty</h1>'));
check('the explanation is shown', reviewText.includes('markup language'));
$('review-tabs').children[0].dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
check('All lists the whole bank', $('review-list').children.length === 48);
$('screen-review').querySelector('[data-back]').dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
check('Back returns to the lobby', $('screen-lobby').hidden === false && $('screen-review').hidden === true);

console.log('\n[10] render path executed');
check('canvas context methods were called', ctxCalls.length > 0);

console.log('\n[11] defeat path');
game.startModule(1);
let guard2 = 0;
while (game.state.mode === 'play' && guard2 < 1200) {
  guard2 += 1;
  const s = game.sim;
  s.player.invuln = 0;
  s.bugs.push({ x: s.player.x, y: s.player.y, vx: 0, vy: 0, w: 12, h: 12, spin: 0, alive: true });
  game.tick(1 / 60);
}
check('losing every heart ends the run', game.sim && game.sim.phase === 'dead');
check('defeat banner replaces the arena', game.state.mode === 'banner');
check('banner offers a retry', $('btn-banner-primary').textContent.includes('Retry'));
check('progress survived the defeat', game.progress.points >= 0 && game.progress.badges.length > 0);
game.startModule(game.progress.module);
check('module restarts cleanly after a defeat', game.sim.phase === 'play' && game.sim.hearts > 0);

console.log(`\n${failures.length ? `FAILURES: ${failures.length}` : 'ALL DOM SMOKE CHECKS PASSED'}`);
if (failures.length) {
  failures.forEach((f) => console.log(`   - ${f}`));
  process.exit(1);
}
