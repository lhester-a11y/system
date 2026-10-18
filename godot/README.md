# CodePlay — Godot 4 build

The whole game, in GDScript. It reads the **same** `data/questions.json` and the
**same** baked pixel sprites as the web build, so a lesson is authored once and
plays identically in the browser and in Godot.

This is no longer just the checkpoint loop: the port covers the lobby and hero
select, the shop, badges, mastery tracking, the save file, the boss fight with
its projectile bugs, shields, revives and the parallax Kalinga background.

## Open it

Requires Godot **4.2 or newer** (standard build, GL Compatibility renderer).

1. Launch Godot → **Import** → pick `godot/project.godot` → **Import & Edit**.
2. Press **F5**.

Controls: ← → (or A/D) move, Space (or ↑, or W) throws the spear, Esc/P or the
`II` button on the HUD pauses, 1–4 answer a checkpoint, Enter continues, and the
`SFX` button on the HUD mutes the sound. On a phone, use the three on-screen
buttons.

The first launch opens **How to play** as a one-time gate; the flag lives in the
save, so it never interrupts a second time. Throwing is single: one press, one spear — holding the button down does
not keep firing, and nothing in the game fans the spear out. Jump straight into play by setting the main scene to `scenes/Main.tscn`,
which it already is.

## File map

| File | Role |
| --- | --- |
| `scripts/CodePlayCheckpoint.gd` | **The core loop.** Receives the absorbed code box, pauses the SceneTree, opens the question, grades the answer, grants the upgrade, releases the pause. |
| `scripts/Main.gd` | Owns the save file, routes the menu screens, spawns the waves and the boss, applies every answer to saved progress. |
| `scripts/Rules.gd` | Level pacing, the upgrade table, scoring, badges and the shop. Pure data, no scene access. |
| `scripts/Save.gd` | `user://codeplay-save.json`, with migration for old or hand-edited saves. |
| `scripts/QuestionBank.gd` | Autoload. Loads the question JSON, picks the next question and shuffles its choices. |
| `scripts/UpgradeSystem.gd` | Autoload. Upgrade levels, the weighted reward roll, and the derived numbers the player and enemies read. |
| `scripts/Bat.gd` / `Bug.gd` / `Spear.gd` / `Player.gd` | The fighters. Bats patrol, swoop and carry code boxes; the boss is only wounded by correct answers. |
| `scripts/Background.gd` | The animated landscape: sky bands, the Sleeping Beauty ridge, four ridges with rim light, stepped terraces, drifting clouds, twinkling stars, mist and the sun/moon with its halo. |
| `scripts/Ambient.gd` / `scripts/Popups.gd` | The motes a bought Effect item wraps around the warrior, and the floating world text ("CODE ABSORBED"). |
| `scripts/Sfx.gd` | Autoload. An eight-voice pool over `assets/sfx/*.wav`, with the mute flag coming from the save. |
| `assets/sfx/` | The eleven clips, baked by `tools/make-sfx.mjs` in the repo root (`npm run sfx`). |
| `scripts/Sprites.gd` / `scripts/Fx.gd` | Texture lookups and one-shot particle bursts. |
| `scripts/ui/*.gd` | Lobby, how-to-play, shop, progress and badges, review questions, pause, banner, HUD, toasts, quiz modal. |
| `tests/SelfTest.gd` | Headless verification of the rules, the save file and a full checkpoint. |

## The loop in four lines

```gdscript
# Bat.gd, when a spear overlaps
absorbed.emit(self, code_box)

# CodePlayCheckpoint.gd
get_tree().paused = true          # the whole world stops
checkpoint_opened.emit(question)  # the modal asks
upgrade = UpgradeSystem.grant(affinity)  # only reachable on a correct answer
```

## Sound

Godot has no Web Audio, so the browser port's procedural blips are rendered
offline into plain WAVs by `npm run sfx` and played through a small voice pool:

```gdscript
Sfx.play("absorb")   # unknown ids and a muted mix are silent no-ops
Sfx.set_enabled(false)
```

`tests/SelfTest.gd` checks every clip imported and really holds audio, because a
missing `.import` file would otherwise pass a "play() did not crash" test.

## Matching the web build

