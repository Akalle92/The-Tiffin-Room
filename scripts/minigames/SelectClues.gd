## SelectClues.gd — "Select the correct subset" verb.
## Powers both the NOSE scent-deduction board and Champa's chai/tiffin matching.
## Config keys (all optional, sensible defaults provided):
##   title, instruction        — framing text
##   clues: [{text, correct}]  — the options to pick from
##   assist_text               — line shown when the stat is high
extends MinigameBase

var _clues: Array = []
var _checks: Array[CheckBox] = []
var _attempts: int = 0

func _make_body() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	return v

func _setup() -> void:
	title_label.text = config.get("title", "Read the room")
	instruction_label.text = config.get("instruction",
		"Some of these are true tells. Select the ones that matter, then confirm.")
	_clues = config.get("clues", _default_clues())

	var v := body as VBoxContainer
	for c in _clues:
		var cb := CheckBox.new()
		cb.text = str(c.get("text", ""))
		cb.add_theme_font_size_override("font_size", 9)
		v.add_child(cb)
		_checks.append(cb)

	var confirm := Button.new()
	confirm.text = config.get("confirm_text", "Confirm")
	confirm.add_theme_font_size_override("font_size", 10)
	confirm.pressed.connect(_on_confirm)
	v.add_child(confirm)

	# Stat-as-assist: a sharp nose highlights the real tells.
	if stat_value >= 3:
		status_label.text = config.get("assist_text",
			"Your instinct is sharp — the true tells are marked.")
		for i in _clues.size():
			if bool(_clues[i].get("correct", false)):
				_checks[i].add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	elif stat_value >= 2:
		status_label.text = "Hint: at least one obvious clue is a decoy."

func _on_confirm() -> void:
	var correct := true
	for i in _clues.size():
		var want := bool(_clues[i].get("correct", false))
		if _checks[i].button_pressed != want:
			correct = false
			break
	if correct:
		_win()
		return
	_attempts += 1
	if _attempts >= 2:
		_lose()
	else:
		status_label.text = "Not quite. Look again — trust the note under the note."

func _default_clues() -> Array:
	return [
		{"text": "The rice is overcooked — she wasn't paying attention.", "correct": true},
		{"text": "There are two teacups set out, not one.", "correct": true},
		{"text": "The tea stall down the lane changed its menu.", "correct": false},
		{"text": "She mentioned the weather twice.", "correct": false},
	]
