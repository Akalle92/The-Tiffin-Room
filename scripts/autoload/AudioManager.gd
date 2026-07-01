## AudioManager — Autoload singleton for music and SFX.
## Registered in project.godot as "AudioManager".
## Listens to GameState day/night signals and crossfades music automatically.
extends Node

# ---------------------------------------------------------------------------
# AUDIO ASSET PATHS
# ---------------------------------------------------------------------------
# Music: download as .m4a, convert to .ogg with ffmpeg (see download_portraits.py)
const MUSIC_DAY   := "res://assets/audio/music_day.ogg"
const MUSIC_NIGHT := "res://assets/audio/music_night.ogg"
# SFX: .mp3 files — Godot 4 imports these natively, no conversion needed
const SFX_TIFFIN  := "res://assets/audio/sfx_tiffin_clink.mp3"
const SFX_BELL    := "res://assets/audio/sfx_bicycle_bell.mp3"

const MUSIC_VOLUME_DB   := -8.0
const SFX_VOLUME_DB     := 0.0
const CROSSFADE_DURATION := 2.0

# ---------------------------------------------------------------------------
# NODES
# ---------------------------------------------------------------------------
@onready var _music_a: AudioStreamPlayer = $MusicA
@onready var _music_b: AudioStreamPlayer = $MusicB
@onready var _sfx_player: AudioStreamPlayer = $SFX

var _active_music: AudioStreamPlayer   # currently playing track
var _inactive_music: AudioStreamPlayer # fading out

# ---------------------------------------------------------------------------
# _READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	_music_a.bus = "Music"
	_music_b.bus = "Music"
	_sfx_player.bus = "SFX"

	_active_music   = _music_a
	_inactive_music = _music_b

	# Connect day/night signals
	if GameState.has_signal("day_started"):
		GameState.day_started.connect(_on_day_started)
		GameState.night_started.connect(_on_night_started)

	# Start day music immediately
	_play_track(MUSIC_DAY)

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
func play_sfx_tiffin() -> void:
	_play_sfx(SFX_TIFFIN)

func play_sfx_bell() -> void:
	_play_sfx(SFX_BELL)

func set_music_volume(db: float) -> void:
	_music_a.volume_db = db
	_music_b.volume_db = db

# ---------------------------------------------------------------------------
# SIGNAL HANDLERS
# ---------------------------------------------------------------------------
func _on_day_started(_day_number: int) -> void:
	_crossfade_to(MUSIC_DAY)

func _on_night_started(_day_number: int) -> void:
	_crossfade_to(MUSIC_NIGHT)

# ---------------------------------------------------------------------------
# INTERNALS
# ---------------------------------------------------------------------------
func _play_track(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: track not found: %s" % path)
		return
	var stream: AudioStream = load(path)
	_active_music.stream = stream
	_active_music.volume_db = MUSIC_VOLUME_DB
	_active_music.play()

func _crossfade_to(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: track not found: %s" % path)
		return

	# Swap active/inactive players
	var next := _inactive_music
	var prev := _active_music
	_active_music   = next
	_inactive_music = prev

	# Load and start new track silently
	next.stream = load(path)
	next.volume_db = -80.0
	next.play()

	# Crossfade
	var tween := create_tween().set_parallel(true)
	tween.tween_property(next, "volume_db", MUSIC_VOLUME_DB, CROSSFADE_DURATION)
	tween.tween_property(prev, "volume_db", -80.0, CROSSFADE_DURATION)
	tween.chain().tween_callback(prev.stop)

func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	_sfx_player.stream = load(path)
	_sfx_player.volume_db = SFX_VOLUME_DB
	_sfx_player.play()
