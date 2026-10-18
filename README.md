# CodePlay

A mobile-first, pixel-art action game that teaches beginner IT students
**programming syntax and logic** — built on the throw-the-spear, absorb-the-code
loop from the brief.

An Igorot warrior stands on the rice terraces of Kalinga. Bats fly across the
Sleeping Beauty mountain carrying glowing syntax boxes. Hit a bat with your spear
and you absorb its code box: the action freezes and a **learning checkpoint**
asks one foundational question. Answer right and you earn an upgrade — real
power, tied to real understanding, never to participation. Clear every checkpoint
and the **Syntax Overlord** descends; beat it and the next language module opens.

---

## Play it

```bash
npm run dev          # serves on http://0.0.0.0:3000
```

`npm run dev` runs `tools/serve.py`, which serves the game at `/` **and** the
hand-over routes, so you never have to type a filename:

| Route | Serves |
| --- | --- |
| `/downloads` | a tap-to-save page listing all three files below |
| `/download-godot` | `CodePlay-godot.zip` — the Godot 4 project (GDScript) |
| `/download-project` | `CodePlay-repo.zip` — the whole tracked tree, for GitHub |
| `/download` | `CodePlay.html` — the single-file offline game |

The game's own title screen has a **Get the Godot code (.zip)** button pointing at
`/downloads`. `npm run dev:static` still serves a bare directory listing if you
only want the static files and no download routes.

No build step, no dependencies, no network calls. It is plain ES modules drawn
onto one `<canvas>`, so any static file server works.

| Input | Action |
| --- | --- |
| `◀` `▶` / ← → / A D | Move the warrior |
| `THROW` / Space / ↑ | Throw the spear (one spear per press) |
| `1`–`4` | Answer a checkpoint with the keyboard |
| `Enter` | Continue after the explanation |
| `Esc` / `P` / the `❚❚` HUD button | Pause |
| The `SFX` HUD button | Mute or unmute the sound effects |

The **How to play** screen interrupts the very first run exactly once, then stays
reachable from the lobby. Everything it teaches — hearts, checkpoints, the boss —
is also in the game itself, so the tutorial never has to be read twice.

### One file, no server (offline)

```bash
npm run build:standalone     # -> dist/CodePlay.html  (~89 KB, everything inside)
```

`dist/CodePlay.html` is the whole game — CSS, all eleven modules and the pixel art
— inlined into a single file with **zero external references**. Open it straight
from a phone's local storage and it plays with no server, no network and no
install.

It exists because browsers refuse ES module imports over `file://` (CORS blocks
them), so the multi-file build cannot be opened from disk. The build bundles to a
classic script and inlines the stylesheet, which is exactly what `file://` allows.

If the browser blocks `localStorage` for local files (iOS Safari sometimes does),
the game still runs — it just falls back to in-memory progress for that session.

## Sound

Eleven effects — throw, hit, absorb, correct, wrong, hurt, shield, badge, boss,
clear and click — and no audio files to download. The browser port synthesises
each clip with the Web Audio API (`js/audio.js`); the Godot port, which has no
such API, bakes the same recipes into WAVs offline:

```bash
npm run sfx          # -> godot/assets/sfx/*.wav (committed, ~200 KB total)
```

The mute switch sits on the HUD (`SFX`) and is remembered in the save file.

## The loop

```
spear ──hit──▶ bat ▲ absorbs code box
                    │
                    ▼
        ┌── action pauses ──────────────┐
        │  question about HTML/CSS/JS/  │
        │  Python/Java/C++              │
        └───────────────┬───────────────┘
                        │
        correct ────────┴──────── wrong
        +points, upgrade          explanation only,
        (damage, speed,           upgrade lost
         shield, cooldown,
         pierce)
```

Enemies are removed either way, so a missed question never blocks progress — it
just costs you the reward, and the explanation is shown immediately.

Throwing is **single**: one press throws one spear, and holding the button down
throws nothing more. The Triple Throw buff that used to fan three spears out is
gone for the same reason — aim, do not spray.

Questions are also **shuffled** every time they are served. The bank is authored
with the right answer first, so without the shuffle the letter A was right almost
every time; `answer` moves with the choices, and the bank itself keeps its
authoring order.

## Modules

Each module maps to a language and a time of day on the mountain.

| Module | Language | Sky | Checkpoints | Boss health |
| --- | --- | --- | --- | --- |
| 1 | HTML | Day | 5 | 3 |
| 2 | CSS | Day | 6 | 3 |
| 3 | JavaScript | Sunset | 7 | 4 |
| 4 | Python | Sunset | 8 | 4 |
| 5 | Java | Night | 8 | 5 |
| 6 | C++ | Night | 8 | 5 |
| 7+ | loops back to HTML, harder | | | |

The boss only takes damage when you answer correctly: one wound per right answer.

## Content

48 hand-written questions — 8 per language, three difficulty bands (recall,
understand, apply), mixed multiple-choice and true/false — each with a
beginner-friendly explanation and a topic tag. They live in one place:

```
js/data/questions.js          # the single source of truth
tools/export-questions-json.mjs   # exports it for the Godot build
```

Add a question by appending to `QUESTIONS`; the tests will validate it.

## Meta systems

* **Shop** — spend points on spear designs, traditional garments and particle
  effects. Garments and spears carry small perks (+move speed, +max heart,
  survive one fatal hit, +1 point per answer), so the shop stays cosmetic-first
  without being pointless.
* **Buffs are permanent** — upgrade levels live in the save file, so dying and
  retrying never takes back what a correct answer earned. The defeat card lists
the buffs you keep.
* **Progress tracker** — mastery per language (solved / total), accuracy, best
  streak, and 19 badges that only unlock from real milestones ("HTML Master"
  requires every HTML question).
