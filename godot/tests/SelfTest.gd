extends Node
## Headless verification for the Godot port.
##
##   godot --headless --path godot res://tests/SelfTest.tscn
##
## It checks the rules layer, the save file, question picking, and then drives
## the real Main scene through a full checkpoint: bat killed -> world paused ->
## question -> graded answer -> progress saved -> boss wounded -> module cleared.
## Exit code 0 means every assertion held.

var failures: Array = []
var checks := 0
var rows_scanned := 0
var row_labels_scanned := 0

func _ready() -> void:
    await get_tree().process_frame
    _test_levels()
    _test_scoring()
    _test_upgrades()
    _test_shop()
    _test_badges()
    _test_save()
    _test_question_bank()
    _test_question_order()
    _test_theme()
    _test_sfx()
    await _test_background()
    await _test_review_screen()
    await _test_ui_layout()
    await _test_game_loop()
    _report()

func _check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("  ok   %s" % label)
    else:
        failures.append(label)
        print("  FAIL %s" % label)

func _eq(actual: Variant, expected: Variant, label: String) -> void:
    _check(str(actual) == str(expected), "%s (got %s, want %s)" % [label, str(actual), str(expected)])

# ------------------------------------------------------------------- the rules

func _test_levels() -> void:
    print("levels")
    var first := Rules.level_config(1)
    _eq(String(first["lang"]), "html", "module 1 is HTML")
    _eq(String(first["sky"]), "day", "module 1 sky is day")
    _eq(int(first["checkpoints"]), 5, "module 1 wants 5 checkpoints")
    _eq(int(first["max_difficulty"]), 2, "module 1 caps difficulty at 2")
    var seventh := Rules.level_config(7)
    _eq(String(seventh["lang"]), "html", "module 7 laps back to HTML")
    _eq(int(seventh["lap"]), 1, "module 7 is lap 1")
    _eq(int(seventh["max_difficulty"]), 3, "later modules allow difficulty 3")
    var ninth := Rules.level_config(9)
    _eq(String(ninth["lang"]), "js", "module 9 is JavaScript")
    _check(float(ninth["bat_speed"]) > float(first["bat_speed"]), "bats speed up with the module")
    _eq(int(Rules.level_config(6)["boss_hp"]), 5, "module 6 boss has 5 HP")

func _test_scoring() -> void:
    print("scoring")
    _eq(Rules.points_for_correct(1), 10, "difficulty 1 is worth 10")
    _eq(Rules.points_for_correct(2), 15, "difficulty 2 is worth 15")
    _eq(Rules.points_for_correct(3), 25, "difficulty 3 is worth 25")
    _eq(Rules.points_for_correct(1, 3), 15, "a 3 streak adds 5")
    _eq(Rules.points_for_correct(1, 5), 20, "a 5 streak adds 10")
    _eq(Rules.points_for_correct(1, 0, 1), 11, "the Gilded Spear adds a point")
    _eq(Rules.boss_points(3), 105, "boss points scale with the module")
    _eq(Rules.level_clear_points(3, false), 70, "clear bonus without a flawless run")
    _eq(Rules.level_clear_points(3, true), 120, "flawless run adds 50")

func _test_upgrades() -> void:
    print("upgrades")
    var empty := Rules.empty_upgrades()
    _eq(empty.size(), 5, "five upgrade families")
    for id in ["damage", "speed", "cooldown", "shield", "pierce"]:
        _check(empty.has(id), "empty_upgrades() has %s" % id)
    # Removed on purpose: throwing is single, so nothing may fan the spear out.
    _check(not empty.has("multishot"), "there is no triple throw family any more")

    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var levels := Rules.empty_upgrades()
    var seen := {}
    for i in 40:
        var id := Rules.choose_upgrade(rng, levels, "shield")
        if id == "":
            break
        seen[id] = true
        levels[id] = int(levels[id]) + 1
    _eq(seen.size(), 5, "the reward roll can reach every family")
    _eq(Rules.choose_upgrade(rng, levels, ""), "", "a maxed table grants nothing")

    var stats := Rules.stats_from_upgrades({"damage": 2, "speed": 1, "shield": 1, "pierce": 2}, {})
    _eq(int(stats["weaponDamage"]), 3, "+2 damage is 3 base damage")
    _eq(int(stats["pierce"]), 2, "piercing tip level 2")
    _check(not stats.has("multishot"), "no buffed stat can fan the spear out")
    _eq(int(stats["startShield"]), 1, "the shield upgrade grants a starting shield")

