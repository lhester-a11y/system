/**
 * Stages the deployable game into ./public - only what the browser needs.
 * Source tools, tests, the Godot project and docs stay out of the upload.
 */
import { cpSync, mkdirSync, rmSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const OUT = 'public';
rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

const files = ['index.html', 'styles.css'];
const dirs = ['js', 'assets/data', 'assets/sprites'];

for (const f of files) cpSync(f, join(OUT, f));
for (const d of dirs) {
  mkdirSync(join(OUT, d), { recursive: true });
  cpSync(d, join(OUT, d), { recursive: true });
}
// the contact sheet is a dev reference, not a game asset
rmSync(join(OUT, 'assets/sprites/_sheet.png'), { force: true });

// Worker: serve the static build from the assets binding.
writeFileSync(join(OUT, '..', 'worker.js'), `/**
 * CodePlay Worker. The whole game is static, so every request is served straight
 * from the assets binding. SPA fallback keeps deep links working.
 */
export default {
  async fetch(request, env) {
    const response = await env.ASSETS.fetch(request);
    if (response.status === 404 && request.method === 'GET') {
      return env.ASSETS.fetch(new Request(new URL('/', request.url), request));
    }
    return response;
  },
};
`);

writeFileSync('deploy.manifest.json', `${JSON.stringify({
  entrypoint: 'worker.js',
  compatibilityDate: '2026-10-12',
  modules: [{ name: 'worker.js', type: 'esm', path: './worker.js' }],
  assetsDirectory: './public',
  spa: true,
}, null, 2)}\n`);

function walk(dir, acc = []) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) walk(p, acc);
    else acc.push(p);
  }
  return acc;
}
const staged = walk(OUT);
const bytes = staged.reduce((n, f) => n + statSync(f).size, 0);
console.log(`staged ${staged.length} files, ${(bytes / 1024).toFixed(1)} KiB into ${OUT}/`);
