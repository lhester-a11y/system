extends RefCounted
class_name Sprites
## Texture lookups for the baked pixel art in assets/sprites.
##
## The exporter bakes every sprite at scale 8 (tools/export-sprites.mjs) while
## the web build draws at scale 3, which is why Sprites.SCALE exists.

const DIR := "res://assets/sprites/"
const SCALE := 3.0 / 8.0

static func texture(path: String) -> Texture2D:
    if not ResourceLoader.exists(path):
        return null
    return load(path)

## The warrior, wearing the garment's baked palette variant when there is one.
static func hero_path(hero: String, garment: String) -> String:
    var who := "girl" if hero == "girl" else "boy"
    var suffix := ""
    match garment:
        "garment-tapis":
            suffix = "tapis"
        "garment-blank":
            suffix = "blank"
        "garment-crown":
            suffix = "crown"
    if suffix != "":
        var variant := "%shero-%s-%s.png" % [DIR, who, suffix]
        if ResourceLoader.exists(variant):
            return variant
    return "%s%s.png" % [DIR, who]

static func hero(hero: String, garment: String) -> Texture2D:
    return texture(hero_path(hero, garment))

static func bat() -> Texture2D:
    return texture(DIR + "bat.png")

static func bug() -> Texture2D:
    return texture(DIR + "bug.png")

static func crown() -> Texture2D:
    return texture(DIR + "crown.png")

static func spear(design: String) -> Texture2D:
    var path := "%sspear-%s.png" % [DIR, design]
    if not ResourceLoader.exists(path):
        path = DIR + "spear-bamboo.png"
    return texture(path)

