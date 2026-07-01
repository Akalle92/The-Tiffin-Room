## Silence.gd — the "let the silence land" timing verb.
## A cursor sweeps back and forth. Press Space/Enter when it sits inside the quiet
## window — say nothing at exactly the right moment. EMPATHY widens the window.
extends MinigameBase

const W := 296.0
const H := 22.0

var _track: Control
var _zone: ColorRect
var _cursor: ColorRect
var _t: float = 0.0
var _zone_lo: float = 0.4
var _zone_hi: float = 0.6

func _make_body() -> Control:
	_track = Control.new()
	_track.custom_minimum_size = Vector2(W, H)
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.16, 0.22, 1.0)
	bg.size = Vector2(W, H)
	_track.add_child(bg)

	_zone = ColorRect.new()
	_zone.color = Color(0.4, 0.7, 0.5, 0.55)
	_track.add_child(_zone)

	_cursor = ColorRect.new()
	_cursor.color = Color(0.95, 0.85, 0.4, 1.0)
	_cursor.size = Vector2(4, H)
	_track.add_child(_cursor)
	return _track

func _setup() -> void:
	title_label.text = "Let the silence land"
	instruction_label.text = "Some moments ask for stillness, not words. Press Space when the marker rests inside the quiet."
	# Assist: a more attuned player gets a wider window.
	var half := clampf(0.06 + 0.03 * stat_value, 0.06, 0.2)
	var center := 0.5
	_zone_lo = center - half
	_zone_hi = center + half
	_zone.position = Vector2(_zone_lo * W, 0)
	_zone.size = Vector2((_zone_hi - _zone_lo) * W, H)
	set_process(true)

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta * 0.9
	# ping-pong 0..1
	var phase := fmod(_t, 2.0)
	var x := phase if phase <= 1.0 else (2.0 - phase)
	_cursor.position = Vector2(clampf(x, 0.0, 1.0) * (W - 4.0), 0)

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		var x := _cursor.position.x / (W - 4.0)
		if x >= _zone_lo and x <= _zone_hi:
			_win()
		else:
			_lose()
		get_viewport().set_input_as_handled()
