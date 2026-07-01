extends Node2D

const MAIN_SCENE := "res://scenes/main.tscn"
const VIDEO_PATH := "res://assets/video/intro_cinematic.ogv"
const FADE_DURATION := 1.2

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var skip_hint: Label = $SkipHint

var _skipped := false


func _ready() -> void:
	# Fade in from black
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, FADE_DURATION)

	# Load and play video if it exists
	if ResourceLoader.exists(VIDEO_PATH):
		var stream := load(VIDEO_PATH)
		video_player.stream = stream
		video_player.play()
		video_player.finished.connect(_on_video_finished)
	else:
		# Video not yet imported — skip straight to game after short delay
		push_warning("IntroCinematic: video not found at %s, skipping." % VIDEO_PATH)
		await get_tree().create_timer(0.5).timeout
		_go_to_main()


func _unhandled_input(event: InputEvent) -> void:
	if _skipped:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_skip()


func _skip() -> void:
	if _skipped:
		return
	_skipped = true
	video_player.stop()
	_go_to_main()


func _on_video_finished() -> void:
	_go_to_main()


func _go_to_main() -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, FADE_DURATION * 0.5)
	await tween.finished
	get_tree().change_scene_to_file(MAIN_SCENE)
