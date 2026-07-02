## DayNightClock.gd — A small radial clock showing time of day.
## Draw a dial: sun arc for day, moon for night.
extends Control

const RADIUS := 6.0
const SUN_COLOR   := Color(1.0, 0.85, 0.3)
const MOON_COLOR  := Color(0.7, 0.65, 0.95)
const TRACK_COLOR := Color(0.2, 0.18, 0.15)

func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2 + 4, RADIUS * 2 + 4)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := Vector2(RADIUS + 2, RADIUS + 2)
	# Track
	draw_arc(center, RADIUS, 0, TAU, 32, TRACK_COLOR, 1.5)
	# Arc progress
	if GameState.is_night:
		draw_arc(center, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * 0.3, 24, MOON_COLOR, 1.5)
		# Moon symbol
		draw_circle(center, 2.5, MOON_COLOR)
	else:
		var t   := GameState.time_of_day
		var end := -PI * 0.5 + TAU * t
		draw_arc(center, RADIUS, -PI * 0.5, end, 32, SUN_COLOR, 1.5)
		# Sun dot
		var sun_pos := center + Vector2(cos(-PI * 0.5 + TAU * t), sin(-PI * 0.5 + TAU * t)) * RADIUS
		draw_circle(sun_pos, 2, SUN_COLOR)
