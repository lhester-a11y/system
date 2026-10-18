/**
 * Exports the shared question bank to JSON so the Godot build reads exactly the
 * same content as the web build. Run with: node tools/export-questions-json.mjs
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { QUESTIONS, LANGUAGES } from '../js/data/questions.js';

mkdirSync('godot/data', { recursive: true });
mkdirSync('assets/data', { recursive: true });

const payload = {
  version: 1,
  languages: LANGUAGES,
  questions: QUESTIONS.map((q) => ({
    id: q.id,
    lang: q.lang,
    difficulty: q.difficulty,
    kind: q.kind,
    prompt: q.prompt,
    code: q.code || '',
    choices: q.choices,
    answer: q.answer,
    explain: q.explain,
    topic: q.topic,
    reward: q.reward,
  })),
};

const json = `${JSON.stringify(payload, null, 2)}\n`;
writeFileSync('assets/data/questions.json', json);
writeFileSync('godot/data/questions.json', json);
console.log(`wrote ${payload.questions.length} questions for ${payload.languages.length} languages to assets/data and godot/data`);
