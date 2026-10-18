extends Node
class_name CodePlayCheckpoint
## ---------------------------------------------------------------------------
## The CodePlay learning checkpoint - the foundational game loop.
##
## Flow:
##   1. A thrown spear overlaps a Bat                     (Bat.gd -> Spear hit)
##   2. Bat reports the code box it was carrying          (Bat.killed)
##   3. This controller PAUSES the whole scene tree       (get_tree().paused)
##   4. QuizUI shows the question and stays interactive because it runs with
##      PROCESS_MODE_ALWAYS
##   5. submit(index) grades the answer:
##        correct   -> points + UpgradeSystem.grant() hands out an upgrade
##        incorrect -> no points, no upgrade, explanation only
##   6. Main applies the result to the saved progress and Continue releases the
##      pause, so the fight resumes
## ---------------------------------------------------------------------------

signal checkpoint_opened(question: Dictionary, kind: String)
signal checkpoint_resolved(result: Dictionary)
signal checkpoint_closed()
signal upgrade_granted(upgrade: Dictionary)

## Pausing the SceneTree is what freezes the bats, the spears and the physics.
var pause_world: bool = true

var language: String = "html"
var cfg: Dictionary = {}
var kind: String = "bat"

var current_question: Dictionary = {}
## The most recently graded answer, kept so Main can act on it when the player
## presses Continue - by which point the question has been cleared.
var last_result: Dictionary = {}
var is_open: bool = false
var awaiting_answer: bool = false

var correct_answers: int = 0
var wrong_answers: int = 0
var streak: int = 0
var best_streak: int = 0
var perfect: bool = true

var _progress: Dictionary = {}
var _asked: Dictionary = {}
var _rng := RandomNumberGenerator.new()

## Main hands over the saved progress and the module config for this run.
func configure(progress: Dictionary, config: Dictionary, run_seed: int = 0) -> void:
    _progress = progress
    cfg = config
    language = String(config.get("lang", "html"))
    _rng.seed = run_seed if run_seed != 0 else Time.get_ticks_usec()

## Clear the per-module memory so a new module can ask solved questions again.
func reset_run() -> void:
    correct_answers = 0
    wrong_answers = 0
    streak = 0
    best_streak = 0
    perfect = true
    _asked.clear()

## Called the moment a code box is taken, or a spear reaches the boss.
func request_checkpoint(next_kind: String = "bat", _code_box: String = "") -> void:
    if is_open or current_question.is_empty() == false:
        return
    var question := QuestionBank.pick(_progress, language, cfg, _rng, _asked)
    if question.is_empty():
        push_error("CodePlay: no question available for '%s'" % language)
        return
    current_question = question
    _asked[String(question["id"])] = true
    kind = next_kind
    is_open = true
    awaiting_answer = true
    if pause_world:
        get_tree().paused = true
    checkpoint_opened.emit(current_question, kind)

## Grade an answer. `choice_index` indexes question["choices"], so a true/false
## question arrives here as 0 (True) or 1 (False).
func submit(choice_index: int) -> Dictionary:
    if not awaiting_answer:
        return {}
    awaiting_answer = false
    is_open = false

    var correct: bool = choice_index == int(current_question["answer"])
    var upgrade: Dictionary = {}
    var earned_points := 0

    if correct:
        correct_answers += 1
        streak += 1
        best_streak = maxi(best_streak, streak)
        earned_points = Rules.points_for_correct(
            int(current_question["difficulty"]), streak, UpgradeSystem.point_bonus()
        )
        upgrade = UpgradeSystem.grant(String(current_question.get("reward", "")))
        if not upgrade.is_empty():
            upgrade_granted.emit(upgrade)
    else:
        wrong_answers += 1
        streak = 0
        perfect = false

    # The world stays frozen while the player reads the explanation; close() is
    # what releases the pause once they press Continue.
    var result := {
        "question": current_question,
        "choice": choice_index,
        "correct": correct,
        "points": earned_points,
        "upgrade": upgrade,
        "streak": streak,
        "kind": kind,
    }
    last_result = result
    checkpoint_resolved.emit(result)
    return result

## Convenience for a true/false style question.
func submit_boolean(value: bool) -> Dictionary:
    return submit(0 if value else 1)

## Called when the player dismisses the feedback panel. Releases the pause.
func close() -> void:
    current_question = {}
    if pause_world:
        get_tree().paused = false
    checkpoint_closed.emit()

func holds_pause() -> bool:
    return is_open or awaiting_answer

func accuracy() -> int:
    var attempts := correct_answers + wrong_answers
    if attempts == 0:
        return 0
    return int(round(float(correct_answers) / float(attempts) * 100.0))

