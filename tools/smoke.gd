extends Node

## Autoplay smoke test. Exercises every dialogue tree with random choice
## walks (minigames resolved as both success and failure), then runs the
## full finale sequence inside main.tscn. Exits 0 on pass, 1 on fail.
## Run: godot --headless --path . res://tools/smoke.tscn

const WALKS_PER_TREE := 6
const MAX_STEPS := 300

var _rng := RandomNumberGenerator.new()
var _last_choices: Array = []
var _failures: Array[String] = []
var _save_backed_up := false

func _ready() -> void:
	_backup_save()
	DialogueManager.node_displayed.connect(func(_n): _last_choices = [])
	DialogueManager.choices_presented.connect(func(c): _last_choices = c)
	await _phase_a()
	await _phase_b()
	_restore_save()
	if _failures.is_empty():
		print("SMOKE: PASS — all trees and the finale loop completed cleanly.")
		get_tree().quit(0)
	else:
		for f in _failures:
			print("SMOKE FAIL: ", f)
		get_tree().quit(1)

# ---------------------------------------------------------------------------
# PHASE A — walk every tree of every NPC
# ---------------------------------------------------------------------------
func _phase_a() -> void:
	var db := _load_db()
	for npc_id in db:
		var trees: Dictionary = db[npc_id].get("dialogue_trees", {})
		for tree_id in trees:
			for walk in range(WALKS_PER_TREE):
				SaveLoad.delete_save()
				GameState.reset_new_game()
				_rng.seed = hash(npc_id + tree_id) + walk
				var ok := await _drive_tree(str(npc_id), str(tree_id))
				if not ok:
					_failures.append("%s/%s walk %d did not terminate" % [npc_id, tree_id, walk])
					return
	print("SMOKE: phase A done — every tree walked %d times." % WALKS_PER_TREE)

func _drive_tree(npc_id: String, tree_id: String) -> bool:
	_last_choices = []
	DialogueManager.start_dialogue(npc_id, tree_id)
	if not DialogueManager.is_active:
		return false
	var steps := 0
	while DialogueManager.is_active and steps < MAX_STEPS:
		steps += 1
		await get_tree().process_frame
		if DialogueManager.is_minigame_active:
			DialogueManager.resolve_minigame({
				"success": _rng.randf() < 0.5, "quality": 1.0, "skipped": false})
			continue
		if _last_choices.size() > 0:
			var idx := _pick_choice()
			_last_choices = []
			DialogueManager.choose(idx)
		else:
			DialogueManager.advance()
	return not DialogueManager.is_active

func _pick_choice() -> int:
	var eligible: Array[int] = []
	for i in range(_last_choices.size()):
		var c: Dictionary = _last_choices[i]
		if not c.get("hidden", false) and not c.get("locked", false):
			eligible.append(i)
	if eligible.is_empty():
		for i in range(_last_choices.size()):
			if not _last_choices[i].get("hidden", false):
				eligible.append(i)
	if eligible.is_empty():
		return 0
	return eligible[_rng.randi() % eligible.size()]

# ---------------------------------------------------------------------------
# PHASE B — full loop: main.tscn, day/night, resolve all spirits, finale
# ---------------------------------------------------------------------------
func _phase_b() -> void:
	SaveLoad.delete_save()
	GameState.reset_new_game()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _settle(10)

	GameState.transition_to_night()
	await _settle(90)   # let the 0.6s fade + world swap complete
	GameState.transition_to_day()
	await _settle(120)
	print("SMOKE: phase B — day/night/day cycle survived.")

	# Resolve four spirits silently, then the fifth triggers the finale.
	var ids: Array = GameState.routes.keys()
	for i in range(ids.size() - 1):
		GameState.update_route(ids[i], {"spirit_resolved": true})
	GameState.update_route(ids[ids.size() - 1], {"spirit_resolved": true})

	# DayNightController now fades out (~0.6s + 0.8s) and starts babulal/finale.
	var waited := 0
	while not DialogueManager.is_active and waited < 600:
		waited += 1
		await get_tree().process_frame
	if not DialogueManager.is_active:
		_failures.append("finale dialogue never started after all spirits resolved")
		return
	print("SMOKE: phase B — finale dialogue started.")

	_rng.seed = 20260702
	var steps := 0
	while DialogueManager.is_active and steps < MAX_STEPS:
		steps += 1
		await get_tree().process_frame
		if DialogueManager.is_minigame_active:
			DialogueManager.resolve_minigame({"success": true, "quality": 1.0, "skipped": false})
			continue
		if _last_choices.size() > 0:
			var idx := _pick_choice()
			_last_choices = []
			DialogueManager.choose(idx)
		else:
			DialogueManager.advance()
	if DialogueManager.is_active:
		_failures.append("finale dialogue did not terminate")
		return
	print("SMOKE: phase B — finale completed; ending scene change is next (verified separately).")

func _settle(frames: int) -> void:
	for _i in range(frames):
		await get_tree().process_frame

# ---------------------------------------------------------------------------
# SAVE PROTECTION — don't clobber the player's real save
# ---------------------------------------------------------------------------
func _backup_save() -> void:
	if FileAccess.file_exists("user://save_game.cfg"):
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path("user://save_game.cfg"),
			ProjectSettings.globalize_path("user://save_game.cfg.smokebak"))
		_save_backed_up = true

func _restore_save() -> void:
	SaveLoad.delete_save()
	if _save_backed_up:
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path("user://save_game.cfg.smokebak"),
			ProjectSettings.globalize_path("user://save_game.cfg"))

func _load_db() -> Dictionary:
	var f := FileAccess.open("res://data/dialogue/npc_data.json", FileAccess.READ)
	var result: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return result if result is Dictionary else {}
