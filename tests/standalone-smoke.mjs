/**
 * Verifies dist/CodePlay.html the way a phone browser opens it:
 * as a classic inline script from a file:// origin, with no network and no server.
 *
 *   node tests/standalone-smoke.mjs     (run tools/build-standalone.mjs first)
 */
import { readFileSync } from 'node:fs';
import { JSDOM } from 'jsdom';

const html = readFileSync(new URL('../dist/CodePlay.html', import.meta.url), 'utf8');

const failures = [];
function check(label, condition) {
  if (condition) console.log(`  ok   ${label}`);
  else { console.log(`  FAIL ${label}`); failures.push(label); }
}

/* ------------------- [1] static: nothing may leave the file ------------------ */
console.log('\n[1] self-containment (static)');
const scriptTags = html.match(/<script\b[^>]*>/gi) || [];
check('exactly one script tag', scriptTags.length === 1);
check('that script is inline (no src)', scriptTags.length === 1 && !/\ssrc=/i.test(scriptTags[0]));
check('no external script src in markup', !/<script[^>]*\ssrc=/i.test(html));
check('styles are inlined', /<style>[\s\S]{1000,}<\/style>/.test(html));
check('no module script tags in markup', !/<script[^>]*type="module"/i.test(html));
check('no fetch/XHR to a remote host', !/https?:\/\/(?!www\.w3\.org)[\w.-]+\//.test(html.replace(/<style>[\s\S]*?<\/style>/g, '').replace(/<[^>]+>/g, ' ')));
check('no canvas image loading', !/new Image|\.src\s*=/.test(html));
check('no @font-face / url() in css', !/@font-face|url\(/.test(html));
check('viewport meta preserved for mobile', /name="viewport"/.test(html));

/* ---------------------- [2] boot as a file:// classic script ----------------- */
console.log('\n[2] boot under file://');
const CTX_METHODS = [
  'fillRect', 'clearRect', 'drawImage', 'save', 'restore', 'translate', 'scale',
  'rotate', 'beginPath', 'moveTo', 'lineTo', 'closePath', 'fill', 'stroke',
  'fillText', 'arc', 'rect', 'strokeRect', 'setTransform',
];
let ctxCalls = 0;
function makeCtx() {
  const base = {
    canvas: { width: 360, height: 640 },
    measureText: () => ({ width: 10 }),
    createLinearGradient: () => ({ addColorStop() {} }),
    imageSmoothingEnabled: false, globalAlpha: 1, fillStyle: '#000', strokeStyle: '#000',
    lineWidth: 1, font: '10px monospace', textAlign: 'left',
  };
  for (const name of CTX_METHODS) base[name] = () => { ctxCalls += 1; };
  return base;
}

const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  pretendToBeVisual: true,
  url: 'file:///CodePlay.html',   // the origin a phone actually gets
  beforeParse(window) {
    window.HTMLCanvasElement.prototype.getContext = () => makeCtx();
    window.requestAnimationFrame = () => 0;   // the test drives frames itself
    window.cancelAnimationFrame = () => {};
  },
});

const game = dom.window.CodePlay;
const $ = (id) => dom.window.document.getElementById(id);
check('script executed (CodePlay handle present)', Boolean(game));
check('zero <link> elements in the parsed document', dom.window.document.querySelectorAll('link').length === 0);
check('zero external <script src> in the parsed document', dom.window.document.querySelectorAll('script[src]').length === 0);
check('storage denial did not break boot', typeof game?.progress === 'object' && game.progress !== null);
check('tutorial gate shown on the first boot', $('screen-howto').hidden === false);
check('tutorial offers a start button', $('btn-howto-done').textContent.startsWith('Got it'));
$('btn-howto-done').dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
check('tutorial dismisses to the lobby', $('screen-howto').hidden === true);
check('lobby screen visible', $('screen-lobby').hidden === false);
check('hero picker rendered 2 warriors', $('hero-picker').children.length === 2);
check('shop grid populated', $('shop-grid').children.length > 0);
check('badge grid populated', $('badge-grid').children.length > 0);
check('game canvas present', Boolean($('game')));

