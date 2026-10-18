extends Node
## CodePlay rules layer - the GDScript port of js/core/rules.js.
##
## Pure data and helpers: level pacing, the upgrade table, scoring, badges and
## the shop. Nothing here touches the scene tree, so every function is directly
## testable from a headless self-test.

const START_HEARTS := 3
const HEART_CAP := 5

# ---------------------------------------------------------------- world geometry
# Mirrors WORLD in js/core/simulation.js.

const WORLD_W := 360.0
const WORLD_H := 640.0
const ART_SCALE := 3.0          ## sprite pixels are baked at scale 8, see scale_for()
const GROUND_Y := 566.0
const PLAYER_MIN_X := 26.0
const PLAYER_MAX_X := 334.0

const PLAYER_SIZE := Vector2(26, 46)
const BAT_SIZE := Vector2(38, 24)
const BOSS_SIZE := Vector2(84, 58)
const BUG_SIZE := Vector2(12, 12)
const SPEAR_SIZE := Vector2(6, 34)

# ------------------------------------------------------------------- languages
# Same six languages, colours, skies and blurbs as js/data/questions.js.

const LANGUAGES := [
    {"id": "html", "name": "HTML", "label": "HTML", "color": "#ef6a5a", "module": 1, "sky": "day", "blurb": "Structure of the web"},
    {"id": "css", "name": "CSS", "label": "CSS", "color": "#6bb8ff", "module": 2, "sky": "day", "blurb": "Styling and layout"},
    {"id": "js", "name": "JavaScript", "label": "JS", "color": "#f2c14e", "module": 3, "sky": "sunset", "blurb": "Behaviour in the browser"},
    {"id": "python", "name": "Python", "label": "Python", "color": "#5fe08a", "module": 4, "sky": "sunset", "blurb": "Readable general-purpose code"},
    {"id": "java", "name": "Java", "label": "Java", "color": "#b98bff", "module": 5, "sky": "night", "blurb": "Strict, typed, everywhere"},
    {"id": "cpp", "name": "C++", "label": "C++", "color": "#7ee3e3", "module": 6, "sky": "night", "blurb": "Close to the metal"},
]

# -------------------------------------------------------------------- upgrades
# `icon` is a short ASCII tag: the default Godot theme font has no emoji, so the
# web build's picture icons become readable letters here.
#
# There is deliberately no Triple Throw here: throwing is single - one press,
# one spear - so a fan of three was the one buff that had to go.

const UPGRADES := [
    {"id": "damage", "icon": "ATK", "name": "Sharpened Spear", "max": 3},
    {"id": "speed", "icon": "SPD", "name": "Swift Feet", "max": 3},
    {"id": "cooldown", "icon": "CD", "name": "Quick Hands", "max": 3},
    {"id": "shield", "icon": "SHD", "name": "Anito Shield", "max": 3},
    {"id": "pierce", "icon": "PRC", "name": "Piercing Tip", "max": 2},
]

# ------------------------------------------------------------------------ shop

const SHOP_CATEGORIES := [
    {"id": "spear", "name": "Spears", "slot": "spear"},
    {"id": "garment", "name": "Garments", "slot": "garment"},
    {"id": "effect", "name": "Effects", "slot": "effect"},
]

