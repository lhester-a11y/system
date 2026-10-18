/**
 * Runs the GDScript self-test headlessly.
 *
 *   npm run godot:test            skips with a notice when Godot is missing
 *   npm run godot:test -- --require   fails instead of skipping
 *
 * The scene it runs drives the real game: bat killed -> world paused -> question
 * -> graded answer -> progress saved -> boss wounded -> module cleared.
 */
import { spawnSync } from 'node:child_process';
import { GODOT_HELP, findGodot } from './godot-bin.mjs';

const requireGodot = process.argv.slice(2).includes('--require');
const godot = findGodot();

if (!godot) {
  console.log('');
  console.log('SKIPPED - the Godot self-test did NOT run: no Godot 4 binary found.');
  console.log(GODOT_HELP);
  process.exit(requireGodot ? 1 : 0);
}

console.log(`Godot: ${godot}`);

// Import once before testing. A fresh clone has no .godot cache, and without it
// the engine has not scanned the scripts yet, so every `class_name` the game
// relies on reads as unknown and the whole run fails to compile.
const imported = spawnSync(godot, ['--headless', '--path', 'godot', '--import'], {
  stdio: 'inherit',
});
if (imported.status !== 0) {
  console.error('the import pass failed - the self-test result would be meaningless');
  process.exit(imported.status === null ? 1 : imported.status);
}

const result = spawnSync(godot, ['--headless', '--path', 'godot', 'res://tests/SelfTest.tscn'], {
  stdio: 'inherit',
});
process.exit(result.status === null ? 1 : result.status);