func _test_shop() -> void:
    print("shop")
    var progress := Save.default_progress()
    _eq((progress["owned"] as Array).size(), 3, "three free starting items")
    var bamboo := Rules.shop_item("spear-bamboo")
    _eq(int(bamboo["cost"]), 0, "the bamboo spear is free")

    var refused := Rules.buy_item(progress, "spear-gold")
    _check(not bool(refused["ok"]), "cannot buy without points")
    _eq(String(refused["reason"]), "Not enough points", "the refusal explains why")

    progress["points"] = 500
    var bought := Rules.buy_item(progress, "spear-gold")
    _check(bool(bought["ok"]), "buys the gilded spear with 500 points")
    progress = bought["progress"]
    _eq(int(progress["points"]), 200, "the price is deducted")
    _check((progress["owned"] as Array).has("spear-gold"), "the item is owned")
    _eq(int(Rules.perks_from(progress)["pointBonus"]), 1, "the perk applies")
    _check(not bool(Rules.buy_item(progress, "spear-gold")["ok"]), "cannot buy it twice")

    var equipped := Rules.equip_item(progress, "spear-gold")
    _check(bool(equipped["ok"]), "equips an owned item")
    progress = equipped["progress"]
    _eq(String((progress["equipped"] as Dictionary)["spear"]), "spear-gold", "the spear slot changed")
    _check(not bool(Rules.equip_item(progress, "garment-crown")["ok"]), "cannot equip what is not owned")

    progress["points"] = 900
    progress = Rules.buy_item(progress, "garment-blank")["progress"]
    var with_blanket := Rules.derived_stats(progress)
    _eq(int(with_blanket["maxHearts"]), 4, "the Mountain Blanket adds a heart")

func _test_badges() -> void:
    print("badges")
    _eq(Rules.badges().size(), 19, "seven milestones plus twelve language badges")
    var progress := Save.default_progress()
    # The three free starting items already count as "owning 3 items" in the web
    # build's badge rule, and this port keeps that behaviour identical.
    var opening_badges := Rules.new_badges(progress, [])
    _eq(opening_badges.size(), 1, "a fresh save qualifies only for the shop badge")
    _check(opening_badges.has("tradepost"), "the three free items count as owning three")

    progress["correct"] = 1
    _check(Rules.new_badges(progress, []).has("first-spear"), "1 correct answer earns First Spear")
    progress["bestStreak"] = 5
    _check(Rules.new_badges(progress, []).has("streak-5"), "a 5 streak earns Hot Streak")
    progress["bossesDefeated"] = 1
    _check(Rules.new_badges(progress, []).has("boss-slayer"), "beating a boss earns Boss Slayer")
    _eq(Rules.new_badges(progress, ["first-spear"]).has("first-spear"), false, "an owned badge is not re-awarded")

    for i in 3:
        progress["answered"]["html-0%d" % (i + 1)] = true
    _check(Rules.solved_ids(progress, "html").size() == 3, "solved ids are tracked per language")
    _eq(Rules.mastery_percent(progress, "html"), 38, "3 of 8 HTML questions rounds to 38 percent")

func _test_save() -> void:
    print("save file")
    var fresh := Save.default_progress()
    _eq(int(fresh["module"]), 1, "a new warrior starts at module 1")
    _eq(String(fresh["hero"]), "boy", "the default hero is the boy")

    fresh["points"] = 275
    fresh["module"] = 4
    fresh["badges"] = ["first-spear"]
    fresh["answered"]["css-01"] = true
    _check(Save.save_progress(fresh), "save_progress writes user://codeplay-save.json")
    var loaded := Save.load_progress()
    _eq(int(loaded["points"]), 275, "points survive a round trip")
    _eq(int(loaded["module"]), 4, "the module survives a round trip")
    _check((loaded["badges"] as Array).has("first-spear"), "badges survive a round trip")
    _check((loaded["answered"] as Dictionary).has("css-01"), "answered ids survive a round trip")

    var migrated := Save.migrate({"points": -50, "module": 9999, "hero": "dragon", "upgrades": {"damage": 2}})
    _eq(int(migrated["points"]), 0, "a negative point total is clamped")
    _eq(int(migrated["module"]), 120, "an absurd module is clamped")
    _eq(String(migrated["hero"]), "boy", "an unknown hero falls back to the boy")
    _eq(int((migrated["upgrades"] as Dictionary)["damage"]), 2, "saved upgrades are kept")
    _check(not Save.migrate(null).is_empty(), "a missing save migrates to a default")
    Save.reset_progress()

func _test_question_bank() -> void:
    print("question bank")
    _eq(QuestionBank.questions.size(), 48, "48 questions loaded from data/questions.json")
    _eq(QuestionBank.questions_for("html", 2).size(), 6, "6 HTML questions at difficulty 2 or below")
    _eq(QuestionBank.questions_for("html", 3).size(), 8, "difficulty 3 does not change the pool")
    _eq(QuestionBank.difficulty_label(1), "Recall", "difficulty 1 reads as Recall")
    _eq(QuestionBank.difficulty_label(3), "Apply", "difficulty 3 reads as Apply")

    for question in QuestionBank.questions:
        if (question["choices"] as Array).size() < 2:
            _check(false, "question %s has at least two choices" % String(question["id"]))
            return
        var answer := int(question["answer"])
        if answer < 0 or answer >= (question["choices"] as Array).size():
            _check(false, "question %s has a valid answer index" % String(question["id"]))
            return
    _check(true, "every question has a valid answer index")

    var rng := RandomNumberGenerator.new()
    rng.seed = 99
    var progress := Save.default_progress()
    var cfg := Rules.level_config(1)
    var asked := {}
    var seen := {}
    for i in 5:
        var question := QuestionBank.pick(progress, "html", cfg, rng, asked)
        _check(not question.is_empty(), "pick returns a question from the HTML pool")
        _eq(String(question["lang"]), "html", "the question belongs to the module language")
        _check(int(question["difficulty"]) <= 2, "module 1 never asks difficulty 3")
        _check(not seen.has(String(question["id"])), "a module does not repeat a question")
        seen[String(question["id"])] = true
        asked[String(question["id"])] = true
    _eq(seen.size(), 5, "five distinct questions for five checkpoints")

