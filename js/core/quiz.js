/** Question selection and answer checking. Pure - no DOM, no timers. */
import { questionsFor, languageById } from '../data/questions.js';

export function checkAnswer(question, index) {
  if (!question) return false;
  return Number(index) === Number(question.answer);
}

export function correctChoice(question) {
  return question ? question.choices[question.answer] : '';
}

/**
 * Return a copy of a question with its choices shuffled and `answer` moved to
 * match.
 *
 * Every question is authored with the right answer first, which made the letter A
 * correct almost every time. Served questions therefore pass through here.
 *
 * The copy matters: the bank keeps its authoring order, so the review screen and
 * the mastery counts never shift under the player's feet.
 */
export function shuffleQuestion(question, rng) {
  const choices = Array.isArray(question.choices) ? question.choices.slice() : [];
  const count = choices.length;
  if (count < 2) return { ...question, choices };

  const order = choices.map((_, i) => i);
  // Fisher-Yates, so every arrangement is equally likely.
  for (let i = count - 1; i > 0; i -= 1) {
    const j = Math.floor(rng() * (i + 1));
    const swap = order[i];
    order[i] = order[j];
    order[j] = swap;
  }

  const answer = Number(question.answer);
  const shuffled = [];
  let newAnswer = 0;
  order.forEach((source, position) => {
    shuffled.push(choices[source]);
    if (source === answer) newAnswer = position;
  });
  return { ...question, choices: shuffled, answer: newAnswer };
}

/**
 * Choose the next checkpoint question.
 *
 * Prioritises questions the player has never solved, then those whose difficulty
 * sits near the current module's target. `exclude` holds ids already asked in
 * this run so a single module never repeats itself.
 *
 * The returned question is shuffled (see shuffleQuestion) so the right answer is
 * not always choice A.
 */
export function pickQuestion(progress, lang, cfg, rng, exclude) {
  const all = questionsFor(lang, cfg.maxDifficulty);
  const answered = progress.answered || {};
  const skip = exclude instanceof Set ? exclude : new Set(exclude || []);
  const target = Math.min(3, 1 + Math.floor((cfg.module - 1) / 2));

  let pool = all.filter((q) => !skip.has(q.id));
  if (!pool.length) {
    // Easy questions are used up: widen to the harder ones before repeating anything.
    const wider = questionsFor(lang, 3).filter((q) => !skip.has(q.id));
    pool = wider.length ? wider : all;
  }

  const scored = pool.map((q) => {
    const unsolved = !answered[q.id];
    const closeness = 1 / (1 + Math.abs(q.difficulty - target));
    return { q, weight: (unsolved ? 3 : 1) * closeness };
  });

  const total = scored.reduce((sum, s) => sum + s.weight, 0);
  if (total <= 0) return shuffleQuestion(scored[0].q, rng);
  let roll = rng() * total;
  for (const s of scored) {
    roll -= s.weight;
    if (roll <= 0) return shuffleQuestion(s.q, rng);
  }
  return shuffleQuestion(scored[scored.length - 1].q, rng);
}

/** Difficulty label used by the quiz card chip. */
export function difficultyLabel(difficulty) {
  return difficulty === 1 ? 'Recall' : difficulty === 2 ? 'Understand' : 'Apply';
}

/** "HTML · Recall · +10" style summary line. */
export function questionMeta(question) {
  const lang = languageById(question.lang);
  return {
    langName: lang ? lang.name : question.lang,
    langColor: lang ? lang.color : '#e8eef7',
    difficulty: difficultyLabel(question.difficulty),
    topic: question.topic,
  };
}
