extends Node
## CodePlay question bank (autoload) - the port of js/data/questions.js plus the
## picking rules from js/core/quiz.js.
##
## The questions live in the exact same res://data/questions.json the web build
## exports, so a lesson is authored once and plays identically in both.

const BANK_PATH := "res://data/questions.json"

var questions: Array = []

func _ready() -> void:
    _load_bank()

func _load_bank() -> void:
    if not FileAccess.file_exists(BANK_PATH):
        push_error("CodePlay: missing %s - run `npm run assets` in the repo root." % BANK_PATH)
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BANK_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("CodePlay: %s is not a JSON object." % BANK_PATH)
        return
    questions = (parsed as Dictionary).get("questions", [])
    print("CodePlay: loaded %d questions across %d languages" % [questions.size(), Rules.LANGUAGES.size()])

func questions_for(lang: String, max_difficulty: int = 3) -> Array:
    var out: Array = []
    for q in questions:
        if String(q["lang"]) == lang and int(q["difficulty"]) <= max_difficulty:
            out.append(q)
    return out

func difficulty_label(difficulty: int) -> String:
    match difficulty:
        1:
            return "Recall"
        2:
            return "Understand"
        _:
            return "Apply"

## Shuffle a question's choices so the right answer is not always the first one.
##
## Every question in data/questions.json is authored with its answer at index 0,
## which made the letter A correct almost every time. Served questions therefore
## leave here through this, and `answer` is rewritten to match.
##
## The copy matters: the bank itself stays in authoring order, so the review
## screen and the mastery counts never change under the player's feet.
static func shuffled(question: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    var out := question.duplicate(true)
    var choices: Array = out.get("choices", [])
    var count := choices.size()
    if count < 2:
        return out

    var order: Array = []
    for i in count:
        order.append(i)
    # Fisher-Yates, so every arrangement is equally likely.
    for i in range(count - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var swap: Variant = order[i]
        order[i] = order[j]
        order[j] = swap

    var answer := int(out.get("answer", 0))
    var shuffled_choices: Array = []
    var new_answer := 0
    for position in count:
        var source := int(order[position])
        shuffled_choices.append(choices[source])
        if source == answer:
            new_answer = position
    out["choices"] = shuffled_choices
    out["answer"] = new_answer
    return out

## Choose the next checkpoint question.
##
## Unanswered questions are weighted three times as heavily as ones the player
## already solved, and difficulty pulls towards the module's target level.
## `exclude` holds ids already asked in this run, so a module never repeats.
func pick(progress: Dictionary, lang: String, cfg: Dictionary, rng: RandomNumberGenerator, exclude: Dictionary) -> Dictionary:
    var all := questions_for(lang, int(cfg.get("max_difficulty", 3)))
    var answered: Dictionary = progress.get("answered", {})
    var target := mini(3, 1 + int((int(cfg.get("module", 1)) - 1) / 2.0))

    var pool: Array = []
    for q in all:
        if not exclude.has(String(q["id"])):
            pool.append(q)
    if pool.is_empty():
        # Easy questions are used up: widen to the harder ones before repeating.
        var wider: Array = []
        for q in questions_for(lang, 3):
            if not exclude.has(String(q["id"])):
                wider.append(q)
        pool = wider if not wider.is_empty() else all
    if pool.is_empty():
        push_error("CodePlay: no questions for language '%s'" % lang)
        return {}

    var weights: Array = []
    var total := 0.0
    for q in pool:
        var unsolved := not answered.has(String(q["id"]))
        var closeness := 1.0 / (1.0 + absi(int(q["difficulty"]) - target))
        var weight := (3.0 if unsolved else 1.0) * closeness
        weights.append(weight)
        total += weight
    if total <= 0.0:
        return shuffled(pool[0], rng)

    var chosen: Dictionary = pool[pool.size() - 1]
    var roll := rng.randf() * total
    for i in pool.size():
        roll -= float(weights[i])
        if roll <= 0.0:
            chosen = pool[i]
            break
    return shuffled(chosen, rng)

