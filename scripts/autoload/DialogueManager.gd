## DialogueManager.gd — Autoloaded dialogue engine.
## Loads npc_data.json at startup. Other nodes call start_dialogue() to begin
## a conversation; the manager emits signals that DialogueBox.gd listens to.
extends Node

# ---------------------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------------------
signal dialogue_started(npc_id: String, tree_id: String)
signal node_displayed(node_data: Dictionary)
signal choices_presented(choices: Array)
signal voice_interjected(skill: String, text: String)
signal dialogue_ended(npc_id: String)
## Emitted when a node asks to run a mini-game. MinigameLayer handles it and
## calls resolve_minigame() with the result.
signal minigame_requested(config: Dictionary)

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var is_active: bool = false
## True while a mini-game overlay is running (dialogue is paused, input frozen).
var is_minigame_active: bool = false
var _npc_db: Dictionary = {}           # parsed npc_data.json
var _skill_voices: Dictionary = {}     # parsed skill_voices.json

var _current_npc_id: String = ""
var _current_tree_id: String = ""
var _current_nodes: Dictionary = {}    # id -> node dict for active tree
var _current_node_id: String = ""
var _pending_choice_effects: Dictionary = {}  # queued until player picks

# ---------------------------------------------------------------------------
# READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	_load_data()

func _load_data() -> void:
	# Load NPC dialogue database
	var npc_file := FileAccess.open("res://data/dialogue/npc_data.json", FileAccess.READ)
	if npc_file:
		var result: Variant = JSON.parse_string(npc_file.get_as_text())
		if result is Dictionary:
			_npc_db = result
		else:
			push_error("DialogueManager: failed to parse npc_data.json")
		npc_file.close()
	else:
		push_error("DialogueManager: npc_data.json not found")

	# Load skill voice interjection bank
	var sv_file := FileAccess.open("res://data/dialogue/skill_voices.json", FileAccess.READ)
	if sv_file:
		var result2: Variant = JSON.parse_string(sv_file.get_as_text())
		if result2 is Dictionary:
			_skill_voices = result2
		sv_file.close()

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

## Start a conversation.
## npc_id   — matches a key in npc_data.json
## tree_id  — which dialogue tree to run (e.g. "first_meeting")
##            if empty, auto-selects the appropriate tree for this NPC's state
func start_dialogue(npc_id: String, tree_id: String = "") -> void:
	if is_active:
		push_warning("DialogueManager: already in dialogue, ignoring start request")
		return
	if not _npc_db.has(npc_id):
		push_error("DialogueManager: unknown npc_id '%s'" % npc_id)
		return

	_current_npc_id = npc_id
	_current_tree_id = tree_id if tree_id != "" else _pick_tree(npc_id)

	var npc_data: Dictionary = _npc_db[npc_id]
	if not npc_data.get("dialogue_trees", {}).has(_current_tree_id):
		push_error("DialogueManager: tree '%s' not found for npc '%s'" % [_current_tree_id, npc_id])
		return

	var tree: Dictionary = npc_data["dialogue_trees"][_current_tree_id]
	_current_nodes = tree.get("nodes", {})
	_current_node_id = tree.get("start", "")

	is_active = true
	dialogue_started.emit(npc_id, _current_tree_id)
	_display_current_node()

## Call this when the player selects a choice (by index).
func choose(choice_index: int) -> void:
	if not is_active:
		return
	var current_node: Dictionary = _current_nodes.get(_current_node_id, {})
	var choices: Array = current_node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		push_error("DialogueManager: invalid choice index %d" % choice_index)
		return

	var choice: Dictionary = choices[choice_index]
	_apply_choice_effects(choice)

	# Resolve next node (stat-check aware)
	var next_id: String = _resolve_next(choice)
	_advance_to(next_id)

## Call this to advance past a node with no choices (auto-advance).
func advance() -> void:
	if not is_active or is_minigame_active:
		return
	var current_node: Dictionary = _current_nodes.get(_current_node_id, {})
	if current_node.get("choices", []).size() > 0:
		# Node has choices — shouldn't be calling advance()
		return
	# Mini-game node: launch the overlay instead of advancing. The text has
	# already been shown as narrative setup; resolve_minigame() advances after.
	var minigame: Variant = current_node.get("minigame", null)
	if minigame is Dictionary and not minigame.is_empty():
		_launch_minigame(minigame)
		return
	var next_id: String = current_node.get("next", "")
	_advance_to(next_id)

# ---------------------------------------------------------------------------
# MINI-GAMES
# ---------------------------------------------------------------------------
func _launch_minigame(minigame: Dictionary) -> void:
	is_minigame_active = true
	var stat: String = minigame.get("stat", "")
	var config: Dictionary = minigame.duplicate()
	config["stat_value"] = GameState.get_stat(stat) if stat != "" else 0
	config["skip"] = GameState.skip_minigames
	minigame_requested.emit(config)

## Called by MinigameLayer when the overlay finishes.
## result = {"success": bool, "quality": float, "skipped": bool}
func resolve_minigame(result: Dictionary) -> void:
	if not is_minigame_active:
		return
	is_minigame_active = false
	var node: Dictionary = _current_nodes.get(_current_node_id, {})
	var success: bool = result.get("success", true)
	# Skipped mini-games are treated as a gentle pass so nobody is ever blocked.
	if result.get("skipped", false):
		success = true
	var eff_key: String = "success_effects" if success else "fail_effects"
	_apply_effects(node.get(eff_key, {}))
	var next_key: String = "success_next" if success else "fail_next"
	var next_id: String = node.get(next_key, node.get("next", ""))
	_advance_to(next_id)