# --------------------------------------------------- answer order and screens

## Every question in the bank is authored with its answer at index 0, so the
## letter A used to be right almost every single time. Served questions must come
## out shuffled, with `answer` moved to match, and the bank itself untouched.
func _test_question_order() -> void:
    print("answer order")

    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    var sample := {
        "id": "sample", "lang": "html", "difficulty": 1, "kind": "mc",
        "prompt": "pick", "choices": ["first", "second", "third", "fourth"],
        "answer": 0, "explain": "",
    }
    var moved := 0
    var seen_letters := {}
    for i in 60:
        var shuffled_question := QuestionBank.shuffled(sample, rng)
        var choices: Array = shuffled_question["choices"]
        var answer := int(shuffled_question["answer"])
        seen_letters[answer] = true
        if String(choices[answer]) != "first":
            _check(false, "the shuffled answer still points at the right choice")
            return
        if choices.size() == 4 and choices.has("first") and choices.has("fourth"):
            moved += 1
        else:
            _check(false, "shuffling keeps every choice")
            return
    _check(true, "the shuffled answer still points at the right choice")
    _eq(moved, 60, "shuffling keeps every choice")
    _eq(seen_letters.size(), 4, "the right answer lands in every position over time")
    _eq(int((sample["choices"] as Array).find("first")), 0, "the source question is not mutated")
    _eq(int(sample["answer"]), 0, "the source answer index is not mutated")

    var progress := Save.default_progress()
    var cfg := Rules.level_config(3)
    var authored_first := 0
    for question in QuestionBank.questions:
        if int(question["answer"]) == 0:
            authored_first += 1
    _check(authored_first >= 40, "the authored bank really does keep the answer first (%d of %d)" % [
        authored_first, QuestionBank.questions.size(),
    ])

    var on_a := 0
    var correct := 0
    var picks := 0
    var served := RandomNumberGenerator.new()
    served.seed = 11
    for i in 30:
        var question := QuestionBank.pick(progress, "js", cfg, served, {})
        if question.is_empty():
            continue
        picks += 1
        if int(question["answer"]) == 0:
            on_a += 1
        var original: Dictionary = {}
        for candidate in QuestionBank.questions:
            if String(candidate["id"]) == String(question["id"]):
                original = candidate
                break
        var choices: Array = question["choices"]
        var answers: Array = original["choices"]
        if String(choices[int(question["answer"])]) == String(answers[int(original["answer"])]):
            correct += 1
    _eq(picks, 30, "thirty questions were served")
    _eq(correct, 30, "every served question still grades the right choice")
    _check(on_a <= 18, "the answer is not always A (%d of 30 landed on A)" % on_a)

