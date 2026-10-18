/**
 * Exports the Godot build into godot/build/<platform>/.
 *
 *   node tools/godot-export.mjs                 every preset
 *   node tools/godot-export.mjs --preset Linux  just one (repeatable)
 *   node tools/godot-export.mjs --list          show the presets found
 *
 * The Android preset needs the Android SDK and a JDK installed and configured in
 * the Godot editor; the desktop and web presets need only the export templates.
 */
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { GODOT_HELP, findGodot } from './godot-bin.mjs';

const PRESETS = 'godot/export_presets.cfg';

/** Read name/platform/export_path out of each [preset.N] section. */
function readPresets() {
  if (!existsSync(PRESETS)) return [];
  const presets = [];
  let current = null;
  for (const rawLine of readFileSync(PRESETS, 'utf8').split('\n')) {
    const line = rawLine.trim();
    const section = line.match(/^\[preset\.(\d+)\]$/);
    if (section) {
      current = { name: '', platform: '', exportPath: '' };
      presets.push(current);
      continue;
    }
    if (line.startsWith('[')) {
      current = null;
      continue;
    }
    if (!current) continue;
    const entry = line.match(/^(\w+)\s*=\s*"?([^"]*)"?$/);
    if (!entry) continue;
    if (entry[1] === 'name') current.name = entry[2];
    else if (entry[1] === 'platform') current.platform = entry[2];
    else if (entry[1] === 'export_path') current.exportPath = entry[2];
  }
  return presets.filter((preset) => preset.name && preset.exportPath);
}

const args = process.argv.slice(2);
const wanted = [];
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === '--preset' && args[i + 1]) wanted.push(args[++i]);
}

const presets = readPresets();
if (!presets.length) {
  console.error(`No export presets found in ${PRESETS}.`);
  process.exit(1);
}

if (args.includes('--list')) {
  for (const preset of presets) console.log(`${preset.name.padEnd(10)} ${preset.platform.padEnd(9)} -> ${preset.exportPath}`);
  process.exit(0);
}

const selected = wanted.length ? presets.filter((preset) => wanted.includes(preset.name)) : presets;
if (!selected.length) {
  console.error(`No preset matched ${wanted.join(', ')}. Known: ${presets.map((p) => p.name).join(', ')}`);
  process.exit(1);
}

const godot = findGodot();
if (!godot) {
  console.error(`Cannot export: no Godot 4 binary found. ${GODOT_HELP}`);
  process.exit(1);
}

console.log(`Godot: ${godot}`);
let failures = 0;
for (const preset of selected) {
  // Godot resolves a relative export path against the project directory, so
  // pass an absolute one.
  const target = resolve('godot', preset.exportPath);
  const platform = preset.platform.toLowerCase();
  const finalTarget = platform === 'web' && target.endsWith('.html') ? join(dirname(target), 'index.html') : target;
  console.log(`\n== ${preset.name} (${preset.platform}) -> ${target}`);
  // Godot does not create the output directory itself.
  mkdirSync(dirname(finalTarget), { recursive: true });
  const result = spawnSync(
    godot,
    ['--headless', '--path', 'godot', '--export-release', preset.name, finalTarget],
    { stdio: 'inherit' },
  );
  if (result.status !== 0) {
    failures += 1;
    console.log(`FAIL ${preset.name}: Godot exited ${result.status}`);
    continue;
  }
  if (!existsSync(finalTarget)) {
    failures += 1;
    console.log(`FAIL ${preset.name}: ${finalTarget} was not produced`);
    continue;
  }
  console.log(`ok  ${preset.name}: ${finalTarget} (${statSync(finalTarget).size} bytes)`);
}

if (failures) {
  console.log(`\n${failures} of ${selected.length} exports failed.`);
  process.exit(1);
}
console.log(`\nAll ${selected.length} exports produced.`);
