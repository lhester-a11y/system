extends CanvasLayer
class_name GameHUD
## The in-game overlay: module line, hearts, shields, points, checkpoint pips,
## mastery meter, the buffs earned so far, the boss bar, and the touch controls.
##
## Layout rule: the whole readout is one top column that ends above the toast
## strip (ToastStack starts at y=150). The old overlay put toasts at y=40, right
## on top of the buff chips, which is why the buffs looked like they vanished
## after a respawn - they were simply covered.

signal move_input(direction: float)
signal throw_held(held: bool)
signal pause_pressed()
signal sound_pressed()

const PAUSE_SIZE := Vector2(34, 30)
const SOUND_SIZE := Vector2(46, 30)

var _hearts_row: HBoxContainer
var _module_label: Label
var _points_label: Label
var _pips_row: HBoxContainer
var _absorbed_label: Label
var _mastery_meter: UiKitMeter
var _mastery_label: Label
var _streak_label: Label
var _shield_label: Label
var _buffs_flow: HFlowContainer
var _buffs_empty: Label
## The chip list only changes when a buff is earned, so rebuild on change instead
## of on every 0.12s refresh (otherwise queued frees and fresh pills would make
## the row double up for a frame and shove the toasts around).
var _chips_key: String = "\u0000"
var _pause_button: Button
var _sound_button: Button
var _controls: Control
var _boss_box: Control
var _boss_fill: ColorRect
var _top: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.anchor_right = 1.0
	holder.anchor_bottom = 1.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_top = UiKit.column(4)
	_top.position = Vector2(10, 6)
	_top.custom_minimum_size = Vector2(340, 0)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_top)
	var top := _top

	# ------------------------------------------------------------ header row
	var header := UiKit.row(6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(header)

	_module_label = UiKit.label("", 12, UiKit.FG, false)
	_module_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_module_label)

	_pause_button = UiKit.pad_button("II", 13)
	_pause_button.custom_minimum_size = PAUSE_SIZE
	_pause_button.tooltip_text = "Pause (Esc)"
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	header.add_child(_pause_button)

	_sound_button = UiKit.pad_button("SFX", 9)
	_sound_button.custom_minimum_size = SOUND_SIZE
	_sound_button.tooltip_text = "Sound on/off"
	_sound_button.pressed.connect(func() -> void: sound_pressed.emit())
	header.add_child(_sound_button)

	# ------------------------------------------------- status and points row
	var status := UiKit.row(6)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(status)

	_hearts_row = UiKit.row(3)
	_hearts_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(_hearts_row)

	_shield_label = UiKit.label("", 11, Color("#6bb8ff"), false)
	status.add_child(_shield_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(spacer)

	_points_label = UiKit.label("", 11, UiKit.GOLD, false)
	status.add_child(_points_label)

	# ------------------------------------------------- mastery, pips, streak
	var mastery_row := UiKit.row(6)
	mastery_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mastery_row)

	_mastery_meter = UiKit.meter(0.0, 116.0, 7.0, Color("#6bb8ff"))
	mastery_row.add_child(_mastery_meter)
	_mastery_label = UiKit.label("0%", 10, UiKit.MUTED, false)
	mastery_row.add_child(_mastery_label)

	_pips_row = UiKit.row(2)
	_pips_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mastery_row.add_child(_pips_row)

	_absorbed_label = UiKit.label("", 10, UiKit.MUTED, false)
	mastery_row.add_child(_absorbed_label)

	_streak_label = UiKit.label("", 10, UiKit.MUTED, false)
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_streak_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mastery_row.add_child(_streak_label)

	# --------------------------------------------------------------- buffs
	_buffs_flow = HFlowContainer.new()
	_buffs_flow.add_theme_constant_override("h_separation", 4)
	_buffs_flow.add_theme_constant_override("v_separation", 3)
	_buffs_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buffs_flow.custom_minimum_size = Vector2(340, 0)
	top.add_child(_buffs_flow)

	_buffs_empty = UiKit.label("No buffs yet - a correct answer grants one", 9, Color("#6f7f9b"), false)
	_buffs_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_buffs_empty)

	_build_boss_bar(top)

	_controls = Control.new()
	_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls.anchor_right = 1.0
	_controls.anchor_bottom = 1.0
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_controls)

	var bar := UiKit.row(8)
	bar.position = Vector2(12, 546)
	bar.size = Vector2(336, 84)
	_controls.add_child(bar)
	bar.add_child(_hold_button("<", func() -> void: move_input.emit(-1.0), func() -> void: move_input.emit(0.0)))
	bar.add_child(_hold_button(">", func() -> void: move_input.emit(1.0), func() -> void: move_input.emit(0.0)))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)
	bar.add_child(_throw_button())