# ---------------------------------------------------------------------------
# INTERNAL — TREE NAVIGATION
# ---------------------------------------------------------------------------
func _pick_tree(npc_id: String) -> String:
	## Auto-select the correct tree based on route progress.
	var route: Dictionary = GameState.get_route(npc_id)
	var trust: int = route.get("trust_level", 0)
	var spirit_unlocked: bool = route.get("spirit_unlocked", false)
	var is_night: bool = GameState.is_night

	if is_night and spirit_unlocked:
		var spirit_resolved: bool = route.get("spirit_resolved", false)
		if spirit_resolved:
			return "spirit_aftermath"
		var spirit_state: int = route.get("spirit_state", 0)
		if spirit_state >= 1:
			return "spirit_resolution"
		return "spirit_intro"

	var day_state: int = route.get("day_state", 0)
	if day_state == 0:
		return "first_meeting"
	elif trust >= 2:
		return "trust"
	else:
		return "developing"

func _display_current_node() -> void:
	if _current_node_id == "" or not _current_nodes.has(_current_node_id):
		_end_dialogue()
		return

	var node: Dictionary = _current_nodes[_current_node_id]

	# Emit skill-voice interjections BEFORE the main line
	for interjection in node.get("voice_interjections", []):
		var skill: String = interjection.get("skill", "")
		var req: int = interjection.get("requires_stat", 0)
		if GameState.check_stat(skill, req):
			voice_interjected.emit(skill, interjection.get("text", ""))

	# Inject portrait path from NPC-level data so DialogueBox can load the texture.
	# npc_data.json stores portrait_day / portrait_spirit at the NPC root, not per-node.
	var node_emit: Dictionary = node.duplicate()
	var npc_top: Dictionary = _npc_db.get(_current_npc_id, {})
	var portrait_key: String = "portrait_spirit" if GameState.is_night else "portrait_day"
	node_emit["portrait_path"] = npc_top.get(portrait_key, "")

	node_displayed.emit(node_emit)

	# Build the list of available choices (filter by stat check)
	var choices: Array = node.get("choices", [])
	if choices.size() > 0:
		var presented: Array = []
		for choice in choices:
			var stat_check: Variant = choice.get("stat_check", null)
			var entry: Dictionary = {
				"id":          choice.get("id", ""),
				"text":        choice.get("text", ""),
				"locked":      false,
				"lock_reason": "",
			}
			if stat_check is Dictionary:
				var skill: String  = stat_check.get("skill", "")
				var threshold: int = stat_check.get("threshold", 0)
				if not GameState.check_stat(skill, threshold):
					entry["locked"] = true
					entry["lock_reason"] = "[%s %d] Not high enough." % [skill, threshold]
			presented.append(entry)
		choices_presented.emit(presented)
	# If no choices, caller should call advance() after displaying text

func _resolve_next(choice: Dictionary) -> String:
	var stat_check: Variant = choice.get("stat_check", null)
	if stat_check is Dictionary:
		var skill: String  = stat_check.get("skill", "")
		var threshold: int = stat_check.get("threshold", 0)
		if not GameState.check_stat(skill, threshold):
			return choice.get("fail_next", choice.get("next", ""))
	return choice.get("next", "")

func _advance_to(next_id: String) -> void:
	if next_id == "" or next_id == "END":
		_end_dialogue()
		return
	_current_node_id = next_id
	_display_current_node()

func _apply_choice_effects(choice: Dictionary) -> void:
	_apply_effects(choice.get("effects", {}))

func _apply_effects(effects: Dictionary) -> void:
	if effects.is_empty():
		return

	# Route updates
	var route_update: Variant = effects.get("route_update", null)
	if route_update is Dictionary:
		GameState.update_route(_current_npc_id, route_update)

	# Stat modifications
	var stat_modify: Variant = effects.get("stat_modify", null)
	if stat_modify is Dictionary:
		for stat in stat_modify:
			GameState.modify_stat(stat, stat_modify[stat])

	# Flags — single ("set_flag": "name") or multiple ("set_flags": ["a", "b"])
	var set_flag: Variant = effects.get("set_flag", null)
	if set_flag is String and set_flag != "":
		GameState.set_flag(set_flag)
	var set_flags: Variant = effects.get("set_flags", null)
	if set_flags is Array:
		for f in set_flags:
			if f is String and f != "":
				GameState.set_flag(f)

	# Notes
	var add_note: Variant = effects.get("add_note", null)
	if add_note is String and add_note != "":
		GameState.add_note(_current_npc_id, add_note)

func _end_dialogue() -> void:
	var npc_id: String = _current_npc_id
	is_active = false
	is_minigame_active = false
	_current_npc_id = ""
	_current_tree_id = ""
	_current_nodes = {}
	_current_node_id = ""
	dialogue_ended.emit(npc_id)

# ---------------------------------------------------------------------------
# SKILL VOICE LOOKUP
# ---------------------------------------------------------------------------
## Returns a random interjection line for a given skill, or "" if none.
func get_skill_voice_line(skill: String) -> String:
	if not _skill_voices.has(skill):
		return ""
	var lines: Array = _skill_voices[skill]
	if lines.is_empty():
		return ""
	return lines[randi() % lines.size()]