const SHOP_ITEMS := [
    {"id": "spear-bamboo", "cat": "spear", "name": "Bamboo Spear", "cost": 0, "free": true, "perk": "", "value": 0.0, "desc": "A spear cut from the groves below the terraces.", "perk_text": ""},
    {"id": "spear-iron", "cat": "spear", "name": "Iron Spear", "cost": 120, "free": false, "perk": "spearSpeed", "value": 0.1, "desc": "Trade-wrought iron head.", "perk_text": "+10% spear speed"},
    {"id": "spear-gold", "cat": "spear", "name": "Gilded Spear", "cost": 300, "free": false, "perk": "pointBonus", "value": 1.0, "desc": "Blessed by the elders of the village.", "perk_text": "+1 point per correct answer"},
    {"id": "spear-crystal", "cat": "spear", "name": "Crystal Spear", "cost": 650, "free": false, "perk": "startShield", "value": 1.0, "desc": "Carved from a cold mountain spring.", "perk_text": "Start every module with a shield"},
    {"id": "garment-bahag", "cat": "garment", "name": "Woven Bahag", "cost": 0, "free": true, "perk": "", "value": 0.0, "desc": "Traditional loincloth of the Cordillera.", "perk_text": ""},
    {"id": "garment-tapis", "cat": "garment", "name": "Embroidered Tapis", "cost": 160, "free": false, "perk": "moveSpeed", "value": 0.05, "desc": "Layered wrap with geometric patterns.", "perk_text": "+5% move speed"},
    {"id": "garment-blank", "cat": "garment", "name": "Mountain Blanket", "cost": 340, "free": false, "perk": "maxHearts", "value": 1.0, "desc": "Thick weave against the cold.", "perk_text": "+1 maximum heart"},
    {"id": "garment-crown", "cat": "garment", "name": "Elder Headdress", "cost": 520, "free": false, "perk": "revive", "value": 1.0, "desc": "Hornbill feathers of the respected.", "perk_text": "Survive one fatal hit per module"},
    {"id": "effect-none", "cat": "effect", "name": "No Effect", "cost": 0, "free": true, "perk": "", "value": 0.0, "desc": "Clean and simple.", "perk_text": ""},
    {"id": "effect-fly", "cat": "effect", "name": "Fireflies", "cost": 90, "free": false, "perk": "", "value": 0.0, "desc": "Alagaw fireflies trail your spear.", "perk_text": ""},
    {"id": "effect-ember", "cat": "effect", "name": "Ember Trail", "cost": 210, "free": false, "perk": "", "value": 0.0, "desc": "Glowing embers drift behind you.", "perk_text": ""},
    {"id": "effect-leaf", "cat": "effect", "name": "Leaf Swirl", "cost": 380, "free": false, "perk": "", "value": 0.0, "desc": "Falling leaves circle the warrior.", "perk_text": ""},
    {"id": "effect-spark", "cat": "effect", "name": "Crystal Sparks", "cost": 600, "free": false, "perk": "", "value": 0.0, "desc": "Cold blue sparks on every hit.", "perk_text": ""},
]

const DEFAULT_EQUIPPED := {"spear": "spear-bamboo", "garment": "garment-bahag", "effect": "effect-none"}

const GARMENT_PALETTES := {
    "garment-tapis": {"r": "#3f6b9e", "y": "#8fc6d8", "w": "#dbeaf7"},
    "garment-blank": {"r": "#8a5c3c", "y": "#b8871c", "w": "#d9c9a8"},
    "garment-crown": {"r": "#5f3f8e", "y": "#f2c14e", "w": "#efe3ff"},
}

const EFFECT_COLORS := {
    "effect-none": ["#3c4a63"],
    "effect-fly": ["#e8f77a", "#b7ffd2"],
    "effect-ember": ["#f2a65a", "#ef6a5a"],
    "effect-leaf": ["#86b566", "#d9c9a8"],
    "effect-spark": ["#7ee3e3", "#6bb8ff"],
}

## Textures are baked by tools/export-sprites.mjs at scale 8, the web draws them
## at scale 3, so a Godot Sprite2D of an enemy or the hero wants this scale.
static func scale_for(world_scale: float) -> float:
    return world_scale / 8.0

# ------------------------------------------------------------------- levels

## Language, pacing and difficulty for a module. Modules past six replay the
## languages harder (lap 1, 2, ...).
func level_config(module: int) -> Dictionary:
    var m := maxi(1, module)
    var lang_count := LANGUAGES.size()
    var lang_index := (m - 1) % lang_count
    var lap := int((m - 1) / lang_count)
    var lang: Dictionary = LANGUAGES[lang_index]
    return {
        "module": m,
        "lang": String(lang["id"]),
        "lang_name": String(lang["name"]),
        "sky": String(lang["sky"]),
        "lap": lap,
        "checkpoints": 4 + mini(m, 4),
        "max_difficulty": 2 if m <= 2 else 3,
        "bat_speed": 46.0 + m * 5.0 + lap * 10.0,
        "spawn_interval": maxf(0.85, 1.9 - m * 0.1),
        "bat_altitude_min": 110.0,
        "bat_altitude_max": 330.0,
        "swoop_chance": minf(0.5, 0.1 + m * 0.05),
        "boss_hp": 2 + int(ceil(m / 2.0)),
        "boss_speed": 32.0 + m * 4.0,
        "boss_fire_interval": maxf(0.8, 1.7 - m * 0.1),
        "bug_speed": 105.0 + m * 8.0,
    }

