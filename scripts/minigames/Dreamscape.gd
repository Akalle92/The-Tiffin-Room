## Dreamscape.gd — spirit-world traversal verb.
## Carry the luminous "unsaid thing" across a drifting dream-street to the spirit
## on the far side (Arjun's door). Arrow keys move; the dream nudges you off line.
## Reach the goal before the light gutters out. GRIEF steadies the drift.
extends MinigameBase

const W := 296.0
const H := 130.0
const RADIUS := 8.0

var _field: Control
var _dot: ColorRect
var _goal: ColorRect
var _pos: Vector2
var _goal_pos: Vector2
var _drift: Vector2 = Vector2.ZERO
var _time_left: float = 9.0
var _goal_radius: float = 14.0

func _make_body() -> Control:
	_field = Control.new()
	_field.custom_minimum_size = Vector2(W, H)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.09, 0.18, 1.0)
	bg.size = Vector2(W, H)
	_field.add_child(bg)

	_goal = ColorRect.new()
	_goal.color = Color(0.55, 0.5, 0.95, 0.8)
	_field.add_child(_goal)

	_dot = ColorRect.new()
	_dot.color = Color(1.0, 0.9, 0.55, 1.0)
	_dot.size = Vector2(RADIUS, RADIUS)
	_field.add_child(_dot)
	return _field

func _setup() -> void:
	title_label.text = "Carry it to the other side"
	instruction_label.text = "Move with the arrow keys. The dream drifts you off your line — bring the light to the far door before it gutters out."
	# Assist: steadier drift, more time, larger door.
	_goal_radius = clampf(12.0 + 2.5 * stat_value, 12.0, 24.0)
	_time_left = 8.0 + 1.2 * stat_value
	_pos = Vector2(RADIUS, H * 0.5)
	_goal_pos = Vector2(W - _goal_radius, H * 0.5)
	_goal.size = Vector2(_goal_radius, _goal_radius)
	_goal.position = _goal_pos - Vector2(_goal_radius, _goal_radius) * 0.5
	set_process(true)

func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_lose()
		return

	var drift_strength := clampf(1.0 - 0.12 * stat_value, 0.4, 1.0)
	_drift += Vector2(randf() - 0.5, randf() - 0.5) * delta * 60.0 * drift_strength
	_drift = _drift.limit_length(24.0)

	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_pos += (input * 90.0 + _drift) * delta
	_pos.x = clampf(_pos.x, 0.0, W - RADIUS)
	_pos.y = clampf(_pos.y, 0.0, H - RADIUS)
	_dot.position = _pos

	if _pos.distance_to(_goal_pos) <= _goal_radius:
		_win()
		return
	status_label.text = "The light holds for %0.1fs" % _time_left
