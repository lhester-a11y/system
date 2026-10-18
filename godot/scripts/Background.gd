extends Node2D
class_name Background
## Parallax pixel-art Kalinga landscape - the Godot take on
## js/render/background.js, layer for layer.
##
## Six sky bands, the Sleeping Beauty silhouette, four ridges (the two nearest
## carry a rim light), the stepped rice terraces, drifting clouds, twinkling
## stars, mist bands and the sun/moon with its pulsing halo. The sky, the
## lighting and the stars are all driven by the active module's language:
## day -> sunset -> night.
##
## The web build animates every one of those in its draw loop; this node keeps
## one Control per element and moves them in _process, so the port animates too
## instead of standing still.

const STEP := 3.0
const HORIZON := 600.0
const SKY_BAND_H := 108.0
const STAR_COUNT := 46
const CLOUD_COUNT := 4
const TERRACE_ROWS := 9
const PADDY_COUNT := 7

const SKIES := {
    "day": {
        "bands": ["#4e9fd8", "#6cb6e8", "#8fcdf1", "#b3dff7", "#d6eefc", "#eaf7fd"],
        "far": "#9dbfe0", "mid": "#7ba6cd", "near": "#5b87b4", "hill": "#3f6b52",
        "terrace": "#5f8f4c", "terrace_top": "#86b566", "paddy": "#8fc6d8",
        "cloud": "#ffffff", "cloud_alpha": 0.7,
        "orb": "#ffeaa8", "halo": "#fff4cf",
        "orb_x": 268.0, "orb_y": 92.0, "orb_r": 26.0, "moon": false,
        "stars": false, "mist": "#e2f4fc", "mist_alpha": 0.55,
    },
    "sunset": {
        "bands": ["#2f2350", "#5a3466", "#8f4468", "#c05a5c", "#e8865a", "#f4b26a"],
        "far": "#96637f", "mid": "#70496a", "near": "#4e3350", "hill": "#3b2a3c",
        "terrace": "#5e4450", "terrace_top": "#8a5c58", "paddy": "#d98b5e",
        "cloud": "#ffb37a", "cloud_alpha": 0.7,
        "orb": "#ffd08a", "halo": "#ff9d5c",
        "orb_x": 296.0, "orb_y": 244.0, "orb_r": 30.0, "moon": false,
        "stars": false, "mist": "#f0aa78", "mist_alpha": 0.4,
    },
    "night": {
        "bands": ["#04081a", "#080f28", "#0d1636", "#131e45", "#1a2752", "#22305f"],
        "far": "#2b3c66", "mid": "#1f2b4b", "near": "#16203a", "hill": "#131c2e",
        "terrace": "#1b2c46", "terrace_top": "#2b4468", "paddy": "#3d6291",
        "cloud": "#33456f", "cloud_alpha": 0.35,
        "orb": "#f2f6ff", "halo": "#9fb4e8",
        "orb_x": 282.0, "orb_y": 74.0, "orb_r": 21.0, "moon": true,
        "stars": true, "mist": "#344a7c", "mist_alpha": 0.5,
    },
}

## Hand-placed profile of the sleeping woman, left (head) to right (feet).
const SLEEPING_BEAUTY := [
    Vector2(-90, 300), Vector2(-60, 268), Vector2(-34, 224), Vector2(-12, 198),
    Vector2(8, 188), Vector2(26, 200), Vector2(36, 222), Vector2(46, 236),
    Vector2(62, 244), Vector2(88, 240), Vector2(112, 252), Vector2(134, 272),
    Vector2(158, 282), Vector2(176, 268), Vector2(196, 288), Vector2(222, 296),
    Vector2(250, 292), Vector2(282, 300), Vector2(318, 296), Vector2(360, 302),
    Vector2(440, 300),
]