## The Syntax Overlord's health bar, in the web build's renderer at the top of
## the stage: a 128x8 bar with its name above it.
func _build_boss_bar(parent: Control) -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.add_theme_constant_override("separation", 1)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	parent.add_child(_boss_box)

	var name_label := UiKit.label("SYNTAX OVERLORD", 9, Color("#ffd9e0"), false)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(name_label)

	var track_row := UiKit.row()
	track_row.alignment = BoxContainer.ALIGNMENT_CENTER
	track_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(track_row)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(132, 12)
	track.color = Color("#05070d")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_row.add_child(track)

	var inner := ColorRect.new()
	inner.custom_minimum_size = Vector2(128, 8)
	inner.color = Color("#2a1330")
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(inner)
	inner.position = Vector2(2, 2)

	_boss_fill = ColorRect.new()
	_boss_fill.position = Vector2(2, 2)
	_boss_fill.size = Vector2(128, 8)
	_boss_fill.color = Color("#e0455f")
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_boss_fill)

func _hold_button(text: String, on_down: Callable, on_up: Callable) -> Button:
	var node := UiKit.pad_button(text, 20)
	node.custom_minimum_size = Vector2(62, 62)
	node.button_down.connect(func() -> void: on_down.call())
	node.button_up.connect(func() -> void: on_up.call())
	return node

func _throw_button() -> Button:
	var node := UiKit.pad_button("THROW", 13, true)
	node.custom_minimum_size = Vector2(84, 84)
	node.button_down.connect(func() -> void: throw_held.emit(true))
	node.button_up.connect(func() -> void: throw_held.emit(false))
	return node

func set_visible_hud(value: bool) -> void:
	visible = value

## Where the bottom of the readout lands. ToastStack uses the same budget, and
## the self-test asserts the two never overlap.
func content_bottom() -> float:
	return _top.position.y + _top.size.y

func pause_button() -> Button:
	return _pause_button

func sound_button() -> Button:
	return _sound_button

## The mute state is owned by Main (it lives in the save file); the HUD only
## shows it.
func set_sound_enabled(value: bool) -> void:
	_sound_button.text = "SFX" if value else "MUTE"
	_sound_button.add_theme_color_override("font_color", UiKit.FG if value else UiKit.MUTED)

## One refresh of the whole overlay. Main supplies the numbers so the HUD stays
## free of gameplay references.
func refresh(data: Dictionary) -> void:
	var hearts := int(data.get("hearts", 0))
	var max_hearts := int(data.get("max_hearts", 0))
	for child in _hearts_row.get_children():
		child.queue_free()
	for i in max_hearts:
		_hearts_row.add_child(UiKit.heart(i < hearts))

	var shield := int(data.get("shield", 0))
	_shield_label.text = "SHIELD x%d" % shield if shield > 0 else ""

	_module_label.text = "Module %d - %s" % [int(data.get("module", 1)), String(data.get("lang_name", ""))]

	var points := int(data.get("points", 0))
	var run_points := int(data.get("run_points", 0))
	_points_label.text = "%d pts (+%d)" % [points, run_points]
	_streak_label.text = "streak %d" % int(data.get("streak", 0))

	var cleared := int(data.get("cleared", 0))
	var total := int(data.get("total", 0))
	for child in _pips_row.get_children():
		child.queue_free()
	for i in total:
		_pips_row.add_child(UiKit.swatch(Color("#5fe08a") if i < cleared else Color("#26314a"), Vector2(7, 7)))
	_pips_row.add_child(UiKit.swatch(Color("#b98bff") if bool(data.get("boss", false)) else Color("#26314a"), Vector2(7, 7)))
	_absorbed_label.text = "%d/%d" % [cleared, total]

	var boss_hp := int(data.get("boss_hp", 0))
	var boss_max_hp := int(data.get("boss_max_hp", 0))
	var boss_alive := boss_max_hp > 0 and boss_hp > 0
	_boss_box.visible = boss_alive
	if boss_alive:
		_boss_fill.size.x = roundf(128.0 * float(boss_hp) / float(boss_max_hp))

	var mastery := int(data.get("mastery", 0))
	_mastery_meter.set_ratio(float(mastery) / 100.0)
	_mastery_label.text = "%d%%" % mastery

	var chips: Array = data.get("chips", [])
	var chips_key := "|".join(PackedStringArray(chips))
	if chips_key != _chips_key:
		_chips_key = chips_key
		for child in _buffs_flow.get_children():
			_buffs_flow.remove_child(child)
			child.queue_free()
		_buffs_empty.visible = chips.is_empty()
		for chip in chips:
			_buffs_flow.add_child(UiKit.pill(String(chip)))
