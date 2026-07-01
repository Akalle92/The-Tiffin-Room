## MinigameBase.gd — Shared scaffold for every optional gameplay verb.
## A mini-game is a Control overlay that runs while dialogue is paused. It
## always offers a Skip button (accessibility) and reports a result via the
## `finished` signal: {"success": bool, "quality": float, "skipped": bool}.
##
## Subclasses override _make_body() (build the interactive widget) and _setup()
## (configure text + logic using `config` / `stat_value`), then call _win()/_lose().
class_name MinigameBase
extends Control

signal finished(result: Dictionary)

## Set by MinigameLayer BEFORE the node enters the tree.
var config: Dictionary = {}
var stat_value: int = 0

var _done: bool = false

# Common UI (built in _ready)
var panel: PanelContainer
var content: VBoxContainer
var title_label: Label
var instruction_label: Label
var body: Control
var status_label: Label
var skip_button: Button

func _ready() -> void:
	stat_value = int(config.get("stat_value", 0))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	style.border_color = Color(0.7, 0.55, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color(1, 0.87, 0.55))
	content.add_child(title_label)

	instruction_label = Label.new()
	instruction_label.add_theme_font_size_override("font_size", 9)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.custom_minimum_size = Vector2(296, 0)
	content.add_child(instruction_label)

	body = _make_body()
	if body:
		content.add_child(body)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(296, 0)
	content.add_child(status_label)

	skip_button = Button.new()
	skip_button.text = "Skip mini-game"
	skip_button.add_theme_font_size_override("font_size", 9)
	skip_button.pressed.connect(_on_skip)
	content.add_child(skip_button)

	_setup()

# ---------------------------------------------------------------------------
# VIRTUALS — override in subclasses
# ---------------------------------------------------------------------------
func _make_body() -> Control:
	return null

func _setup() -> void:
	pass

# ---------------------------------------------------------------------------
# RESULT HELPERS
# ---------------------------------------------------------------------------
func _win(quality: float = 1.0) -> void:
	_finish({"success": true, "quality": quality})

func _lose() -> void:
	_finish({"success": false, "quality": 0.0})

func _on_skip() -> void:
	_finish({"success": true, "skipped": true})

func _finish(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	finished.emit(result)
	queue_free()
