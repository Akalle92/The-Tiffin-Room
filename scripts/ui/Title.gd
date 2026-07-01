## Title.gd — Main menu shown at boot. New Game / Continue / Quit.
extends Control

const INTRO_SCENE := "res://scenes/intro/intro_cinematic.tscn"
const MAIN_SCENE  := "res://scenes/main.tscn"

@onready var new_game_btn: Button = $Menu/NewGameButton
@onready var continue_btn: Button = $Menu/ContinueButton
@onready var quit_btn: Button     = $Menu/QuitButton
@onready var skip_minigames_toggle: CheckButton = $Menu/SkipMinigamesToggle

func _ready() -> void:
	# GameState._ready() already attempted to load a save at boot.
	continue_btn.disabled = not SaveLoad.has_save()

	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	quit_btn.pressed.connect(_on_quit)

	# Accessibility: honour the persistent "skip mini-games" preference.
	skip_minigames_toggle.button_pressed = GameState.skip_minigames
	skip_minigames_toggle.toggled.connect(_on_skip_minigames_toggled)

	# Focus the most likely action for keyboard/controller players.
	if continue_btn.disabled:
		new_game_btn.grab_focus()
	else:
		continue_btn.grab_focus()

func _on_new_game() -> void:
	SaveLoad.delete_save()
	GameState.reset_new_game()
	get_tree().change_scene_to_file(INTRO_SCENE)

func _on_continue() -> void:
	# The autoloaded GameState already holds the loaded save; jump into the world.
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_quit() -> void:
	get_tree().quit()

func _on_skip_minigames_toggled(pressed: bool) -> void:
	GameState.set_skip_minigames(pressed)
