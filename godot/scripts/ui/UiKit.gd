extends RefCounted
class_name UiKit
## Small builders shared by every screen. The web build keeps its text in the DOM
## with CSS; here the same look is assembled from Godot Control nodes.
##
## All text is ASCII on purpose: the default Godot theme font has no emoji, so
## the web build's picture icons become short letter tags in this port.

const FG := Color("#e8eef7")
const MUTED := Color("#93a2bd")
const GOLD := Color("#f2c14e")
const GOOD := Color("#5fe08a")
const BAD := Color("#ef6a5a")
const PANEL_BG := Color("#171e2e")
const PANEL_BG_ALT := Color("#0f1524")
const BORDER := Color("#5b6d8c")

## ------------------------------------------------------------------ palette
## The same colours as styles.css, so a ported screen reads like the web build.
const LINE := Color("#3c4a63")
const LINE_2 := Color("#5b6d8c")
const BUTTON_BG := Color("#232e45")
const BUTTON_BG_HOVER := Color("#2b374f")
const BUTTON_BG_PRESSED := Color("#1a2333")
const BUTTON_BD_DISABLED := Color("#3c4a63")
const DISABLED_FG := Color("#93a2bd")
const PRIMARY_BG := Color("#f2c14e")
const PRIMARY_BG_HOVER := Color("#ffe08a")
const PRIMARY_BD := Color("#7a560f")
const PRIMARY_FG := Color("#1b1206")
const INPUT_BG := Color("#0e1421")
const PAD_BG := Color("#26314a")
const PAD_BG_HOVER := Color("#3a4a6d")
const PAD_BD := Color("#4d5f80")

## Wrapping is on by default: these labels live in vertical columns, where
## autowrap is what keeps long copy (the tagline, explanations, badge text) on
## screen instead of running off the right edge of the scroll container.
##
## Pass wrap = false for any label that sits directly inside an HBoxContainer.
## An autowrapping Label reports a minimum width of about one character, so a
## row hands it almost no space and it wraps one letter per line - that is what
## rendered the lobby's "Name" label as a vertical "N / a / m / e" column.
static func label(text: String, size: int = 13, color: Color = FG, wrap: bool = true) -> Label:
    var node := Label.new()
    node.text = text
    node.add_theme_font_size_override("font_size", size)
    node.add_theme_color_override("font_color", color)
    node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
    return node

static func button(text: String, size: int = 15) -> Button:
    var node := Button.new()
    node.text = text
    node.add_theme_font_size_override("font_size", size)
    return node

## A flat panel/button box. Square corners on purpose: the web build never uses
## border-radius, so rounding here is what made the port look like a different
## game.
static func style(bg: Color = PANEL_BG, border: Color = BORDER, border_width: int = 3, margin: int = 9) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = bg
    box.border_color = border
    box.set_border_width_all(border_width)
    box.set_content_margin_all(margin)
    return box

static func button_style(bg: Color, border: Color, width: int = 3, margin_x: int = 12, margin_y: int = 10) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = bg
    box.border_color = border
    box.set_border_width_all(width)
    box.content_margin_left = margin_x
    box.content_margin_right = margin_x
    box.content_margin_top = margin_y
    box.content_margin_bottom = margin_y
    return box

## The whole UI theme, in one place.
##
## styles.css draws every control dark with a 3px slate border and a hard shadow;
## Godot's default theme is a pale grey rounded look. Assigning this theme to the
## window is what makes the ported screens match the web build instead of looking
## like a stock Godot project.
static func theme() -> Theme:
    var out := Theme.new()

    # .btn / .choice: dark slate, 3px line-2 border, square, text #e8eef7.
    out.set_stylebox("normal", "Button", button_style(BUTTON_BG, LINE_2))
    out.set_stylebox("hover", "Button", button_style(BUTTON_BG_HOVER, LINE_2))
    out.set_stylebox("pressed", "Button", button_style(BUTTON_BG_PRESSED, LINE_2))
    out.set_stylebox("disabled", "Button", button_style(Color("#1b2333"), BUTTON_BD_DISABLED))
    out.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    out.set_color("font_color", "Button", FG)
    out.set_color("font_hover_color", "Button", FG)
    out.set_color("font_pressed_color", "Button", Color("#cfd9ea"))
    out.set_color("font_disabled_color", "Button", DISABLED_FG)
    out.set_font_size("font_size", "Button", 13)

    # .panel / .item-card / .dialog: the dark panel with a slate border.
    out.set_stylebox("panel", "PanelContainer", style(PANEL_BG, LINE_2))
    out.set_stylebox("panel", "Panel", style(PANEL_BG, LINE_2))

    # .text-input: near-black field, gold border while focused.
    out.set_stylebox("normal", "LineEdit", button_style(INPUT_BG, LINE, 2, 8, 6))
    out.set_stylebox("focus", "LineEdit", button_style(INPUT_BG, GOLD, 2, 8, 6))
    out.set_color("font_color", "LineEdit", FG)
    out.set_color("font_placeholder_color", "LineEdit", MUTED)
    out.set_color("caret_color", "LineEdit", GOLD)
    out.set_color("selection_color", "LineEdit", Color("#28406b"))

    # Scrollbars, so a long question list does not look like a stock control.
    out.set_stylebox("scroll", "VScrollBar", style(Color("#101725"), LINE, 2, 0))
    out.set_stylebox("grabber", "VScrollBar", style(LINE_2, LINE_2, 2, 0))
    out.set_stylebox("grabber_highlight", "VScrollBar", style(FG, FG, 2, 0))
    out.set_stylebox("grabber_pressed", "VScrollBar", style(FG, FG, 2, 0))
    return out