/* ------------------- [3] play a whole module through the UI ------------------ */
console.log('\n[3] full module, real buttons');
game.startModule(1);
check('HUD visible while playing', $('hud').hidden === false);
check('touch controls visible', $('controls').hidden === false);

let frames = 0, sawQuiz = 0, sawBoss = false;
while (game.state.mode !== 'banner' && frames < 60 * 400) {
  frames += 1;
  const sim = game.sim;
  if (sim?.boss) sawBoss = true;
  if (sim?.phase === 'quiz' && !sim.result) {
    sawQuiz += 1;
    if (sawQuiz === 1) {
      check('quiz modal shown', $('screen-quiz').hidden === false);
      check('answer choices rendered', $('quiz-choices').children.length >= 2);
    }
    $('quiz-choices').children[sim.pendingQuiz.question.answer]
      .dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
    if (sawQuiz === 1) {
      check('feedback shown', $('quiz-feedback').hidden === false);
      check('explanation present', $('quiz-fb-body').textContent.length > 10);
    }
    game.onQuizContinue();
    continue;
  }
  const target = sim.boss || sim.bats.slice().sort((a, b) => a.y - b.y)[0];
  if (target) sim.setMove(Math.abs(target.x - sim.player.x) < 6 ? 0 : Math.sign(target.x - sim.player.x));
  sim.throwSpear();
  game.tick(1 / 60);
}

console.log('\n[4] module result');
check('module completed', game.state.mode === 'banner');
check('banner screen visible', $('screen-banner').hidden === false);
check('boss appeared', sawBoss);
check('a checkpoint ran for every bat', sawQuiz >= game.sim.totalCheckpoints);
check('module advanced to 2', game.progress.module === 2);
check('points awarded', game.progress.points > 0);
check('badges unlocked', game.progress.badges.length > 0);
check('renderer actually drew', ctxCalls > 0);
check('banner offers continue', $('btn-banner-primary').textContent.length > 0);

/* --------------------- [5] the wrong-answer learning path -------------------- */
console.log('\n[5] wrong answer teaches, does not reward');
const ptsBefore = game.progress.points;
const upgBefore = JSON.stringify(game.progress.upgrades);
game.startModule(game.progress.module);
let guard = 0;
let sawWrong = false;
while (game.state.mode !== 'banner' && guard < 60 * 400) {
  guard += 1;
  const sim = game.sim;
  if (sim?.phase === 'quiz' && !sim.result) {
    const wrongIdx = (sim.pendingQuiz.question.answer + 1) % $('quiz-choices').children.length;
    $('quiz-choices').children[wrongIdx]
      .dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
    sawWrong = true;
    check('wrong choice marked wrong', $('quiz-choices').children[wrongIdx].classList.contains('wrong'));
    check('correct answer revealed', [...$('quiz-choices').children].some((b) => b.classList.contains('correct')));
    check('no points for a wrong answer', game.progress.points === ptsBefore);
    check('no upgrade for a wrong answer', JSON.stringify(game.progress.upgrades) === upgBefore);
    check('feedback still explains', $('quiz-fb-body').textContent.length > 10);
    game.onQuizContinue();
    check('action resumes after a wrong answer', game.sim.phase === 'play');
    break;
  }
  const t = sim.boss || sim.bats.slice().sort((a, b) => a.y - b.y)[0];
  if (t) sim.setMove(Math.abs(t.x - sim.player.x) < 6 ? 0 : Math.sign(t.x - sim.player.x));
  sim.throwSpear();
  game.tick(1 / 60);
}
check('the wrong-answer branch was actually exercised', sawWrong);

console.log(`\n${failures.length === 0 ? 'PASS' : 'FAIL'} - ${failures.length} failure(s)`);
if (failures.length) { for (const f of failures) console.log(`  - ${f}`); process.exit(1); }