func language(id: String) -> Dictionary:
    for l in LANGUAGES:
        if String(l["id"]) == id:
            return l
    return LANGUAGES[0]

func language_name(id: String) -> String:
    return String(language(id)["name"])

func language_color(id: String) -> Color:
    return Color.from_string(String(language(id)["color"]), Color.WHITE)

# ------------------------------------------------------------------ upgrades

func upgrade_def(id: String) -> Dictionary:
    for u in UPGRADES:
        if String(u["id"]) == id:
            return u
    return {}

func empty_upgrades() -> Dictionary:
    var out := {}
    for u in UPGRADES:
        out[String(u["id"])] = 0
    return out

## Human sentence for a level, e.g. "Sharpened Spear Lv2 (+2 spear damage)".
func upgrade_describe(id: String, level: int) -> String:
    match id:
        "damage":
            return "+%d spear damage" % level
        "speed":
            return "+%d%% move speed" % (level * 18)
        "cooldown":
            return "throw %d%% faster" % (level * 22)
        "shield":
            return "%d shield charge%s" % [level, "" if level == 1 else "s"]
        "pierce":
            return "spears pierce bats and bosses" if level >= 2 else "spears pierce bats"
        _:
            return "upgrade"

func upgrade_label(id: String, level: int) -> String:
    var def := upgrade_def(id)
    if def.is_empty():
        return "Upgrade"
    return "%s Lv%d (%s)" % [String(def["name"]), level, upgrade_describe(id, level)]

## Weighted pick of an upgrade the player has not maxed. `affinity` is the topic
## family of the question that was just answered. Returns "" when all are maxed.
func choose_upgrade(rng: RandomNumberGenerator, upgrades: Dictionary, affinity: String) -> String:
    var pool: Array = []
    var weights: Array = []
    var total := 0
    for u in UPGRADES:
        var id := String(u["id"])
        if int(upgrades.get(id, 0)) < int(u["max"]):
            pool.append(id)
            var w := 3 if id == affinity else 1
            weights.append(w)
            total += w
    if pool.is_empty():
        return ""
    var roll := rng.randi_range(1, total)
    for i in pool.size():
        roll -= int(weights[i])
        if roll <= 0:
            return String(pool[i])
    return String(pool[pool.size() - 1])

# ------------------------------------------------------------------- scoring

const BASE_POINTS := {1: 10, 2: 15, 3: 25}

## Points for a correct answer. Streaks reward consistency, not participation.
func points_for_correct(difficulty: int, streak: int = 0, bonus_per_answer: int = 0) -> int:
    var base := int(BASE_POINTS.get(difficulty, 10))
    var streak_bonus := 0
    if streak >= 5:
        streak_bonus = 10
    elif streak >= 3:
        streak_bonus = 5
    return base + streak_bonus + bonus_per_answer

func boss_points(module: int) -> int:
    return 60 + module * 15

func level_clear_points(module: int, perfect: bool) -> int:
    return 40 + module * 10 + (50 if perfect else 0)

# --------------------------------------------------------------- progression

## Unique correctly answered question ids for a language.
func solved_ids(progress: Dictionary, lang: String) -> Array:
    var answered: Dictionary = progress.get("answered", {})
    var out: Array = []
    for q in QuestionBank.questions:
        if String(q["lang"]) == lang and answered.has(String(q["id"])):
            out.append(String(q["id"]))
    return out

func mastery_percent(progress: Dictionary, lang: String) -> int:
    var total := QuestionBank.questions_for(lang).size()
    if total == 0:
        return 0
    return mini(100, int(round(float(solved_ids(progress, lang).size()) / float(total) * 100.0)))

