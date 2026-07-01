## Ending.gd — Resolution / credits screen shown when all spirit arcs resolve.
## The epilogue is assembled at runtime from the flags each arc set, so the
## closing lines reflect the fates the player actually chose (and Babulal's payoff).
extends Control

const TITLE_SCENE := "res://scenes/ui/title.tscn"

@onready var to_title_btn: Button = $Panel/VBox/ToTitleButton
@onready var body: RichTextLabel  = $Panel/VBox/Body

func _ready() -> void:
	to_title_btn.pressed.connect(_on_to_title)
	to_title_btn.grab_focus()
	body.text = _build_epilogue()

func _on_to_title() -> void:
	# The run is finished; wipe the save so the title offers a fresh start.
	SaveLoad.delete_save()
	get_tree().change_scene_to_file(TITLE_SCENE)

# ---------------------------------------------------------------------------
# EPILOGUE ASSEMBLY
# ---------------------------------------------------------------------------
func _flag(name: String) -> bool:
	return GameState.get_flag(name, false)

func _build_epilogue() -> String:
	var lines: Array[String] = []
	lines.append("[center]Five spirits lingered over unfinished things. One by one, you carried the words they could not.\n")
	lines.append(_mehta_line())
	lines.append(_raju_line())
	lines.append(_desai_line())
	lines.append(_arjun_line())
	lines.append(_champa_line())
	lines.append("")
	lines.append(_babulal_line())
	lines.append("\n[i]The stalls open again tomorrow. Tonight the lane is quiet — and it remembers you.[/i][/center]")
	return "\n".join(lines)

func _mehta_line() -> String:
	if _flag("mrs_mehta_hardened"):
		return "[b]Mrs. Mehta[/b] read her husband's letter at last — later than she should have had to, the wonder worn thin, but she read it."
	return "[b]Mrs. Mehta[/b] keeps his letter in her sari drawer now, and leaves the window open to the morning again."

func _raju_line() -> String:
	if _flag("raju_went_home"):
		return "[b]Raju[/b] went home. His mother did most of the talking; he did most of the crying, and none of it was the bad kind."
	if _flag("raju_stayed_seen"):
		return "[b]Raju[/b] hasn't called home — not yet. But he sits on the temple steps in daylight now, and the chai stall knows his order."
	if _flag("raju_hardened"):
		return "[b]Raju[/b] called home after a long silence. It landed softer than it should have. It still landed."
	return "[b]Raju[/b] stopped being a rumour on the steps, and started being a boy again."

func _desai_line() -> String:
	if _flag("desai_bittersweet"):
		return "[b]Desai Sahib[/b] filed the honest form. Whether it comes in time for his wife, no one will promise — but no other family will pay for his fear."
	return "[b]Desai Sahib[/b] filed the form he'd hidden from for two years, and stopped charging strangers for his own dread."

func _arjun_line() -> String:
	if _flag("arjun_hardened"):
		return "[b]Arjun[/b]'s father opened the door at last — stiff from being shut so long. Both of them were still behind it."
	return "[b]Arjun[/b] and his father sit on the same side of the door now. Neither says much. Neither has to."

func _champa_line() -> String:
	if _flag("champa_hardened"):
		return "[b]Champa Tai[/b] nearly let 'someday' harden into 'never.' She booked the journey south late — but she booked it."
	return "[b]Champa Tai[/b] took the train south. She'll bring back good mangoes and complain about the heat the whole way home."

func _babulal_line() -> String:
	if _flag("babulal_words_received"):
		return "And you — you finally took [b]Babulal[/b]'s last delivery from his own hands: [i]\"I saw you. All of you. I was proud every single day.\"[/i] Then you set the tin down, and went home."
	if _flag("babulal_finale_played"):
		return "And [b]Babulal[/b] — who taught you the route instead of goodbye — said the thing at last. You carried it the final few steps for him."
	return "And somewhere on the route, your grandfather's own last errand was finally, quietly done."