## base_y, amplitude, parallax and colour key of the four rolling ridges.
const RIDGES := [
    {"base": 250.0, "amp": 26.0, "parallax": 0.08, "color": "far", "alpha": 0.92},
    {"base": 296.0, "amp": 22.0, "parallax": 0.16, "color": "mid", "alpha": 1.0},
    {"base": 372.0, "amp": 26.0, "parallax": 0.28, "color": "near", "alpha": 1.0},
    {"base": 452.0, "amp": 20.0, "parallax": 0.42, "color": "hill", "alpha": 1.0},
]

## Layers whose parallax is past this get the rim light along the crest.
const RIM_LIGHT_PARALLAX := 0.25

var _bands: Array = []
var _stars: Array = []          ## {rect, phase}
var _clouds: Array = []         ## {node, rects, x, y, drift}
var _ridges: Array = []         ## {poly, rim, points, base, amp, parallax, color}
var _terraces: Array = []       ## {top, body, inset}
var _paddies: Array = []
var _mist: Array = []           ## {rect, base_y}
var _tufts: Array = []
var _ground_band: ColorRect
var _ground_edge: ColorRect
var _ground_paddy: ColorRect
var _orb_holder: Node2D
var _orb_pixels: Array = []
var _halo: Array = []
var _target: Node2D = null
var _time := 0.0

func _ready() -> void:
    _build_bands()
    _build_stars()
    _build_far()
    _build_ridges()
    _build_terraces()
    _build_orb()
    _build_clouds()
    # ...mist sits above the terraces and the clouds, right below the ground band.
    _build_mist()
    _build_ground()
    set_sky("day", 1337)

# ------------------------------------------------------------------ construction

func _build_bands() -> void:
    for i in 6:
        var band := ColorRect.new()
        band.size = Vector2(Rules.WORLD_W, SKY_BAND_H + 1.0)
        band.position = Vector2(0, i * SKY_BAND_H)
        band.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(band)
        _bands.append(band)

func _build_stars() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    for i in STAR_COUNT:
        var x := _quantise(rng.randf_range(0.0, Rules.WORLD_W))
        var y := _quantise(rng.randf_range(4.0, 300.0))
        var phase := rng.randf_range(0.0, TAU)
        var size := 3.0 if rng.randf() > 0.85 else 2.0
        var star := ColorRect.new()
        star.size = Vector2(size, size)
        star.color = Color("#eaf2ff")
        star.position = Vector2(x, y)
        star.visible = false
        star.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(star)
        _stars.append({"rect": star, "phase": phase})

func _build_far() -> void:
    var far := Polygon2D.new()
    far.polygon = _closed(SLEEPING_BEAUTY, HORIZON)
    add_child(far)
    _ridges.append({"poly": far, "rim": null, "points": SLEEPING_BEAUTY,
        "base": 0.0, "amp": 0.0, "parallax": 0.035, "color": "far"})

func _build_ridges() -> void:
    for spec in RIDGES:
        var poly := Polygon2D.new()
        var points := _ridge_points(1337, float(spec["base"]), float(spec["amp"]))
        poly.polygon = _closed(points, HORIZON)
        add_child(poly)
        var rim: Line2D = null
        if float(spec["parallax"]) > RIM_LIGHT_PARALLAX:
            rim = Line2D.new()
            rim.points = points
            rim.width = 1.0
            rim.modulate.a = 0.35
            add_child(rim)
        _ridges.append({
            "poly": poly, "rim": rim, "points": points,
            "base": float(spec["base"]), "amp": float(spec["amp"]),
            "parallax": float(spec["parallax"]), "color": String(spec["color"]),
        })

func _build_terraces() -> void:
    for i in TERRACE_ROWS:
        var y := _quantise(468.0 + i * 15.0)
        var inset := _quantise(8.0 + i * 9.0)
        var top := ColorRect.new()
        top.position = Vector2(inset, y)
        top.size = Vector2(Rules.WORLD_W - inset, STEP)
        top.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(top)
        var body := ColorRect.new()
        body.position = Vector2(inset, y + STEP)
        body.size = Vector2(Rules.WORLD_W - inset, 12.0)
        body.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(body)
        _terraces.append({"top": top, "body": body, "inset": inset})

    # flooded paddies catch the light
    for i in PADDY_COUNT:
        var rect := ColorRect.new()
        rect.position = Vector2(_quantise(24.0 + float((i * 61) % 250)), _quantise(486.0 + i * 15.0))
        rect.size = Vector2(_quantise(26.0 + float((i * 37) % 40)), STEP)
        rect.modulate.a = 0.35
        rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(rect)
        _paddies.append(rect)

