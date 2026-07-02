extends Node

## Review harness: renders major game surfaces to PNG so they can be
## eyeballed without a human at the keyboard.
## Run: godot --path . res://tools/capture.tscn -- <what>
## what: title | day | night | game | dialogue | spirit | minigame | ending

var what := "game"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		what = a
	match what:
		"title":
			_add_scene("res://scenes/ui/title.tscn")
			await _snap()
		"ending":
			GameState.set_flag("raju_went_home")
			GameState.set_flag("babulal_words_received")
			_add_scene("res://scenes/ui/ending.tscn")
			await _snap()
		"day":
			GameState.is_night = false
			_add_scene("res://scenes/main.tscn")
			await _snap()
		"night":
			GameState.is_night = true
			for id in GameState.routes:
				GameState.routes[id]["day_state"] = 1
				GameState.routes[id]["spirit_unlocked"] = true
			_add_scene("res://scenes/main.tscn")
			await _snap()
		"dialogue":
			GameState.is_night = false
			_add_scene("res://scenes/main.tscn")
			await _settle(6)
			DialogueManager.start_dialogue("mrs_mehta", "first_meeting")
			await _settle(30)  # let typewriter run a bit
			await _snap(false)
		"spirit":
			GameState.is_night = true
			for id in GameState.routes:
				GameState.routes[id]["day_state"] = 1
				GameState.routes[id]["spirit_unlocked"] = true
			_add_scene("res://scenes/main.tscn")
			await _settle(6)
			DialogueManager.start_dialogue("mrs_mehta", "spirit_intro")
			await _settle(30)
			await _snap(false)
		"minigame":
			_add_scene("res://scenes/main.tscn")
			await _settle(6)
			DialogueManager.start_dialogue("champa", "developing")
			await _settle(10)
			DialogueManager.advance()  # into minigame node if tree starts with text
			await _settle(20)
			await _snap(false)
		_:
			push_error("capture: unknown target " + what)
			get_tree().quit(1)

func _add_scene(path: String) -> void:
	var packed: PackedScene = load(path)
	add_child(packed.instantiate())

func _settle(frames: int) -> void:
	for _i in range(frames):
		await get_tree().process_frame

func _snap(settle_first: bool = true) -> void:
	if settle_first:
		await _settle(6)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := "res://tools/cap_%s.png" % what
	img.save_png(out)
	print("capture: saved ", out)
	get_tree().quit()
