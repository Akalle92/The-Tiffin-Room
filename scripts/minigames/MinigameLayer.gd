## MinigameLayer.gd — Bridges DialogueManager to the mini-game overlays.
## Instanced once in main.tscn. Listens for minigame_requested, runs the right
## overlay, and reports the result back so dialogue can resume.
extends CanvasLayer

const SCENES := {
	"nose_board": preload("res://scenes/minigames/nose_board.tscn"),
	"balance":    preload("res://scenes/minigames/balance.tscn"),
	"route":      preload("res://scenes/minigames/route.tscn"),
	"dreamscape": preload("res://scenes/minigames/dreamscape.tscn"),
	"prep":       preload("res://scenes/minigames/prep.tscn"),
	"silence":    preload("res://scenes/minigames/silence.tscn"),
}

var _active: Node = null

func _ready() -> void:
	layer = 20
	DialogueManager.minigame_requested.connect(_on_minigame_requested)

func _on_minigame_requested(config: Dictionary) -> void:
	# Accessibility skip, or an unknown type: pass gently so nothing is blocked.
	if config.get("skip", false):
		_resolve({"success": true, "skipped": true})
		return
	var type: String = config.get("type", "")
	if not SCENES.has(type):
		push_warning("MinigameLayer: unknown mini-game '%s' — auto-passing." % type)
		_resolve({"success": true, "skipped": true})
		return

	var mg := SCENES[type].instantiate() as MinigameBase
	if mg == null:
		push_warning("MinigameLayer: '%s' scene is not a MinigameBase — auto-passing." % type)
		_resolve({"success": true, "skipped": true})
		return
	mg.config = config
	mg.finished.connect(_on_minigame_finished)
	add_child(mg)
	_active = mg

func _on_minigame_finished(result: Dictionary) -> void:
	_active = null
	_resolve(result)

func _resolve(result: Dictionary) -> void:
	DialogueManager.resolve_minigame(result)