func accuracy(progress: Dictionary) -> int:
    var correct := int(progress.get("correct", 0))
    var wrong := int(progress.get("wrong", 0))
    var attempts := correct + wrong
    if attempts == 0:
        return 0
    return int(round(float(correct) / float(attempts) * 100.0))

# -------------------------------------------------------------------- badges
# Built lazily because a lambda is not a constant expression.

var _badges: Array = []

func badges() -> Array:
    if _badges.is_empty():
        _build_badges()
    return _badges

func _build_badges() -> void:
    _badges = [
        {"id": "first-spear", "name": "First Spear", "desc": "Answer 1 checkpoint correctly", "check": func(p: Dictionary) -> bool: return int(p.get("correct", 0)) >= 1},
        {"id": "streak-5", "name": "Hot Streak", "desc": "5 correct answers in a row", "check": func(p: Dictionary) -> bool: return int(p.get("bestStreak", 0)) >= 5},
        {"id": "ten-check", "name": "Ten Checkpoints", "desc": "Answer 10 checkpoints correctly", "check": func(p: Dictionary) -> bool: return int(p.get("correct", 0)) >= 10},
        {"id": "sharpened", "name": "Sharpened Stone", "desc": "Reach level 3 of any upgrade", "check": func(p: Dictionary) -> bool: return _best_upgrade_level(p) >= 3},
        {"id": "boss-slayer", "name": "Boss Slayer", "desc": "Defeat your first Boss bat", "check": func(p: Dictionary) -> bool: return int(p.get("bossesDefeated", 0)) >= 1},
        {"id": "tradepost", "name": "Tradepost Regular", "desc": "Own 3 items from the shop", "check": func(p: Dictionary) -> bool: return (p.get("owned", []) as Array).size() >= 3},
        {"id": "six-mountains", "name": "Six Mountains", "desc": "Clear all six language modules", "check": func(p: Dictionary) -> bool: return int(p.get("modulesCleared", 0)) >= LANGUAGES.size()},
    ]
    for lang in LANGUAGES:
        var lid := String(lang["id"])
        var lname := String(lang["name"])
        _badges.append({
            "id": lid + "-trainee",
            "name": lname + " Trainee",
            "desc": "Answer 3 %s checkpoints correctly" % lname,
            "check": func(p: Dictionary) -> bool: return solved_ids(p, lid).size() >= 3,
        })
        _badges.append({
            "id": lid + "-master",
            "name": lname + " Master",
            "desc": "Master every %s checkpoint" % lname,
            "check": func(p: Dictionary) -> bool: return solved_ids(p, lid).size() >= QuestionBank.questions_for(lid).size(),
        })

func _best_upgrade_level(progress: Dictionary) -> int:
    var up: Dictionary = progress.get("upgrades", {})
    var best := 0
    for u in UPGRADES:
        best = maxi(best, int(up.get(String(u["id"]), 0)))
    return best

func badge_by_id(id: String) -> Dictionary:
    for b in badges():
        if String(b["id"]) == id:
            return b
    return {}

func earned_badges(progress: Dictionary) -> Array:
    var out: Array = []
    for b in badges():
        var check: Callable = b["check"]
        if check.is_valid() and bool(check.call(progress)):
            out.append(String(b["id"]))
    return out

## Badge ids that are newly unlocked.
func new_badges(progress: Dictionary, already_owned: Array) -> Array:
    var out: Array = []
    for id in earned_badges(progress):
        if not already_owned.has(id):
            out.append(id)
    return out

# ---------------------------------------------------------------------- shop

func shop_item(id: String) -> Dictionary:
    for i in SHOP_ITEMS:
        if String(i["id"]) == id:
            return i
    return {}

func items_in_category(cat: String) -> Array:
    var out: Array = []
    for i in SHOP_ITEMS:
        if String(i["cat"]) == cat:
            out.append(i)
    return out

## Total perk value across everything the player owns (defaults always count).
func perk_total(progress: Dictionary, perk: String) -> float:
    if perk == "":
        return 0.0
    var owned: Array = (progress.get("owned", []) as Array).duplicate()
    for id in DEFAULT_EQUIPPED.values():
        if not owned.has(id):
            owned.append(id)
    var sum := 0.0
    for i in SHOP_ITEMS:
        if owned.has(String(i["id"])) and String(i["perk"]) == perk:
            sum += float(i["value"])
    return sum

