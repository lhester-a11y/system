extends GameScreen
class_name HowToScreen
## The "how to play" screen from index.html.
##
## It doubles as the first-run tutorial: Main opens it in gate mode once, before
## the player has ever started a module, and writes progress["tutorialSeen"] when
## they dismiss it. After that the same screen stays reachable from the lobby,
## it just stops interrupting.

signal back_pressed()

var _intro: Label
var _back: Button

func build() -> void:
    add_title("How to play", "Everything the warrior needs to know.")

    _intro = UiKit.label("", 11, UiKit.GOLD)
    column.add_child(_intro)

    var lines := [
        "1. Move with the on-screen arrows, the arrow keys or A and D.",
        "2. THROW (or Space) sends one spear upward - one press, one spear.",
        "3. A spear that hits a bat absorbs the code box it carries.",
        "4. The world freezes and a checkpoint question opens.",
        "5. Answer correctly to earn points and a permanent buff.",
        "6. A wrong answer costs the buff, never a heart - read the explanation.",
        "7. Clear every checkpoint and the Syntax Overlord descends.",
        "8. Only correct answers wound the boss; finish it to unlock the next module.",
        "9. Bats that reach you cost a heart. Shields absorb the hit first.",
        "10. Buffs you have earned are never lost - a retry keeps every level.",
        "11. Press II (or Esc) to pause, and SFX to mute the sound.",
        "12. Points buy spears, garments and effects in the Shop.",
    ]
    for line in lines:
        column.add_child(UiKit.label(String(line), 12))

    column.add_child(UiKit.spacer(4))
    _back = UiKit.primary_button("Back", 15)
    _back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _back.pressed.connect(func() -> void: back_pressed.emit())
    column.add_child(_back)

## The first-run version: a short welcome and a button that reads like a start.
func open_as_gate() -> void:
    _intro.text = "First time here? Sixty seconds of reading is worth three hearts."
    _intro.visible = true
    _back.text = "Got it - let's play"
    open()

func open_as_reference() -> void:
    _intro.text = ""
    _intro.visible = false
    _back.text = "Back"
    open()