func _build_mist() -> void:
    for i in 3:
        var rect := ColorRect.new()
        rect.size = Vector2(Rules.WORLD_W, 9.0)
        rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(rect)
        _mist.append({"rect": rect, "base_y": _quantise(388.0 + i * 40.0)})

func _build_orb() -> void:
    _orb_holder = Node2D.new()
    add_child(_orb_holder)
    for i in 5:
        var halo := ColorRect.new()
        halo.modulate.a = 0.32
        halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _orb_holder.add_child(halo)
        _halo.append(halo)

func _build_clouds() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 1337
    for i in CLOUD_COUNT:
        var x := rng.randf_range(-40.0, 400.0)
        var y := _quantise(40.0 + i * 46.0 + rng.randf_range(-10.0, 10.0))
        var width := _quantise(rng.randf_range(40.0, 90.0))
        var drift := rng.randf_range(2.5, 7.0)
        var cloud := Node2D.new()
        var rects: Array = []
        # .drawClouds: three stacked bars make a chunky pixel cloud.
        for puff in [[0.0, 8.0, width, 8.0], [8.0, 0.0, width - 20.0, 8.0], [-6.0, 16.0, width + 12.0, 6.0]]:
            var puff_width := _quantise(float(puff[2]))
            if puff_width <= 0.0:
                continue
            var rect := ColorRect.new()
            rect.position = Vector2(float(puff[0]), y + float(puff[1]))
            rect.size = Vector2(puff_width, float(puff[3]))
            rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
            cloud.add_child(rect)
            rects.append(rect)
        add_child(cloud)
        _clouds.append({"node": cloud, "rects": rects, "x": x, "drift": drift})

func _build_ground() -> void:
    _ground_band = ColorRect.new()
    _ground_band.position = Vector2(0, HORIZON)
    _ground_band.size = Vector2(Rules.WORLD_W, Rules.WORLD_H - HORIZON)
    _ground_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_ground_band)

    _ground_edge = ColorRect.new()
    _ground_edge.position = Vector2(0, HORIZON)
    _ground_edge.size = Vector2(Rules.WORLD_W, STEP)
    _ground_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_ground_edge)

    # hill tufts along the horizon
    var x := 0.0
    while x < Rules.WORLD_W:
        var tuft := ColorRect.new()
        tuft.position = Vector2(x, HORIZON + 6.0)
        tuft.size = Vector2(STEP, 3.0 + float((int(x) * 7) % 6))
        tuft.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(tuft)
        _tufts.append(tuft)
        x += 9.0

    _ground_paddy = ColorRect.new()
    _ground_paddy.position = Vector2(0, 620.0)
    _ground_paddy.size = Vector2(Rules.WORLD_W, 20.0)
    _ground_paddy.modulate.a = 0.22
    _ground_paddy.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_ground_paddy)

