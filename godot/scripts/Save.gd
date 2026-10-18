extends Node
## Persistence - the GDScript port of js/core/save.js.
##
## One JSON blob in user://codeplay-save.json. user:// is writable inside an
## exported build, so progress, badges, points and purchases all survive a
## restart the same way localStorage does on the web.

const SAVE_PATH := "user://codeplay-save.json"
const SAVE_VERSION := 1

func default_progress() -> Dictionary:
    var free_items: Array = []
    for item in Rules.SHOP_ITEMS:
        if bool(item["free"]):
            free_items.append(String(item["id"]))
    return {
        "version": SAVE_VERSION,
        "createdAt": "",
        "hero": "boy",
        "name": "Bagani",
        "points": 0,
        "module": 1,
        "highestModule": 1,
        "modulesCleared": 0,
        "bossesDefeated": 0,
        "correct": 0,
        "wrong": 0,
        "streak": 0,
        "bestStreak": 0,
        "answered": {},
        "mastery": {},
        "badges": [],
        "owned": free_items,
        "equipped": Rules.DEFAULT_EQUIPPED.duplicate(true),
        "upgrades": Rules.empty_upgrades(),
        "playSeconds": 0.0,
        "sound": true,
        "tutorialSeen": false,
    }

## Fill in anything missing so an old or hand-edited save still loads.
func migrate(raw: Variant) -> Dictionary:
    var base := default_progress()
    if typeof(raw) != TYPE_DICTIONARY:
        return base
    var source: Dictionary = raw
    var merged := base
    for key in source.keys():
        merged[key] = source[key]
    merged["version"] = SAVE_VERSION
    merged["answered"] = source["answered"] if typeof(source.get("answered")) == TYPE_DICTIONARY else {}
    merged["mastery"] = source["mastery"] if typeof(source.get("mastery")) == TYPE_DICTIONARY else {}
    merged["badges"] = (source["badges"] as Array).duplicate() if typeof(source.get("badges")) == TYPE_ARRAY else []
    var upgrades := Rules.empty_upgrades()
    if typeof(source.get("upgrades")) == TYPE_DICTIONARY:
        for key in (source["upgrades"] as Dictionary).keys():
            upgrades[key] = int(source["upgrades"][key])
    merged["upgrades"] = upgrades
    var equipped: Dictionary = Rules.DEFAULT_EQUIPPED.duplicate(true)
    if typeof(source.get("equipped")) == TYPE_DICTIONARY:
        for key in (source["equipped"] as Dictionary).keys():
            equipped[key] = source["equipped"][key]
    merged["equipped"] = equipped
    var owned: Array = (source["owned"] as Array).duplicate() if typeof(source.get("owned")) == TYPE_ARRAY else []
    for id in base["owned"]:
        if not owned.has(id):
            owned.append(id)
    merged["owned"] = owned
    merged["points"] = maxi(0, int(float(merged.get("points", 0))))
    merged["module"] = clampi(int(float(merged.get("module", 1))), 1, Rules.LANGUAGES.size() * 20)
    merged["highestModule"] = maxi(int(merged["module"]), int(float(merged.get("highestModule", 1))))
    merged["hero"] = "girl" if String(merged.get("hero", "boy")) == "girl" else "boy"
    var player_name := String(merged.get("name", "Bagani"))
    merged["name"] = player_name.substr(0, 12) if player_name != "" else "Bagani"
    merged["answered"] = (merged["answered"] as Dictionary).duplicate()
    merged["mastery"] = (merged["mastery"] as Dictionary).duplicate()
    # Added after the first saves shipped: default them rather than trusting a
    # missing key, so an old save boots with sound on and the tutorial to come.
    merged["sound"] = bool(merged.get("sound", true))
    merged["tutorialSeen"] = bool(merged.get("tutorialSeen", false))
    return merged

func load_progress() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        var fresh := default_progress()
        fresh["createdAt"] = Time.get_datetime_string_from_system()
        return fresh
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return default_progress()
    var text := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null:
        return default_progress()
    return migrate(parsed)

func save_progress(progress: Dictionary) -> bool:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("CodePlay: could not write %s" % SAVE_PATH)
        return false
    file.store_string(JSON.stringify(progress))
    file.close()
    return true

func reset_progress() -> Dictionary:
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    var fresh := default_progress()
    fresh["createdAt"] = Time.get_datetime_string_from_system()
    return fresh