The web build draws its own controls in CSS: dark panels with a 3px `#5b6d8c`
border, square corners, a gold call to action. Godot's stock theme is a pale grey
rounded look, which made the port read as a different game. `UiKit.theme()` puts
the CSS numbers back and `Main` assigns it to the window, so every Button, Panel
and LineEdit in the project is themed at once.

## Three Godot gotchas worth knowing

**1. The pause freezes the UI too.** `get_tree().paused = true` stops `_process`
on every node that inherits the default pause mode — *including the buttons*.
Every screen and the quiz modal therefore opt out:

```gdscript
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
```

If a question ever appears but ignores clicks, that line is the fix.

**2. Sprites are baked at scale 8, drawn at 3.** `tools/export-sprites.mjs` in
the repo root bakes every sprite at 8×, while the web build draws at 3×, so a
`Sprite2D` wants `Sprites.SCALE` (0.375). The boss uses 0.75 because the web
draws it at 6×.

**3. Garment colours are baked, not tinted.** The web swaps three palette slots
while drawing; Godot renders the PNG as-is, so `tools/bake-hero-variants.py`
pre-bakes one file per hero and garment (`hero-boy-tapis.png`, …). Re-run it
after editing the sprite art:

```bash
python3 godot/tools/bake-hero-variants.py
```

## Save file

`user://codeplay-save.json` — the same schema as the web build's localStorage
blob, so points, badges, mastery, purchases and upgrades all survive a restart.
`Save.migrate()` fills in anything missing, clamps absurd values and repairs an
unknown hero. Delete the file to start over.

## Verify it

The self-test drives the real scene: it kills a bat through the signal path,
checks the world actually paused, answers a question, checks the points and the
upgrade landed in the save, takes a wrong answer, wounds the boss, clears the
module and reloads from disk. It also builds every screen and asserts that no
wrapping `Label` sits directly inside a row container, and that the lobby's name
label lays out on a single line.

That layout check exists because of a real bug: Godot gives an autowrapping
`Label` a minimum width of about one character, so an `HBoxContainer` hands it
almost no space and its text stacks one letter per line. The lobby's "Name"
label shipped as a vertical `N / a / m / e` column, and the same trap was lying
in wait for the HUD, the banner stat rows and the progress rows. Rows therefore
use non-wrapping labels (`UiKit.label(..., false)`).

```bash
godot --headless --path godot res://tests/SelfTest.tscn   # exit 0 = all green
```

It prints every check and exits non-zero on the first failure, so it works in CI.
Run the game itself without a window the same way:

```bash
godot --headless --path godot --quit-after 300
```

## Export it

Godot needs its export templates once: **Editor → Manage Export Templates →
Download and Install**, or drop the `.tpz` contents into
`~/.local/share/godot/export_templates/<version>/`.

```bash
npm run godot:export                        # every preset
npm run godot:export -- --preset Linux      # just one
node tools/godot-export.mjs --list          # show the presets
```

Outputs land in `godot/build/<platform>/` (git-ignored). `tests/*` is excluded
from every export.

| Preset | Output | State |
| --- | --- | --- |
| Web | `build/web/index.html` + `.wasm` + `.pck` | exported (35 MB wasm); not yet opened in a browser |
| Linux | `build/linux/codeplay.x86_64` + `.pck` | exported **and booted**: 48 questions loaded, no errors |
| Windows | `build/windows/codeplay.exe` + `.pck` | exported; not run (cross-built from Linux) |
| Android | `build/android/codeplay.apk` | blocked on the Java and Android SDK paths in Editor Settings |

## Differences from the web build

* **No emoji.** The default Godot theme font has none, so the web build's icon
  glyphs became short ASCII tags (`ATK`, `SHD`, `x3`) and hearts and progress
  pips are drawn as small colour blocks instead of characters.
* **Particles are simplified.** Hit bursts use `CPUParticles2D` rather than the
  canvas particle pool; there is no shop "effect" trail yet, though the items
  are still purchasable.
* **Layout is Godot Controls**, not DOM. The screens are built in code in
  `scripts/ui/`, so there are no `.tscn` files to re-wire by hand.
* Everything else — scoring, badges, mastery, shop perks, level pacing, the
  boss's fire rate, the shield and revive rules — mirrors `js/core/*.js`.