## A gold call-to-action button (.btn-primary / .pad-throw).
static func primary_button(text: String, size: int = 15) -> Button:
    var node := button(text, size)
    node.add_theme_stylebox_override("normal", button_style(PRIMARY_BG, PRIMARY_BD))
    node.add_theme_stylebox_override("hover", button_style(PRIMARY_BG_HOVER, PRIMARY_BD))
    node.add_theme_stylebox_override("pressed", button_style(PRIMARY_BG, PRIMARY_BD))
    node.add_theme_stylebox_override("disabled", button_style(Color("#6b5a26"), PRIMARY_BD))
    for state in ["font_color", "font_hover_color", "font_pressed_color"]:
        node.add_theme_color_override(state, PRIMARY_FG)
    node.add_theme_color_override("font_disabled_color", Color("#4a3f1c"))
    return node

## The in-game touch pad: dark slate, gold when it is the THROW button.
static func pad_button(text: String, size: int = 14, gold: bool = false) -> Button:
    var node := primary_button(text, size) if gold else button(text, size)
    if not gold:
        node.add_theme_stylebox_override("normal", button_style(PAD_BG, PAD_BD))
        node.add_theme_stylebox_override("hover", button_style(PAD_BG_HOVER, PAD_BD))
        node.add_theme_stylebox_override("pressed", button_style(PAD_BG, PAD_BD))
    return node

## "Code" + "Play" in the web build's two colours (.logo-code / .logo-play).
static func logo(first: String, second: String, size: int = 32) -> HBoxContainer:
    var row := row(0)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # wrap = false: both halves live in a row, where autowrap collapses them.
    row.add_child(label(first, size, GOOD, false))
    row.add_child(label(second, size, GOLD, false))
    return row

## Pixel-art hearts, so the HUD marks look like the web build's hearts instead of
## plain squares. The 11x9 pattern is baked once per state and reused.
const HEART_ART := [
    ".xx.....xx.",
    "xxxx...xxxx",
    "xxxxxxxxxxx",
    "xxxxxxxxxxx",
    ".xxxxxxxxx.",
    "..xxxxxxx..",
    "...xxxxx...",
    "....xxx....",
    ".....x.....",
]
const HEART_FILLED := Color("#ef6a5a")
const HEART_EMPTY := Color("#3a2a30")

static var _heart_cache: Dictionary = {}

static func heart(filled: bool, scale: int = 2) -> TextureRect:
    var key := "%s@%d" % [filled, scale]
    if not _heart_cache.has(key):
        var color := HEART_FILLED if filled else HEART_EMPTY
        var image := Image.create(HEART_ART[0].length() * scale, HEART_ART.size() * scale, false, Image.FORMAT_RGBA8)
        for y in HEART_ART.size():
            var row_text := String(HEART_ART[y])
            for x in row_text.length():
                if row_text[x] != "x":
                    continue
                for sy in scale:
                    for sx in scale:
                        image.set_pixel(x * scale + sx, y * scale + sy, color)
        _heart_cache[key] = ImageTexture.create_from_image(image)
    var node := TextureRect.new()
    node.texture = _heart_cache[key]
    node.custom_minimum_size = Vector2(HEART_ART[0].length() * scale, HEART_ART.size() * scale)
    node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return node

## A compact tag for an earned buff ("Sharpened Spear Lv2") in the HUD. Tight
## margins on purpose: several of them share one 340px row.
static func pill(text: String, color: Color = GOLD, bg: Color = PANEL_BG) -> PanelContainer:
    var node := PanelContainer.new()
    node.add_theme_stylebox_override("panel", style(bg, color, 1, 4))
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.add_child(label(text, 9, color, false))
    return node

static func panel(bg: Color = PANEL_BG, border: Color = BORDER) -> PanelContainer:
    var node := PanelContainer.new()
    node.add_theme_stylebox_override("panel", style(bg, border))
    return node

static func row(separation: int = 7) -> HBoxContainer:
    var node := HBoxContainer.new()
    node.add_theme_constant_override("separation", separation)
    return node

static func column(separation: int = 7) -> VBoxContainer:
    var node := VBoxContainer.new()
    node.add_theme_constant_override("separation", separation)
    return node

static func spacer(height: float) -> Control:
    var node := Control.new()
    node.custom_minimum_size = Vector2(0, height)
    return node

static func swatch(color: Color, size: Vector2, radius: float = 2.0) -> Panel:
    var node := Panel.new()
    node.custom_minimum_size = size
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.corner_radius_top_left = int(radius)
    box.corner_radius_top_right = int(radius)
    box.corner_radius_bottom_left = int(radius)
    box.corner_radius_bottom_right = int(radius)
    node.add_theme_stylebox_override("panel", box)
    return node

## A thin horizontal meter: dark track plus a fill whose width is a ratio.
static func meter(ratio: float, width: float = 180.0, height: float = 7.0, fill: Color = GOOD) -> UiKitMeter:
    var meter_node := UiKitMeter.new(width, height, fill)
    meter_node.fill_color = fill
    meter_node.set_ratio(ratio)
    return meter_node

static func screen_root(layer: int) -> CanvasLayer:
    var node := CanvasLayer.new()
    node.layer = layer
    node.process_mode = Node.PROCESS_MODE_ALWAYS
    return node

