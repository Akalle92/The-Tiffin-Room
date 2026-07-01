## Route.gd — STREET_SENSE "read the street / plan the route" verb.
## Pick the safe way through. A keen street sense reveals the tell on each option.
## Config: options: [{text, safe, tell}]
extends MinigameBase

var _options: Array = []

func _make_body() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	return v

func _setup() -> void:
	title_label.text = config.get("title", "Choose your way through")
	instruction_label.text = config.get("instruction",
		"One of these routes is safe to walk right now. Read the street and pick it.")
	_options = config.get("options", _default_options())

	var reveal := stat_value >= 2
	if reveal:
		status_label.text = "Street sense: you can read the tell on each route."

	var v := body as VBoxContainer
	for i in _options.size():
		var opt: Dictionary = _options[i]
		var btn := Button.new()
		var label := str(opt.get("text", ""))
		if reveal and opt.get("tell", "") != "":
			label += "  —  " + str(opt.get("tell", ""))
		btn.text = label
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(296, 0)
		btn.add_theme_font_size_override("font_size", 9)
		var idx := i
		btn.pressed.connect(func(): _choose(idx))
		v.add_child(btn)

func _choose(index: int) -> void:
	if bool(_options[index].get("safe", false)):
		_win()
	else:
		_lose()

func _default_options() -> Array:
	return [
		{"text": "The main bazaar road — fastest.", "safe": false, "tell": "Two men watching from the shade. Not regulars."},
		{"text": "The quiet gully behind the temple.", "safe": true, "tell": "Empty this time of day. Room to talk."},
		{"text": "Past the chai stall, up the stairs.", "safe": false, "tell": "The stall shutters at six; someone's loitering."},
	]