## The port has to look like the web build, not like a stock Godot project.
func _test_theme() -> void:
    print("theme")
    var theme := UiKit.theme()
    var normal := theme.get_stylebox("normal", "Button") as StyleBoxFlat
    _check(normal != null and normal.bg_color == UiKit.BUTTON_BG,
        "buttons use the web build's dark slate instead of Godot's pale grey")
    _check(normal != null and normal.border_color == UiKit.LINE_2 and normal.border_width_top == 3,
        "buttons keep the CSS 3px #5b6d8c border")
    _check(normal != null and normal.corner_radius_top_left == 0, "buttons are square like the CSS")

    var primary := UiKit.primary_button("Start", 16)
    var gold := primary.get_theme_stylebox("normal") as StyleBoxFlat
    _check(gold != null and gold.bg_color == UiKit.PRIMARY_BG, "the call to action is the gold .btn-primary")
    _check(primary.get_theme_color("font_color") == UiKit.PRIMARY_FG, "gold buttons carry dark text")

    var pad := UiKit.pad_button("<", 20)
    _check((pad.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == UiKit.PAD_BG,
        "the movement pads are the .pad-btn slate")
    var throw_button := UiKit.pad_button("THROW", 13, true)
    _check((throw_button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == UiKit.PRIMARY_BG,
        "THROW is the gold .pad-throw")

    var filled := UiKit.heart(true)
    var empty := UiKit.heart(false)
    _check(filled.texture != null and filled.texture.get_width() == 22,
        "hearts are 11x9 pixel art at scale 2, not plain squares")
    _check(empty.texture != filled.texture, "an empty heart is its own dimmed art")

## The clips are baked by tools/make-sfx.mjs. A missing .import or a silent
## placeholder would pass a "play() did not crash" test, so check the stream
## itself has real audio in it.
func _test_sfx() -> void:
    print("sound")
    _eq(Sfx.voice_count(), 8, "eight voices, so blips can overlap")
    for id in ["throw", "hit", "absorb", "correct", "wrong", "hurt", "shield", "badge", "boss", "clear", "click"]:
        _check(Sfx.has_clip(String(id)), "the %s clip imported" % id)
    var total_seconds := 0.0
    for id in Sfx.clip_names():
        var stream := Sfx._streams[id] as AudioStreamWAV
        if stream == null:
            _check(false, "%s is an AudioStreamWAV" % id)
            continue
        _check(stream.get_length() > 0.02, "%s holds %.2fs of audio" % [id, stream.get_length()])
        total_seconds += stream.get_length()
    _check(total_seconds > 2.5, "the whole set is %.1fs of audio" % total_seconds)

    _check(Sfx.enabled, "sound is on by default")
    Sfx.set_enabled(false)
    Sfx.play("throw")
    _check(not Sfx.enabled, "a muted play() is a silent no-op")
    Sfx.set_enabled(true)
    Sfx.play("click")
    _check(Sfx.enabled, "re-enabling sound restores playback")

## The landscape is a port of js/render/background.js: if a layer is missing or
## nothing moves, the game stops looking like the web build.
func _test_background() -> void:
    print("background")
    var host := Node.new()
    add_child(host)
    var sky := Background.new()
    host.add_child(sky)
    var walker := Node2D.new()
    walker.position = Vector2(Rules.WORLD_W / 2.0, Rules.GROUND_Y)
    host.add_child(walker)
    sky.set_target(walker)
    await get_tree().process_frame

    var day: Dictionary = sky.snapshot()
    _eq(int(day["bands"]), 6, "six sky bands")
    _eq(int(day["ridges"]), 5, "the Sleeping Beauty silhouette plus four ridges")
    _eq(int(day["rim_lights"]), 2, "the two nearest ridges carry a rim light")
    _eq(int(day["terraces"]), 9, "nine stepped terrace rows")
    _eq(int(day["paddies"]), 7, "seven flooded paddies")
    _eq(int(day["clouds"]), 4, "four drifting clouds")
    _eq(int(day["cloud_puffs"]), 12, "each cloud is three stacked bars")
    _eq(int(day["mist"]), 3, "three mist bands")
    _eq(int(day["stars"]), 46, "46 stars")
    _eq(int(day["stars_visible"]), 0, "daylight hides the stars")
    _check(day["band_first"] == Color("#4e9fd8"), "the day sky starts on #4e9fd8")
    _check(int(day["orb_pixels"]) > 40, "the sun is drawn from pixel squares (%d)" % int(day["orb_pixels"]))

    # Nothing may stand still while the player plays.
    var before: Dictionary = sky.snapshot()
    sky._process(1.0)
    var later: Dictionary = sky.snapshot()
    _check(float(later["cloud_x"]) != float(before["cloud_x"]),
        "clouds drift (%.1f -> %.1f)" % [before["cloud_x"], later["cloud_x"]])
    _check(float(later["star_alpha"]) != float(before["star_alpha"]), "the stars twinkle")

    # The mist steps in 3px quantised jumps like the web build, so give it time to
    # cross a boundary before deciding it is standing still.
    var mist_start := float(before["mist_y"])
    var mist_breathed := false
    for i in 12:
        sky._process(0.5)
        if float(sky.snapshot()["mist_y"]) != mist_start:
            mist_breathed = true
            break
    _check(mist_breathed, "the mist breathes")

    var halo_blinked := false
    for i in 40:
        sky._process(0.25)
        if int(sky.snapshot()["halos_visible"]) < 5:
            halo_blinked = true
            break
    _check(halo_blinked, "the sun's halo shimmers")

    var left := float(sky.snapshot()["terrace_x"])
    walker.position.x = Rules.WORLD_W
    sky._process(0.25)
    var right := float(sky.snapshot()["terrace_x"])
    _check(right < left, "walking right slides the terraces the other way (%.1f -> %.1f)" % [left, right])

    sky.set_sky("night", 7919)
    var night: Dictionary = sky.snapshot()
    _eq(int(night["stars_visible"]), 46, "night shows every star")
    _check(night["band_first"] == Color("#04081a"), "rolling into night retints the sky")
    _check(absf((night["orb"] as Vector2).x - 282.0) < 0.01, "the moon hangs at x=282")
    sky.set_sky("sunset", 3)
    var dusk: Dictionary = sky.snapshot()
    _check(absf((dusk["orb"] as Vector2).y - 244.0) < 0.01, "the setting sun drops to y=244")
    _eq(int(dusk["stars_visible"]), 0, "sunset hides the stars again")
    host.free()

## The study screen: every question, the answer, and the reason.
func _test_review_screen() -> void:
    print("review screen")
    var host := Node.new()
    add_child(host)
    var review := ReviewScreen.new()
    host.add_child(review)

    var progress := Save.default_progress()
    review.render(progress)
    review.open()
    await get_tree().process_frame

    var lessons := QuestionBank.questions_for("html", 3)
    _eq(lessons.size(), 8, "HTML offers eight checkpoints to review")
    var texts := _collect_label_texts(review)
    var listed := 0
    for question in lessons:
        if texts.has(String(question["prompt"]).replace("__BLANK__", "____")):
            listed += 1
    _eq(listed, lessons.size(), "every question of the module is listed")

    var first: Dictionary = lessons[0]
    var marked := "[x]  %s" % String((first["choices"] as Array)[int(first["answer"])])
    _check(texts.has(marked), "the right choice is marked: %s" % marked)
    _check(texts.has(String(first.get("explain", ""))), "the explanation is shown")
    _eq(_count_prefix(texts, "[x]  "), lessons.size(), "exactly one choice per question is marked")

    # A solved checkpoint gets ticked, so the screen doubles as a study list.
    var studied := Save.default_progress()
    (studied["answered"] as Dictionary)[String(first["id"])] = true
    review.render(studied)
    await get_tree().process_frame
    _eq(_count_exact(_collect_label_texts(review), "[x]"), 1, "an answered question is ticked")

    review._select("js")
    await get_tree().process_frame
    var js_texts := _collect_label_texts(review)
    var js_listed := 0
    for question in QuestionBank.questions_for("js", 3):
        if js_texts.has(String(question["prompt"]).replace("__BLANK__", "____")):
            js_listed += 1
    _eq(js_listed, 8, "switching language swaps the list")
    host.free()

func _collect_label_texts(node: Node, out: Array = []) -> Array:
    var label := node as Label
    if label != null:
        out.append(label.text)
    for child in node.get_children():
        _collect_label_texts(child, out)
    return out

func _count_prefix(texts: Array, prefix: String) -> int:
    var count := 0
    for text in texts:
        if String(text).begins_with(prefix):
            count += 1
    return count

func _count_exact(texts: Array, wanted: String) -> int:
    var count := 0
    for text in texts:
        if String(text) == wanted:
            count += 1
    return count

# ----------------------------------------------------------- the UI layout

## Godot sizes an autowrapping Label to about one character of minimum width, so
## an HBoxContainer hands it almost no space and its text stacks one letter per
## line. That is exactly what turned the lobby's "Name" label into a vertical
## "N / a / m / e" column, and the HUD and banner rows had the same latent bug.
## Rows are therefore required to use non-wrapping labels.
func _scan_autowrap_in_rows(node: Node, offenders: Array) -> void:
    if node is HBoxContainer:
        rows_scanned += 1
        for child in node.get_children():
            var label := child as Label
            if label != null:
                row_labels_scanned += 1
                if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
                    var segments := String(label.get_path()).split("/")
                    offenders.append("\"%s\" inside %s" % [
                        label.text, segments[segments.size() - 2]
                    ])
    for child in node.get_children():
        _scan_autowrap_in_rows(child, offenders)

func _test_ui_layout() -> void:
    print("ui layout")
    var host := Node.new()
    add_child(host)

    var lobby := LobbyScreen.new()
    var shop := ShopScreen.new()
    var progress_screen := ProgressScreen.new()
    var pause := PauseScreen.new()
    var banner := BannerPanel.new()
    var quiz := QuizUI.new()
    var review := ReviewScreen.new()
    var howto := HowToScreen.new()
    var hud := GameHUD.new()
    var toast := ToastStack.new()
    var screens: Array[Node] = [
        lobby, shop, progress_screen, pause, howto,
        review, banner, quiz, hud, toast,
    ]
    for screen in screens:
        host.add_child(screen)
    howto.open_as_gate()
    _check(howto._back.text.begins_with("Got it"), "the first-run how-to reads like a start button")

    # The shop, progress and banner rows are built lazily when they are rendered,
    # so drive them here - otherwise the scan would never see those rows and the
    # check would pass without testing anything.
    var progress := Save.default_progress()
    lobby.render(progress)
    shop.render(progress)
    progress_screen.render(progress)
    progress_screen.open()
    review.render(progress)
    pause.render({"module": 2, "lang_name": "CSS", "cleared": 3, "total": 5, "streak": 4, "points": 120})
    banner.show_banner({
        "title": "Module cleared",
        "body": "The Syntax Overlord falls and the next module opens.",
        "stats": [["Checkpoints cleared", "5/5"], ["Points earned", "120"]],
        "primary": "Continue",
    })
    var question: Dictionary = QuestionBank.questions[0]
    quiz.show_question(question, "Checkpoint", "+10")
    quiz.show_result({
        "question": question,
        "choice": int(question["answer"]),
        "correct": true,
        "upgrade": {"id": "damage", "name": "Sharpened Tip", "level": 1, "description": "+1 damage"},
        "points": 10,
        "streak": 1,
    })

    hud.refresh({
        "hearts": 4, "max_hearts": 5, "shield": 2, "module": 5, "lang_name": "Java",
        "points": 1240, "run_points": 135, "streak": 9, "cleared": 5, "total": 7,
        "boss": true, "boss_hp": 4, "boss_max_hp": 5, "mastery": 62,
        "chips": ["Sharpened Spear Lv3", "Swift Feet Lv2", "Anito Shield Lv3", "Piercing Tip Lv2"],
    })

    await get_tree().process_frame
    await get_tree().process_frame

    var offenders: Array = []
    rows_scanned = 0
    row_labels_scanned = 0
    _scan_autowrap_in_rows(host, offenders)

    # Guard against the scan quietly going vacuous if the UI is restructured.
    _check(rows_scanned >= 8, "the scan reached %d row containers" % rows_scanned)
    _check(row_labels_scanned >= 12, "the scan reached %d labels inside rows" % row_labels_scanned)
    _eq(offenders.size(), 0, "no autowrapping Label is a direct child of an HBoxContainer%s" % (
        "" if offenders.is_empty() else " - offenders: %s" % ", ".join(PackedStringArray(offenders))
    ))

    # The badges-are-broken report: a GridContainer/VBox gives an autowrapping
    # label one character of width unless the card itself has a floor. Check the
    # laid-out widths, not just the tree shapes.
    var badge_cards: Array = progress_screen._badges.get_children()
    _check(badge_cards.size() >= 6, "the badge case rendered %d cards" % badge_cards.size())
    var narrowest_badge := 9999.0
    for card in badge_cards:
        narrowest_badge = minf(narrowest_badge, (card as Control).size.x)
    _check(narrowest_badge >= 240.0, "no badge card collapsed (narrowest %.0fpx)" % narrowest_badge)

    var stat_cards: Array = progress_screen._summary.get_children()
    _check(stat_cards.size() >= 8, "the stat grid rendered %d cards" % stat_cards.size())
    var narrowest_stat := 9999.0
    for card in stat_cards:
        narrowest_stat = minf(narrowest_stat, (card as Control).size.x)
    _check(narrowest_stat >= 120.0, "no stat card collapsed (narrowest %.0fpx)" % narrowest_stat)
    _eq(progress_screen._summary.columns, 2, "the stat grid is two columns wide")

    # The toast strip follows the HUD instead of a hardcoded y; that overlap is
    # what hid the buff chips after a respawn.
    toast.place_below(hud.content_bottom() + 8.0)
    _check(toast.top_y() >= hud.content_bottom() + 6.0,
        "toasts sit below the readout (%.0f vs hud %.0f)" % [toast.top_y(), hud.content_bottom()])
    _check(ToastStack.TOP >= 140.0, "the toast strip starts below the HUD (y=%.0f)" % ToastStack.TOP)
    _check(hud.pause_button() != null and hud.pause_button().visible, "the HUD pause button is built")
    _check(hud.sound_button() != null and hud.sound_button().visible, "the HUD sound button is built")
    _check(hud._buffs_flow.get_child_count() == 4, "every buff chip is laid out in the HUD")
    host.free()

# ----------------------------------------------------------- the game itself

func _test_game_loop() -> void:
    print("game loop")
    Save.reset_progress()
    var main = load("res://scenes/Main.tscn").instantiate()
    add_child(main)
    await get_tree().process_frame
    await get_tree().process_frame

    _eq(main.mode, CodePlayMain.Mode.LOBBY, "boots into the lobby")
    # The tutorial is a one-time gate: it interrupts the very first boot only.
    _check(main.howto.visible, "a first run opens the how-to tutorial")
    _check(not main.lobby.visible, "the tutorial covers the lobby")
    main._on_howto_back()
    await get_tree().process_frame
    _check(bool(main.progress["tutorialSeen"]), "dismissing the tutorial records it in the save")
    _check(main.lobby.visible, "the lobby is on screen once the tutorial is closed")
    _check(not main.howto.visible, "the tutorial closes")
    _check(not main.hud.visible, "the HUD is hidden in the lobby")

    main.start_module(1)
    await get_tree().process_frame
    _eq(main.mode, CodePlayMain.Mode.PLAY, "start_module() enters play")
    _eq(main.progress["module"], 1, "the module is recorded in the save")
    _eq(main.player.hearts, main.player.max_hearts, "the warrior starts on full hearts")

    # The reported symptom, checked against real laid-out pixels: the lobby's
    # "Name" label must occupy one line, not one character per line.
    var name_label := main.lobby.find_child("NameLabel", true, false) as Label
    _check(name_label != null, "the lobby name label is in the tree")
    if name_label != null:
        var font := name_label.get_theme_font("font")
        var line_height := 0.0 if font == null else font.get_height(name_label.get_theme_font_size("font_size"))
        _check(name_label.size.y > 0.0 and name_label.size.y <= line_height * 1.5,
            "the lobby name label renders on a single line (h=%.1f, line=%.1f)" % [name_label.size.y, line_height])
    _check(main.player.visible, "the warrior is visible")
    _check(main.hud.visible, "the HUD is visible in play")

    # The pause button is back on the HUD, and it drives the same pause as Esc.
    _check(main.hud.pause_button() != null and main.hud.pause_button().visible,
        "the HUD carries an on-screen pause button")
    main.hud.pause_button().pressed.emit()
    await get_tree().process_frame
    _check(get_tree().paused, "the pause button pauses the world")
    _check(main.pause_screen.visible, "the pause card opens from the HUD button")
    main._on_resume()
    await get_tree().process_frame
    _check(main.mode == CodePlayMain.Mode.PLAY and not get_tree().paused, "Resume returns to play")

    # The sound toggle is on the HUD too, and its choice goes into the save.
    _check(Sfx.enabled, "sound starts switched on")
    main._on_sound_toggled()
    await get_tree().process_frame
    _check(not Sfx.enabled, "the SFX button mutes the game")
    _eq(main.hud.sound_button().text, "MUTE", "the HUD shows the muted state")
    _check(not bool(main.progress["sound"]), "the mute is written to the save")
    main._on_sound_toggled()
    await get_tree().process_frame
    _check(Sfx.enabled and bool(main.progress["sound"]), "the SFX button unmutes again")

    _check(main.player.throw_spear(), "throw_spear() fires")
    _check(not main.player.throw_spear(), "the throw cooldown is respected")

    # Single shot: one press, one spear. Holding the control down must not keep
    # firing, whatever the cooldown would have allowed.
    main.player.hold_throw = true
    main.player._cooldown = 0.0
    main.player._process(0.7)
    var fired := _spear_count(main)
    _check(fired >= 1, "pressing THROW sends a spear")
    main.player._cooldown = 0.0
    main.player._process(0.7)
    _eq(_spear_count(main), fired, "holding THROW does not keep firing")
    main.player.hold_throw = false
    main.player._process(0.016)
    main.player._cooldown = 0.0
    main.player.hold_throw = true
    main.player._process(0.7)
    _eq(_spear_count(main), fired + 1, "release and press again sends exactly one more")
    main.player.hold_throw = false
    main.player._process(0.016)

    # A bat killed through the real signal path opens a checkpoint.
    main.spawn_bat()
    await get_tree().process_frame
    var bat := _first_bat(main)
    _check(bat != null, "spawn_bat() added a bat to the world")
    _eq(bat.code_box, "HTML", "the bat carries the module's code box")

    var before_points := int(main.progress["points"])
    bat.apply_damage(1)
    await get_tree().process_frame
    _check(bat.solved, "one spear thrust kills a bat")
    _eq(main.kills, 1, "the kill is counted")
    _check(get_tree().paused, "the world is paused by the checkpoint")
    _check(main.quiz.is_open(), "the question modal is up")
    _eq(main.mode, CodePlayMain.Mode.QUIZ, "the game is in quiz mode")
    _check(not main.checkpoint.current_question.is_empty(), "a question was picked")
    _check(main.checkpoint.current_question.has("prompt"), "the question has a prompt")

    var question: Dictionary = main.checkpoint.current_question
    var result: Dictionary = main.checkpoint.submit(int(question["answer"]))
    await get_tree().process_frame
    _check(bool(result["correct"]), "the right answer grades as correct")
    _check(int(result["points"]) > 0, "the right answer is worth points")
    _eq(int(main.progress["correct"]), 1, "the correct answer is saved")
    _eq(int(main.progress["points"]), before_points + int(result["points"]), "the points are saved")
    _check((main.progress["answered"] as Dictionary).has(String(question["id"])), "the question is marked answered")
    _eq(int(main.progress["bestStreak"]), 1, "the streak is tracked")
    _check(not (result["upgrade"] as Dictionary).is_empty(), "a correct answer grants an upgrade")
    var upgrade: Dictionary = result["upgrade"]
    _eq(int((main.progress["upgrades"] as Dictionary)[String(upgrade["id"])]), int(upgrade["level"]), "the upgrade is saved")

    main._on_quiz_continue()
    await get_tree().process_frame
    _check(not get_tree().paused, "Continue releases the pause")
    _eq(main.mode, CodePlayMain.Mode.PLAY, "Continue returns to play")
    _check(not main.quiz.is_open(), "the modal is dismissed")

    # A wrong answer costs the upgrade but never a heart.
    var hearts_before: int = main.player.hearts
    var points_before := int(main.progress["points"])
    main.checkpoint.request_checkpoint("bat", "HTML")
    await get_tree().process_frame
    var wrong_question: Dictionary = main.checkpoint.current_question
    var wrong_index := (int(wrong_question["answer"]) + 1) % (wrong_question["choices"] as Array).size()
    var wrong_result: Dictionary = main.checkpoint.submit(wrong_index)
    await get_tree().process_frame
    _check(not bool(wrong_result["correct"]), "the wrong answer grades as incorrect")
    _eq(int(wrong_result["points"]), 0, "a wrong answer earns nothing")
    _check((wrong_result["upgrade"] as Dictionary).is_empty(), "a wrong answer grants no upgrade")
    _eq(int(main.progress["wrong"]), 1, "the miss is saved")
    _eq(int(main.progress["points"]), points_before, "the point total is untouched")
    _eq(main.player.hearts, hearts_before, "a wrong answer never costs a heart")
    _eq(main.checkpoint.streak, 0, "the streak resets")
    _check(not main.checkpoint.perfect, "the flawless run is over")
    main._on_quiz_continue()
    await get_tree().process_frame

    # Dying must not wipe what the player earned: the buff levels, the rebuilt
    # hearts and the HUD chips all come back on the retry.
    var kept_id := String(upgrade["id"])
    var kept_level := UpgradeSystem.level_of(kept_id)
    _check(kept_level > 0, "a buff was earned earlier in the run")
    main.player.hearts = 1
    main.player.shield = 0
    main.player.invulnerable = 0.0
    main.player.take_hit()
    await get_tree().process_frame
    _eq(main.mode, CodePlayMain.Mode.BANNER, "the last heart ends the run")
    _check(main.banner.is_open(), "the game-over banner is up")
    main._on_banner_primary()
    await get_tree().process_frame
    _eq(main.mode, CodePlayMain.Mode.PLAY, "Retry restarts the module")
    _eq(UpgradeSystem.level_of(kept_id), kept_level, "the buff level survives death")
    _eq(int((main.progress["upgrades"] as Dictionary)[kept_id]), kept_level, "the saved buff survives death")
    _eq(main.player.max_hearts, UpgradeSystem.max_hearts(), "max hearts are rebuilt from the kept buffs")
    _check((main._hud_data()["chips"] as Array).size() > 0, "the HUD still lists the kept buffs")

    # Every checkpoint cleared -> the boss arrives.
    main.kills = int(main.cfg["checkpoints"])
    main._update_spawning(2.0)
    await get_tree().process_frame
    main._update_spawning(2.0)
    await get_tree().process_frame
    _check(main.boss != null, "clearing the checkpoints summons the boss")
    _check(main.boss.is_boss, "the boss knows it is the boss")
    _eq(main.boss.max_hp, int(main.cfg["boss_hp"]), "the boss uses the module's HP")
    var boss_hp: int = main.boss.hp

    main._on_boss_engaged(main.boss)
    await get_tree().process_frame
    _check(get_tree().paused, "a spear reaching the boss pauses the world")
    _eq(main.checkpoint.kind, "boss", "the checkpoint knows it is a boss question")
    var boss_question: Dictionary = main.checkpoint.current_question
    main.checkpoint.submit(int(boss_question["answer"]))
    await get_tree().process_frame
    main._on_quiz_continue()
    await get_tree().process_frame
    _check(main.boss != null and main.boss.hp == boss_hp - 1, "a correct answer wounds the boss")

    main.kills = int(main.cfg["checkpoints"])
    main.boss.hp = 1
    main._on_boss_engaged(main.boss)
    await get_tree().process_frame
    var last_question: Dictionary = main.checkpoint.current_question
    main.checkpoint.submit(int(last_question["answer"]))
    await get_tree().process_frame
    main._on_quiz_continue()
    await get_tree().process_frame
    _eq(main.mode, CodePlayMain.Mode.BANNER, "beating the boss shows the banner")
    _check(main.banner.is_open(), "the banner is up")
    _eq(int(main.progress["modulesCleared"]), 1, "the module is recorded as cleared")
    _eq(int(main.progress["bossesDefeated"]), 1, "the boss defeat is saved")
    _eq(int(main.progress["module"]), 2, "the save advances to module 2")
    _check((main.progress["badges"] as Array).has("boss-slayer"), "the boss badge is awarded")
    _check(int(main.progress["points"]) > 100, "the clear bonus lands")

    # The paused tree keeps the modal interactive; the pause menu uses the same trick.
    main._on_banner_primary()
    await get_tree().process_frame
    _eq(int(main.progress["module"]), 2, "the banner starts the next module")
    _eq(String(main.cfg["lang"]), "css", "module 2 teaches CSS")
    _eq(main.mode, CodePlayMain.Mode.PLAY, "back in play on module 2")

    main._set_paused(true)
    await get_tree().process_frame
    _check(get_tree().paused, "the pause menu pauses the world")
    _check(main.pause_screen.visible, "the pause card is up")
    main._set_paused(false)
    await get_tree().process_frame
    _check(not get_tree().paused, "Resume unpauses")

    main.to_lobby()
    await get_tree().process_frame
    _eq(main.mode, CodePlayMain.Mode.LOBBY, "quit returns to the lobby")
    _check(main.lobby.visible, "the lobby is back")

    # The study screen hangs off the lobby, and Back returns there.
    main._open_review()
    await get_tree().process_frame
    _check(main.review_screen.visible, "the lobby opens the review screen")
    _check(not main.lobby.visible, "the lobby steps aside for it")
    main.review_screen.back_pressed.emit()
    await get_tree().process_frame
    _check(main.lobby.visible, "Back returns to the lobby")
    _check(not main.review_screen.visible, "the review screen closes")

    # Reopening the game must read the same progress back off disk.
    var reloaded := Save.load_progress()
    _eq(int(reloaded["points"]), int(main.progress["points"]), "the session was saved to disk")
    _eq(int(reloaded["module"]), 2, "the saved module survives a reload")
    _check(bool(reloaded["tutorialSeen"]), "the tutorial flag survives a reload")
    _check(bool(reloaded["sound"]), "the sound setting survives a reload")

    main.queue_free()
    await get_tree().process_frame

    # A second boot must not show the tutorial again.
    var second = load("res://scenes/Main.tscn").instantiate()
    add_child(second)
    await get_tree().process_frame
    await get_tree().process_frame
    _check(not second.howto.visible, "the tutorial does not reopen on the next boot")
    _check(second.lobby.visible, "the next boot goes straight to the lobby")
    second.queue_free()
    await get_tree().process_frame

func _spear_count(main: Node) -> int:
    var count := 0
    for child in main.get_children():
        if child is Spear:
            count += 1
    return count

func _first_bat(main: Node) -> Bat:
    for child in main.get_children():
        if child is Bat:
            return child
    return null

func _report() -> void:
    print("")
    if failures.is_empty():
        print("SELFTEST PASS - %d checks" % checks)
        get_tree().quit(0)
        return
    print("SELFTEST FAIL - %d of %d checks failed" % [failures.size(), checks])
    for failure in failures:
        print("  - %s" % failure)
    get_tree().quit(1)
