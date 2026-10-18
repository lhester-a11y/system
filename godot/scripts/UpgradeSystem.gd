extends Node
## CodePlay upgrade state (autoload) - the port of the upgrade half of
## js/core/rules.js plus sim.grantUpgrade() from js/core/simulation.js.
##
## `levels` is the live upgrade map for the current run; `stats` is the derived
## set of numbers Player.gd, Bat.gd and Spear.gd read every frame. Both are
## rebuilt from the persisted progress at the start of every module.

var levels: Dictionary = {}
var stats: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Cosmetic spear art, set by Main from progress.equipped.spear.
var spear_design: String = "bamboo"

func _ready() -> void:
    levels = Rules.empty_upgrades()
    stats = Rules.stats_from_upgrades(levels, {})

## Start a module: keep the persisted upgrade levels, reseed the reward roll.
func begin_run(progress: Dictionary, run_seed: int = 0) -> void:
    rng.seed = run_seed if run_seed != 0 else Time.get_ticks_usec()
    levels = Rules.empty_upgrades()
    var saved: Dictionary = progress.get("upgrades", {})
    for id in levels.keys():
        levels[id] = int(saved.get(id, 0))
    recompute(progress)

func recompute(progress: Dictionary) -> void:
    stats = Rules.stats_from_upgrades(levels, Rules.perks_from(progress))

## Weighted reward roll, biased to the topic family of the question answered.
## Returns {} when every upgrade is already maxed.
func grant(affinity: String = "") -> Dictionary:
    var id := Rules.choose_upgrade(rng, levels, affinity)
    if id == "":
        return {}
    levels[id] = int(levels[id]) + 1
    var def := Rules.upgrade_def(id)
    return {
        "id": id,
        "level": int(levels[id]),
        "name": String(def["name"]),
        "icon": String(def["icon"]),
        "description": Rules.upgrade_describe(id, int(levels[id])),
    }

func level_of(id: String) -> int:
    return int(levels.get(id, 0))

# --- derived numbers used by the gameplay scripts --------------------------

func weapon_damage() -> int:
    return int(stats.get("weaponDamage", 1))

func move_speed() -> float:
    return float(stats.get("moveSpeed", 130.0))

func throw_cooldown() -> float:
    return float(stats.get("throwCooldown", 0.62))

func spear_speed() -> float:
    return float(stats.get("spearSpeed", 430.0))

func max_hearts() -> int:
    return int(stats.get("maxHearts", Rules.START_HEARTS))

func start_shield() -> int:
    return int(stats.get("startShield", 0))

func revives() -> int:
    return int(stats.get("revives", 0))

func point_bonus() -> int:
    return int(stats.get("pointBonus", 0))

func pierce() -> int:
    return int(stats.get("pierce", 0))

## Human-readable chips for the HUD and the progress screen.
func summary() -> Array:
    var out: Array = []
    for u in Rules.UPGRADES:
        var id := String(u["id"])
        if int(levels.get(id, 0)) > 0:
            out.append("%s Lv%d" % [String(u["name"]), int(levels[id])])
    return out
