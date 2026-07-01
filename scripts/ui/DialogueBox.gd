## DialogueBox.gd — Renders the dialogue UI.
## Attached to the DialogueBox CanvasLayer node in hud.tscn / main.tscn.
## Listens to DialogueManager signals.
extends CanvasLayer

# ---------------------------------------------------------------------------
# NODES (wire in scene)
# ---------------------------------------------------------------------------
@onready var panel: PanelContainer        = $Panel
@onready var portrait: TextureRect        = $Panel/HBox/Portrait
@onready var speaker_label: Label         = $Panel/HBox/VBox/SpeakerName
@onready var dialogue_text: RichTextLabel = $Panel/HBox/VBox/DialogueText
@onready var choices_container: VBoxContainer = $Panel/HBox/VBox/ChoicesContainer
@onready var advance_hint: Label          = $Panel/HBox/VBox/AdvanceHint
@onready var voice_panel: PanelContainer  = $VoicePanel
@onready var voice_label: RichTextLabel   = $VoicePanel/VoiceLabel

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var _current_choices: Array = []
var _choice_buttons: Array[Button] = []
var _voice_timer: float = 0.0
var _voice_visible: bool = false
const VOICE_DISPLAY_DURATION := 4.0
const TEXT_SPEED := 40.0   # characters per second for typewriter
var _full_text: String = ""
var _displayed_chars: int = 0
var _typing: bool = false

# ---------------------------------------------------------------------------
# _READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	hide()
	voice_panel.hide() if voice_panel else null
	_apply_ui_skin()

	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.node_displayed.connect(_on_node_displayed)
	DialogueManager.choices_presented.connect(_on_choices_presented)
	DialogueManager.voice_interjected.connect(_on_voice_interjected)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

# ---------------------------------------------------------------------------
# UI SKIN — apply tiffin-tin frame texture if asset is available
# ---------------------------------------------------------------------------
func _apply_ui_skin() -> void:
	const FRAME_PATH := "res://assets/ui/dialogue_frame.png"
	if not ResourceLoader.exists(FRAME_PATH):
		return  # placeholder PanelContainer style stays until asset is downloaded

	var tex: Texture2D = load(FRAME_PATH)
	var style := StyleBoxTexture.new()
	style.texture = tex
	# Inset the content area so text doesn't overlap the frame border (~12 px each side)
	style.texture_margin_left   = 16.0
	style.texture_margin_right  = 16.0
	style.texture_margin_top    = 10.0
	style.texture_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

	# Voice panel — subtle dark tint (no custom texture, keep readable)
	var voice_style := StyleBoxFlat.new()
	voice_style.bg_color = Color(0.08, 0.07, 0.12, 0.85)
	voice_style.corner_radius_top_left     = 4
	voice_style.corner_radius_top_right    = 4
	voice_style.corner_radius_bottom_left  = 4
	voice_style.corner_radius_bottom_right = 4
	if voice_panel:
		voice_panel.add_theme_stylebox_override("panel", voice_style)

# ---------------------------------------------------------------------------
# PROCESS — typewriter + voice panel fade
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	# Typewriter
	if _typing:
		_displayed_chars = mini(_displayed_chars + int(TEXT_SPEED * delta) + 1, len(_full_text))
		dialogue_text.visible_characters = _displayed_chars
		if _displayed_chars >= len(_full_text):
			_typing = false
			_show_advance_or_choices()

	# Voice panel fade out
	if _voice_visible and voice_panel:
		_voice_timer -= delta
		if _voice_timer <= 0.0:
			_voice_visible = false
			var tween := create_tween()
			tween.tween_property(voice_panel, "modulate:a", 0.0, 0.5)
			tween.tween_callback(voice_panel.hide)

# ---------------------------------------------------------------------------
# INPUT — advance dialogue with Enter / Space / E
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not visible: return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if _typing:
			# Skip typewriter
			_displayed_chars = len(_full_text)
			dialogue_text.visible_characters = -1
			_typing = false
			_show_advance_or_choices()
		elif _current_choices.is_empty():
			DialogueManager.advance()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# SIGNAL HANDLERS
# ---------------------------------------------------------------------------
func _on_dialogue_started(_npc_id: String, _tree_id: String) -> void:
	show()

func _on_node_displayed(node_data: Dictionary) -> void:
	# Speaker name
	var speaker: String = node_data.get("speaker", "")
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""

	# Portrait — DialogueManager injects "portrait_path" (string) from npc_data.json.
	# We also fall back to a Texture2D if set directly on the node dict.
	if portrait:
		var path: String = node_data.get("portrait_path", "")
		var tex: Variant = node_data.get("portrait", null)
		if path != "" and ResourceLoader.exists(path):
			portrait.texture = load(path)
			portrait.visible = true
		elif tex is Texture2D:
			portrait.texture = tex
			portrait.visible = true
		else:
			portrait.visible = false

	# Dialogue text — begin typewriter
	_full_text = node_data.get("text", "")
	_displayed_chars = 0
	_typing = true
	dialogue_text.text = _full_text
	dialogue_text.visible_characters = 0

	# Clear old choices
	_clear_choices()
	advance_hint.visible = false

func _on_choices_presented(choices: Array) -> void:
	# Called after typewriter finishes (via _show_advance_or_choices)
	_current_choices = choices
	# Buttons shown when typing done — see _show_advance_or_choices

func _on_voice_interjected(skill: String, text: String) -> void:
	if voice_panel == null: return
	var col := StatCheck.stat_color(skill).to_html(false)
	voice_label.text = "[color=#%s][b]%s[/b][/color]  %s" % [col, skill, text]
	voice_panel.modulate.a = 1.0
	voice_panel.show()
	_voice_timer   = VOICE_DISPLAY_DURATION
	_voice_visible = true

func _on_dialogue_ended(_npc_id: String) -> void:
	_clear_choices()
	hide()

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _show_advance_or_choices() -> void:
	if not _current_choices.is_empty():
		_build_choice_buttons()
	else:
		advance_hint.visible = true

func _build_choice_buttons() -> void:
	_clear_choices()
	for i in range(_current_choices.size()):
		var choice: Dictionary = _current_choices[i]
		var btn := Button.new()
		var locked: bool = choice.get("locked", false)

		if locked:
			btn.text = "✗ " + choice.get("lock_reason", choice.get("text", ""))
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
		else:
			btn.text = choice.get("text", "")

		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_ALL
		var idx := i
		btn.pressed.connect(func(): _on_choice_pressed(idx))
		choices_container.add_child(btn)
		_choice_buttons.append(btn)

	# Auto-focus first enabled button
	for btn in _choice_buttons:
		if not btn.disabled:
			btn.grab_focus()
			break

func _clear_choices() -> void:
	_current_choices = []
	for btn in _choice_buttons:
		btn.queue_free()
	_choice_buttons.clear()
	advance_hint.visible = false

func _on_choice_pressed(index: int) -> void:
	_clear_choices()
	DialogueManager.choose(index)
