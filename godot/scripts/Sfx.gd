extends Node
## Sound effects (autoload) - the Godot side of js/audio.js.
##
## The clips are baked from tools/make-sfx.mjs into godot/assets/sfx/. A small
## pool of players lets a spear throw, a hit and a quiz chime overlap instead of
## cutting each other off.
##
## The mute switch lives in the save file: Main reads progress["sound"] at boot
## and calls set_enabled(), so the choice survives a restart.

## Names, volumes and pitch spread of the eleven clips. Pitch spread makes the
## repeated ones (hit, click) sound struck rather than sampled.
const CLIPS := {
	"throw": {"volume_db": -6.0, "spread": 0.05},
	"hit": {"volume_db": -5.0, "spread": 0.12},
	"absorb": {"volume_db": -4.0, "spread": 0.04},
	"correct": {"volume_db": -2.5, "spread": 0.0},
	"wrong": {"volume_db": -4.0, "spread": 0.0},
	"hurt": {"volume_db": -1.5, "spread": 0.06},
	"shield": {"volume_db": -3.0, "spread": 0.05},
	"badge": {"volume_db": -3.5, "spread": 0.0},
	"boss": {"volume_db": -2.0, "spread": 0.0},
	"clear": {"volume_db": -1.5, "spread": 0.0},
	"click": {"volume_db": -8.0, "spread": 0.08},
}

const DIR := "res://assets/sfx/"
const VOICES := 8

var enabled: bool = true

var _streams: Dictionary = {}
var _voices: Array = []
var _next: int = 0
var _last_played: Dictionary = {}

func _ready() -> void:
	# Menus and the quiz run with PROCESS_MODE_ALWAYS while the world is paused;
	# keeping the players in the same mode means a chime still reaches the end.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in CLIPS.keys():
		var path := DIR + String(id) + ".wav"
		if ResourceLoader.exists(path):
			_streams[id] = load(path)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.bus = "Master"
		add_child(player)
		_voices.append(player)

## Play a clip by id. Unknown ids and muted audio are silent no-ops, so callers
## never need to guard the call.
func play(id: String, volume_offset: float = 0.0) -> void:
	if not enabled:
		return
	if not _streams.has(id):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(id, -1000)) < 25:
		return  # the same blip twice in one frame is just noise
	_last_played[id] = now

	var clip: Dictionary = CLIPS[id]
	var voice: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = _streams[id]
	voice.volume_db = float(clip["volume_db"]) + volume_offset
	var spread := float(clip["spread"])
	voice.pitch_scale = 1.0 if spread <= 0.0 else 1.0 + randf_range(-spread, spread)
	voice.play()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop_all()

func stop_all() -> void:
	for voice in _voices:
		(voice as AudioStreamPlayer).stop()

## True when every clip resolved, so the self-test can prove the assets imported
## and did not silently fall back to silence.
func has_clip(id: String) -> bool:
	return _streams.has(id)

func clip_names() -> Array:
	return _streams.keys()

func voice_count() -> int:
	return _voices.size()
