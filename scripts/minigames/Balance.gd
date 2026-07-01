## Balance.gd — STEADY_HANDS "carry the tiffin level" verb.
## Hold Left/Right to counter a random sway and keep the stack centred until the
## steadiness meter fills. Touching an edge spills it (soft fail, narrative only).
extends MinigameBase

const W := 296.0
const H := 26.0
const REQUIRED := 2.6   # seconds inside the band to win

var _track: Control
var _band: ColorRect
var _marker: ColorRect
var _pos: float = 0.0      # -1 .. 1
var _drift: float = 0.0
var _time_in_band: float = 0.0
var _band_norm: float = 0.35

func _make_body() -> Control:
	_track = Control.new()
	_track.custom_minimum_size = Vector2(W, H)

	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.18, 0.24, 1.0)
	bg.position = Vector2(0, H * 0.5 - 3)
	bg.size = Vector2(W, 6)
	_track.add_child(bg)

	_band = ColorRect.new()
	_band.color = Color(0.3, 0.7, 0.45, 0.5)
	_track.add_child(_band)

	_marker = ColorRect.new()
	_marker.color = Color(0.95, 0.85, 0.4, 1.0)
	_marker.size = Vector2(6, H)
	_track.add_child(_marker)
	return _track

func _setup() -> void:
	title_label.text = "Keep the tiffin level"
	instruction_label.text = "Hold A / D (or the arrow keys) to counter the sway. Keep the stack centred until the meter fills."
	# Assist: a steadier hand gets a wider safe band.
	_band_norm = clampf(0.28 + 0.08 * stat_value, 0.28, 0.68)
	var band_px := _band_norm * (W * 0.5) * 2.0
	_band.position = Vector2(W * 0.5 - band_px * 0.5, 0)
	_band.size = Vector2(band_px, H)
	set_process(true)

func _process(delta: float) -> void:
	if _done:
		return
	_drift += (randf() - 0.5) * delta * 2.4
	_drift = clampf(_drift, -0.9, 0.9)
	var input := Input.get_axis("ui_left", "ui_right")
	_pos += (_drift * 0.55 + input * 1.3) * delta
	_pos = clampf(_pos, -1.0, 1.0)

	if absf(_pos) >= 0.999:
		_lose()
		return

	if absf(_pos) <= _band_norm:
		_time_in_band += delta

	_marker.position = Vector2(W * 0.5 + _pos * (W * 0.5 - 3.0) - 3.0, 0)
	status_label.text = "Steady: %d%%" % int(clampf(_time_in_band / REQUIRED, 0.0, 1.0) * 100.0)

	if _time_in_band >= REQUIRED:
		_win()