* **Review questions** — study screen reachable from the lobby. Every checkpoint
  in the bank, grouped by language, with the right choice marked, the explanation
  shown and a tick on the ones already answered correctly. It reads the same bank
  the game asks from, so it can never drift from what is tested.
* **Save file** — one JSON blob in `localStorage`, versioned and self-repairing;
  a corrupt or hand-edited save falls back to defaults instead of crashing.

## Architecture

The game logic is a pure state machine with no DOM and no canvas, which is what
makes it testable: the renderer only reads it, and the DOM UI only feeds it input.

```
index.html          screens, HUD and touch controls (real DOM, so text stays crisp)
styles.css          the whole pixel-art UI
js/data/            question bank
js/core/            rng · rules · save · quiz selection · simulation   ← pure, unit tested
js/render/          sprites · parallax background · world renderer
js/ui.js            DOM screens: lobby, quiz modal, shop, progress, review
js/audio.js         procedural sound effects (Web Audio, no files)
js/main.js          rAF loop, input, persistence, screen routing
tools/              PNG encoder, sprite baker, JSON exporter
godot/              the whole game in GDScript (Godot 4)
assets/             baked sprite PNGs + questions.json
```

## Tests

```bash
npm test             # 33 unit tests over the pure core (no dependencies)
npm run test:dom     # 113 end-to-end checks in a real DOM (needs jsdom)
npm run test:standalone  # 43 checks on the single-file offline build
npm run godot:test   # 276 checks driving the real game in Godot
```

`npm run test:all` runs all four. `godot:test` prints a SKIPPED notice and exits
0 when no Godot 4 binary is on `PATH` (point `GODOT` at one, or pass `--require`
to make a missing Godot fail instead).

`npm test` covers the question bank, level pacing, upgrade caps and bias,
scoring, mastery, badges, shop transactions and immutability, save migration,
question selection, and the simulation: freezing during a checkpoint, correct vs
wrong rewards, boss gating, hearts/shield/revive order, pierce and multi-shot,
determinism, and a full winnable module.

`npm run test:dom` boots `index.html` in jsdom with a stub 2D context, then plays
a complete module through the actual buttons and modal, checking the render path
runs and that a wrong answer really pays nothing.

`npm run test:standalone` builds nothing — it opens `dist/CodePlay.html` the way a
phone does: as a classic inline script from a `file://` origin, with no module
loader and no server. It asserts the file has zero external references, then plays
a full module and exercises the wrong-answer path.

```bash
npm i                    # installs jsdom + esbuild (dev-only; the game itself has no deps)
```

## Art

Every sprite is hand-authored pixel data in `js/render/sprites.js` and baked to
canvas at integer scale, so the game ships with **zero image requests and no
external fonts**. The Kalinga background (Sleeping Beauty silhouette, three
parallax ridges, terraced paddies, drifting clouds) is generated from a seed and
quantised to 3px steps to match the sprite chunk.

Regenerate the PNG exports:

```bash
npm run assets      # assets/sprites/*.png + assets/data/questions.json (+ godot/)
```

To commission higher-fidelity art, these are the prompts the assets were designed
around:

```
A 2D pixel art background for a mobile game, featuring the Sleeping Beauty
mountain of Kalinga, Philippines. Lush green mountains, clear blue sky,
traditional Cordilleran landscape, modern high-quality 16-bit pixel art style,
parallax scrolling layers, vibrant colors, similar to Rayadillo game aesthetic
--ar 16:9 --niji 6

2D pixel art sprite sheet of a young indigenous Igorot warrior holding a wooden
spear, wearing traditional woven bahag, heroic stance. Modern 16-bit pixel art,
transparent background, character design for a mobile platformer game, clear
silhouette, vibrant colors --ar 1:1

2D pixel art of a dark cave bat carrying a glowing square technological box in
its claws. The box has green glowing code syntax on it. 16-bit retro game enemy
sprite, clean pixel art, transparent background --ar 1:1

2D pixel art mobile game UI for a shop menu. The shop is a traditional wooden
Igorot hut. UI elements showing character upgrades, spears, and traditional
clothing items. Pixelated buttons, clean layout, engaging educational game
interface --ar 9:16
```

## Godot build

`godot/` is the **whole game** in GDScript (Godot 4.2+), reading the same
`questions.json` and the same baked sprites — see `godot/README.md`. Open
`godot/project.godot` in the editor and press F5. The star file is
`scripts/CodePlayCheckpoint.gd`: collision → pause → question → upgrade.

```bash
npm run godot:test                          # 276 headless checks
npm run godot:export                        # build every export preset
npm run godot:export -- --preset Linux      # just one
node tools/godot-export.mjs --list          # show what is available
```

Desktop and web exports need only the Godot export templates installed once
(Editor → Manage Export Templates). The Android preset additionally needs the
Java and Android SDK paths set in Editor Settings.

## Design notes

* **Competence, not participation.** Points, upgrades and badges all require a
  correct answer. A wrong answer awards nothing but the explanation.
* **Never blocked.** Every question is answerable in a few seconds, and enemies
  are cleared regardless of the answer, so a beginner cannot get stuck.
* **Uncluttered on a phone.** One canvas at a fixed 360×640 logical resolution
  scaled up, three on-screen buttons, and all text in the DOM at real size.
* **Progressive difficulty.** Module 1 only asks difficulty 1–2 questions; the
  cap lifts at module 3, and unsolved questions are always preferred over repeats.
* **Respectful depiction.** The warrior, garments and landscape are drawn as
  Cordilleran rather than generic fantasy, and the shop names the real items
  (bahag, tapis, mountain blanket, elder headdress).
