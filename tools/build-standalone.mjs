/**
 * Builds dist/CodePlay.html - the entire game as ONE self-contained file.
 *
 * Why: the normal build uses ES modules and a separate stylesheet, which browsers
 * refuse to load over file:// (module imports are blocked by CORS on file origins).
 * Bundling to a classic script with inlined CSS means the game runs from a phone's
 * local storage with no server, no network and no install step.
 *
 *   node tools/build-standalone.mjs
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { build } from 'esbuild';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT_DIR = join(ROOT, 'dist');
const OUT_FILE = join(OUT_DIR, 'CodePlay.html');

/* ------------------------------ 1. bundle JS ------------------------------ */
const result = await build({
  entryPoints: [join(ROOT, 'js/main.js')],
  bundle: true,
  format: 'iife',            // classic script: runs from file:// with no module loader
  target: ['es2020'],        // iOS Safari 14+, Chrome 87+
  platform: 'browser',
  minify: true,
  write: false,
  legalComments: 'none',
  logLevel: 'warning',
});
const js = result.outputFiles[0].text;

/* ---------------------------- 2. inline CSS ------------------------------ */
const css = readFileSync(join(ROOT, 'styles.css'), 'utf8');
const html = readFileSync(join(ROOT, 'index.html'), 'utf8');

/* ------------------------- 3. splice them into HTML ---------------------- */
const LINK_RE = /<link\s+rel="stylesheet"\s+href="styles\.css"\s*\/?>/;
const SCRIPT_RE = /<script\s+type="module"\s+src="js\/main\.js"\s*><\/script>/;

if (!LINK_RE.test(html)) throw new Error('could not find the stylesheet link tag in index.html');
if (!SCRIPT_RE.test(html)) throw new Error('could not find the module script tag in index.html');

// The lobby's download button needs the dev server's /downloads route, which a
// file:// copy can never reach - drop it so the offline build has no dead link.
const DOWNLOAD_RE = /\s*<a\b[^>]*id="btn-getcode"[\s\S]*?<\/a>/;

const out = html
  .replace(LINK_RE, () => `<style>\n${css}\n</style>`)
  .replace(SCRIPT_RE, () => `<script>\n${js}\n</script>`)
  .replace(DOWNLOAD_RE, '');

/* ------------------------------ 4. guardrails ---------------------------- */
// A literal </script> or <!-- inside the inlined payload would end the block early.
for (const [name, payload] of [['js', js], ['css', css]]) {
  if (/<\/script/i.test(payload)) throw new Error(`${name} payload contains a literal </script> sequence`);
  if (/<!--/.test(payload)) throw new Error(`${name} payload contains an HTML comment opener`);
}
// Nothing may still point at an external file, or the offline build is broken.
const leftovers = [
  [/<script[^>]*\ssrc=/i, 'a <script src=...> tag'],
  [/<link[^>]+rel="stylesheet"/i, 'a <link rel=stylesheet> tag'],
  [/\b(from|import)\s*['"]\.{1,2}\//, 'a relative ES module import'],
];
for (const [re, what] of leftovers) {
  const hit = out.match(re);
  if (hit) throw new Error(`standalone build would still contain ${what}: ${hit[0]}`);
}
if (!/<style>/.test(out) || !/<script>/.test(out)) throw new Error('inlining did not happen');
// If this ever stops matching, the offline build would ship a broken download link.
if (/btn-getcode/.test(out)) throw new Error('the /downloads link survived into the offline build');

/* -------------------------------- 5. write ------------------------------- */
mkdirSync(OUT_DIR, { recursive: true });
writeFileSync(OUT_FILE, out, 'utf8');

const kb = (n) => `${(n / 1024).toFixed(1)} KB`;
console.log('standalone build ok');
console.log(`  bundle : ${kb(js.length)}  (${result.outputFiles.length} output file)`);
console.log(`  css    : ${kb(css.length)}`);
console.log(`  html in: ${kb(html.length)}`);
console.log(`  output : ${kb(out.length)} -> ${OUT_FILE}`);