func perks_from(progress: Dictionary) -> Dictionary:
    return {
        "moveSpeed": perk_total(progress, "moveSpeed"),
        "spearSpeed": perk_total(progress, "spearSpeed"),
        "pointBonus": int(perk_total(progress, "pointBonus")),
        "maxHearts": int(perk_total(progress, "maxHearts")),
        "startShield": int(perk_total(progress, "startShield")),
        "revive": int(perk_total(progress, "revive")),
    }

## Gameplay numbers from an upgrade map plus flat perk bonuses.
func stats_from_upgrades(upgrades: Dictionary, perks: Dictionary = {}) -> Dictionary:
    var u := empty_upgrades()
    for k in upgrades.keys():
        u[k] = int(upgrades[k])
    var p := {
        "moveSpeed": 0.0, "spearSpeed": 0.0, "pointBonus": 0, "maxHearts": 0,
        "startShield": 0, "revive": 0,
    }
    for k in perks.keys():
        p[k] = perks[k]
    var max_hearts := mini(HEART_CAP, START_HEARTS + int(p["maxHearts"]))
    return {
        "weaponDamage": 1 + int(u["damage"]),
        "moveSpeed": 130.0 * (1.0 + int(u["speed"]) * 0.18) * (1.0 + float(p["moveSpeed"])),
        "throwCooldown": maxf(0.18, 0.62 * (1.0 - int(u["cooldown"]) * 0.22)),
        "spearSpeed": 430.0 * (1.0 + float(p["spearSpeed"])),
        "maxHearts": max_hearts,
        "startHearts": max_hearts,
        "startShield": int(u["shield"]) + int(p["startShield"]),
        "pierce": int(u["pierce"]),
        "pointBonus": int(p["pointBonus"]),
        "revives": int(p["revive"]),
    }

func derived_stats(progress: Dictionary) -> Dictionary:
    return stats_from_upgrades(progress.get("upgrades", {}), perks_from(progress))

# ------------------------------------------------------------------ purchases

func can_buy(progress: Dictionary, item_id: String) -> Dictionary:
    var item := shop_item(item_id)
    if item.is_empty():
        return {"ok": false, "reason": "Unknown item"}
    if (progress.get("owned", []) as Array).has(item_id):
        return {"ok": false, "reason": "Already owned"}
    if int(progress.get("points", 0)) < int(item["cost"]):
        return {"ok": false, "reason": "Not enough points"}
    return {"ok": true, "reason": ""}

## Pure purchase: returns a NEW progress dictionary (or the same one on failure).
func buy_item(progress: Dictionary, item_id: String) -> Dictionary:
    var check := can_buy(progress, item_id)
    var item := shop_item(item_id)
    if not bool(check["ok"]):
        return {"progress": progress, "item": item, "ok": false, "reason": String(check["reason"])}
    var next := progress.duplicate(true)
    next["points"] = int(progress["points"]) - int(item["cost"])
    var owned: Array = (progress.get("owned", []) as Array).duplicate()
    owned.append(item_id)
    next["owned"] = owned
    return {"progress": next, "item": item, "ok": true, "reason": ""}

## Pure equip: returns a NEW progress dictionary.
func equip_item(progress: Dictionary, item_id: String) -> Dictionary:
    var item := shop_item(item_id)
    if item.is_empty():
        return {"progress": progress, "ok": false, "reason": "Unknown item"}
    var owned: Array = (progress.get("owned", []) as Array).duplicate()
    for id in DEFAULT_EQUIPPED.values():
        if not owned.has(id):
            owned.append(id)
    if not owned.has(item_id):
        return {"progress": progress, "ok": false, "reason": "Not owned"}
    var next := progress.duplicate(true)
    var equipped: Dictionary = (progress.get("equipped", {}) as Dictionary).duplicate()
    for slot in DEFAULT_EQUIPPED.keys():
        if not equipped.has(slot):
            equipped[slot] = DEFAULT_EQUIPPED[slot]
    equipped[String(item["cat"])] = item_id
    next["equipped"] = equipped
    return {"progress": next, "ok": true, "reason": ""}