## The web's ridgePath(): the profile, closed along the bottom edge.
func _closed(points: PackedVector2Array, bottom: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    if points.is_empty():
        return out
    out.append(Vector2(points[0].x, bottom))
    for point in points:
        out.append(point)
    out.append(Vector2(points[points.size() - 1].x, bottom))
    return out

func _quantise(value: float) -> float:
    return roundf(value / STEP) * STEP

## Port of ridgeFrom() in js/render/background.js, including its clamp, which -
## as in the web build - lands the profile on a gentle seeded sine wave rather
## than a random walk. Quantised to 3px to match the sprite chunkiness.
func _ridge_points(seed_value: int, base_y: float, amp: float) -> PackedVector2Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var points := PackedVector2Array()
    var y := base_y
    var x := -120.0
    while x <= 480.0:
        y += rng.randf_range(-amp * 0.45, amp * 0.45)
        var wave := sin((x + float(seed_value)) * 0.017) * amp * 0.5
        var clamped := minf(base_y - amp, maxf(base_y + amp, y))
        points.append(Vector2(x, _quantise(minf(clamped, base_y + amp) * 0.6 + (base_y + wave) * 0.4)))
        x += STEP
    return points

# ---------------------------------------------------------------------- lighting

## Follow this node for the parallax offset.
func set_target(node: Node2D) -> void:
    _target = node

## Retint and rebuild the whole landscape for a sky preset. `seed_value` picks
## new ridge profiles, exactly like passing a seed to createBackground().
func set_sky(sky_name: String, seed_value: int = 1337) -> void:
    var sky: Dictionary = SKIES.get(sky_name, SKIES["day"])
    var bands: Array = sky["bands"]
    for i in _bands.size():
        (_bands[i] as ColorRect).color = _color(bands[mini(i, bands.size() - 1)])

    for i in _ridges.size():
        var ridge: Dictionary = _ridges[i]
        (ridge["poly"] as Polygon2D).color = _color(sky[String(ridge["color"])])
        if float(ridge["amp"]) > 0.0:
            var points := _ridge_points(seed_value + i * 97, float(ridge["base"]), float(ridge["amp"]))
            ridge["points"] = points
            (ridge["poly"] as Polygon2D).polygon = _closed(points, HORIZON)
            if ridge["rim"] != null:
                (ridge["rim"] as Line2D).points = points
        if ridge["rim"] != null:
            (ridge["rim"] as Line2D).default_color = _color(sky["terrace_top"])

    for row in _terraces:
        (row["top"] as ColorRect).color = _color(sky["terrace_top"])
        (row["body"] as ColorRect).color = _color(sky["terrace"])
    for paddy in _paddies:
        (paddy as ColorRect).color = _color(sky["paddy"])

    for entry in _mist:
        (entry["rect"] as ColorRect).color = _color(sky["mist"])
        (entry["rect"] as ColorRect).modulate.a = 0.35

    for cloud in _clouds:
        for rect in cloud["rects"]:
            (rect as ColorRect).color = _color(sky["cloud"])
            (rect as ColorRect).modulate.a = float(sky["cloud_alpha"])

    _ground_band.color = _color(sky["terrace"])
    _ground_edge.color = _color(sky["terrace_top"])
    for tuft in _tufts:
        (tuft as ColorRect).color = _color(sky["hill"])
    _ground_paddy.color = _color(sky["paddy"])

    for star in _stars:
        (star["rect"] as ColorRect).visible = bool(sky["stars"])

    _build_orb_pixels(sky)

func _build_orb_pixels(sky: Dictionary) -> void:
    for pixel in _orb_pixels:
        (pixel as ColorRect).queue_free()
    _orb_pixels.clear()

    var radius := float(sky["orb_r"])
    _orb_holder.position = Vector2(float(sky["orb_x"]), float(sky["orb_y"]))

    for i in _halo.size():
        var halo := _halo[i] as ColorRect
        var rr := _quantise(radius + 8.0 + i * 9.0)
        halo.size = Vector2(rr * 2.0, rr * 2.0)
        halo.position = Vector2(-rr, -rr)
        halo.color = _color(sky["halo"])

    var y := -radius
    while y < radius:
        var x := -radius
        while x < radius:
            if x * x + y * y <= radius * radius:
                var pixel := ColorRect.new()
                pixel.size = Vector2(STEP, STEP)
                pixel.position = Vector2(_quantise(x), _quantise(y))
                pixel.color = _color(sky["orb"])
                pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE
                _orb_holder.add_child(pixel)
                _orb_pixels.append(pixel)
            x += STEP
        y += STEP

    if bool(sky["moon"]):
        for crater in [[-6.0, -6.0, 6.0, 6.0], [3.0, 3.0, 6.0, 6.0], [6.0, -9.0, 3.0, 3.0]]:
            var pixel := ColorRect.new()
            pixel.position = Vector2(float(crater[0]), float(crater[1]))
            pixel.size = Vector2(float(crater[2]), float(crater[3]))
            pixel.color = Color("#c9d6f2")
            pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE
            _orb_holder.add_child(pixel)
            _orb_pixels.append(pixel)

func _color(hex: String) -> Color:
    return Color.from_string(hex, Color.MAGENTA)

## Structure and live positions, for the self-test. Counts prove the landscape is
## complete; the positions are what make the animation measurable rather than a
## matter of opinion.
func snapshot() -> Dictionary:
    var stars_visible := 0
    for star in _stars:
        if (star["rect"] as ColorRect).visible:
            stars_visible += 1
    var halos_visible := 0
    for halo in _halo:
        if (halo as ColorRect).visible:
            halos_visible += 1
    var puffs := 0
    for cloud in _clouds:
        puffs += (cloud["rects"] as Array).size()
    var rim_lights := 0
    for ridge in _ridges:
        if ridge["rim"] != null:
            rim_lights += 1
    return {
        "bands": _bands.size(),
        "band_first": (_bands[0] as ColorRect).color,
        "band_last": (_bands[5] as ColorRect).color,
        "stars": _stars.size(),
        "stars_visible": stars_visible,
        "star_alpha": (_stars[0]["rect"] as ColorRect).modulate.a,
        "halos": _halo.size(),
        "halos_visible": halos_visible,
        "ridges": _ridges.size(),
        "rim_lights": rim_lights,
        "terraces": _terraces.size(),
        "terrace_x": (_terraces[3]["top"] as ColorRect).position.x,
        "paddies": _paddies.size(),
        "clouds": _clouds.size(),
        "cloud_puffs": puffs,
        "cloud_x": (_clouds[0]["node"] as Node2D).position.x,
        "mist": _mist.size(),
        "mist_y": (_mist[1]["rect"] as ColorRect).position.y,
        "orb": _orb_holder.position,
        "orb_pixels": _orb_pixels.size(),
    }

# -------------------------------------------------------------------- animation

func _process(delta: float) -> void:
    _time += delta
    var camera_x := _target.position.x if _target != null else Rules.WORLD_W / 2.0
    var slide := -(camera_x - Rules.WORLD_W / 2.0)

    for ridge in _ridges:
        var offset := slide * float(ridge["parallax"])
        (ridge["poly"] as Polygon2D).position.x = offset
        if ridge["rim"] != null:
            (ridge["rim"] as Line2D).position.x = offset

    # Terraces slide at half the near-ridge speed; the visible part of each step
    # starts where that row's own inset meets the offset.
    var terrace_offset := slide * 0.5
    for row in _terraces:
        var x0 := maxf(0.0, float(row["inset"]) + terrace_offset)
        var width := maxf(0.0, Rules.WORLD_W - x0)
        (row["top"] as ColorRect).position.x = x0
        (row["top"] as ColorRect).size.x = width
        (row["body"] as ColorRect).position.x = x0
        (row["body"] as ColorRect).size.x = width

    for i in _mist.size():
        var base_y := float(_mist[i]["base_y"])
        (_mist[i]["rect"] as ColorRect).position.y = _quantise(base_y + sin(_time * 0.4 + i) * 3.0)

    for cloud in _clouds:
        (cloud["node"] as Node2D).position.x = _quantise(fmod(float(cloud["x"]) + _time * float(cloud["drift"]), 440.0) - 40.0)

    for star in _stars:
        var rect := star["rect"] as ColorRect
        rect.modulate.a = maxf(0.12, 0.55 + 0.45 * sin(_time * 1.6 + float(star["phase"])))

    for i in _halo.size():
        (_halo[i] as ColorRect).visible = sin(_time * 0.7 + i) >= -0.85
