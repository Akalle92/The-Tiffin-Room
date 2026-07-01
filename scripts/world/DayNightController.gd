## DayNightController.gd — Manages swapping between day and night worlds.
## Lives as a node inside main.tscn. Listens to GameState signals and
## replaces the active world scene + adjusts lighting accordingly.
extends Node

# ---------------------------------------------------------------------------
# SCENE PATHS
# ---------------------------------------------------------------------------
const CITY_DAY_SCENE   := "res://scenes/world/city_day.tscn"
const CITY_NIGHT_SCENE := "res://scenes/world/city_night.tscn"
const ENDING_SCENE     := "res://scenes/ui/ending.tscn"

# ---------------------------------------------------------------------------
# LIGHTING
# ---------------------------------------------------------------------------
## Day:   warm turmeric-amber
## Night: cool indigo with lantern-gold tint
const COLOR_DAY   := Color(1.0,  0.92, 0.75, 1.0)
const COLOR_DUSK  := Color(0.85, 0.55, 0.35, 1.0)
const COLOR_NIGHT := Color(0.18, 0.15, 0.32, 1.0)

# ---------------------------------------------------------------------------
# REFERENCES (set by main.tscn via @onready or manual assignment)
# ---------------------------------------------------------------------------
@onready var world_container: Node2D   = $"../WorldContainer"
@onready var canvas_modulate: CanvasModulate = $"../CanvasModulate"
@onready var transition_overlay: ColorRect   = $"../TransitionOverlay" if $"../".has_node("TransitionOverlay") else null

var _current_world: Node2D = null
var _transitioning: bool   = false

## Finale orchestration: when the fifth spirit resolves we let the closing
## dialogue finish, then play Babulal's payoff beat before the credits roll.
var _pending_finale: bool = false
var _finale_active: bool  = false

# ---------------------------------------------------------------------------
# _READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	GameState.day_started.connect(_on_day_started)
	GameState.night_started.connect(_on_night_started)
	GameState.game_completed.connect(_on_game_completed)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	# Load the correct world for current state
	if GameState.is_night:
		_load_world(CITY_NIGHT_SCENE)
	else:
		_load_world(CITY_DAY_SCENE)
		_apply_day_modulate(GameState.time_of_day)

# ---------------------------------------------------------------------------
# PROCESS — smooth daylight colour shift
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if _transitioning or GameState.is_night:
		return
	_apply_day_modulate(GameState.time_of_day)

func _apply_day_modulate(t: float) -> void:
	if canvas_modulate == null: return
	# 0.0–0.7: day colour; 0.7–1.0: lerp toward dusk
	if t < 0.7:
		canvas_modulate.color = COLOR_DAY
	else:
		var f := (t - 0.7) / 0.3
		canvas_modulate.color = lerp(COLOR_DAY, COLOR_DUSK, f)

# ---------------------------------------------------------------------------
# TRANSITION CALLBACKS
# ---------------------------------------------------------------------------
func _on_night_started(_day: int) -> void:
	await _fade_out()
	_load_world(CITY_NIGHT_SCENE)
	if canvas_modulate:
		canvas_modulate.color = COLOR_NIGHT
	await _fade_in()

func _on_day_started(_day: int) -> void:
	await _fade_out()
	_load_world(CITY_DAY_SCENE)
	if canvas_modulate:
		canvas_modulate.color = COLOR_DAY
	await _fade_in()

# ---------------------------------------------------------------------------
# WORLD LOADING
# ---------------------------------------------------------------------------
func _load_world(scene_path: String) -> void:
	# Remove existing world
	if _current_world != null:
		_current_world.queue_free()
		_current_world = null

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("DayNightController: could not load '%s'" % scene_path)
		return

	_current_world = packed.instantiate() as Node2D
	world_container.add_child(_current_world)

# ---------------------------------------------------------------------------
# FADE HELPERS  (uses TransitionOverlay ColorRect)
# ---------------------------------------------------------------------------
func _fade_out() -> void:
	_transitioning = true
	if transition_overlay == null: return
	transition_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(transition_overlay, "color:a", 1.0, 0.6)
	await tween.finished

func _fade_in() -> void:
	if transition_overlay:
		var tween := create_tween()
		tween.tween_property(transition_overlay, "color:a", 0.0, 0.8)
		await tween.finished
		transition_overlay.visible = false
	_transitioning = false

# ---------------------------------------------------------------------------
# DEBUG
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	# Rest until morning: only at night and never mid-dialogue/transition.
	if event.is_action_pressed("rest"):
		if GameState.is_night and not _transitioning and not DialogueManager.is_active:
			GameState.transition_to_day()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_night_debug"):
		if GameState.is_night:
			GameState.transition_to_day()
		else:
			GameState.transition_to_night()

# ---------------------------------------------------------------------------
# ENDING / FINALE
# ---------------------------------------------------------------------------
## Fired when the fifth spirit resolves. The resolving dialogue is still on
## screen, so we defer: wait for it to close, then play Babulal's finale beat.
func _on_game_completed() -> void:
	_pending_finale = true
	if not DialogueManager.is_active:
		_play_finale()

## The player's own arc: having carried everyone else's last words, they finally
## receive Babulal's. Runs as a normal dialogue tree ("babulal"/"finale") so it
## reuses the whole dialogue UI; on close we roll the choice-reflective ending.
func _play_finale() -> void:
	if _finale_active:
		return
	_pending_finale = false
	_finale_active = true
	await _fade_out()
	if GameState.is_night and canvas_modulate:
		canvas_modulate.color = COLOR_NIGHT
	await _fade_in()
	DialogueManager.start_dialogue("babulal", "finale")

func _on_dialogue_ended(npc_id: String) -> void:
	# Closing dialogue for the fifth spirit just ended — cue Babulal.
	if _pending_finale and not _finale_active:
		_play_finale()
		return
	# Babulal's finale just ended — roll credits.
	if _finale_active and npc_id == "babulal":
		_finale_active = false
		await _fade_out()
		get_tree().change_scene_to_file(ENDING_SCENE)
