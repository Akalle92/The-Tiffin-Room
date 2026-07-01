## Ending.gd — Resolution / credits screen shown when all spirit arcs resolve.
extends Control

const TITLE_SCENE := "res://scenes/ui/title.tscn"

@onready var to_title_btn: Button = $Panel/VBox/ToTitleButton

func _ready() -> void:
	to_title_btn.pressed.connect(_on_to_title)
	to_title_btn.grab_focus()

func _on_to_title() -> void:
	# The run is finished; wipe the save so the title offers a fresh start.
	SaveLoad.delete_save()
	get_tree().change_scene_to_file(TITLE_SCENE)
